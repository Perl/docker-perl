#!/usr/bin/env perl
use v5.20;
use strict;
use warnings;
use YAML::XS;

sub die_with_sample {
  die <<EOF;

The Releases.yaml file must look roughly like:

releases:
  - version: 5.20.0
    sha1:    asdasdadas
    pause:   RJBS

Where version is the version number of Perl, sha1 is the SHA1 of the
tar.bz2 file, and pause is the PAUSE account of the release manager.

If needed or desired, extra_flags: can be added, which will be passed
verbatim to Configure.

EOF
}

my $yaml = do {
  open my $fh, "Releases.yaml" or die "Couldn't open releases";
  local $/;
  Load <$fh>;
};

my $template = do {
  local $/;
  <DATA>;
};

my %builds = (
  "64bit"          => "-Duse64bitall",
  "64bit,threaded" => "-Dusethreads -Duse64bitall",
);

die_with_sample unless defined $yaml->{releases};
die_with_sample unless ref $yaml->{releases} eq "ARRAY";

for my $release (@{$yaml->{releases}}) {
  do { die_with_sample unless $release->{$_}} for (qw(version pause sha1));
  $release->{pause} =~ s#(((.).).*)#$3/$2/$1#;
  $release->{extra_flags} = "" unless defined $release->{extra_flags};

  for my $config (keys %builds) {
    my $output = $template;
    $output =~ s/{{$_}}/$release->{$_}/mg for (qw(version pause extra_flags sha1));
    $output =~ s/{{args}}/$builds{$config}/mg;

    my $dir = sprintf "%i.%03i.%03i-%s",
                      ($release->{version} =~ /(\d+)\.(\d+)\.(\d+)/),
                      $config;

    open my $dockerfile, ">$dir/Dockerfile" or die "Couldn't open $dir/Dockerfile for writing";
    print $dockerfile $output;
    close $dockerfile;
  }
}

=pod

=head1 NAME

generate.pl

=head1 SYNOPSIS

generate.pl is a little helper script to reinitalize the Dockerfiles from a YAML file.

=head1 DESCRIPTION

generate.pl is meant to be run from the actual repo directory, with a Releases.yaml file
correctly configured.  It starts with a 'releases' key, which contains a list of releases,
each with the following keys:

=over 4

=item version

The actual perl version, such as B<5.20.1>.

=item sha1

The SHA-1 of the C<.tar.bz2> file for that release.

=item pause

The PAUSE (CPAN user) account that the release was uploaded to.

=item (optionally) extra_args

Additional text to pass to C<Configure>.  At the moment, this is necessary for
5.18.x so that it can get the C<-fwrapv> flag.

=back

=cut

__DATA__
FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/{{pause}}/perl-{{version}}.tar.bz2 -o perl-{{version}}.tar.bz2 \
    && echo '{{sha1}} *perl-{{version}}.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-{{version}}.tar.bz2 -C /usr/src/perl \
    && rm perl-{{version}}.tar.bz2 \
    && ./Configure {{args}} {{extra_flags}} -des \
    && make -j$(nproc) \
    && TEST_JOBS=$(nproc) make test_harness \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl

WORKDIR /root

CMD ["perl{{version}}","-de0"]
