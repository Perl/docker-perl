FROM buildpack-deps:jessie
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/D/DA/DAPM/perl-5.14.4.tar.bz2 -o perl-5.14.4.tar.bz2 \
    && echo 'eece8c2b0d491bf6f746bd1f4f1bb7ce26f6b98e91c54690c617d7af38964745 *perl-5.14.4.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-5.14.4.tar.bz2 -C /usr/src/perl \
    && rm perl-5.14.4.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Duse64bitall -Duseshrplib -Dvendorprefix=/usr/local -A ccflags=-fwrapv -des \
    && make -j$(nproc) \
    && make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.14.4","-de0"]
