FROM ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest AS otel
FROM alpine:latest

RUN apk add bash nmap bind-tools curl
RUN apk add --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing grpcurl

COPY --from=otel /telemetrygen /bin/.

ENTRYPOINT ["/bin/sleep", "infinity"]
