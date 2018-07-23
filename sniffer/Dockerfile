FROM alpine
RUN apk add --no-cache tcpdump coreutils
ENV args -v
ENTRYPOINT /usr/sbin/tcpdump $args