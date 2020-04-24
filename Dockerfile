FROM alpine:3.11

LABEL description "Simple DNS authoritative server with DNSSEC support" \
      maintainer="Hardware <contact@meshup.net>, Magicalex <magicalex@mondedie.fr>"

ARG NSD_VERSION=4.3.1

# https://keyserver.ubuntu.com/pks/lookup?search=wouter%40nlnetlabs.nl&fingerprint=on&op=index
# pub rsa4096/edfaa3f2ca4e6eb05681af8e9f6f1c2d7e045f8d 2011-04-21T09:47:08Z W.C.A. Wijngaards <wouter@nlnetlabs.nl>
ARG GPG_SHORTID="0x9f6f1c2d7e045f8d"
ARG GPG_FINGERPRINT="EDFA A3F2 CA4E 6EB0 5681  AF8E 9F6F 1C2D 7E04 5F8D"

ENV UID=991 GID=991

RUN apk add --no-cache --virtual build-dependencies \
    gnupg \
    build-base \
    libevent-dev \
    openssl-dev \
    ca-certificates \
  && apk add --no-cache \
     ldns \
     ldns-tools \
     libevent \
     openssl \
     tini \
  && cd /tmp \
  && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz \
  && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz.asc \
  && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz.sha256 \
  && echo "Verifying both integrity and authenticity of nsd-${NSD_VERSION}.tar.gz..." \
  && CHECKSUM=$(sha256sum nsd-${NSD_VERSION}.tar.gz | awk '{print $1}') \
  && SHA256_HASH=$(cat nsd-${NSD_VERSION}.tar.gz.sha256) \
  && if [ "${CHECKSUM}" != "${SHA256_HASH}" ]; then echo "ERROR: Checksum does not match!" && exit 1; fi \
  && gpg --keyserver keyserver.ubuntu.com --receive-keys "${GPG_SHORTID}" \
  && FINGERPRINT="$(LANG=C gpg --verify nsd-${NSD_VERSION}.tar.gz.asc nsd-${NSD_VERSION}.tar.gz 2>&1 | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" \
  && if [ -z "${FINGERPRINT}" ]; then echo "ERROR: Invalid GPG signature!" && exit 1; fi \
  && if [ "${FINGERPRINT}" != "${GPG_FINGERPRINT}" ]; then echo "ERROR: Wrong GPG fingerprint!" && exit 1; fi \
  && echo "All seems good, now unpacking nsd-${NSD_VERSION}.tar.gz..." \
  && tar xzf nsd-${NSD_VERSION}.tar.gz \
  && cd nsd-${NSD_VERSION} \
  && ./configure \
    CFLAGS="-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong -Wformat -Werror=format-security" \
    LDFLAGS="-Wl,-z,now -Wl,-z,relro" \
  && make \
  && make install \
  && apk del build-dependencies \
  && rm -rf /var/cache/apk/* /tmp/* /root/.gnupg

COPY bin /usr/local/bin
VOLUME /zones /etc/nsd /var/db/nsd
EXPOSE 53 53/udp
CMD ["run.sh"]
