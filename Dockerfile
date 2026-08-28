FROM alpine:latest AS builder

ARG DOGECOIN_VERSION=1.14.9

RUN apk add --no-cache \
    autoconf automake build-base git libevent-dev libtool \
    boost-dev openssl-dev pkgconf wget zeromq-dev miniupnpc-dev

WORKDIR /build
RUN wget -O dogecoin.tar.gz "https://github.com/dogecoin/dogecoin/archive/refs/tags/v${DOGECOIN_VERSION}.tar.gz" \
 && tar -xzf dogecoin.tar.gz --strip-components=1 \
 && ./autogen.sh \
 && ./configure --prefix=/usr/local --without-gui --disable-tests --disable-bench --disable-wallet \
 && make -j"$(nproc)" \
 && make install DESTDIR=/out

FROM alpine:latest

RUN apk add --no-cache \
    bash ca-certificates curl libstdc++ boost-system boost-filesystem \
    boost-thread libevent openssl miniupnpc zeromq supervisor su-exec \
    shadow tzdata wget

RUN arch="$(apk --print-arch)" \
 && case "$arch" in \
      x86_64) cf_arch=amd64 ;; \
      aarch64) cf_arch=arm64 ;; \
      armv7) cf_arch=arm ;; \
      *) echo "Unsupported cloudflared arch: $arch" && exit 1 ;; \
    esac \
 && wget -O /usr/local/bin/cloudflared \
      "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}" \
 && chmod +x /usr/local/bin/cloudflared

COPY --from=builder /out/usr/local/bin/dogecoind /usr/local/bin/
COPY --from=builder /out/usr/local/bin/dogecoin-cli /usr/local/bin/
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisord.conf

RUN addgroup -S dogecoin && adduser -S -G dogecoin dogecoin \
 && chmod +x /entrypoint.sh

VOLUME ["/dogecoin", "/config"]

HEALTHCHECK --interval=60s --timeout=10s --start-period=120s \
  CMD dogecoin-cli -conf=/config/dogecoin.conf -datadir=/dogecoin getblockchaininfo >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
