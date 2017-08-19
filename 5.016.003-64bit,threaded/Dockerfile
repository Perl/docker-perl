FROM buildpack-deps:jessie
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY cpanm *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://www.cpan.org/src/5.0/perl-5.16.3.tar.bz2 -o perl-5.16.3.tar.bz2 \
    && echo 'bb7bc735e6813b177dcfccd480defcde7eddefa173b5967eac11babd1bfa98e8 *perl-5.16.3.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.16.3.tar.bz2 -C /usr/src/perl \
    && rm perl-5.16.3.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Dusethreads -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && chmod +x ./cpanm \
    && mv ./cpanm /usr/local/bin \
    && rm -fr /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.16.3","-de0"]
