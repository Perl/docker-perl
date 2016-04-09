FROM alpine:latest
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN mkdir -p /usr/src/perl
COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

ENV PERL_CPANM_OPT --no-wget

RUN set -x \
    && NPROC=$(getconf _NPROCESSORS_ONLN) \
    && apk add --no-cache curl procps tar build-base \
    && curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.22.1.tar.bz2 -o perl-5.22.1.tar.bz2 \
    && echo '29f9b320b0299577a3e1d02e9e8ef8f26f160332 *perl-5.22.1.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-5.22.1.tar.bz2 -C /usr/src/perl \
    && rm perl-5.22.1.tar.bz2 \
    && cat *.patch | patch -p1 \
    && ./Configure -Duse64bitall -Duseshrplib  -des \
    && sed -i -e "s,\(d_setlocale=\)'define',\1'undef',g" ./config.sh \
    && ./Configure -S \
    && install -m0644 ./config.sh ./xconfig.sh \
    && make -j$NPROC \
    && TEST_JOBS=$NPROC make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /tmp/*

WORKDIR /root

CMD ["perl5.22.1","-de0"]
