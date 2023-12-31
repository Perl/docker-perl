requires 'CPAN::Perl::Releases::MetaCPAN';
requires 'Devel::PatchPerl';
requires 'YAML::XS';
requires 'LWP::Simple';
requires 'LWP::Protocol::https';
requires 'Perl::Version';

on 'develop' => sub {
    requires 'Perl::Tidy';
};
