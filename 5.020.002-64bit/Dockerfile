FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY DevelPatchPerl.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.20.2.tar.bz2 -o perl-5.20.2.tar.bz2 \
    && echo '63126c683b4c79c35008a47d56f7beae876c569f *perl-5.20.2.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-5.20.2.tar.bz2 -C /usr/src/perl \
    && rm perl-5.20.2.tar.bz2 \
    && cat DevelPatchPerl.patch | patch -p1 \
    && ./Configure -Duse64bitall  -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl

WORKDIR /root

CMD ["perl5.20.2","-de0"]
