#!/bin/bash

source $(dirname $0)/scripts/common
source $(dirname $0)/scripts/version

ROOT_DIR=$(cd $(dirname $0); pwd)

echo ${ROOT_DIR}

[ ! -d dist ] && mkdir dist
[ ! -d bin ] && mkdir bin
[ ! -d rancher-repos ] && mkdir rancher-repos
[ ! -d .states ] && mkdir .states

cd rancher-repos

git_apply() {
    (
        cd $1
        tag="$2-rancher-${CO_BRANCH}"
        if [ -n "$3" ]; then
            tag="$3"
        fi
        log_info "tag: ${tag}"
        git tag -d "${tag}" || true
        if [ -f ${ROOT_DIR}/patch/$1.diff ]; then
            git apply ${ROOT_DIR}/patch/$1.diff
            git add .
            git commit -m "patch for rancher ${CO_BRANCH}"
        fi
        git tag -a "${tag}" -m "for rancher ${CO_BRANCH}"
    )
}

check-skip() {
    if test -f "${ROOT_DIR}/.states/$1-${CO_BRANCH}-done"; then
        log_info "$1 was built"
        return 0
    else
        log_info "building $1"
        return 1
    fi
}

mark-done() {
    touch ${ROOT_DIR}/.states/$1-${CO_BRANCH}-done
}

export REPO=${REPO}
export ARCH=arm64
export DAPPER_MODE=bind

build-hyperkube() {
    if check-skip hyperkube ; then return 0; fi

    git_ensure https://github.com/rancher/hyperkube
    reset hyperkube "${RANCHER_HYPERKUBE_VERSION}"
    log_info patching
    git_apply hyperkube "${RANCHER_HYPERKUBE_VERSION}"

    log_info build
    (
        cd hyperkube
        docker build -t ${REPO}/hyperkube${RR_SUFFIX}:${RANCHER_HYPERKUBE_VERSION} . && \
        docker push ${REPO}/hyperkube${RR_SUFFIX}:${RANCHER_HYPERKUBE_VERSION}
    ) && mark-done hyperkube
}

build-flannel-cni() {
    if check-skip flannel-cni ; then return 0; fi

    git_ensure https://github.com/coreos/flannel-cni
    reset flannel-cni "${FLANNEL_CNI_VERSION}"
    log_info patching
    git_apply flannel-cni "${FLANNEL_CNI_VERSION}" "${FLANNEL_CNI_VERSION}${RR_SUFFIX}"

    log_info build
    (
        cd flannel-cni
        make build-image
    ) && mark-done flannel-cni
}

build-rke-tools() {
    if check-skip rke-tools ; then return 0; fi

    git_ensure https://github.com/rancher/rke-tools.git
    reset rke-tools "${RKE_TOOLS_VERSION}"
    log_info patching
    git_apply rke-tools "${RKE_TOOLS_VERSION}"

    log_info build
    (
        cd rke-tools
        make build && make package && \
        docker tag ${REPO}/rke-tools:${RKE_TOOLS_VERSION}-rancher-${CO_BRANCH} ${REPO}/rke-tools${RR_SUFFIX}:${RKE_TOOLS_VERSION} && \
        docker push ${REPO}/rke-tools:${RKE_TOOLS_VERSION}-rancher-${CO_BRANCH} && \
        docker push ${REPO}/rke-tools${RR_SUFFIX}:${RKE_TOOLS_VERSION}
    ) && mark-done rke-tools
}

build-share-mnt() {
    if check-skip share-mnt ; then return 0; fi

    git_ensure https://github.com/rancher/share-mnt.git
    reset share-mnt "${SHARE_MNT_VERSION}"
    log_info patching
    git_apply share-mnt "${SHARE_MNT_VERSION}"

    log_info build
    (
        cd share-mnt
        make
        cp dist/share-mnt.tar.gz ${ROOT_DIR}/dist/
    ) && mark-done share-mnt
}

build-telemetry() {
    if check-skip telemetry ; then return 0; fi

    git_ensure https://github.com/rancher/telemetry.git
    reset telemetry "${TELEMETRY_VERSION}"
    log_info patching
    git_apply telemetry "${TELEMETRY_VERSION}"

    log_info build
    (
        cd telemetry
        make
        cp bin/telemetry ${ROOT_DIR}/dist/
    ) && mark-done telemetry
}

build-machine-package() {
    if check-skip machine-package ; then return 0; fi

    git_ensure https://github.com/rancher/machine-package.git
    reset machine-package "${CATTLE_MACHINE_VERSION}"
    log_info patching
    git_apply machine-package "${CATTLE_MACHINE_VERSION}"

    log_info build
    (
        cd machine-package
        make
        cp dist/artifacts/docker-machine.tar.gz ${ROOT_DIR}/dist/
    ) && mark-done machine-package
}

build-loglevel() {
    if check-skip loglevel ; then return 0; fi

    git_ensure https://github.com/rancher/loglevel.git
    reset loglevel "${LOGLEVEL_VERSION}"
    log_info patching
    git_apply loglevel "${LOGLEVEL_VERSION}" "${LOGLEVEL_VERSION}"

    log_info build
    (
        cd loglevel
        make
        cp dist/artifacts/loglevel-arm64-${LOGLEVEL_VERSION}*.tar.gz ${ROOT_DIR}/dist/
    ) && mark-done loglevel
}

build-helm() {
    if check-skip helm ; then return 0; fi

    CURT_DIR=$(pwd)
    [ -d helm ] || mkdir -p helm/src/k8s.io
    (
        log_info prepare
        cd helm
        export CGO_ENABLED=0
        export GOBIN=$(pwd)/bin GOPATH=$(pwd)
        export PATH=$GOBIN:$PATH

        cd src/k8s.io
        git_ensure https://github.com/rancher/helm.git
        reset helm "${CATTLE_HELM_VERSION}"
        log_info patching
        git_apply helm "${CATTLE_HELM_VERSION}"

        log_info build
        cd helm
        make release
        cp bin/* ${ROOT_DIR}/dist/

    ) && mark-done helm
}

build-ingress-nginx() {
    if check-skip ingress-nginx ; then return 0; fi

    git_ensure https://github.com/rancher/ingress-nginx.git
    reset ingress-nginx "${INGRESS_NGINX_VERSION}"
    log_info patching
    git_apply ingress-nginx "${INGRESS_NGINX_VERSION}" "${INGRESS_NGINX_VERSION}${RR_SUFFIX}"

    log_info build
    (
        cd ingress-nginx
        export CROSS="${ARCH}"
        make build && make package
        source scripts/version
        docker push "${REPO}/nginx-ingress-controller:${TAG}"
    ) && mark-done ingress-nginx
}

build-rancher() {
    if check-skip rancher ; then return 0; fi

    git_ensure https://github.com/rancher/rancher.git
    reset rancher "${RANCHER_TAG}"
    log_info patching
    git_apply rancher "${RANCHER_TAG}" "${RANCHER_TAG}${RR_SUFFIX}"

    log_info build
    (
        cd rancher
        make build && make package \
        && docker push ${REPO}/rancher:${RANCHER_TAG}${RR_SUFFIX} \
        && docker push ${REPO}/rancher-agent:${RANCHER_TAG}${RR_SUFFIX} \
        && cp bin/* ${ROOT_DIR}/bin/
    ) && mark-done rancher
}

build-hyperkube && \
build-flannel-cni && \
build-rke-tools && \
build-share-mnt && \
build-telemetry && \
build-machine-package && \
build-loglevel && \
build-helm && \
build-ingress-nginx

log_info "<= building rancher =>"
build-rancher
