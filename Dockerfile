FROM alpine:3.22
LABEL maintainer="Travis Quinnelly"
LABEL maintainer_url="https://github.com/tquizzle/"
LABEL clamav_version="1.4.2-r1"

RUN apk update && apk upgrade && \
    apk add --no-cache pv ca-certificates clamav clamav-libunrar tzdata && \
    apk add --upgrade apk-tools libcurl openssl busybox && \
    rm -rf /var/cache/apk/*

ENV SCANDIR=/scan
COPY scan.sh /scan.sh
COPY clamd.conf /etc/clamav/clamd.conf

ENTRYPOINT ["sh", "/scan.sh"]
