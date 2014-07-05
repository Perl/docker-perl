FROM buildpack-deps

RUN apt-get update && apt-get install -y curl procps

RUN mkdir /usr/src/perl
WORKDIR /usr/src/perl
RUN curl -SL http://www.cpan.org/src/5.0/perl-5.20.0.tar.gz \
                | tar -xz --strip-components=1

RUN ./Configure -des \
        && make -j$(nproc) \
        && TEST_JOBS=8 make test_harness \
        && make install \
        && make veryclean

CMD ["perl5.20.0 -V"]

WORKDIR /root
RUN rm -fR /usr/src/perl
