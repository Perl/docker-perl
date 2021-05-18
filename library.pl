#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
use YAML::XS;

my %arches = (
	# https://github.com/docker-library/official-images/blob/master/library/debian
	buster => 'amd64, arm32v7, arm64v8, i386, ppc64le, s390x',
	stretch => 'amd64, arm32v7, arm64v8, i386',
);

print <<"END_HEADER";
Maintainers: Peter Martini <PeterCMartini\@GMail.com> (\@PeterMartini),
             Zak B. Elep <zakame\@cpan.org> (\@zakame)
GitRepo: https://github.com/perl/docker-perl.git
GitCommit: @{[ qx{ git log -1 --format=format:%H } ]}
Architectures: $arches{buster}
END_HEADER

sub suffix {
	my $suffix = shift;
	return map { $_ eq 'latest' ? $suffix : $_ . '-' . $suffix } @_;
}

sub entry {
	my $version = shift;
	my $build = shift;
	my $debian = shift;
	my $eol = shift // 0;

	my @versionAliases = ();

	my @version = split /[.]/, $version;
	for my $i (reverse 0 .. @version-1) {
		push @versionAliases, join '.', @version[0 .. $i];
	}

	push @versionAliases, 'latest';

	(my $buildSuffix = $build) =~ s/^main,//;
	$buildSuffix =~ s/,/-/g;
	my @buildAliases = ($build eq 'main' ? @versionAliases : suffix $buildSuffix, @versionAliases);

	my @debianAliases = suffix $debian, @buildAliases;

	my @aliases = ( ($eol ? () : @buildAliases), @debianAliases );

	state %latest = ();
	@aliases = grep { !defined $latest{$_} } @aliases;
	@latest{ @aliases } = ( 1 ) x @aliases;

	print <<~"END_ENTRY";

	Tags: @{[ join ', ', @aliases ]}@{[ defined $arches{$debian} ? "\nArchitectures: $arches{$debian}" : '' ]}
	Directory: @{[ ($eol ? 'eol/' : '') . sprintf '%i.%03i.%03i-%s-%s', @version, $build, $debian ]}
	END_ENTRY
}

sub release {
	my $release = shift;
	my $builds = shift;
	my $eol = shift // 0;

	my @builds = (@$builds, map { "$_,threaded" } @$builds);

	for my $build (@builds) {
		for my $debian (reverse @{ $release->{debian_release} }) {
			entry $release->{version}, $build, $debian, $eol;
		}
	}
}

my $config = do {
	open my $fh, '<', 'config.yml' or die "Couldn't open config";
	local $/;
	Load <$fh>;
};

release $_, $config->{builds} for (reverse @{ $config->{releases} });

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

release $_, $config->{builds}, 1 for (reverse @{ $config->{releases} });
