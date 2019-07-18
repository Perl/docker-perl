docker-perl
===========

This project is the source for the Docker perl repo; for more details,
take a look at https://registry.hub.docker.com/_/perl/.

The structure of this repo is to use the full version ID of each Perl
version, plus a comma separate list of extensions, followed by the
Debian release codename that the resulting Docker image will be based
from.

The Docker Perl image now builds and runs in architectures other than
`amd64`, such as [`i386`][1] and [`arm64v8`][2]; see
[docker-library/official-images][3] for the details.


[1]: https://hub.docker.com/r/i386/perl/
[2]: https://hub.docker.com/r/arm64v8/perl
[3]: https://github.com/docker-library/official-images#architectures-other-than-amd64

## Getting Started

The individual Dockerfiles are generated via `generate.pl`, which uses
Releases.yaml to populate the individual files.  This needs the
`Devel::PatchPerl` and `YAML::XS` modules, which you can install by
doing `cpanm --installdeps .` in this repository's root directory.
    
To regenerate the `Dockerfile`s, just run `./generate.pl`.  Do note that
this might take time as it will download the Perl source tarballs for
each version to re-patch with updates from `Devel::PatchPerl` as needed.
Also, it is advised to update `Devel::PatchPerl` as soon as a new
version comes out.

For older versions of Perl, some patches may be necessary to build
properly on a current base OS.  In those cases, perl -V will show the
locally applied patches.  These changes should be limited to Configure
rather than to code itself, and will be a cherry pick or back port of a
patch from the mainline perl branch whenever possible.
