FROM --platform=$BUILDPLATFORM golang:alpine AS builder
ARG TARGETOS
ARG TARGETARCH
ARG VERSION
WORKDIR /build
RUN apk add --no-cache git
RUN CGO_ENABLED=0 go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH /go/bin/xcaddy build ${VERSION} \
  --output /usr/bin/caddy \
  --with github.com/caddy-dns/cloudflare

FROM alpine:latest
RUN apk add --no-cache ca-certificates mailcap tzdata
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
RUN set -eux; \
  mkdir -p /config/caddy /data/caddy /etc/caddy /usr/share/caddy; \
  apk add --no-cache --virtual .setcap libcap-utils; \
  setcap cap_net_bind_service=+ep /usr/bin/caddy; \
  apk del --no-network .setcap
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data
VOLUME /config
VOLUME /data
EXPOSE 80 443 443/udp 2019
WORKDIR /srv
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
