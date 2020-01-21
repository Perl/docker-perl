requires 'Devel::PatchPerl';
requires 'YAML::XS';
requires 'version', '0.77';

on 'develop' => sub {
    requires 'Perl::Tidy';
};
