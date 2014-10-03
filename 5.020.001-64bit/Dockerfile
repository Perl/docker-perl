FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update && apt-get install -y curl procps

WORKDIR /tmp
ADD sha1.txt /tmp/sha1.txt
RUN curl -SL https://cpan.metacpan.org/authors/id/S/SH/SHAY/perl-5.20.1.tar.bz2 -o /tmp/perl-5.20.1.tar.bz2
RUN sha1sum -c /tmp/sha1.txt

WORKDIR /usr/src/perl
RUN tar --strip-components=1 -xjf /tmp/perl-5.20.1.tar.bz2
RUN rm /tmp/perl-5.20.1.tar.bz2 /tmp/sha1.txt
RUN ./Configure -Duse64bitall -des \
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

CMD ["perl5.20.1","-de0"]
