# rancher-arm64

Out of tree build rancher on arm64 platform(like raspberry pi 3b+)

```shell
sudo docker run -d --restart=unless-stopped -p 80:80 -p 443:443 rancherpi/rancher:v2.0.8-arm64
```

## Supported versions

We track rancher's release in corresponding branch with patches

Packages used to build image is host in another [repo](https://github.com/rancherpi/arm64-packages)

* [v2.0.8](https://github.com/rancherpi/rancher-arm64/tree/v2.0.8-arm64) with rke kubernetes v1.11.2-rancher1-1, check [releases](https://github.com/rancherpi/rancher-arm64/releases)
* v2.1.0 is working in progress

## Missing Features

* Pipeline (WIP)
* Embeded ELK for logging

## Known issuses

* Cannel is working but calico node is yellow with readiness probe 503
* Calico is not tested
* "Import existing cluster" can only import arm64 k8s
* Nginx ingress is not work due to [resty issuse #1152](https://github.com/openresty/lua-nginx-module/issues/1152), but should be fixed with [custom patches](https://github.com/debayang/lua-nginx-module/commit/543a722ec585d0cacb5223122c6f7e252ca75edd) which is WIP

## Credits

* [rancher.com](https://rancher.com)
* [ags131](https://github.com/ags131) thanks for his [gist](https://gist.github.com/ags131/7bdde11c932ef7a54f44c6decbfd88b8)

## Screenshot

![rancher-node-added](https://user-images.githubusercontent.com/354668/46616529-5263e980-cb4d-11e8-9cb2-ecce04af8cc7.png)

## License

[Apache License 2.0](https://github.com/kubernetes/ingress-nginx/blob/master/LICENSE)
