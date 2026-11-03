FROM alpine:latest
RUN apk add --no-cache bash coreutils curl docker-cli tzdata
COPY docker-health.sh /usr/local/bin/docker-health.sh
RUN chmod +x /usr/local/bin/docker-health.sh
ENTRYPOINT ["/usr/local/bin/docker-health.sh"]
