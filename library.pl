#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use Perl::Version;
use YAML::XS;

my %arches = (

  # https://github.com/docker-library/official-images/blob/master/library/debian
  default  => 'amd64, arm32v5, arm32v7, arm64v8, ppc64le, riscv64, s390x',
  bookworm => 'amd64, arm32v7, arm64v8, i386, ppc64le',
  bullseye => 'amd64, arm32v7, arm64v8, i386',

  # https://github.com/docker-library/official-images/blob/master/library/alpine
  # Same set across 3.23/3.24; kept per-tag so a future divergence is a
  # one-line edit instead of a refactor.
  'alpine3.23' => 'amd64, arm32v6, arm32v7, arm64v8, i386, ppc64le, riscv64, s390x',
  'alpine3.24' => 'amd64, arm32v6, arm32v7, arm64v8, i386, ppc64le, riscv64, s390x',
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
  my $family  = shift;   # 'debian' or 'alpine'
  my $tag     = shift;   # OS tag, e.g. 'bookworm' or 'alpine3.23'
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

  # Tag-specific aliases (e.g. '5.42.2-alpine3.23') always emitted.
  my @tagAliases = suffix $tag, @buildAliases;

  # Bare-family aliases (e.g. '5.42.2-alpine') emitted for non-debian
  # families so users can pull 'perl:alpine' like they pull 'perl:slim'.
  # The state %latest dedup below guarantees only the first-seen entry
  # per family per Perl version wins these short aliases.
  my @familyAliases = $family eq 'debian' ? () : suffix $family, @buildAliases;

  my @aliases = (($eol ? () : @buildAliases), @familyAliases, @tagAliases);

  state %latest = ();
  @aliases = grep { !defined $latest{$_} } @aliases;
  @latest{@aliases} = (1) x @aliases;

  # For debian, an unlisted tag safely falls back to the header's default
  # Architectures line (e.g. trixie has no override because it matches
  # default). Non-debian families have no such safe fallback: the header
  # default is debian-shaped (e.g. includes arm32v5, excludes i386), so a
  # missing %arches entry for e.g. a new alpine tag would silently publish
  # the wrong architecture list instead of failing loudly.
  warn "No \%arches entry for '$tag' (family '$family') in library.pl."
    . " Falling back to the debian-shaped default Architectures list, which is"
    . " probably wrong for this family. Add a '$tag' entry to \%arches.\n"
    if $family ne 'debian' && !defined $arches{$tag};

  print <<~"END_ENTRY";

	Tags: @{[ join ', ', @aliases ]}@{[ defined $arches{$tag} ? "\nArchitectures: $arches{$tag}" : '' ]}
	Directory: @{[ ($eol ? 'eol/' : '') . sprintf '%i.%03i.%03i-%s-%s', @version, $build, $tag ]}
	END_ENTRY
}

sub release {
  my $release     = shift;
  my $builds      = shift;
  my $constraints = shift // {};
  my $eol         = shift // 0;

  # Backwards compat for eol/config.yml: synthesize os_release from
  # legacy debian_release. Lets us defer migrating the EOL backfill
  # config without breaking manifest emission.
  if (!exists $release->{os_release} && exists $release->{debian_release}) {
    $release->{os_release} = [
      map { { family => 'debian', tag => $_ } } @{$release->{debian_release}}
    ];
  }

  my @builds = (@$builds, map {"$_,threaded"} @$builds);

  # Partition so debian wins top-level unsuffixed aliases and the newest
  # alpine wins rolling `-alpine` aliases. Within each group, reverse so
  # the LAST listed entry in config.yml (typically the newest tag) is
  # consumed first by the state %latest dedup.
  my @debian_entries = grep { $_->{family} eq 'debian' } @{$release->{os_release}};
  my @other_entries  = grep { $_->{family} ne 'debian' } @{$release->{os_release}};

  for my $build (@builds) {
    for my $os (reverse(@debian_entries), reverse(@other_entries)) {
      my ($family, $tag) = @{$os}{qw(family tag)};

      # Honor build_constraints: if the family has an allowlist, the
      # core build (sans ',threaded') must be in it.
      if (exists $constraints->{$family}) {
        (my $core = $build) =~ s/,threaded$//;
        next unless grep { $_ eq $core } @{$constraints->{$family}};
      }

      entry $release->{version}, $build, $family, $tag, $eol;
    }
  }
}

my $config = do {
  open my $fh, '<', 'config.yml' or die "Couldn't open config";
  local $/;
  Load <$fh>;
};

release $_, $config->{builds}, $config->{build_constraints} for reverse @{$config->{releases}};

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

release $_, $config->{builds}, $config->{build_constraints}, 1 for reverse @{$config->{releases}};

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

=head1 FUNCTIONS

=head2 entry($version, $build, $family, $tag, $eol)

Emits a single Docker image manifest stanza for the given combination of
Perl C<$version> (e.g. C<5.42.2>), build variant C<$build> (e.g. C<main>,
C<main,threaded>), OS C<$family> (C<debian> or C<alpine>), OS C<$tag>
(e.g. C<bookworm>, C<alpine3.23>), and optional C<$eol> flag.

=head3 Tag Aliasing

Two alias groups are emitted per entry:

=over 4

=item Pinned tag aliases

Always emitted. Include the OS tag as a suffix (e.g. C<5.42.2-alpine3.23>,
C<5.42.2-threaded-alpine3.23>).

=item Rolling family aliases

Emitted for non-C<debian> families only (e.g. C<5.42.2-alpine>,
C<5.42.2-threaded-alpine>). This lets users pull C<perl:alpine> the same
way they pull C<perl:slim>.

=back

A C<state %latest> dedup table ensures each alias is claimed by at most
one entry. The emission order in C<release()> (debian entries first,
then other families, each group reversed) guarantees that Debian entries
win top-level unsuffixed aliases and the newest alpine tag (last in
C<config.yml>) wins the rolling C<-alpine> aliases.

=head2 release($release, $builds, $constraints, $eol)

Emits manifest stanzas for all build × OS combinations for a single
C<$release> hash (as read from C<config.yml>).

C<$constraints> is the C<build_constraints> hash from C<config.yml>:
when a family appears in it, only the listed core build variants are
emitted for that family (threaded counterparts are added automatically).

Includes a backwards-compatibility shim: if C<os_release> is absent but
C<debian_release> is present (used by C<eol/config.yml> entries), it
synthesises C<os_release> from the legacy key so EOL entries do not need
to be migrated.

=cut
