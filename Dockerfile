FROM alpine:latest AS builder

ARG DOGECOIN_VERSION=1.14.9

RUN apk add --no-cache \
    autoconf automake build-base git libevent-dev libtool \
    boost-dev openssl-dev pkgconf wget

WORKDIR /build
RUN wget -O dogecoin.tar.gz "https://github.com/dogecoin/dogecoin/archive/refs/tags/v${DOGECOIN_VERSION}.tar.gz" \
 && tar -xzf dogecoin.tar.gz --strip-components=1 \
 && ./autogen.sh \
 && ./configure --prefix=/usr/local --without-gui --disable-wallet --disable-tests --disable-bench --without-miniupnpc --disable-zmq \
 && make -j"$(nproc)" \
 && make install DESTDIR=/out

FROM alpine:latest

RUN apk add --no-cache \
    bash ca-certificates libstdc++ boost-system boost-filesystem \
    boost-thread boost-chrono libevent openssl supervisor su-exec \
    shadow tzdata wget

RUN arch="$(apk --print-arch)" \
 && case "$arch" in \
      x86_64) cf_arch=amd64 ;; \
      aarch64) cf_arch=arm64 ;; \
      armv7) cf_arch=arm ;; \
      *) echo "Unsupported arch: $arch" && exit 1 ;; \
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

ENTRYPOINT ["/entrypoint.sh"]
