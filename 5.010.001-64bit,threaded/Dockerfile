FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/D/DA/DAPM/perl-5.10.1.tar.bz2 -o perl-5.10.1.tar.bz2 \
    && echo '9385f2c8c2ca8b1dc4a7c31903f1f8dc8f2ba867dc2a9e5c93012ed6b564e826 *perl-5.10.1.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.10.1.tar.bz2 -C /usr/src/perl \
    && rm perl-5.10.1.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Dusethreads -Duse64bitall -Duseshrplib -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.10.1","-de0"]
