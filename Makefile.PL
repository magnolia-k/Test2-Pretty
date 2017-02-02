use 5.006;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test2-Pretty',
    AUTHOR              => q{magnolia <magnolia.k@me.com>},
    VERSION_FROM        => 'lib/Test/Pretty.pm',
    ABSTRACT_FROM       => 'lib/Test/Pretty.pm',
    LICENSE             => 'perl',
    MIN_PERL_VERSION    => 5.008001,

    CONFIGURE_REQUIRES  => {
        'ExtUtils::MakeMaker' => 6.52,
    },

    BUILD_REQUIRES      => {
        'ExtUtils::MakeMaker' => 6.52,
    },

    TEST_REQUIRES       => {
        'Test::Requires'    => 0,
    },

    PREREQ_PM           => {
        'Test::More'        => 1.302075,
        'Term::Encoding'    => 0,
        'Scorp::Guard'      => 0,
    }
);
