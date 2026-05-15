#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use Test::More;
use YAML::XS qw(LoadFile);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $root = abs_path(dirname(__FILE__) . '/..');
chdir $root or BAIL_OUT("couldn't chdir to $root: $!");

my @alpine_dirs = sort grep { -d } glob '*-alpine*';
BAIL_OUT("no *-alpine* directories found, has generate.pl been run?")
  unless @alpine_dirs;

diag("Found " . scalar(@alpine_dirs) . " alpine directories.");

my $config = LoadFile('config.yml');

# Expected count: each `family: alpine` os_release entry across all releases,
# times 2 threading variants (main and main,threaded).
my @alpine_tags;
for my $release (@{$config->{releases}}) {
  push @alpine_tags, map { $_->{tag} }
    grep { $_->{family} eq 'alpine' } @{$release->{os_release} // []};
}
my $expected_alpine = @alpine_tags * 2;

is(scalar(@alpine_dirs), $expected_alpine,
  "expected exactly $expected_alpine alpine directories");

# Adversarial: no slim+alpine combinations should exist.
my @slim_alpine = grep { /slim/ } @alpine_dirs;
is(scalar(@slim_alpine), 0,
  "no slim+alpine directories (build_constraints violation)")
  or diag("found: @slim_alpine");

# Adversarial: each known alpine tag must individually have the right count
# (the total can mask a tag being entirely missing if another has double).
my @atags = sort keys %{{map { $_ => 1 } @alpine_tags}};
my $expected_per_tag = @atags ? $expected_alpine / @atags : 0;
for my $atag (@atags) {
  my @tag_dirs = grep { /-\Q$atag\E\z/ } @alpine_dirs;
  is(scalar(@tag_dirs), $expected_per_tag,
    "$atag: expected $expected_per_tag directories");
}

for my $dir (@alpine_dirs) {
  subtest $dir => sub {
    open my $fh, '<', "$dir/Dockerfile"
      or BAIL_OUT("couldn't read $dir/Dockerfile: $!");
    local $/;
    my $dockerfile = <$fh>;
    close $fh;

    # Static: patches present, non-empty, and contain expected content.
    my $musl_patch = "$dir/musl-stack-size.patch";
    if (ok(-s $musl_patch, "musl-stack-size.patch present and non-empty")) {
      like(slurp($musl_patch), qr/256\*1024/,
        "musl-stack-size.patch has the expected stack-size hunk");
    }

    my $busybox_patch = "$dir/skip-test-due-to-busybox-ps.patch";
    if (ok(-s $busybox_patch, "skip-test-due-to-busybox-ps.patch present and non-empty")) {
      like(slurp($busybox_patch),
        qr/Skip test to avoid external ps\(1\) dependency/,
        "skip-test-due-to-busybox-ps.patch has the expected busybox-ps skip hunk");
    }

    # Static: Dockerfile copies patches into build context, then applies them.
    like($dockerfile, qr/COPY \*\.patch/,
      "Dockerfile copies *.patch into build context");
    like($dockerfile, qr/cat \*\.patch \| patch -p1/,
      "Dockerfile applies patches (cat *.patch | patch -p1)");
    like($dockerfile, qr/make test_harness_notty/,
      "Dockerfile uses test_harness_notty");

    like($dockerfile, qr/^FROM alpine:/m, "Dockerfile is FROM alpine:<tag>");

    # Adversarial: FROM alpine tag must be well-formed N.NN (not 'latest',
    # 'edge', etc), and must match the alpine tag encoded in the directory name.
    my ($alpine_tag) = $dockerfile =~ /^FROM alpine:(\S+)/m;
    if (ok(defined($alpine_tag), "found a FROM alpine: tag")) {
      like($alpine_tag, qr/^\d+\.\d+\z/,
        "FROM alpine tag '$alpine_tag' is well-formed (N.NN)");

      my ($dir_alpine_tag) = $dir =~ /(alpine[\d.]+)\z/;
      is("alpine$alpine_tag", $dir_alpine_tag,
        "FROM alpine:$alpine_tag matches directory tag $dir_alpine_tag");
    }

    # Adversarial: -Dusethreads in ./Configure must align with whether the
    # directory is a threaded variant.
    my ($configure_line) = $dockerfile =~ /^(.*\.\/Configure.*)$/m;
    $configure_line //= '';
    my $is_threaded = $dir =~ /,threaded/;
    my $has_usethreads = $configure_line =~ /-Dusethreads/;
    is(!!$has_usethreads, !!$is_threaded,
      $is_threaded
        ? "threaded variant has -Dusethreads in ./Configure"
        : "non-threaded variant has no -Dusethreads in ./Configure");

    # Static: tzdata must appear in the permanent apk add block.
    like($dockerfile, qr/tzdata/, "Dockerfile installs tzdata");

    # Static: CMD must reference the perl version that matches the directory name.
    my ($dir_version) = $dir =~ /^([\d.]+)-/;
    my $expected_version = join '.', map { $_ + 0 } split /\./, $dir_version;
    my ($cmd_version) = $dockerfile =~ /^CMD.*?perl([\d.]+)"/m;
    is($cmd_version, $expected_version,
      "CMD references perl$expected_version");

    # Static: cpanm must have the HTTPS URL rewrite, no-LWP, and no-wget
    # patches applied (busybox wget lacks --retry-connrefused).
    like($dockerfile, qr/s\{http:\/\//, "cpanm HTTPS URL rewrite patch present");
    like($dockerfile, qr/try_lwp=>0/, "cpanm no-LWP patch present");
    like($dockerfile, qr/try_wget=>0/, "cpanm no-wget patch present");

    # Runtime checks (optional, requires already-built perl:<tag> images).
    SKIP: {
      skip "RUN_RUNTIME not set", 7 unless $ENV{RUN_RUNTIME};

      # Repo convention (see .github/workflows/build-image.yml): tag the
      # built image as perl:${dir//,/-}. Comma in `main,threaded` becomes a
      # dash, because Docker tags don't accept commas.
      (my $tag_suffix = $dir) =~ s/,/-/g;
      my $tag = "perl:$tag_suffix";

      is(system(qw(docker run --rm), $tag, qw(sh -c),
          'apk info -e build-base make openssl-dev linux-headers libc-dev zlib-dev bzip2-dev ca-certificates curl > /dev/null'),
        0, "$tag retains all permanent apk packages");

      # Checked per-package so partial retention (e.g. only 'patch' left
      # behind) is not missed by a single combined query.
      my $retained = 0;
      for my $pkg (qw(dpkg dpkg-dev patch procps tar xz)) {
        if (system(qw(docker run --rm), $tag, qw(sh -c),
            'apk info -e "$1" > /dev/null 2>&1', 'sh', $pkg) == 0) {
          diag("$tag retained transient build-dep: $pkg (should have been apk del'd)");
          $retained = 1;
        }
      }
      ok(!$retained, "$tag purged all transient build-deps");

      is(system(qw(docker run --rm), $tag, qw(sh -c),
          'which gcc && which make && pkg-config --exists openssl'),
        0, "$tag toolchain (gcc, make, openssl) reachable at runtime");

      is(system(qw(docker run --rm), $tag, qw(perl -e),
          'use POSIX; my $l = POSIX::setlocale(POSIX::LC_ALL, ""); print defined($l) ? $l : "undef"; print "\n"'),
        0, "$tag POSIX::setlocale does not die");

      is(system(qw(docker run --rm), $tag, qw(perl -e), 'use Net::SSLeay; use IO::Socket::SSL'),
        0, "$tag can load Net::SSLeay and IO::Socket::SSL");

      SKIP: {
        skip "not a threaded variant", 1 unless $is_threaded;
        is(system(qw(docker run --rm), $tag, qw(perl -e), 'use threads; threads->create(sub {})->join'),
          0, "$tag threaded variant can create and join a thread");
      }

      is(system(qw(docker run --rm), $tag, qw(cpanm -n Linux::Inotify2)),
        0, "$tag can install Linux::Inotify2 (XS musl/linux-headers smoke)");
    }
  };
}

done_testing();

sub slurp {
  my ($file) = @_;
  open my $fh, '<', $file or BAIL_OUT("couldn't read $file: $!");
  local $/;
  return <$fh>;
}

=pod

=head1 NAME

alpine-checks.t - static and (optional) runtime checks for the alpine variant

=head1 SYNOPSIS

    prove t/alpine-checks.t                  # static only
    RUN_RUNTIME=1 prove t/alpine-checks.t    # also runtime (requires built images)

=head1 DESCRIPTION

Static checks assert against the generated Dockerfile and patch presence
for every C<*-alpine*> directory. Runtime checks (gated on C<RUN_RUNTIME=1>)
run C<docker run> assertions against already-built C<perl:E<lt>tagE<gt>>
images and are skipped otherwise.

=cut
