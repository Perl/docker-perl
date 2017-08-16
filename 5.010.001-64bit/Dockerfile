FROM buildpack-deps:jessie
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY cpanm *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/D/DA/DAPM/perl-5.10.1.tar.bz2 -o perl-5.10.1.tar.bz2 \
    && echo '9385f2c8c2ca8b1dc4a7c31903f1f8dc8f2ba867dc2a9e5c93012ed6b564e826 *perl-5.10.1.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.10.1.tar.bz2 -C /usr/src/perl \
    && rm perl-5.10.1.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && chmod +x ./cpanm \
    && mv ./cpanm /usr/local/bin \
    && rm -fr /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.10.1","-de0"]
