FROM golang:alpine

ARG XCADDY_GO_BUILD_FLAGS='-trimpath -ldflags "-s -w -buildid="'

WORKDIR /tmp/xcaddy

RUN set -eux \
    ; go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest \
    && /go/bin/xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive \
    --with github.com/mholt/caddy-ratelimit

FROM alpine:latest

COPY --chmod=0755 --from=0 /tmp/xcaddy/caddy /usr/bin/caddy

RUN set -eux \
    ; apk add --no-cache ca-certificates mailcap libcap \
    ; mkdir -p /config/caddy /data/caddy /etc/caddy /usr/share/caddy

ENV XDG_CONFIG_HOME /config
ENV XDG_DATA_HOME /data

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 2019

CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
