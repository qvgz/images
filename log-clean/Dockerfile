FROM alpine:latest
# 脚本依赖 GNU date/find/truncate/mktemp、flock、gzip
RUN apk add --no-cache bash coreutils findutils flock gzip tzdata
ADD --chmod=755 https://raw.githubusercontent.com/qvgz/sh/master/ops/log-clean.sh /usr/local/bin/log-clean.sh
# 上游按 Asia/Shanghai 计算昨日日期
ENV TZ=Asia/Shanghai
ENTRYPOINT ["/usr/local/bin/log-clean.sh"]
