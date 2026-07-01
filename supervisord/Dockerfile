FROM --platform=$BUILDPLATFORM golang:alpine AS builder
ARG VERSION
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0 \
  GOOS=$TARGETOS \
  GOARCH=$TARGETARCH
WORKDIR /src
RUN apk add --no-cache git
RUN git clone --branch ${VERSION} --depth 1 https://github.com/ochinchina/supervisord.git .
RUN go build -trimpath -buildvcs=false -ldflags="-s -w -buildid= -X main.Version=${VERSION}" -o /usr/local/bin/supervisord .

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=builder /usr/local/bin/supervisord /usr/local/bin/supervisord
ENTRYPOINT ["/usr/local/bin/supervisord"]
