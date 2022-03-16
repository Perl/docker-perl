requires 'Devel::PatchPerl';
requires 'YAML::XS';
requires 'LWP::Simple';

on 'develop' => sub {
    requires 'Perl::Tidy';
};
