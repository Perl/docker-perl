ARG VARIANT=5-bookworm
FROM perl:${VARIANT}

COPY cpanfile /tmp/cpanfile
RUN cpm install -g --with-develop --cpanfile /tmp/cpanfile \
    && rm -rf /root/.perl-cpm /tmp/cpanfile
