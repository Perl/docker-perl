FROM debian:bookworm-slim

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bzip2 \
       ca-certificates \
       # cpio \
       curl \
       dpkg-dev \
       # file \
       gcc \
       # g++ \
       # libbz2-dev \
       # libdb-dev \
       libc6-dev \
       # libgdbm-dev \
       # liblzma-dev \
       make \
       netbase \
       patch \
       # procps \
       zlib1g-dev \
       xz-utils \
       libssl-dev \
    && curl -fL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.38.5.tar.gz -o perl-5.38.5.tar.gz \
    && echo 'b7667d3ff309068852af7853910aaccec26c839d717402121b664ac705e07bfe *perl-5.38.5.tar.gz' | sha256sum --strict --check - \
    && tar --strip-components=1 -xaf perl-5.38.5.tar.gz -C /usr/src/perl \
    && rm perl-5.38.5.tar.gz \
    && cat *.patch | patch -p1 \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" -Duseshrplib -Dvendorprefix=/usr/local  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -fLO https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7049.tar.gz \
    && echo 'b9ffb88e62a06aa91bd7d5a28ef6bdbb942608aea90e3969aa29b33640035214 *App-cpanminus-1.7049.tar.gz' | sha256sum --strict --check - \
    && tar -xzf App-cpanminus-1.7049.tar.gz && cd App-cpanminus-1.7049 \
    && perl -pi -E 's{http://(www\.cpan\.org|backpan\.perl\.org|cpan\.metacpan\.org|fastapi\.metacpan\.org|cpanmetadb\.plackperl\.org)}{https://$1}g' bin/cpanm \
    && perl -pi -E 's{try_lwp=>1}{try_lwp=>0}g' bin/cpanm \
    && perl bin/cpanm . && cd /root \
    && curl -fLO 'https://www.cpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.96.tar.gz' \
    && echo 'ab213691685fb2a576c669cbc8d9266f8165a31563ad15b7c4030b94adfc0753 *Net-SSLeay-1.96.tar.gz' | sha256sum --strict --check - \
    && cpanm --notest --from $PWD Net-SSLeay-1.96.tar.gz \
    && curl -fLO 'https://www.cpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.098.tar.gz' \
    && echo 'b38473be20256b1a06447dd6769ad162bfad6a258234ed2c7e2e1819c16c4df7 *IO-Socket-SSL-2.098.tar.gz' | sha256sum --strict --check - \
    && SSL_CERT_DIR=/etc/ssl/certs cpanm --from $PWD IO-Socket-SSL-2.098.tar.gz \
    && curl -fL https://raw.githubusercontent.com/skaji/cpm/0.998003/cpm -o /usr/local/bin/cpm \
    # sha256 checksum is from docker-perl team, cf https://github.com/docker-library/official-images/pull/12612#issuecomment-1158288299
    && echo '6a27e528cf37635773e738db36c4b4ab4345d5a9d00b8cbd2f2dc01abc73177d */usr/local/bin/cpm' | sha256sum --strict --check - \
    && chmod +x /usr/local/bin/cpm \
    && savedPackages="ca-certificates curl make netbase zlib1g-dev libssl-dev" \
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedPackages \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -fr /var/cache/apt/* /var/lib/apt/lists/* \
    && rm -fr /root/.cpanm /root/Net-SSLeay-1.96* /root/IO-Socket-SSL-2.098* /usr/src/perl /usr/src/App-cpanminus-1.7049* /tmp/* \
    && cpanm --version && cpm --version

WORKDIR /usr/src/app

CMD ["perl5.38.5","-de0"]
