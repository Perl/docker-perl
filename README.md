docker-perl
===========

Dockerfiles for Perl5

The structure of this repo is to use the full version ID of each Perl version,
plus a comma separate list of extensions.  Every directory is expected to have
at least the bit specification (32bit or 64bit), and at the moment the only
other extension is threaded.

There are currently no 32bit extensions as Docker does not (yet?) support 32-bit
builds.

The 64bit builds specify use64bitall despite this being largely redundant
(Configure would properly detect this) to make the desired bit size explicit.
