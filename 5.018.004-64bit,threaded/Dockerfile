FROM buildpack-deps:jessie
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.18.4.tar.bz2 -o perl-5.18.4.tar.bz2 \
    && echo '1fb4d27b75cd244e849f253320260efe1750641aaff4a18ce0d67556ff1b96a5 *perl-5.18.4.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.18.4.tar.bz2 -C /usr/src/perl \
    && rm perl-5.18.4.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Dusethreads -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.18.4","-de0"]
