FROM debian:bullseye-slim

# No DevelPatchPerl.patch generated
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
    && curl -fL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.42.3.tar.gz -o perl-5.42.3.tar.gz \
    && echo '1137740985837b5cdf15f0cfab932279dcb4352f912fed6fc144e8b4f0823627 *perl-5.42.3.tar.gz' | sha256sum --strict --check - \
    && tar --strip-components=1 -xaf perl-5.42.3.tar.gz -C /usr/src/perl \
    && rm perl-5.42.3.tar.gz \
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
    && curl -fLO 'https://www.cpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.099.tar.gz' \
    && echo 'a0be800ff4852b1567ee5500e772417ad7a360abff80c01b5b875c15d44be832 *IO-Socket-SSL-2.099.tar.gz' | sha256sum --strict --check - \
    && SSL_CERT_DIR=/etc/ssl/certs cpanm --from $PWD IO-Socket-SSL-2.099.tar.gz \
    && curl -fL https://raw.githubusercontent.com/skaji/cpm/v1.1.5/cpm -o /usr/local/bin/cpm \
    # sha256 checksum is from docker-perl team, cf https://github.com/docker-library/official-images/pull/12612#issuecomment-1158288299
    && echo '2e7cdae8f84a673384d40e2486aa236955b7f69547d66f9920564c05b330f9e0 */usr/local/bin/cpm' | sha256sum --strict --check - \
    && chmod +x /usr/local/bin/cpm \
    && savedPackages="ca-certificates curl make netbase zlib1g-dev libssl-dev" \
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedPackages \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -fr /var/cache/apt/* /var/lib/apt/lists/* \
    && rm -fr /root/.cpanm /root/Net-SSLeay-1.96* /root/IO-Socket-SSL-2.099* /usr/src/perl /usr/src/App-cpanminus-1.7049* /tmp/* \
    && cpanm --version && cpm --version

WORKDIR /usr/src/app

CMD ["perl5.42.3","-de0"]
