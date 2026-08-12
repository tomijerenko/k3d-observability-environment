FROM alpine:latest

RUN apk add tcpdump

ENTRYPOINT ["tcpdump", "-i", "any", "-A"]
