FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.24.1.tar.bz2 -o perl-5.24.1.tar.bz2 \
    && echo '482ac5dca262b57d26c381382a3e057b22ede631fcce32523c004b8bf773f6f0 *perl-5.24.1.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.24.1.tar.bz2 -C /usr/src/perl \
    && rm perl-5.24.1.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.24.1","-de0"]
