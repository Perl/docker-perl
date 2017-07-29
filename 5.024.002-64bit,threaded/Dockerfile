FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN mkdir /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.24.2.tar.bz2 -o perl-5.24.2.tar.bz2 \
    && echo 'e28c8fa588c4227eb25350036b45d7b1b46d61bb3a2194ee09dc79be6ed0fd0f *perl-5.24.2.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.24.2.tar.bz2 -C /usr/src/perl \
    && rm perl-5.24.2.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Dusethreads -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.24.2","-de0"]
