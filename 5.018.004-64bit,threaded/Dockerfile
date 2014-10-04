FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update && apt-get install -y curl procps

RUN mkdir /usr/src/perl
WORKDIR /usr/src/perl

COPY sha1.txt /tmp/sha1.txt
RUN curl -SL https://cpan.metacpan.org/authors/id/R/RJ/RJBS/perl-5.18.4.tar.bz2 -o perl-5.18.4.tar.bz2 \
    && sha1sum -c /tmp/sha1.txt \
    && tar --strip-components=1 -xjf perl-5.18.4.tar.bz2 -C /usr/src/perl \
    && rm perl-5.18.4.tar.bz2 /tmp/sha1.txt

# ccflags=-fwrapv is needed for gcc 4.9, and added by Configure automatically in 5.20+
RUN ./Configure -Dusethreads -A ccflags=-fwrapv -Duse64bitall -des \
        && make -j$(nproc) \
        && TEST_JOBS=$(nproc) make test_harness \
        && make install \
        && make veryclean

WORKDIR /usr/src
RUN curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
        && chmod +x cpanm \
        && ./cpanm App::cpanminus \
        && rm ./cpanm

WORKDIR /root

CMD ["perl5.18.4","-de0"]
