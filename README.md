docker-perl
===========

Dockerfiles for Perl5

This project is the source for the Docker perl repo; for more details, take
a look at https://registry.hub.docker.com/_/perl/.

The structure of this repo is to use the full version ID of each Perl version,
plus a comma separate list of extensions.  Every directory is expected to have
at least the bit specification (32bit or 64bit), and at the moment the only
other extension is threaded.

There are currently no 32bit extensions as Docker does not (yet?) support 32-bit
builds.

The 64bit builds specify use64bitall despite this being largely redundant
(Configure would properly detect this) to make the desired bit size explicit.

The individual Dockerfiles are generated via 'generate.pl', which uses
Releases.yaml to populate the individual files.

For older versions of Perl, some patches may be necessary to build properly on
a current base OS.  In those cases, perl -V will show the locally applied patches.
These changes should be limited to Configure rather than to code itself, and
will be a cherry pick or back port of a patch from the mainline perl branch
whenever possible.

## Generate Dockerfiles

You can (re)generate Dockerfiles locally by

	$ cpanm --installdeps .

to install a single dependent library, and then

	$ ./generate.pl
	
After that, you can check any file like this

	$ sudo docker build -t test-perl-5.26 5.026.000-64bit/
	
	
