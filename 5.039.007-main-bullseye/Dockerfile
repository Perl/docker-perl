FROM buildpack-deps:bullseye

# No DevelPatchPerl.patch generated
WORKDIR /usr/src/perl

RUN true \
    && curl -fL https://cpan.metacpan.org/authors/id/C/CO/CORION/perl-5.39.7.tar.gz -o perl-5.39.7.tar.gz \
    && echo 'c85f9ef13fa674839b076d81edb45242a5ddff3df4b111f764a7abe72edd83eb *perl-5.39.7.tar.gz' | sha256sum --strict --check - \
    && tar --strip-components=1 -xaf perl-5.39.7.tar.gz -C /usr/src/perl \
    && rm perl-5.39.7.tar.gz \
    && cat *.patch | patch -p1 \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" -Duseshrplib -Dvendorprefix=/usr/local -Dusedevel -Dversiononly=undef -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -fLO https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7047.tar.gz \
    && echo '963e63c6e1a8725ff2f624e9086396ae150db51dd0a337c3781d09a994af05a5 *App-cpanminus-1.7047.tar.gz' | sha256sum --strict --check - \
    && tar -xzf App-cpanminus-1.7047.tar.gz && cd App-cpanminus-1.7047 && perl bin/cpanm . && cd /root \
    && cpanm IO::Socket::SSL \
    && curl -fL https://raw.githubusercontent.com/skaji/cpm/0.997014/cpm -o /usr/local/bin/cpm \
    # sha256 checksum is from docker-perl team, cf https://github.com/docker-library/official-images/pull/12612#issuecomment-1158288299
    && echo 'ee525f2493e36c6f688eddabaf53a51c4d3b2a4ebaa81576ac8b9f78ab57f4a1 */usr/local/bin/cpm' | sha256sum --strict --check - \
    && chmod +x /usr/local/bin/cpm \
    && true \
    && rm -fr /root/.cpanm /usr/src/perl /usr/src/App-cpanminus-1.7047* /tmp/* \
    && cpanm --version && cpm --version

WORKDIR /usr/src/app

CMD ["perl5.39.7","-de0"]
