# fail2ban

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/fail2ban)

基于 alpine，构建时取上游 [fail2ban](https://github.com/fail2ban/fail2ban) release 源码安装。示范 [compose.yaml](./compose.yaml)、[jail.d/sshd.local](./jail.d/sshd.local)、[jail.d/nginx.local](./jail.d/nginx.local)。

| 路径 | 说明 |
| --- | --- |
| `/etc/fail2ban/jail.d/*.local` | jail 配置，挂载此目录即可；上游 `jail.conf` 默认 `paths-debian.conf` |
| `/etc/fail2ban/filter.d/*.local`、`action.d/*.local` | 自定义过滤器、动作，按文件挂载，避免覆盖内置 |
| `/var/lib/fail2ban` | 封禁数据库，持久化后重启恢复封禁 |

日志输出到容器 stdout；查看状态：`docker exec fail2ban fail2ban-client status [jail]`，解封：`fail2ban-client set <jail> unbanip <IP>`。

## 宿主机要求

镜像内 `iptables`/`ip6tables` 为 nf_tables 后端，另含 `nft`、`ipset`，无 legacy iptables。宿主机须同为 nf_tables 后端，否则规则与宿主机（含 Docker）不在同一套表。

| 系统 | 最低版本 | 说明 |
| --- | --- | --- |
| Debian | 10 (buster) | 起默认 `iptables-nft`；若手动切到 legacy，用 `update-alternatives --set iptables /usr/sbin/iptables-nft` 切回 |
| CentOS / RHEL | 8 | 起只提供 `iptables-nft`；CentOS 7 仅 legacy（iptables 1.4.21），不支持 |

宿主机执行 `iptables -V`，输出含 `(nf_tables)` 即可用。

## 注意
+ 须 `network_mode: host` 与 `NET_ADMIN`、`NET_RAW`，规则写入宿主机防火墙
+ 无 systemd，不支持 `backend = systemd`；宿主机日志在 journald 时需开启 rsyslog 写文件，或用 `polling` 读文件
+ 封禁 Docker 发布端口的访问需 `chain = DOCKER-USER`（INPUT 链对容器端口无效）
+ 挂载的日志路径须与 `logpath` 一致；文件不存在时 jail 启动失败

## 参考
[fail2ban](https://github.com/fail2ban/fail2ban)、[crazy-max/docker-fail2ban](https://github.com/crazy-max/docker-fail2ban)、[Debian Wiki nftables](https://wiki.debian.org/nftables)、[RHEL 8 网络变更](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/considerations_in_adopting_rhel_8/networking_considerations-in-adopting-rhel-8)、[RHBZ#1873474](https://bugzilla.redhat.com/show_bug.cgi?id=1873474)
