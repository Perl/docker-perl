#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use Perl::Version;
use YAML::XS;

my %arches = (

  # https://github.com/docker-library/official-images/blob/master/library/debian
  default  => 'amd64, arm32v5, arm32v7, arm64v8, i386, mips64le, ppc64le, s390x',
  bullseye => 'amd64, arm32v7, arm64v8, i386',
  buster   => 'amd64, arm32v7, arm64v8, i386',
);

print <<"END_HEADER";
Maintainers: Peter Martini <PeterCMartini\@GMail.com> (\@PeterMartini),
             Zak B. Elep <zakame\@cpan.org> (\@zakame)
GitRepo: https://github.com/perl/docker-perl.git
GitCommit: @{[ qx{ git log -1 --format=format:%H } ]}
Architectures: $arches{default}
END_HEADER

sub suffix {
  my $suffix = shift;
  map { $_ eq 'latest' ? $suffix : $_ . '-' . $suffix } @_;
}

sub entry {
  my $version = shift;
  my $build   = shift;
  my $debian  = shift;
  my $eol     = shift // 0;

  my @versionAliases = ();

  my @version = split /[.]/, $version;
  for my $i (reverse 0 .. @version - 1) {
    push @versionAliases, join '.', @version[0 .. $i];
  }

  if (Perl::Version->new($version)->version % 2) {
    push @versionAliases, 'devel';
  }
  else {
    push @versionAliases, 'latest', 'stable';
  }
 
  (my $buildSuffix = $build) =~ s/^main,//;
  $buildSuffix =~ s/,/-/g;
  my @buildAliases = ($build eq 'main' ? @versionAliases : suffix $buildSuffix, @versionAliases);

  my @debianAliases = suffix $debian, @buildAliases;

  my @aliases = (($eol ? () : @buildAliases), @debianAliases);

  state %latest = ();
  @aliases = grep { !defined $latest{$_} } @aliases;
  @latest{@aliases} = (1) x @aliases;

  print <<~"END_ENTRY";

	Tags: @{[ join ', ', @aliases ]}@{[ defined $arches{$debian} ? "\nArchitectures: $arches{$debian}" : '' ]}
	Directory: @{[ ($eol ? 'eol/' : '') . sprintf '%i.%03i.%03i-%s-%s', @version, $build, $debian ]}
	END_ENTRY
}

sub release {
  my $release = shift;
  my $builds  = shift;
  my $eol     = shift // 0;

  my @builds = (@$builds, map {"$_,threaded"} @$builds);

  for my $build (@builds) {
    for my $debian (reverse @{$release->{debian_release}}) {
      entry $release->{version}, $build, $debian, $eol;
    }
  }
}

my $config = do {
  open my $fh, '<', 'config.yml' or die "Couldn't open config";
  local $/;
  Load <$fh>;
};

release $_, $config->{builds} for reverse @{$config->{releases}};

exit unless @ARGV == 1 && $ARGV[0] eq '--eol';

print <<END_EOL_COMMENT;

#
# THE FOLLOWING (EOL) TAGS ARE INTENDED AS A ONE-TIME BACKFILL/REBUILD
#
#   (they will be removed after they are successfully rebuilt)
#
END_EOL_COMMENT

$config = do {
  open my $fh, '<', 'eol/config.yml' or die "Couldn't open config";
  local $/;
  Load <$fh>;
};

release $_, $config->{builds}, 1 for reverse @{$config->{releases}};

=pod

=head1 NAME

library.pl - generate YAML for library/perl manifest on docker-library

=head1 SYNOPSIS

    cd /path/to/docker-perl
    ./library.pl [--eol]

=head1 DESCRIPTION

library.pl is a helper script to generate a suitable manifest for
updating C<library/perl> on
L<docker-library/official-images|https://github.com/docker-library/official-images>,
which is the reference for producing the
L<official Docker Perl images|https://hub.docker.com/_/perl>.

This script optionally takes an C<--eol> option, for including entries
corresponding to unsupported Perl versions that require a rebuild on the
Docker Hub as needed (e.g. for updating base image dependencies.)

=cut
