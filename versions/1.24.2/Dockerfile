# ==============================================================================
# Stage 1: Builder
# ==============================================================================
ARG ALPINE_VERSION=3.23.3

FROM alpine:${ALPINE_VERSION} AS builder

# Default values (overridden by GitHub Actions during build)
ARG UNBOUND_VERSION=1.24.2
ARG UNBOUND_SHA256=44e7b53e008a6dcaec03032769a212b46ab5c23c105284aa05a4f3af78e59cdb

ENV UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-${UNBOUND_VERSION}.tar.gz

WORKDIR /tmp/src

RUN apk upgrade --no-cache && \
    apk add --no-cache \
    build-base \
    bison \
    flex \
    curl \
    expat-dev \
    libevent-dev \
    nghttp2-dev \
    openssl-dev \
    protobuf-c-dev \
    fstrm-dev

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
        --enable-dnstap \
        --enable-tfo-server \
        --enable-tfo-client \
        --enable-event-api \
        --enable-subnet && \
    make -j$(nproc) install

# ==============================================================================
# Stage 2: Final Runtime Image
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# Re-declare ARG in Stage 2 to use it for labels
ARG UNBOUND_VERSION=1.24.2

LABEL org.opencontainers.image.version="${UNBOUND_VERSION}" \
      org.opencontainers.image.title="alpine-unbound" \
      org.opencontainers.image.description="A validating, recursive, and caching DNS resolver built strictly from source on Alpine"

WORKDIR /opt/unbound

COPY --from=builder /opt/unbound /opt/unbound

# Install dependencies (includes ldns for the drill health check)
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    ca-certificates \
    wget \
    expat \
    fstrm \
    ldns \
    libevent \
    nghttp2-libs \
    openssl \
    protobuf-c && \
    addgroup -S _unbound && \
    adduser -S -G _unbound -H -h /opt/unbound _unbound

COPY entrypoint.sh /entrypoint.sh
COPY unbound.conf /opt/unbound/etc/unbound/unbound.conf

RUN chmod +x /entrypoint.sh

ENV PATH=/opt/unbound/sbin:"$PATH"

# Expose port 5335 for integration with ad-blockers
EXPOSE 5335/tcp
EXPOSE 5335/udp

# Using drill (via ldns) to health-check the custom port
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD drill -p 5335 cloudflare.com @127.0.0.1 > /dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
