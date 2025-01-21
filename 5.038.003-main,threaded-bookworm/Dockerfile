FROM buildpack-deps:bookworm

# No DevelPatchPerl.patch generated
WORKDIR /usr/src/perl

RUN true \
    && curl -fL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.38.3.tar.gz -o perl-5.38.3.tar.gz \
    && echo '8a8033859dd1d75eb0c9158eedd7384df1af6b46a2a4e85073b07e6cc7c5b873 *perl-5.38.3.tar.gz' | sha256sum --strict --check - \
    && tar --strip-components=1 -xaf perl-5.38.3.tar.gz -C /usr/src/perl \
    && rm perl-5.38.3.tar.gz \
    && cat *.patch | patch -p1 \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" -Dusethreads -Duseshrplib -Dvendorprefix=/usr/local  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -fLO https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7047.tar.gz \
    && echo '963e63c6e1a8725ff2f624e9086396ae150db51dd0a337c3781d09a994af05a5 *App-cpanminus-1.7047.tar.gz' | sha256sum --strict --check - \
    && tar -xzf App-cpanminus-1.7047.tar.gz && cd App-cpanminus-1.7047 \
    && perl -pi -E 's{http://(www\.cpan\.org|backpan\.perl\.org|cpan\.metacpan\.org|fastapi\.metacpan\.org|cpanmetadb\.plackperl\.org)}{https://$1}g' bin/cpanm \
    && perl -pi -E 's{try_lwp=>1}{try_lwp=>0}g' bin/cpanm \
    && perl bin/cpanm . && cd /root \
    && curl -fLO 'https://www.cpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.94.tar.gz' \
    && echo '9d7be8a56d1bedda05c425306cc504ba134307e0c09bda4a788c98744ebcd95d *Net-SSLeay-1.94.tar.gz' | sha256sum --strict --check - \
    && cpanm --from $PWD Net-SSLeay-1.94.tar.gz \
    && curl -fLO 'https://www.cpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.085.tar.gz' \
    && echo '95b2f7c0628a7e246a159665fbf0620d0d7835e3a940f22d3fdd47c3aa799c2e *IO-Socket-SSL-2.085.tar.gz' | sha256sum --strict --check - \
    && SSL_CERT_DIR=/etc/ssl/certs cpanm --from $PWD IO-Socket-SSL-2.085.tar.gz \
    && curl -fL https://raw.githubusercontent.com/skaji/cpm/0.997017/cpm -o /usr/local/bin/cpm \
    # sha256 checksum is from docker-perl team, cf https://github.com/docker-library/official-images/pull/12612#issuecomment-1158288299
    && echo 'e3931a7d994c96f9c74b97d1b5b75a554fc4f06eadef1eca26ecc0bdcd1f2d11 */usr/local/bin/cpm' | sha256sum --strict --check - \
    && chmod +x /usr/local/bin/cpm \
    && true \
    && rm -fr /root/.cpanm /root/Net-SSLeay-1.94* /root/IO-Socket-SSL-2.085* /usr/src/perl /usr/src/App-cpanminus-1.7047* /tmp/* \
    && cpanm --version && cpm --version

WORKDIR /usr/src/app

CMD ["perl5.38.3","-de0"]
