FROM alpine:3.21

RUN apk add --no-cache stunnel openssl

COPY stunnel.conf.tmpl /etc/stunnel/stunnel.conf.tmpl
COPY entrypoint.sh     /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
