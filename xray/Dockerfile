FROM golang:alpine

WORKDIR /tmp/xray

RUN set -eux \
    ; apk add --no-cache git \
    && git clone https://github.com/XTLS/Xray-core.git . \
    && go build -o xray -trimpath -ldflags "-s -w -buildid=" ./main

FROM alpine:latest

COPY --chmod=0755 --from=0 /tmp/xray/xray /usr/bin/xray

RUN set -eux \
    ; apk add --no-cache ca-certificates

CMD [ "/usr/bin/xray", "-config", "/etc/xray/config.json" ]
