# log-trigger

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/r/qvgz/log-trigger)

常驻任务：监控文件新增行，匹配字符串（支持 `*` `?` 通配）在时间窗口内达到次数时执行命令，带抑制时间。脚本构建时取自上游 [qvgz/sh ops/log-trigger.sh](https://github.com/qvgz/sh/blob/master/ops/log-trigger.sh)，说明见 [log-trigger.sh.md](https://github.com/qvgz/sh/blob/master/ops/log-trigger.sh.md)。

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `FILE` | 必须 | 监控文件（容器内路径） |
| `PATTERN` | 必须 | 匹配字符串，`*` 任意字符串、`?` 单字节，其他按字面 |
| `CMD` | 必须 | 触发时 `bash -c` 执行，可用 `$FILE`、`$MATCH_LINE` |
| `HITS` | `1` | 窗口内命中多少次算一次触发 |
| `WINDOW` | `60` | 计数窗口（秒），`0` 不清零 |
| `SUPPRESS` | `60` | 两次执行最短间隔（秒） |
| `TIMEOUT` | `60` | 命令超时（秒），`0` 不限制 |
| `TZ` | `Asia/Shanghai` | 日志时区，命令同样继承 |

```bash
# 挂载日志所在目录（非单个文件）；60 秒内命中 10 次触发，5 分钟内只执行一次
docker run -d --name log-trigger --restart unless-stopped \
  -v /var/log/app:/logs:ro \
  -e FILE=/logs/app.log -e PATTERN='OutOfMemory' -e HITS=10 -e SUPPRESS=300 \
  -e CMD='curl -fsS -m 10 -H "Content-Type: application/json" --data "{\"text\":\"$MATCH_LINE\"}" "$WEBHOOK"' \
  -e WEBHOOK=https://example.com/hook \
  qvgz/log-trigger
docker logs -f log-trigger
```

## 说明

- 须挂载日志所在目录：单文件挂载绑定的是原 inode，宿主轮转（mv 后新建）后容器内看不到新文件，监控静默失效；截断（copytruncate）不受影响。
- 镜像 tail 为 coreutils 9.x，上游所述 CentOS 7 tail 8.22 遇 overlayfs 放弃跟踪的问题不存在：overlayfs、fuse 等被视为远程文件系统，自动改为 1 秒轮询，轮转、删除重建、截断均正常跟踪；ext4、xfs、btrfs、tmpfs 用 inotify，即时感知。
- 轮询模式（远程文件系统，或启动时 `FILE` 尚不存在）下，轮转后 1～3 秒切换到新文件（实测），切换后从头读取不丢行；但新文件在此期间又被轮转或截断，其中的行会丢失。启动前确保文件已存在且位于本地文件系统，即可使用 inotify。
- 命令在本容器内执行，镜像含 bash、coreutils、grep、sed、curl 及 busybox；`systemctl`、`docker` 等不可用，需要时自行扩展镜像或挂载。
- 以 tini 作 PID 1，`docker stop` 即时退出；tail 异常退出时脚本返回 `2`，可配合 `--restart` 重启。
- 执行日志写标准输出，tail 诊断写标准错误，均可用 `docker logs` 查看；命中计数与抑制时间只保存在内存，容器重启即重置。
