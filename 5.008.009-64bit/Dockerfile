FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/N/NW/NWCLARK/perl-5.8.9.tar.bz2 -o perl-5.8.9.tar.bz2 \
    && echo '19843b5a7585cf35d96c07dbcd419bbdd5813617 *perl-5.8.9.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-5.8.9.tar.bz2 -C /usr/src/perl \
    && rm perl-5.8.9.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Duse64bitall -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.8.9","-de0"]
