FROM buildpack-deps:jessie
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY cpanm *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.9.tar.bz2 -o perl-5.8.9.tar.bz2 \
    && echo '1097fbcd48ceccb2bc735d119c9db399a02a8ab9f7dc53e29e47e6a8d0d72e79 *perl-5.8.9.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.8.9.tar.bz2 -C /usr/src/perl \
    && rm perl-5.8.9.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Dusethreads -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && chmod +x ./cpanm \
    && mv ./cpanm /usr/local/bin \
    && rm -fr /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.8.9","-de0"]
