#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use Test::More;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Pod::Usage qw(pod2usage);

pod2usage(-verbose => 1, -exitval => 0)
  if @ARGV && ($ARGV[0] eq '-h' || $ARGV[0] eq '--help');

my $root;
if (!@ARGV) {
  $root = abs_path(dirname(__FILE__) . '/..');
}
elsif ($ARGV[0] =~ /^-/) {
  BAIL_OUT("unknown option: $ARGV[0]");
}
else {
  BAIL_OUT("not a directory: $ARGV[0]") unless -d $ARGV[0];
  $root = abs_path($ARGV[0]);
}

chdir $root or BAIL_OUT("couldn't chdir to $root: $!");

BAIL_OUT("$root is not inside a git work tree (git ls-files unavailable)")
  unless system('sh', '-c', 'git rev-parse --is-inside-work-tree >/dev/null 2>&1') == 0;

my @to_check;
for my $dockerfile (sort glob '*/Dockerfile') {
  open my $fh, '<', $dockerfile or BAIL_OUT("couldn't read $dockerfile: $!");
  local $/;
  my $content = <$fh>;
  close $fh;

  # Alpine-specific marker: only alpine variants build FROM alpine:<tag>.
  next unless $content =~ /^FROM alpine:/m;

  # Only care about Dockerfiles that actually depend on patch files.
  next unless $content =~ /COPY \*\.patch/ || $content =~ /patch -p1/;

  (my $dir = $dockerfile) =~ s{/Dockerfile\z}{};
  push @to_check, $dir;
}

if (!@to_check) {
  plan skip_all => "found no alpine Dockerfiles that depend on patches, has generate.pl been run?";
}

for my $dir (@to_check) {
  subtest $dir => sub {
    my @patches = sort glob "$dir/*.patch";

    if (!@patches) {
      fail("$dir/Dockerfile requires patches (COPY *.patch / patch -p1)"
        . " but no *.patch files exist in $dir/,"
        . " docker build would fail at the COPY step on a fresh clone");
      return;
    }

    for my $patch (@patches) {
      # Pass $patch as a positional arg to the inner shell (rather than
      # interpolating it into the command string) so list-form system()
      # still gets the >/dev/null redirect without any quoting concerns.
      system('sh', '-c', 'git ls-files --error-unmatch "$1" >/dev/null 2>&1', 'sh', $patch);
      ok($? == 0, "$patch is tracked by git")
        or diag("$patch exists on disk but is NOT tracked by git,"
          . " a fresh clone won't have it, so 'COPY *.patch' in $dir/Dockerfile will fail."
          . " Fix: git add $patch");
    }
  };
}

done_testing();

=pod

=head1 NAME

check-patch-consistency.t - alpine Dockerfile patches present and tracked

=head1 SYNOPSIS

    prove t/check-patch-consistency.t                 # scan this repo
    prove t/check-patch-consistency.t :: /some/dir    # scan a specific repo/worktree
    perl t/check-patch-consistency.t --help

=head1 DESCRIPTION

Each generated alpine Dockerfile does C<COPY *.patch /usr/src/perl/> and then
C<cat *.patch | patch -p1>. If those patch files are missing, or exist on
disk but are not committed, a fresh C<git clone> will not have them.
Under current BuildKit/ash semantics this is a silent failure, not a loud
one: C<COPY> with zero glob matches no-ops, and C<cat *.patch | patch -p1>
on empty input exits 0 without C<pipefail>. This test catches that class of
bug statically, before any image is built.

Read-only: inspects files and queries git, never modifies the working tree.

=cut
