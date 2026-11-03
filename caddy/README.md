# Caddy

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/caddy)

使用 [xcaddy - Custom Caddy Builder](https://github.com/caddyserver/xcaddy) 构建并推送最新版本 [caddy](https://github.com/caddyserver/caddy) 镜像。

基础镜像 `gcr.io/distroless/static:nonroot`（无 shell，以 65532:65532 运行）  
配置文件路径 /etc/caddy/Caddyfile，示范 [Caddyfile](./Caddyfile)、[compose.yaml](./compose.yaml)  
文档参考 [The Caddyfile](https://caddyserver.com/docs/caddyfile)

添加插件如下：
+ [Cloudflare module for Caddy](https://github.com/caddy-dns/cloudflare)

## 注意
+ 非 root 绑定 80/443 依赖 `net.ipv4.ip_unprivileged_port_start=0`：Docker 20.10+ 非 host 网络默认已设置；不支持 `network_mode: host`
+ `/data`、`/config` 用命名卷时自动继承 65532 属主；改用目录挂载需先 `chown -R 65532:65532 ./data ./config`。挂载的 Caddyfile、站点目录需对 65532 可读
+ 未持久化 `/data` 时，重建容器会重新申请证书，可能触发 ACME 频率限制

参考：
[caddy-docker](https://github.com/caddyserver/caddy-docker/tree/master)
