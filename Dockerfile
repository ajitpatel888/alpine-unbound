# ==============================================================================
# Stage 1: Builder
# ==============================================================================
ARG ALPINE_VERSION=3.23.3
FROM alpine:${ALPINE_VERSION} AS builder

ARG UNBOUND_VERSION=1.24.2
ARG UNBOUND_SHA256=44e7b53e008a6dcaec03032769a212b46ab5c23c105284aa05a4f3af78e59cdb
ENV UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz

WORKDIR /tmp/src

RUN apk upgrade --no-cache && \
    apk add --no-cache \
    build-base bison flex curl expat-dev libevent-dev \
    nghttp2-dev openssl-dev protobuf-c-dev fstrm-dev \
    hiredis-dev libsodium-dev python3-dev swig

RUN curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz && \
    echo "${UNBOUND_SHA256}  unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    addgroup -S _unbound && \
    adduser -S -G _unbound -H -s /dev/null _unbound && \
    ./configure \
        --disable-dependency-tracking \
        --prefix=/opt/unbound \
        --with-pthreads \
        --with-username=_unbound \
        --with-libevent \
        --with-libnghttp2 \
        --with-libhiredis \
        --with-pythonmodule \
        --with-pyunbound \
        --enable-dnstap \
        --enable-dnscrypt \
        --enable-cachedb \
        --enable-subnet \
        --enable-tfo-server \
        --enable-tfo-client \
        --enable-event-api \
        --enable-pie \
        --enable-relro-now && \
    make -j$(nproc) install

# ==============================================================================
# Stage 2: Final Runtime Image
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

ARG UNBOUND_VERSION=1.24.2

LABEL org.opencontainers.image.version="${UNBOUND_VERSION}" \
      org.opencontainers.image.title="alpine-unbound" \
      org.opencontainers.image.description="A complete, fully-featured validating, recursive, and caching DNS resolver built strictly from source on Alpine"

WORKDIR /opt/unbound

COPY --from=builder /opt/unbound /opt/unbound

# Install runtime dependencies including those for Python, Redis, and DNSCrypt
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    ca-certificates wget expat fstrm ldns libevent nghttp2-libs \
    openssl protobuf-c hiredis libsodium python3 tini tzdata su-exec && \
    addgroup -S _unbound && \
    adduser -S -G _unbound -H -h /opt/unbound _unbound && \
    mkdir -p /opt/unbound/etc/unbound/conf.d \
             /opt/unbound/etc/unbound/zones.d \
             /opt/unbound/etc/unbound/certs.d \
             /opt/unbound/etc/unbound/log.d && \
    chown -R _unbound:_unbound /opt/unbound/etc/unbound

COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /opt/unbound/sbin/healthcheck.sh
COPY unbound.conf /opt/unbound/etc/unbound/unbound.conf

RUN chmod +x /entrypoint.sh /opt/unbound/sbin/healthcheck.sh

ENV PATH=/opt/unbound/sbin:"$PATH"

EXPOSE 5335/tcp
EXPOSE 5335/udp

HEALTHCHECK --interval=30s --timeout=15s --start-period=10s --retries=3 \
    CMD /opt/unbound/sbin/healthcheck.sh

# Use tini as the init system to properly handle OS signals
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
