#!/usr/bin/env perl
use v5.14;
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
    sha256:  asdasdadas

Where version is the version number of Perl and sha256 is the SHA256 of
the tar.bz2 file.

If needed or desired, extra_flags: can be added, which will be passed
verbatim to Configure.

EOF
}

my $yaml = do {
  open my $fh, "<", "Releases.yaml" or die "Couldn't open releases";
  local $/;
  Load <$fh>;
};

my $template = do {
  local $/;
  <DATA>;
};

my $common = join " ", qw{
-Duseshrplib
-Dvendorprefix=/usr/local
};

my %builds = (
  "64bit"          => "$common",
  "64bit,threaded" => "-Dusethreads $common",
);

# sha256 taken from http://www.cpan.org/authors/id/M/MI/MIYAGAWA/CHECKSUMS
my %cpanm = (
    name => "App-cpanminus-1.7043",
    url => "http://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7043.tar.gz",
    sha256 => "68a06f7da80882a95bc02c92c7ee305846fb6ab648cf83678ea945e44ad65c65",
);

die_with_sample unless defined $yaml->{releases};
die_with_sample unless ref $yaml->{releases} eq "ARRAY";

if (! -d "downloads") {
  mkdir "downloads" or die "Couldn't create a downloads directory";
}

for my $release (@{$yaml->{releases}}) {
  do { die_with_sample unless $release->{$_}} for (qw(version sha256));

  die "Bad version: $release->{version}" unless $release->{version} =~ /\A5\.\d+\.\d+\Z/;

  my $patch;
  my $file = "perl-$release->{version}.tar.bz2";
  my $url = "https://www.cpan.org/src/5.0/$file";
  if (-f "downloads/$file" &&
    `sha256sum downloads/$file` =~ /^\Q$release->{sha256}\E\s+\Qdownloads\/$file\E/) {
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
      cd $dir && git diff
    };
    die "Couldn't create a Devel::PatchPerl patch for $release->{version}" if $? != 0;
  }

  $release->{url} = $url;
  $release->{extra_flags} = "" unless defined $release->{extra_flags};
  $release->{_tag} = $release->{buildpack_deps} || "stretch";
  $release->{"cpanm_dist_$_"} = $cpanm{$_} for keys %cpanm;

  for my $config (keys %builds) {
    my $output = $template;
    $output =~ s/\{\{$_\}\}/$release->{$_}/mg
        for (qw(version pause extra_flags sha256 url _tag cpanm_dist_name cpanm_dist_url cpanm_dist_sha256));
    $output =~ s/\{\{args\}\}/$builds{$config}/mg;

    my $dir = sprintf "%i.%03i.%03i-%s",
                      ($release->{version} =~ /(\d+)\.(\d+)\.(\d+)/),
                      $config;

    mkdir $dir unless -d $dir;

    # Set up the generated DevelPatchPerl.patch
    {
      open my $fh, ">", "$dir/DevelPatchPerl.patch";
      print $fh $patch;
    }

    if (defined $release->{test_parallel} && $release->{test_parallel} eq "no") {
        $output =~ s/\{\{test\}\}/make test_harness/;
    } elsif (!defined $release->{test_parallel} || $release->{test_parallel} eq "yes") {
        $output =~ s/\{\{test\}\}/TEST_JOBS=\$(nproc) make test_harness/;
    } else {
        die "test_parallel was provided for $release->{version} but is invalid; should be 'yes' or 'no'\n";
    }

    open my $dockerfile, ">", "$dir/Dockerfile" or die "Couldn't open $dir/Dockerfile for writing";
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

=item sha256

The SHA-256 of the C<.tar.bz2> file for that release.

=item OPTIONAL

=over 4

=item buildpack_deps

The Docker L<buildpack-deps|https://hub.docker.com/_/buildpack-deps>
image tag which this Perl would build on.

Defaults: C<stretch>

=item extra_flags

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
FROM buildpack-deps:{{_tag}}
LABEL maintainer="Peter Martini <PeterCMartini@GMail.com>, Zak B. Elep <zakame@cpan.org>"

COPY *.patch /usr/src/perl/
WORKDIR /usr/src/perl

RUN curl -SL {{url}} -o perl-{{version}}.tar.bz2 \
    && echo '{{sha256}} *perl-{{version}}.tar.bz2' | sha256sum -c - \
    && tar --strip-components=1 -xjf perl-{{version}}.tar.bz2 -C /usr/src/perl \
    && rm perl-{{version}}.tar.bz2 \
    && cat *.patch | patch -p1 \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" {{args}} {{extra_flags}} -des \
    && make -j$(nproc) \
    && {{test}} \
    && make install \
    && cd /usr/src \
    && curl -LO {{cpanm_dist_url}} \
    && echo '{{cpanm_dist_sha256}} *{{cpanm_dist_name}}.tar.gz' | sha256sum -c - \
    && tar -xzf {{cpanm_dist_name}}.tar.gz && cd {{cpanm_dist_name}} && perl bin/cpanm . && cd /root \
    && rm -fr ./cpanm /root/.cpanm /usr/src/perl /usr/src/{{cpanm_dist_name}}* /tmp/*

WORKDIR /root

CMD ["perl{{version}}","-de0"]
