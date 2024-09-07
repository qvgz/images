FROM golang:alpine AS builder

RUN apk add --no-cache --update git gcc rust

WORKDIR /supervisord

RUN set -eux \
    ; apk add --no-cache git \
    && git clone https://github.com/ochinchina/supervisord.git . \
    && go build -o /usr/local/bin/supervisord -trimpath -ldflags "-s -w -buildid=" github.com/ochinchina/supervisord

FROM alpine

COPY --from=builder /usr/local/bin/supervisord /usr/local/bin/supervisord

ENTRYPOINT ["/usr/local/bin/supervisord"]
