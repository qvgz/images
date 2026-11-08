FROM alpine:latest
# 脚本依赖 GNU tail（-F --pid --max-unchanged-stats）/timeout（-k，进程组信号）、grep（--line-buffered）、sed；busybox 版本不满足；curl 供 CMD 发通知
# tini 作 PID 1：bash 为 PID 1 时忽略 SIGTERM，docker stop 需等超时 KILL
RUN apk add --no-cache bash coreutils curl grep sed tini tzdata
ADD --chmod=755 https://raw.githubusercontent.com/qvgz/sh/master/ops/log-trigger.sh /usr/local/bin/log-trigger.sh
# 上游默认 TZ=Asia/Shanghai，此处显式设置便于覆盖
ENV TZ=Asia/Shanghai
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/log-trigger.sh"]
