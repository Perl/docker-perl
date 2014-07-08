FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update && apt-get install -y curl procps

RUN mkdir /usr/src/perl
WORKDIR /usr/src/perl
RUN curl -SL http://www.cpan.org/src/5.0/perl-5.20.0.tar.gz \
                | tar -xz --strip-components=1

RUN ./Configure -Duse64bitall -des \
        && make -j$(nproc) \
        && TEST_JOBS=$(nproc) make test_harness \
        && make install \
        && make veryclean

WORKDIR /root

CMD ["perl5.20.0","-de0"]
