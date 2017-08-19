FROM buildpack-deps:stretch
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY cpanm *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://www.cpan.org/src/5.0/perl-5.24.2.tar.bz2 -o perl-5.24.2.tar.bz2 \
    && echo 'e28c8fa588c4227eb25350036b45d7b1b46d61bb3a2194ee09dc79be6ed0fd0f *perl-5.24.2.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.24.2.tar.bz2 -C /usr/src/perl \
    && rm perl-5.24.2.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Dusethreads -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && chmod +x ./cpanm \
    && mv ./cpanm /usr/local/bin \
    && rm -fr /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.24.2","-de0"]
