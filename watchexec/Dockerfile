FROM alpine:latest
# 上游 tag（如 v2.8.0），为空取最新
ARG VERSION
ARG TARGETARCH
RUN apk add --no-cache bash coreutils curl docker-cli tzdata
RUN set -eu; \
    case "$TARGETARCH" in amd64) arch=x86_64 ;; arm64) arch=aarch64 ;; *) echo "不支持的架构 $TARGETARCH"; exit 1 ;; esac; \
    v=${VERSION:-$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/watchexec/watchexec/releases/latest)}; \
    v=${v##*/}; v=${v#v}; \
    name=watchexec-$v-$arch-unknown-linux-musl; \
    url=https://github.com/watchexec/watchexec/releases/download/v$v/$name.tar.xz; \
    cd /tmp; \
    curl -fsSLo w.tar.xz "$url"; \
    echo "$(curl -fsSL "$url.sha256")  w.tar.xz" | sha256sum -c -; \
    tar -xJf w.tar.xz "$name/watchexec"; \
    install -m 755 "$name/watchexec" /usr/local/bin/watchexec; \
    rm -rf /tmp/*; \
    watchexec --version
COPY --chmod=755 watchexec.sh /usr/local/bin/watchexec.sh
ENV TZ=Asia/Shanghai
ENTRYPOINT ["/usr/local/bin/watchexec.sh"]
