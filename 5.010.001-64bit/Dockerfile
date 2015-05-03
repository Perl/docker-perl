FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/D/DA/DAPM/perl-5.10.1.tar.bz2 -o perl-5.10.1.tar.bz2 \
    && echo '98b762b5cd4fb76dd354dfa5ba0d21bc2acacaf2 *perl-5.10.1.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-5.10.1.tar.bz2 -C /usr/src/perl \
    && rm perl-5.10.1.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Duse64bitall -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl

WORKDIR /root

CMD ["perl5.10.1","-de0"]
