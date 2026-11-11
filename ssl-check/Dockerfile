FROM alpine:latest
RUN apk add --no-cache bash coreutils gawk openssl tzdata
ADD --chmod=755 https://raw.githubusercontent.com/qvgz/sh/master/ops/ssl-check.sh /usr/local/bin/ssl-check.sh
# 默认清单改为 /data/ssl-check.sh.txt（上游为脚本同目录）
RUN sed -i 's|^default_list=.*|default_list=/data/ssl-check.sh.txt|' /usr/local/bin/ssl-check.sh \
    && grep -qx 'default_list=/data/ssl-check.sh.txt' /usr/local/bin/ssl-check.sh
WORKDIR /data
ENTRYPOINT ["/usr/local/bin/ssl-check.sh"]
