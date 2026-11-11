# docker-images
一些自用的 docker image

actions 每月 1 号自动构建最新版本镜像推送至 [Docker Hub](https://hub.docker.com/u/qvgz)；
不依赖上游镜像手动触发构建。

| 镜像 | 说明 |
| --- | --- |
| [caddy](./caddy) | Caddy Web 服务器，含 Cloudflare DNS 插件 |
| [supervisord](./supervisord) | Go 版 supervisord 进程管理器 |
| [docker-health](./docker-health) | 自动重启 unhealthy 容器并通知 |
| [docker-image-clean](./docker-image-clean) | 一次性清理旧镜像，每个仓库保留最近 N 个 |
| [rdap](./rdap) | WHOIS/RDAP 查询域名到期时间 |
| [ssl-check](./ssl-check) | 查询 HTTPS 证书信息及到期时间 |
| [log-clean](./log-clean) | 一次性备份并清空日志、删除过期备份 |
| [log-trigger](./log-trigger) | 监控日志新增行，命中达到次数执行命令 |
| [watchexec](./watchexec) | 监听文件变更执行命令 |
