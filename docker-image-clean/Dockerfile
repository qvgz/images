FROM alpine:latest
RUN apk add --no-cache bash docker-cli
ADD --chmod=755 https://raw.githubusercontent.com/qvgz/sh/master/containers/docker-image-clean.sh /usr/local/bin/docker-image-clean.sh
ENTRYPOINT ["/usr/local/bin/docker-image-clean.sh"]
