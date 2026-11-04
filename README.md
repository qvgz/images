# docker-images
一些自用的 docker image

actions 每月 1 号自动构建最新版本镜像推送至 [Docker Hub](https://hub.docker.com/u/qvgz)；
不依赖上游镜像手动触发构建。

| 镜像 | 说明 |
| --- | --- |
| [caddy](./caddy) | Caddy Web 服务器，含 Cloudflare DNS 插件 |
| [supervisord](./supervisord) | Go 版 supervisord 进程管理器 |
| [docker-health](./docker-health) | 自动重启 unhealthy 容器并通知 |
| [rdap](./rdap) | WHOIS/RDAP 查询域名到期时间 |
