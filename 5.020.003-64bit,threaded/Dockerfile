FROM buildpack-deps:stretch
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY cpanm *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://www.cpan.org/src/5.0/perl-5.20.3.tar.bz2 -o perl-5.20.3.tar.bz2 \
    && echo '1b40068166c242e34a536836286e70b78410602a80615143301e52aa2901493b *perl-5.20.3.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.20.3.tar.bz2 -C /usr/src/perl \
    && rm perl-5.20.3.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Dusethreads -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && chmod +x ./cpanm \
    && mv ./cpanm /usr/local/bin \
    && rm -fr /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.20.3","-de0"]
