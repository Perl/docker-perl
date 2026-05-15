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

sub load_template {
  my $family = shift;
  open my $fh, '<', "Dockerfile.$family.template"
    or die "Couldn't open Dockerfile.$family.template: $!";
  local $/;
  return <$fh>;
}

my %builds;

my %install_modules = (
  cpanm => {
    name => "App-cpanminus-1.7049",
    url  => "https://www.cpan.org/authors/id/M/MI/MIYAGAWA/App-cpanminus-1.7049.tar.gz",

    # sha256 taken from http://www.cpan.org/authors/id/M/MI/MIYAGAWA/CHECKSUMS
    sha256 => "b9ffb88e62a06aa91bd7d5a28ef6bdbb942608aea90e3969aa29b33640035214",

    patch_https =>
      q[perl -pi -E 's{http://(www\.cpan\.org|backpan\.perl\.org|cpan\.metacpan\.org|fastapi\.metacpan\.org|cpanmetadb\.plackperl\.org)}{https://$1}g' bin/cpanm],
    patch_nolwp => q[perl -pi -E 's{try_lwp=>1}{try_lwp=>0}g' bin/cpanm],
  },
  iosocketssl => {
    name => "IO-Socket-SSL-2.099",
    url  => "https://www.cpan.org/authors/id/S/SU/SULLR/IO-Socket-SSL-2.099.tar.gz",

    # sha256 taken from http://www.cpan.org/authors/id/S/SU/SULLR/CHECKSUMS
    sha256 => "a0be800ff4852b1567ee5500e772417ad7a360abff80c01b5b875c15d44be832",
  },
  netssleay => {
    name => "Net-SSLeay-1.96",
    url  => "https://www.cpan.org/authors/id/C/CH/CHRISN/Net-SSLeay-1.96.tar.gz",

    # sha256 taken from http://www.cpan.org/authors/id/C/CH/CHRISN/CHECKSUMS
    sha256 => "ab213691685fb2a576c669cbc8d9266f8165a31563ad15b7c4030b94adfc0753",
  },
);

# sha256 checksum is from docker-perl team, cf https://github.com/docker-library/official-images/pull/12612#issuecomment-1158288299
my %cpm = (
  url    => "https://raw.githubusercontent.com/skaji/cpm/v1.1.4/cpm",
  sha256 => "6f5ae6d0e25ba20f768b8856ea61481da9d142a04629d658025011c76d3bbc3f",
);

die_with_sample unless defined $config->{releases};
die_with_sample unless ref $config->{releases} eq "ARRAY";

my $downloads = $ENV{DOCKER_PERL_DOWNLOADS_DIR} // "downloads";
if (!-d "$downloads") {
  mkdir "$downloads" or die "Couldn't create a downloads directory at $downloads";
}

my %templates = (
  debian => load_template('debian'),
  alpine => load_template('alpine'),
);

my $constraints = $config->{build_constraints} // {};

for my $build (@{$config->{builds}}) {
  $builds{$build} = $config->{options}{common};
  $builds{"$build,threaded"} = "@{$config->{options}}{qw/threaded common/}";
}

for my $release (@{$config->{releases}}) {
  do { die_with_sample unless $release->{$_} }
    for (qw(version sha256));

  die "Bad version: $release->{version}" unless $release->{version} =~ /\A5\.\d+\.\d+\Z/;

  my $patch;
  my $busybox_ps_patch;
  my $perl_src_dir;
  my $tarball = CPAN::Perl::Releases::MetaCPAN::perl_tarballs($release->{version})->{'tar.gz'};
  my ($file)  = File::Basename::fileparse($tarball);
  my $url     = "https://cpan.metacpan.org/authors/id/$tarball";
  if (-f "$downloads/$file" && `sha256sum $downloads/$file` =~ /^\Q$release->{sha256}\E\s+\Q$downloads\/$file\E/) {
    print "Skipping download of $file, already current\n";
  }
  else {
    print "Downloading $url\n";
    getstore($url, "$downloads/$file");
  }
  {
    $perl_src_dir = "$downloads/perl-$release->{version}";
    qx{rm -fR $perl_src_dir};
    mkdir $perl_src_dir or die "Couldn't create $perl_src_dir";
    qx{
      tar -C "$downloads" -xf $perl_src_dir.tar.gz &&\
      cd $perl_src_dir &&\
      chown -R \$(id -u):\$(id -g) . &&\
      git init &&\
      git add . &&\
      git commit -m tmp
    };
    die "Couldn't create a temp git repo for $release->{version}" if $? != 0;
    Devel::PatchPerl->patch_source($release->{version}, $perl_src_dir);
    $patch = qx{
      cd $perl_src_dir && git -c 'diff.mnemonicprefix=false' diff
    };
    die "Couldn't create a Devel::PatchPerl patch for $release->{version}" if $? != 0;

    # Generate the per-Perl-version busybox-ps test skip patch, but only for
    # releases that actually ship an alpine variant (nothing else consumes
    # it). Keeps debian-only releases config-only and immune to a
    # t/op/magic.t regex miss on a Perl version that never needed this patch.
    if (grep { $_->{family} eq 'alpine' } @{$release->{os_release} // []}) {
      # Line numbers in t/op/magic.t drift between Perl minors so this patch
      # must be emitted per version, parallel to DevelPatchPerl.patch above.
      # The substitution itself is stable: replace the prctl-detecting skip
      # with a busybox-compatible one.
      qx{cd $perl_src_dir && git add -A && git commit -m 'after-devel-patchperl' --allow-empty};
      qx{
        cd $perl_src_dir && perl -pi -E '
          s{skip "We don.+?prctl\\(\\).+?".*?;}{skip "Skip test to avoid external ps(1) dependency", 2;}
        ' t/op/magic.t
      };
      $busybox_ps_patch = qx{
        cd $perl_src_dir && git -c 'diff.mnemonicprefix=false' diff
      };
      die "Couldn't create busybox-ps patch for $release->{version}" if $? != 0;
      die "busybox-ps patch for $release->{version} is empty, regex may have missed t/op/magic.t"
        unless $busybox_ps_patch =~ /\S/;
    }
  }

  for my $build (keys %builds) {
    $release->{url} = $url;

    for my $name (keys %install_modules) {
      my $module = $install_modules{$name};
      $release->{"${name}_dist_$_"} = $module->{$_} for keys %$module;
    }
    $release->{"cpm_dist_$_"} = $cpm{$_} for keys %cpm;

    $release->{extra_flags} //= '';

    $release->{image} = $build =~ /main/ ? 'buildpack-deps' : 'debian';

    for my $os (@{$release->{os_release}}) {
      my ($family, $tag) = @{$os}{qw(family tag)};

      # Honor build_constraints (e.g. no slim on alpine).
      if (exists $constraints->{$family}) {
        (my $core = $build) =~ s/,threaded$//;
        next unless grep { $_ eq $core } @{$constraints->{$family}};
      }

      my $output = $templates{$family}
        or die "No template loaded for family '$family'";
      $output =~ s/\{\{$_\}\}/$release->{$_}/mg for keys %$release;
      $output =~ s/\{\{args\}\}/$builds{$build}/mg;

      if ($family eq 'debian') {
        if ($build =~ /slim/) {
          $output =~ s/\{\{docker_slim_run_install\}\}/$docker_slim_run_install/mg;
          $output =~ s/\{\{docker_slim_run_purge\}\}/$docker_slim_run_purge/mg;
          $output =~ s/\{\{tag\}\}/$tag-slim/mg;
        }
        else {
          $output =~ s/\{\{docker_slim_run_install\}\}/true/mg;
          $output =~ s/\{\{docker_slim_run_purge\}\}/true/mg;
          $output =~ s/\{\{tag\}\}/$tag/mg;
        }
      }
      elsif ($family eq 'alpine') {
        (my $alpine_tag_short = $tag) =~ s/^alpine//;
        $output =~ s/\{\{alpine_tag_short\}\}/$alpine_tag_short/mg;
      }
      else {
        die "Unknown family '$family' for $release->{version}/$tag";
      }

      my $dir = sprintf "%i.%03i.%03i-%s-%s",
        ($release->{version} =~ /(\d+)\.(\d+)\.(\d+)/), $build, $tag;

      mkdir $dir unless -d $dir;

      # Set up the generated DevelPatchPerl.patch (shared across families).
      if ($patch) {
        open my $fh, ">", "$dir/DevelPatchPerl.patch" or die "Couldn't write $dir/DevelPatchPerl.patch: $!";
        print $fh $patch;
        close $fh;
        $output =~ s!\{\{docker_copy_perl_patch\}\}!COPY *.patch /usr/src/perl/!mg;
      }
      else {
        $output =~ s!\{\{docker_copy_perl_patch\}\}!# No DevelPatchPerl.patch generated!mg;
      }

      # Alpine-specific patches: musl-stack-size (static) + skip-test-due-to-busybox-ps (per-version).
      if ($family eq 'alpine') {
        # Copy the static musl-stack-size.patch into the dir.
        qx{cp musl-stack-size.patch "$dir/musl-stack-size.patch"};
        die "Couldn't copy musl-stack-size.patch to $dir" if $? != 0;

        # Write the per-version busybox-ps patch.
        open my $fh, ">", "$dir/skip-test-due-to-busybox-ps.patch"
          or die "Couldn't write $dir/skip-test-due-to-busybox-ps.patch: $!";
        print $fh $busybox_ps_patch;
        close $fh;

        # Ensure the COPY *.patch line is enabled even if DevelPatchPerl.patch
        # was empty for this version — musl patches need to be applied.
        $output =~ s!^# No DevelPatchPerl.patch generated$!COPY *.patch /usr/src/perl/!mg;
      }

      $release->{run_tests} //= "parallel";
      if ($family eq 'alpine') {
        # Alpine uses `test_harness_notty` per Alpine APKBUILD convention for
        # no-tty Docker builds. Same parallel/serial/no semantics otherwise.
        if ($release->{run_tests} eq "serial") {
          $output =~ s/\{\{test_alpine\}\}/make test_harness_notty/;
        }
        elsif ($release->{run_tests} eq "parallel") {
          $output =~ s/\{\{test_alpine\}\}/TEST_JOBS=\$(nproc) make test_harness_notty/;
        }
        elsif ($release->{run_tests} eq "no") {
          $output =~ s/\{\{test_alpine\}\}/LD_LIBRARY_PATH=. .\/perl -Ilib -de0/;
        }
        else {
          die "run_tests was provided for $release->{version} but is invalid; should be 'parallel', 'serial', or 'no'\n";
        }
      }
      else {
        if ($release->{run_tests} eq "serial") {
          $output =~ s/\{\{test\}\}/make test_harness/;
        }
        elsif ($release->{run_tests} eq "parallel") {
          $output =~ s/\{\{test\}\}/TEST_JOBS=\$(nproc) make test_harness/;
        }
        elsif ($release->{run_tests} eq "no") {
          $output =~ s/\{\{test\}\}/LD_LIBRARY_PATH=. .\/perl -Ilib -de0/;
        }
        else {
          die "run_tests was provided for $release->{version} but is invalid; should be 'parallel', 'serial', or 'no'\n";
        }
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
config.yml file correctly configured.

The top-level config keys are:

=over 4

=item builds

A list of build variant names (e.g. C<main>, C<slim>). Each build is
also emitted in a threaded variant (C<main,threaded>).

=item options

A hash with C<common> and C<threaded> keys supplying C<Configure> flags
shared across all releases.

=item build_constraints

An optional map from OS family name to an allowlist of build variants.
When a family appears here, only the listed (non-threaded) builds are
emitted for that family; the threaded counterparts follow automatically.
If a family is absent, all builds apply. An empty list skips the family
entirely.

    build_constraints:
      alpine: [main]   # no slim on alpine

=back

The C<releases> key contains a list of releases, each with the following keys:

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

=item os_release

A list of OS targets this Perl release should be built for. Each entry
is a hash with C<family> and C<tag> keys:

    - version: 5.42.2
      sha256: ...
      os_release:
        - { family: debian, tag: bullseye }
        - { family: debian, tag: bookworm }
        - { family: alpine, tag: alpine3.23 }
        - { family: alpine, tag: alpine3.24 }

C<family> is either C<debian> or C<alpine>. C<tag> is the OS-specific
release tag. For Debian families, C<-slim> is appended to the tag for
C<slim> builds. For Alpine families, only the builds listed in
C<build_constraints> (top-level key) are emitted.

=item extra_flags

Additional text to pass to C<Configure>.  At the moment, this is
necessary for 5.18.x so that it can get the C<-fwrapv> flag.

Default: C<"">

=item run_tests

This can be 'parallel' (default), 'serial', or 'no'.

Added due to dist/IO/t/io_unix.t failing when TEST_JOBS > 1, but should
only be used in case of a documented issue or old release (see
L<Devel::PatchPerl's CAVEAT|https://metacpan.org/pod/Devel::PatchPerl#CAVEAT>).

Default: C<parallel>

=back

=back

=head1 ALPINE VARIANT GENERATION

For each release with C<family: alpine> entries in C<os_release>,
C<generate.pl> performs additional steps:

=over 4

=item Template dispatch

Alpine Dockerfiles are rendered from C<Dockerfile.alpine.template>
instead of C<Dockerfile.debian.template>. The C<{{alpine_tag_short}}>
template variable is derived by stripping the C<alpine> prefix from the
OS tag (e.g. C<alpine3.23> → C<3.23>).

=item musl-stack-size.patch

The static C<musl-stack-size.patch> (in the repo root) is copied into
every alpine output directory. It bumps the minimum thread stack size to
256k, working around L<perl5#18160|https://github.com/Perl/perl5/issues/18160>
which remains open on musl/Alpine.

=item skip-test-due-to-busybox-ps.patch

A per-Perl-version patch is generated by editing C<t/op/magic.t> to
replace the C<prctl()>-detecting ps-skip with a busybox-compatible one.
Because the relevant line numbers in C<t/op/magic.t> drift between Perl
minors, this patch must be regenerated for each version rather than
being static.

=item C<COPY *.patch> always enabled

For alpine directories, the C<COPY *.patch> Dockerfile line is
force-enabled even when C<DevelPatchPerl.patch> is empty, so that the
musl-specific patches are always applied.

=item Test harness

Alpine builds use C<test_harness_notty> instead of C<test_harness> (the
C<{{test_alpine}}> template variable) per Alpine APKBUILD convention for
no-tty Docker environments.

=back

=cut
