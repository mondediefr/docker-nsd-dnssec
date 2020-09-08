FROM alpine:3.12

LABEL description "Simple DNS authoritative server with DNSSEC support" \
      maintainer="Magicalex <magicalex@mondedie.fr>"

# http://keys.gnupg.net/pks/lookup?search=wouter%40nlnetlabs.nl&fingerprint=on&op=index
ARG GPG_FINGERPRINT="EDFA A3F2 CA4E 6EB0 5681  AF8E 9F6F 1C2D 7E04 5F8D"
ARG GPG_SHORTID="0x9f6f1c2d7e045f8d"
ARG NSD_VERSION=4.3.2

ENV UID=991 GID=991

COPY bin /usr/local/bin

RUN apk add --no-progress --no-cache --virtual build-dependencies \
    gnupg \
    build-base \
    libevent-dev \
    openssl-dev \
    ca-certificates \
  && apk add --no-progress --no-cache \
     ldns \
     ldns-tools \
     libevent \
     openssl \
     tini \
  && cd /tmp \
  && wget https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz \
  && wget https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz.asc \
  && wget https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz.sha256 \
  && CHECKSUM=$(sha256sum nsd-${NSD_VERSION}.tar.gz | awk '{print $1}') \
  && SHA256_HASH=$(cat nsd-${NSD_VERSION}.tar.gz.sha256) \
  && if [ "${CHECKSUM}" != "${SHA256_HASH}" ]; then echo "ERROR: Checksum does not match!" && exit 1; fi \
  && ( \
      gpg --keyserver ha.pool.sks-keyservers.net --recv-keys ${GPG_SHORTID} || \
      gpg --keyserver keyserver.pgp.com --recv-keys ${GPG_SHORTID} || \
      gpg --keyserver pgp.mit.edu --recv-keys ${GPG_SHORTID} \
    ) \
  && FINGERPRINT="$(LANG=C gpg --verify nsd-${NSD_VERSION}.tar.gz.asc nsd-${NSD_VERSION}.tar.gz 2>&1 | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" \
  && if [ -z "${FINGERPRINT}" ]; then echo "ERROR: Invalid GPG signature!" && exit 1; fi \
  && if [ "${FINGERPRINT}" != "${GPG_FINGERPRINT}" ]; then echo "ERROR: Wrong GPG fingerprint!" && exit 1; fi \
  && tar xzf nsd-${NSD_VERSION}.tar.gz \
  && cd nsd-${NSD_VERSION} \
  && ./configure \
    CFLAGS="-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong -Wformat -Werror=format-security" \
    LDFLAGS="-Wl,-z,now -Wl,-z,relro" \
  && make \
  && make install \
  && apk del --purge build-dependencies \
  && rm -rf /tmp/* /root/.gnupg \
  && chmod 775 /usr/local/bin/*

VOLUME /zones /etc/nsd /var/db/nsd
EXPOSE 53 53/udp
CMD ["/usr/local/bin/startup"]
