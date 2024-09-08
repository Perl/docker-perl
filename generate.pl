#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use YAML::XS;
use CPAN::Perl::Releases::MetaCPAN;
use Devel::PatchPerl;
use File::Basename;
use LWP::Simple;

sub die_with_sample {
  die <<EOF;

The config.yml file must look roughly like:

    ---
    builds:
      - main
      - slim

    options:
      common: "-Duseshrplib -Dvendorprefix=/usr/local"
      threaded: "-Dusethreads"

    releases:
      - version: 5.20.0
        sha256:  asdasdadas

Where "version" is the version number of Perl and "sha256" is the SHA256
of the Perl distribution tarball.

If needed or desired, extra_flags: can be added, which will be passed
verbatim to Configure.

Run "perldoc ./generate.pl" to read the complete documentation.

EOF
}

my $docker_slim_run_install = <<'EOF';
apt-get update \
    && apt-get install -y --no-install-recommends \
       bzip2 \
       ca-certificates \
       # cpio \
       curl \
       dpkg-dev \
       # file \
       gcc \
       # g++ \
       # libbz2-dev \
       # libdb-dev \
       libc6-dev \
       # libgdbm-dev \
       # liblzma-dev \
       make \
       netbase \
       patch \
       # procps \
       zlib1g-dev \
       xz-utils \
       libssl-dev
EOF
chomp $docker_slim_run_install;

my $docker_slim_run_purge = <<'EOF';
savedPackages="ca-certificates curl make netbase zlib1g-dev libssl-dev" \
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedPackages \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -fr /var/cache/apt/* /var/lib/apt/lists/*
EOF
chomp $docker_slim_run_purge;

my $config = do {
  open my $fh, '<', 'config.yml' or die "Couldn't open config";
  local $/;
  Load <$fh>;
};

my $template = do {
  local $/;
  <DATA>;
};

my %builds;

my %install_modules = (
  cpanm => {
    name => "App-cpanminus-1.7047",
    url  => "https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7047.tar.gz",

    # sha256 taken from http://www.cpan.org/authors/id/M/MI/MIYAGAWA/CHECKSUMS
    sha256 => "963e63c6e1a8725ff2f624e9086396ae150db51dd0a337c3781d09a994af05a5",

    patch_https =>
      q[perl -pi -E 's{http://(www\.cpan\.org|backpan\.perl\.org|cpan\.metacpan\.org|fastapi\.metacpan\.org|cpanmetadb\.plackperl\.org)}{https://$1}g' bin/cpanm],
    patch_nolwp => q[perl -pi -E 's{try_lwp=>1}{try_lwp=>0}g' bin/cpanm],
  },
  iosocketssl => {
    name => "IO-Socket-SSL-2.085",
    url  => "https://www.cpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.085.tar.gz",

    # sha256 taken from http://www.cpan.org/authors/id/S/SU/SULLR/CHECKSUMS
    sha256 => "95b2f7c0628a7e246a159665fbf0620d0d7835e3a940f22d3fdd47c3aa799c2e",
  },
  netssleay => {
    name => "Net-SSLeay-1.94",
    url  => "https://www.cpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.94.tar.gz",

    # sha256 taken from http://www.cpan.org/authors/id/C/CH/CHRISN/CHECKSUMS
    sha256 => "9d7be8a56d1bedda05c425306cc504ba134307e0c09bda4a788c98744ebcd95d",
  },
);

# sha256 checksum is from docker-perl team, cf https://github.com/docker-library/official-images/pull/12612#issuecomment-1158288299
my %cpm = (
  url    => "https://raw.githubusercontent.com/skaji/cpm/0.997017/cpm",
  sha256 => "e3931a7d994c96f9c74b97d1b5b75a554fc4f06eadef1eca26ecc0bdcd1f2d11",
);

die_with_sample unless defined $config->{releases};
die_with_sample unless ref $config->{releases} eq "ARRAY";

if (!-d "downloads") {
  mkdir "downloads" or die "Couldn't create a downloads directory";
}

for my $build (@{$config->{builds}}) {
  $builds{$build} = $config->{options}{common};
  $builds{"$build,threaded"} = "@{$config->{options}}{qw/threaded common/}";
}

for my $release (@{$config->{releases}}) {
  do { die_with_sample unless $release->{$_} }
    for (qw(version sha256));

  die "Bad version: $release->{version}" unless $release->{version} =~ /\A5\.\d+\.\d+\Z/;

  my $patch;
  my $tarball = CPAN::Perl::Releases::MetaCPAN::perl_tarballs($release->{version})->{'tar.gz'};
  my ($file)  = File::Basename::fileparse($tarball);
  my $url     = "https://cpan.metacpan.org/authors/id/$tarball";
  if (-f "downloads/$file" && `sha256sum downloads/$file` =~ /^\Q$release->{sha256}\E\s+\Qdownloads\/$file\E/) {
    print "Skipping download of $file, already current\n";
  }
  else {
    print "Downloading $url\n";
    getstore($url, "downloads/$file");
  }
  {
    my $dir = "downloads/perl-$release->{version}";
    qx{rm -fR $dir};
    mkdir $dir or die "Couldn't create $dir";
    qx{
      tar -C "downloads" -xf $dir.tar.gz &&\
      cd $dir &&\
      find . -exec chmod u+w {} + &&\
      git init &&\
      git add . &&\
      git commit -m tmp
    };
    die "Couldn't create a temp git repo for $release->{version}" if $? != 0;
    Devel::PatchPerl->patch_source($release->{version}, $dir);
    $patch = qx{
      cd $dir && git -c 'diff.mnemonicprefix=false' diff
    };
    die "Couldn't create a Devel::PatchPerl patch for $release->{version}" if $? != 0;
  }

  for my $build (keys %builds) {
    $release->{url} = $url;

    for my $name (keys %install_modules) {
      my $module = $install_modules{$name};
      $release->{"${name}_dist_$_"} = $module->{$_} for keys %$module;
    }
    $release->{"cpm_dist_$_"} = $cpm{$_} for keys %cpm;

    $release->{extra_flags} ||= '';

    $release->{image} = $build =~ /main/ ? 'buildpack-deps' : 'debian';

    for my $debian_release (@{$release->{debian_release}}) {

      my $output = $template;
      $output =~ s/\{\{$_\}\}/$release->{$_}/mg for keys %$release;
      $output =~ s/\{\{args\}\}/$builds{$build}/mg;

      if ($build =~ /slim/) {
        $output =~ s/\{\{docker_slim_run_install\}\}/$docker_slim_run_install/mg;
        $output =~ s/\{\{docker_slim_run_purge\}\}/$docker_slim_run_purge/mg;
        $output =~ s/\{\{tag\}\}/$debian_release-slim/mg;
      }
      else {
        $output =~ s/\{\{docker_slim_run_install\}\}/true/mg;
        $output =~ s/\{\{docker_slim_run_purge\}\}/true/mg;
        $output =~ s/\{\{tag\}\}/$debian_release/mg;
      }

      my $dir = sprintf "%i.%03i.%03i-%s-%s", ($release->{version} =~ /(\d+)\.(\d+)\.(\d+)/), $build, $debian_release;

      mkdir $dir unless -d $dir;

      # Set up the generated DevelPatchPerl.patch
      if ($patch) {
        open my $fh, ">", "$dir/DevelPatchPerl.patch";
        print $fh $patch;
        $output =~ s!\{\{docker_copy_perl_patch\}\}!COPY *.patch /usr/src/perl/!mg;
      }
      else {
        $output =~ s!\{\{docker_copy_perl_patch\}\}!# No DevelPatchPerl.patch generated!mg;
      }

      $release->{run_tests} //= "parallel";
      if ($release->{run_tests} eq "serial") {
        $output =~ s/\{\{test\}\}/make test_harness/;
      }
      elsif ($release->{run_tests} eq "parallel") {
        $output =~ s/\{\{test\}\}/TEST_JOBS=\$(nproc) make test_harness/;
      }
      elsif ($release->{run_tests} eq "no") {

        # https://metacpan.org/pod/Devel::PatchPerl#CAVEAT
        $output =~ s/\{\{test\}\}/LD_LIBRARY_PATH=. .\/perl -Ilib -de0/;

        # https://metacpan.org/pod/distribution/perl/INSTALL#Building-a-shared-Perl-library
      }
      else {
        die "run_tests was provided for $release->{version} but is invalid; should be 'parallel', 'serial', or 'no'\n";
      }

      open my $dockerfile, ">", "$dir/Dockerfile" or die "Couldn't open $dir/Dockerfile for writing";
      print $dockerfile $output;
      close $dockerfile;
    }
  }
}

=pod

=head1 NAME

generate.pl - generate Dockerfiles for Perl

=head1 SYNOPSIS

    cd /path/to/docker-perl
    ./generate.pl

=head1 DESCRIPTION

generate.pl is meant to be run from the actual repo directory, with a
config.yml file correctly configured.  It contains with a 'releases'
key, which contains a list of releases, each with the following keys:

=over 4

=item REQUIRED

=over 4

=item version

The actual perl version, such as B<5.20.1>.

=item sha256

The SHA-256 of the tarball for that release.

=back

=item OPTIONAL

=over 4

=item debian_release

The Docker image tag which this Perl would build on, common to both the
L<buildpack-deps|https://hub.docker.com/_/buildpack-deps> and
L<debian|https://hub.docker.com/_/debian> Docker images.

This should be a list of tags for different Debian versions:

    - version: 5.30.0
      debian_release:
        - bullseye
        - buster

C<-slim> will be appended to this value for C<slim> builds.

=item extra_flags

Additional text to pass to C<Configure>.  At the moment, this is
necessary for 5.18.x so that it can get the C<-fwrapv> flag.

Default: C<"">

=item run_tests

This can be 'parallel' (default), 'serial', or 'no'.

Added due to dist/IO/t/io_unix.t failing when TEST_JOBS > 1, but should
only be used in case of a documented issue or old release (see
L<Devel::PatchPerl's CAVEAT|https://metacpan.org/pod/Devel::PatchPerl#CAVEAT>).

Default: C<yes>

=back

=back

=cut

__DATA__
FROM {{image}}:{{tag}}

{{docker_copy_perl_patch}}
WORKDIR /usr/src/perl

RUN {{docker_slim_run_install}} \
    && curl -fL {{url}} -o perl-{{version}}.tar.gz \
    && echo '{{sha256}} *perl-{{version}}.tar.gz' | sha256sum --strict --check - \
    && tar --strip-components=1 -xaf perl-{{version}}.tar.gz -C /usr/src/perl \
    && rm perl-{{version}}.tar.gz \
    && cat *.patch | patch -p1 \
    && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    && archBits="$(dpkg-architecture --query DEB_BUILD_ARCH_BITS)" \
    && archFlag="$([ "$archBits" = '64' ] && echo '-Duse64bitall' || echo '-Duse64bitint')" \
    && ./Configure -Darchname="$gnuArch" "$archFlag" {{args}} {{extra_flags}} -des \
    && make -j$(nproc) \
    && {{test}} \
    && make install \
    && cd /usr/src \
    && curl -fLO {{cpanm_dist_url}} \
    && echo '{{cpanm_dist_sha256}} *{{cpanm_dist_name}}.tar.gz' | sha256sum --strict --check - \
    && tar -xzf {{cpanm_dist_name}}.tar.gz && cd {{cpanm_dist_name}} \
    && {{cpanm_dist_patch_https}} \
    && {{cpanm_dist_patch_nolwp}} \
    && perl bin/cpanm . && cd /root \
    && curl -fLO '{{netssleay_dist_url}}' \
    && echo '{{netssleay_dist_sha256}} *{{netssleay_dist_name}}.tar.gz' | sha256sum --strict --check - \
    && cpanm --from $PWD {{netssleay_dist_name}}.tar.gz \
    && curl -fLO '{{iosocketssl_dist_url}}' \
    && echo '{{iosocketssl_dist_sha256}} *{{iosocketssl_dist_name}}.tar.gz' | sha256sum --strict --check - \
    && SSL_CERT_DIR=/etc/ssl/certs cpanm --from $PWD {{iosocketssl_dist_name}}.tar.gz \
    && curl -fL {{cpm_dist_url}} -o /usr/local/bin/cpm \
    # sha256 checksum is from docker-perl team, cf https://github.com/docker-library/official-images/pull/12612#issuecomment-1158288299
    && echo '{{cpm_dist_sha256}} */usr/local/bin/cpm' | sha256sum --strict --check - \
    && chmod +x /usr/local/bin/cpm \
    && {{docker_slim_run_purge}} \
    && rm -fr /root/.cpanm /root/{{netssleay_dist_name}}* /root/{{iosocketssl_dist_name}}* /usr/src/perl /usr/src/{{cpanm_dist_name}}* /tmp/* \
    && cpanm --version && cpm --version

WORKDIR /usr/src/app

CMD ["perl{{version}}","-de0"]
