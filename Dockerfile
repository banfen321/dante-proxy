FROM alpine:3.21 AS builder

ARG DANTE_VER=1.4.4
ARG DANTE_SHA=1973c7732f1f9f0a4c0ccf2c1ce462c7c25060b25643ea90f9b98f53a813faec

RUN apk add --no-cache build-base curl linux-pam-dev

RUN install -d /src && \
    curl -sSL "https://www.inet.no/dante/files/dante-${DANTE_VER}.tar.gz" \
         -o /src/dante.tar.gz && \
    echo "${DANTE_SHA}  /src/dante.tar.gz" | sha256sum -c && \
    tar -C /src -xzf /src/dante.tar.gz && \
    cd "/src/dante-${DANTE_VER}" && \
    ac_cv_func_sched_setscheduler=no \
    CFLAGS="-Wno-implicit-function-declaration -D_GNU_SOURCE" \
    ./configure --prefix=/usr --sysconfdir=/etc && \
    make -j"$(nproc)" && \
    make install DESTDIR=/install

FROM alpine:3.21

RUN apk add --no-cache linux-pam iproute2 shadow

COPY --from=builder /install/usr/sbin/sockd /usr/sbin/sockd
COPY sockd.conf.tmpl /etc/sockd.conf.tmpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1080

ENTRYPOINT ["/entrypoint.sh"]
