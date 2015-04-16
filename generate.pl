#!/usr/bin/env perl
use v5.20;
use strict;
use warnings;
use YAML::XS;
use Devel::PatchPerl;
use LWP::Simple;

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

if (! -d "downloads") {
  mkdir "downloads" or die "Couldn't create a downloads directory";
}

for my $release (@{$yaml->{releases}}) {
  do { die_with_sample unless $release->{$_}} for (qw(version pause sha1));

  die "Bad version: $release->{version}" unless $release->{version} =~ /\A5\.\d+\.\d+\Z/;

  my $patch;
  my $file = "perl-$release->{version}.tar.bz2";
  my $url = "http://www.cpan.org/src/5.0/$file";
  if (-f "downloads/$file" &&
    `sha1sum downloads/$file` =~ /^\Q$release->{sha1}\E\s+\Qdownloads\/$file\E/) {
      print "Skipping download of $file, already current\n";
  } else {
    print "Downloading $url\n";
    getstore($url, "downloads/$file");
  }
  {
    my $dir = "downloads/perl-$release->{version}";
    qx{rm -fR $dir};
    mkdir $dir or die "Couldn't create $dir";
    qx{
      tar -C "downloads" -jxf $dir.tar.bz2 &&\
      cd $dir &&\
      find . -exec chmod u+w {} + &&\
      git init &&\
      git add . &&\
      git commit -m tmp
    };
    die "Couldn't create a temp git repo for $release->{version}" if $? != 0;
    Devel::PatchPerl->patch_source($release->{version}, $dir);
    $patch = qx{
      cd $dir && git commit -am tmp >/dev/null 2>/dev/null && git format-patch -1 --stdout
    };
    die "Couldn't create a Devel::PatchPerl patch for $release->{version}" if $? != 0;
  }

  $release->{pause} =~ s#(((.).).*)#$3/$2/$1#;
  $release->{extra_flags} = "" unless defined $release->{extra_flags};

  for my $config (keys %builds) {
    my $output = $template;
    $output =~ s/{{$_}}/$release->{$_}/mg for (qw(version pause extra_flags sha1));
    $output =~ s/{{args}}/$builds{$config}/mg;

    my $dir = sprintf "%i.%03i.%03i-%s",
                      ($release->{version} =~ /(\d+)\.(\d+)\.(\d+)/),
                      $config;

    mkdir $dir unless -d $dir;

    # Set up the generated DevelPatchPerl.patch
    {
      open(my $fh, ">$dir/DevelPatchPerl.patch");
      print $fh $patch;
    }

    if (defined $release->{test_parallel} && $release->{test_parallel} eq "no") {
        $output =~ s/{{test}}/make test_harness/;
    } elsif (!defined $release->{test_parallel} || $release->{test_parallel} eq "yes") {
        $output =~ s/{{test}}/TEST_JOBS=\$(nproc) make test_harness/;
    } else {
        die "test_parallel was provided for $release->{version} but is invalid; should be 'yes' or 'no'\n";
    }

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

=item REQUIRED

=over 4

=item version

The actual perl version, such as B<5.20.1>.

=item sha1

The SHA-1 of the C<.tar.bz2> file for that release.

=item pause

The PAUSE (CPAN user) account that the release was uploaded to.

=back

=item OPTIONAL

=over 4

=item extra_args

Additional text to pass to C<Configure>.  At the moment, this is necessary for
5.18.x so that it can get the C<-fwrapv> flag.

Default: C<"">

=item test_parallel

This can be either 'no', 'yes', or unspecified (equivalent to 'yes').
Added due to dist/IO/t/io_unix.t failing when TEST_JOBS > 1, but should
only be used in case of a documented issue.

Default: C<yes>

=back

=back

=cut

__DATA__
FROM buildpack-deps
MAINTAINER Peter Martini <PeterCMartini@GMail.com>

RUN apt-get update \
    && apt-get install -y curl procps \
    && rm -fr /var/lib/apt/lists/*

RUN mkdir /usr/src/perl
COPY DevelPatchPerl.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL https://cpan.metacpan.org/authors/id/{{pause}}/perl-{{version}}.tar.bz2 -o perl-{{version}}.tar.bz2 \
    && echo '{{sha1}} *perl-{{version}}.tar.bz2' | sha1sum -c - \
    && tar --strip-components=1 -xjf perl-{{version}}.tar.bz2 -C /usr/src/perl \
    && rm perl-{{version}}.tar.bz2 \
    && cat DevelPatchPerl.patch | patch -p1 \
    && ./Configure {{args}} {{extra_flags}} -des \
    && make -j$(nproc) \
    && {{test}} \
    && make install \
    && cd /usr/src \
    && curl -LO https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm \
    && chmod +x cpanm \
    && ./cpanm App::cpanminus \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl

WORKDIR /root

CMD ["perl{{version}}","-de0"]
