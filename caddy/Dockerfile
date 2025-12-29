FROM --platform=$BUILDPLATFORM golang:alpine AS builder
ARG TARGETOS
ARG TARGETARCH
ARG VERSION
WORKDIR /build
RUN apk add --no-cache git
RUN CGO_ENABLED=0 GOOS= GOARCH= go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH /go/bin/xcaddy build ${VERSION} \
    --output /usr/bin/caddy \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive

FROM alpine:latest
RUN apk add --no-cache ca-certificates mailcap libcap tzdata
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
RUN set -eux; \
    mkdir -p /config/caddy /data/caddy /etc/caddy /usr/share/caddy; \
    setcap cap_net_bind_service=+ep /usr/bin/caddy
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data
VOLUME /config
VOLUME /data
EXPOSE 80 443 443/udp 2019
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]