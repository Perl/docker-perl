FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.20.1.tar.bz2 -o perl-5.20.1.tar.bz2 \
    && echo 'cd424d1520ba2686fe5d4422565aaf880e9467f6 *perl-5.20.1.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-5.20.1.tar.bz2 -C /usr/src/perl \
    && rm perl-5.20.1.tar.bz2 \
    && ./Configure -Dusethreads -Duse64bitall  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl

WORKDIR /root

CMD ["perl5.20.1","-de0"]
