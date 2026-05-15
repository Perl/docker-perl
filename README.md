docker-perl
===========

This project is the source for the [Docker Library official perl images](https://registry.hub.docker.com/_/perl/),
which builds the officially-supported perl versions ([perlpolicy](https://perldoc.perl.org/perlpolicy)) on 
the officially supported Debian base images for several 
architectures. These are reviewed and built by Docker Library.

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

The `t/` directory holds regression checks for the generated
Dockerfiles, run with `prove -r t/`.  These read the generated files,
so run `./generate.pl` first.  By default only static checks run;
setting `RUN_RUNTIME=1` additionally runs `docker run` assertions in
`t/alpine-checks.t` against already-built `perl:<tag>` images, which
are skipped otherwise.

## Alpine Variants

From Perl 5.40 onwards, `perl` is also published in Alpine Linux variants
alongside the existing Debian-based ones. These follow the same template-driven
generation through `generate.pl` and share the same Net::SSLeay / IO::Socket::SSL
/ cpanm / cpm tooling as the Debian `main` variants.

**Published tags** (per supported Perl version, `<version>`):

| Tag | Base | Threading |
|---|---|---|
| `<version>-alpine` (rolling, aliases current stable) | alpine:3.24 | non-threaded |
| `<version>-threaded-alpine` (rolling) | alpine:3.24 | threaded |
| `<version>-alpine3.24` (pinned, current stable) | alpine:3.24 | non-threaded |
| `<version>-threaded-alpine3.24` (pinned) | alpine:3.24 | threaded |
| `<version>-alpine3.23` (pinned, previous stable) | alpine:3.23 | non-threaded |
| `<version>-threaded-alpine3.23` (pinned) | alpine:3.23 | threaded |

Two alpine versions ship per Perl release: current stable and previous stable,
mirroring the cadence of `python:3-alpine` and `ruby:3-alpine`.

### Caveats

* **No `-slim` on alpine.** Alpine is already minimal, there is no separate
  `slim-alpine` variant. Use `perl:<version>-slim-<debian-tag>` for the
  smallest official images.
* **Alpine uses musl libc.** For the vast majority of Pure Perl and well-behaved
  XS modules, this is transparent. Quirks users may occasionally encounter:
  * `setlocale()` and locale handling work but may differ from glibc in edge
    cases (musl's locale support is functional but not full-fat).
  * Threaded Perl on musl: all alpine images ship a musl stack-size patch
    (256k floor) that works around upstream
    [perl5#18160](https://github.com/Perl/perl5/issues/18160).
* **Build toolchain retained at runtime.** Unlike `python:3-alpine` and
  `ruby:3-alpine` which strip the compiler after build, these images keep
  `build-base`, `make`, `openssl-dev`, and friends so `cpanm` / `cpm`
  installs of XS modules work out of the box, parallel to debian-main's
  `buildpack-deps`-based image.
* **`tzdata` pre-installed.** Unlike many Alpine images, `tzdata` is
  permanently installed so timezone-aware Perl applications work without
  any extra setup.
* **Default shell is busybox `sh`, not bash.** `RUN` steps using
  bash-specific syntax (`[[ ]]`, `source`, process substitution) will
  fail. Write portable POSIX shell in `RUN` steps, or add
  `apk add bash` and use `SHELL ["/bin/bash", "-c"]`.

## See Also

* [Docker Library FAQ](https://github.com/docker-library/faq?tab=readme-ov-file#what-do-you-mean-by-official)

