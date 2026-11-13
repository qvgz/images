FROM alpine:latest
# 上游 tag（如 1.1.1），为空取最新
ARG VERSION
RUN apk add --no-cache python3 iptables ip6tables nftables ipset tzdata
RUN set -eu; \
    apk add --no-cache --virtual .build curl py3-setuptools; \
    v=${VERSION:-$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/fail2ban/fail2ban/releases/latest)}; \
    v=${v##*/}; \
    mkdir /tmp/src; cd /tmp/src; \
    curl -fsSL "https://github.com/fail2ban/fail2ban/archive/refs/tags/$v.tar.gz" | tar -xz --strip-components=1; \
    python3 setup.py -q install --without-tests --optimize=1; \
    cd /; rm -rf /tmp/src; \
    apk del .build; \
    rm -rf /root/.cache; \
    fail2ban-server -V
# 日志输出到容器 stdout
RUN printf '[Definition]\nlogtarget = STDOUT\n' > /etc/fail2ban/fail2ban.d/00-docker.conf
ENV TZ=Asia/Shanghai
VOLUME /var/lib/fail2ban
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD ["fail2ban-client", "ping"]
ENTRYPOINT ["fail2ban-server", "-f", "-x", "-v", "start"]
