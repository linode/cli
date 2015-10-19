use strict;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Linode::CLI',
    VERSION_FROM => 'lib/Linode/CLI/Util.pm',
    ABSTRACT     => 'A simple command-line interface to the Linode platform.',
    AUTHOR       => 'Linode, LLC',
    PREREQ_PM    => {
        'JSON'               => 0,
        'LWP::UserAgent'     => 0,
        'Mozilla::CA'        => 0,
        'Try::Tiny'          => 0,
        'WebService::Linode' => 0,
    },
    PMLIBDIRS    => [
        'lib/Linode',
    ],
    EXE_FILES    => [
        'linode',
        'linode-account',
        'linode-domain',
        'linode-linode',
        'linode-nodebalancer',
        'linode-stackscript',
    ],
);