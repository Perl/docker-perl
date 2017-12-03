FROM buildpack-deps:jessie
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl
RUN DEBIAN_FRONTEND=noninteractive apt-get -y update && apt-get -y upgrade
RUN curl -SL https://www.cpan.org/src/5.0/perl-5.16.3.tar.bz2 -o perl-5.16.3.tar.bz2 \
    && echo 'bb7bc735e6813b177dcfccd480defcde7eddefa173b5967eac11babd1bfa98e8 *perl-5.16.3.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.16.3.tar.bz2 -C /usr/src/perl \
    && rm perl-5.16.3.tar.bz2 \
    && cat *.patch | patch -p1 \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" -Dusethreads -Duseshrplib -Dvendorprefix=/usr/local -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO http://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7043.tar.gz \
    && echo '68a06f7da80882a95bc02c92c7ee305846fb6ab648cf83678ea945e44ad65c65 *App-cpanminus-1.7043.tar.gz' | sha256sum -c - \
    && tar -xzf App-cpanminus-1.7043.tar.gz && cd App-cpanminus-1.7043 && perl bin/cpanm . && cd /root \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /usr/src/App-cpanminus-1.7043* /tmp/*

WORKDIR /root

CMD ["perl5.16.3","-de0"]
