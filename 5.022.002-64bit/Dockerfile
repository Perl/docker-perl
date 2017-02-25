FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.22.2.tar.bz2 -o perl-5.22.2.tar.bz2 \
    && echo 'f2322b9b04fe0cdbca9fe755360da04892cb6483d44959457cfebc0bcddc8058 *perl-5.22.2.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.22.2.tar.bz2 -C /usr/src/perl \
    && rm perl-5.22.2.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Duse64bitall -Duseshrplib  -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.22.2","-de0"]
