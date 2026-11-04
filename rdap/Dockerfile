FROM alpine:latest
RUN apk add --no-cache bash coreutils curl gawk jq tzdata whois
ADD --chmod=755 https://raw.githubusercontent.com/qvgz/sh/master/ops/rdap.sh /usr/local/bin/rdap.sh
# 默认清单改为 /data/rdap.sh.txt（上游为脚本同目录）
RUN sed -i 's|^default_list=.*|default_list=/data/rdap.sh.txt|' /usr/local/bin/rdap.sh \
    && grep -qx 'default_list=/data/rdap.sh.txt' /usr/local/bin/rdap.sh
WORKDIR /data
ENTRYPOINT ["/usr/local/bin/rdap.sh"]
