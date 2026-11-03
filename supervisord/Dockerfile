FROM alpine:latest
ARG VERSION
ARG TARGETARCH
RUN apk add --no-cache tzdata
ADD --chmod=755 https://github.com/ochinchina/supervisord/releases/download/${VERSION}/supervisord_linux_${TARGETARCH} /usr/local/bin/supervisord
ENTRYPOINT ["/usr/local/bin/supervisord"]
