FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/D/DO/DOM/perl-5.12.5.tar.bz2 -o perl-5.12.5.tar.bz2 \
    && echo '10749417fd3010aae320a34181ad4cd6a4855c1fc63403b87fa4d630b18e966c *perl-5.12.5.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.12.5.tar.bz2 -C /usr/src/perl \
    && rm perl-5.12.5.tar.bz2 \
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

CMD ["perl5.12.5","-de0"]
