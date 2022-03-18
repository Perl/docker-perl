requires 'Devel::PatchPerl';
requires 'YAML::XS';
requires 'LWP::Simple';
requires 'LWP::Protocol::https';

on 'develop' => sub {
    requires 'Perl::Tidy';
};
