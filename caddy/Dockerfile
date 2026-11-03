FROM --platform=$BUILDPLATFORM golang:alpine AS builder
ARG TARGETOS
ARG TARGETARCH
ARG VERSION
WORKDIR /build
RUN apk add --no-cache git mailcap \
  && CGO_ENABLED=0 GOOS= GOARCH= go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH /go/bin/xcaddy build ${VERSION} \
  --output /rootfs/usr/bin/caddy \
  --with github.com/caddy-dns/cloudflare
# distroless 无 shell，在构建阶段准备目录与权限
RUN mkdir -p /rootfs/config/caddy /rootfs/data/caddy /rootfs/etc/caddy /rootfs/usr/share/caddy \
  && cp /etc/mime.types /rootfs/etc/mime.types \
  && chown -R 65532:65532 /rootfs/config /rootfs/data

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /rootfs/ /
RUN ["caddy", "version"]
ENV XDG_CONFIG_HOME=/config
ENV XDG_DATA_HOME=/data
VOLUME /config
VOLUME /data
EXPOSE 80 443 443/udp 2019
WORKDIR /srv
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
