package Linode::CLI::Util;

use 5.010;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT      = qw();
our %EXPORT_TAGS = (
    basic => [(qw(
        error load_config human_displaymemory succeed fail format_squish format_tf
        format_len colorize glob_tilde %correct_case %humanstatus %humanyn
        %humandc %paramsdef @MODES $VERSION
    ))],
    config => ['write_config'],
    json   => ['json_response'],
);
our @EXPORT_OK = (qw(
        json_response error load_config write_config human_displaymemory succeed fail
        format_squish format_tf format_len colorize glob_tilde %correct_case
        %humanstatus %humanyn %humandc %paramsdef @MODES $VERSION
));

use Carp;
use JSON;
use Pod::Usage;
use Getopt::Long (qw(:config no_ignore_case bundling pass_through));
use Term::ANSIColor ':constants';

our $VERSION = '1.3.2';
our @MODES   = (qw(
    linode stackscript domain nodebalancer longview account user
));

our %correct_case = (
    'linode'       => 'Linode',
    'account'      => 'Account',
    'stackscript'  => 'Stackscript',
    'domain'       => 'Domain',
    'nodebalancer' => 'Nodebalancer',
);

our %humanstatus = (
    '-2' => 'boot failed',
    '-1' => 'being created',
    '0'  => 'brand new',
    '1'  => 'running',
    '2'  => 'powered off',
    '3'  => 'shutting down',
    '4'  => 'saved to disk',
);

our %humanyn = (
    '0' => 'no',
    '1' => 'yes',
);

our %humandc = (
    '2' => 'dallas',
    '3' => 'fremont',
    '4' => 'atlanta',
    '6' => 'newark',
    '7' => 'london',
    '8' => 'tokyo',
);

our %paramsdef = (
    'linode' => {
        'create' => {
            'options' => {
                'label'           => 'label|l=s@',
                'datacenter'      => 'datacenter|location|L=s',
                'distribution'    => 'distribution|d=s',
                'plan'            => 'plan|p=s',
                'password'        => 'password|P:s',
                'payment-term'    => 'payment-term|t:i',
                'group'           => 'group|g:s',
                'pubkey-file'     => 'pubkey-file|K:s',
                'stackscript'     => 'stackscript|S:s',
                'stackscriptjson' => 'stackscriptjson|J:s',
                'wait'            => 'wait|w:i'
            },
            'format'    => { 'plan' => 'format_squish', 'datacenter'  => 'format_squish' },
            'warmcache' => [ 'plan', 'distribution', 'datacenter', 'kernel' ],
        },
        'rebuild' => {
            'options' => {
                'label'           => 'label|l=s@',
                'distribution'    => 'distribution|d=s',
                'password'        => 'password|P:s',
                'pubkey-file'     => 'pubkey-file|K:s',
                'stackscript'     => 'stackscript|S:s',
                'stackscriptjson' => 'stackscriptjson|J:s',
                'wait'            => 'wait|w:i'
            },
            'run'       => 'rebuild',
            'warmcache' => [ 'distribution', 'kernel' ]
        },
        'boot'  => { 'alias' => 'start' },
        'start' => {
            'options' => {
                'label' => 'label|l=s@',
                'wait'  => 'wait|w:i'
            },
            'run'     => 'change_state'
        },
        'shutdown' => { 'alias' => 'stop' },
        'stop'     => {
            'options' => {
                'label' => 'label|l=s@',
                'wait'  => 'wait|w:i'
            },
            'run'     => 'change_state'
        },
        'reboot'  => { 'alias' => 'restart' },
        'restart' => {
            'options' => {
                'label' => 'label|l=s@',
                'wait'  => 'wait|w:i'
            },
            'run'     => 'change_state'
        },
        'rename' => {
            'options' => {
                'label'     => 'label|l=s@',
                'new-label' => 'new-label|n=s'
            },
            'run'      => 'update',
            'seeknext' => [ 'new-label' ],
        },
        'resize' => {
            'options' => {
                'label' => 'label|l=s@',
                'plan'  => 'plan|p=s',
                'wait'  => 'wait|w:i'
            },
            'format' => { 'plan' => 'format_squish' },
            'seeknext'  => [ 'plan' ],
            'warmcache' => [ 'plan' ],
        },
        'group' => {
            'options' => {
                'label' => 'label|l=s@',
                'group' => 'group|n=s'
            },
            'run' => 'update',
        },
        'list'   => { 'options' => { 'label' => 'label|l:s@' }, },
        'show'   => {
            'options'   => { 'label' => 'label|l=s@' },
            'warmcache' => [ 'datacenter' ],
         },
        'delete' => { 'options' => { 'label' => 'label|l=s@' }, },
        'add-ip' => { 'alias' => 'ip-add' },
        'ip-add' => {
            'options'   => {
                'label'   => 'label|l=s@',
                'private' => 'private',
            },
            'run'       => 'add_ip',
        },
        'configure' => {
            'run' => 'configure',
            'warmcache' => [ 'plan', 'distribution', 'datacenter' ]
        },
        'datacenters' => { 'alias' => 'locations' },
        'locations' => {
            'run' => 'showoptions',
            'warmcache' => [ 'datacenter' ]
        },
        'distributions' => { 'alias' => 'distros' },
        'distros' => {
            'run' => 'showoptions',
            'warmcache' => [ 'distribution' ]
        },
        'plans' => {
            'run' => 'showoptions',
            'warmcache' => [ 'plan' ]
        },
    },
    'account' => {
        'info'  => { 'alias' => 'show' },
        'show'  => { 'run'   => 'show' },
        'list'  => { 'run'   => 'list' }
    },
    'stackscript' => {
        'create'  => {
            'options' => {
                'label'        => 'label|l=s@',
                'codefile'     => 'codefile|s=s',
                'distribution' => 'distribution|d=s@',
                'ispublic'     => 'ispublic|p:s',
                'revnote'      => 'revnote|r:s',
                'description'  => 'description|D:s',
            },
            'warmcache' => [ 'distribution' ],
        },
        'update' => {
            'options' => {
                'label'        => 'label|l=s@',
                'new-label'    => 'new-label|n:s',
                'codefile'     => 'codefile|c:s',
                'distribution' => 'distribution|d:s@',
                'ispublic'     => 'ispublic|p:s',
                'revnote'      => 'revnote|r:s',
                'description'  => 'description|D:s',
            },
            'warmcache' => [ 'distribution' ],
        },
        'delete' => { 'options' => { 'label' => 'label|l=s@' }, },
        'list'   => { 'options' => { 'label' => 'label|l:s@' }, },
        'show'   => { 'options' => { 'label' => 'label|l=s@' }, },
        'source' => {
            'options' => { 'label' => 'label|l:s@' },
            'run'     => 'show',
        },
    },
    'domain' => {
        'create'  => {
            'options' => {
                'label'       => 'label|domain|l=s@',
                'type'        => 'type|t:s',
                'email'       => 'email|soa|e:s',
                'description' => 'description|D:s',
                'refresh'     => 'refresh|R:s',
                'retry'       => 'retry|Y:s',
                'expire'      => 'expire|E:s',
                'ttl'         => 'ttl|T:s',
                'group'       => 'group|g:s',
                'status'      => 'status|s:s',
                'masterip'    => 'masterip|m:s@',
                'axfrip'      => 'axfrip|x:s@',
            },
            'seeknext' => [ 'email', 'masterip' ],
        },
        'update' => {
            'options' => {
                'label'       => 'label|domain|l=s@',
                'new-label'   => 'new-label|n:s',
                'type'        => 'type|t:s',
                'email'       => 'email|soa|e:s',
                'description' => 'description|D:s',
                'refresh'     => 'refresh|R:s',
                'retry'       => 'retry|Y:s',
                'expire'      => 'expire|E:s',
                'ttl'         => 'ttl|T:s',
                'group'       => 'group|g:s',
                'status'      => 'status|s:s',
                'masterip'    => 'masterip|m:s@',
                'axfrip'      => 'axfrip|x:s@',
            },
        },
        'delete' => { 'options' => { 'label' => 'label|domain|l=s@' } },
        'list'   => { 'options' => { 'label' => 'label|domain|l:s@' } },
        'show'   => { 'options' => { 'label' => 'label|domain|l=s@' } },
        'record-create' => {
            'options' => {
                'label'    => 'label|domain|l=s@',
                'type'     => 'type|t=s',
                'name'     => 'name|n:s',
                'target'   => 'target|R:s',
                'priority' => 'priority|P:s',
                'weight'   => 'weight|W:s',
                'port'     => 'port|p:s',
                'protocol' => 'protocol|L:s',
                'ttl'      => 'ttl|T:s',
            },
            'run'      => 'domainrecord',
            'seeknext' => [ 'type', 'name', 'target' ],
        },
        'record-update' => {
            'options' => {
                'label'    => 'label|domain|l=s@',
                'type'     => 'type|t=s',
                'match'    => 'match|m=s',
                'name'     => 'name|n:s',
                'target'   => 'target|R:s',
                'priority' => 'priority|P:s',
                'weight'   => 'weight|W:s',
                'port'     => 'port|p:s',
                'protocol' => 'protocol|L:s',
                'ttl'      => 'ttl|T:s',
            },
            'run'      => 'domainrecord',
            'seeknext' => [ 'type', 'match' ],
        },
        'record-delete' => {
            'options' => {
                'label' => 'label|domain|l=s@',
                'type'  => 'type|t=s',
                'match' => 'match|m=s',
            },
            'run'      => 'domainrecord',
            'seeknext' => [ 'type', 'match' ],
        },
        'record-list' => {
            'options' => {
                'label' => 'label|domain|l=s@',
                'type'  => 'type|t:s',
            },
            'run' => 'list',
        },
        'record-show' => {
            'options' => {
                'label' => 'label|domain|l=s@',
                'type'  => 'type|t:s',
            },
            'run' => 'show',
        },
    },
    'nodebalancer' => {
        'create'  => {
            'options' => {
                'label'        => 'label|l=s@',
                'datacenter'   => 'datacenter|location|L=s',
                'payment-term' => 'payment-term|t:i',
            },
            'format'    => { 'datacenter'  => 'format_squish' },
            'warmcache' => [ 'datacenter' ],
            'seeknext' => [ 'datacenter', 'payment-term' ],
        },
        'rename' => {
            'options' => {
                'label'     => 'label|l=s@',
                'new-label' => 'new-label|n=s',
            },
            'run'      => 'update',
            'seeknext' => [ 'new-label' ],
        },
        'throttle' => {
            'options' => {
                'label'       => 'label|l=s@',
                'connections' => 'connections|c=i',
            },
            'run'      => 'update',
            'seeknext' => [ 'connections' ],
        },
        'delete' => { 'options' => { 'label' => 'label|l=s@' }, },
        'list'   => { 'options' => { 'label' => 'label|l:s@' }, },
        'show'   => { 'options' => { 'label' => 'label|l=s@' }, },
        'config-create'  => {
            'options' => {
            'label'          => 'label|nodebalancer|l=s@',
            'port'           => 'port|config|p:i',
            'protocol'       => 'protocol|L:s',
            'algorithm'      => 'algorithm|A:s',
            'stickiness'     => 'stickiness|S:s',
            'check-health'   => 'check-health|H:s',
            'check-interval' => 'check-interval|I:i',
            'check-timeout'  => 'check-timeout|T:i',
            'check-attempts' => 'check-attempts|X:i',
            'check-path'     => 'check-path|P:s',
            'check-body'     => 'check-body|B:s',
            'ssl-cert'       => 'ssl-cert|C:s',
            'ssl-key'        => 'ssl-key|K:s',
            },
            'run'      => 'nodebalancer',
            'seeknext' => [ 'port' ],
         },
        'config-update'  => {
            'options' => {
            'label'          => 'label|nodebalancer|l=s@',
            'port'           => 'port|config|p=i',
            'new-port'       => 'new-port|N:i',
            'protocol'       => 'protocol|L:s',
            'algorithm'      => 'algorithm|A:s',
            'stickiness'     => 'stickiness|S:s',
            'check-health'   => 'check-health|H:s',
            'check-interval' => 'check-interval|I:i',
            'check-timeout'  => 'check-timeout|T:i',
            'check-attempts' => 'check-attempts|X:i',
            'check-path'     => 'check-path|P:s',
            'check-body'     => 'check-body|B:s',
            'ssl-cert'       => 'ssl-cert|C:s',
            'ssl-key'        => 'ssl-key|K:s',
            },
            'run'      => 'nodebalancer',
            'seeknext' => [ 'port' ],
         },
        'config-delete' => {
            'options' => {
                'label' => 'label|nodebalancer|l=s@',
                'port'  => 'port|config|p=i',
            },
            'run'      => 'nodebalancer',
            'seeknext' => [ 'port'],
        },
        'config-list'   => {
            'options' => {
                'label' => 'label|nodebalancer|l=s@',
            },
            'run' => 'list',
        },
        'config-show'   => {
            'options' => {
                'label' => 'label|nodebalancer|l=s@',
                'port'  => 'port|config|p=i',
            },
            'run' => 'show',
            'seeknext' => [ 'port' ],
        },
        'node-create'  => {
            'options' => {
                'label'   => 'label|nodebalancer|l=s@',
                'port'    => 'port|config|p=i',
                'name'    => 'name|n=s',
                'address' => 'address|A=s',
                'weight'  => 'weight|W:s',
                'mode'    => 'mode|M:s',
            },
            'run'      => 'nodebalancer',
            'seeknext' => [ 'port', 'name', 'address' ],
         },
        'node-update'  => {
            'options' => {
                'label'    => 'label|nodebalancer|l=s@',
                'port'     => 'port|config|p=i',
                'name'     => 'name|n=s',
                'new-name' => 'new-name|N:s',
                'address'  => 'address|A:s',
                'weight'   => 'weight|W:s',
                'mode'     => 'mode|M:s',
            },
            'run'      => 'nodebalancer',
            'seeknext' => [ 'port', 'name' ],
         },
        'node-delete' => {
            'options' => {
                'label' => 'label|nodebalancer|l=s@',
                'port'  => 'port|config|p=i',
                'name'  => 'name|n=s',
            },
            'run'      => 'nodebalancer',
            'seeknext' => [ 'port', 'name' ],
        },
        'node-list'   => {
            'options' => {
                'label' => 'label|nodebalancer|l=s@',
                'port'  => 'port|config|p=i',
            },
            'run' => 'list',
            'seeknext' => [ 'port' ],
        },
        'node-show'   => {
            'options' => {
                'label' => 'label|nodebalancer|l=s@',
                'port'  => 'port|config|p=i',
                'name'  => 'name|n=s',
            },
            'run' => 'show',
            'seeknext' => [ 'port', 'name' ],
        },
    },
);

# parses command line arguments, verifies action is valid and enforces required parameters
sub eat_cmdargs {
    my $mode = shift || 'linode';
    my @paramsfirst = qw( action|a:s version|V|v help|h username|U|u:s ); # initial parse of args
    my @paramscommon = qw( json|j:s output:s ); # args needed for every action
    my $cmdargs = {};
    $cmdargs->{output} = 'martian';

    check_configs();
    GetOptions( $cmdargs, @paramsfirst );

    if ( exists $cmdargs->{version} ) {
        version_message();
    }

    if ( ( exists $cmdargs->{action} && $cmdargs->{action} ne 'configure' )
          || ( defined $ARGV[0] && $ARGV[0] ne 'configure' ) ) {
        push @paramscommon, 'api-key|k=s';
    }

    if ( !exists $cmdargs->{action} && defined( $ARGV[0] ) ) {
        # no action parsed, try using $ARGV
        $cmdargs->{action} = lc( $ARGV[0] );
        my ( $i, $parsing ) = ( 1, 1 );
        while ($parsing) {
            if ( defined( $ARGV[$i] ) && $ARGV[$i] !~ m/^\-/ ) {
                if ( $i >= 2 && exists $paramsdef{$mode}{ $cmdargs->{action} }{'seeknext'} ) {
                    # some shortcuts have specific parameters following the label
                    if ( (scalar(@{ $paramsdef{$mode}{ $cmdargs->{action} }{'seeknext'} }) + 1) >= $i) {
                        $cmdargs->{ $paramsdef{$mode}{ $cmdargs->{action} }{'seeknext'}[$i-2] } = $ARGV[$i];
                    } else {
                        $parsing = 0;
                    }
                } else {
                    push( @{ $cmdargs->{label} }, $ARGV[$i] ); # assume this is the label
                }
                $i++;
            }
            else {
                $parsing = 0;
            }
        }
        $cmdargs = check_parse($mode, $cmdargs);
    }

    # action validation
    my @validactions = keys %{ $paramsdef{$mode} }; # load valid actions for this mode
    if ( exists $cmdargs->{action} && (my @found = grep { $_ eq $cmdargs->{action} } @validactions) ) { # is this a valid action?

        # check if this action is an alias to another action
        if ( exists $paramsdef{$mode}{ $cmdargs->{action} }{'alias'} ) {
            $cmdargs->{action}
                = $paramsdef{$mode}{ $cmdargs->{action} }{'alias'}; # switch to real action
        }

        # HELP - is the user only requesting help for this action?
        if ( exists $cmdargs->{help} ) {
            # show help specificially for this command/action and exit
            pod2usage(-verbose => 99, -sections => [ 'ACTIONS/' . uc($cmdargs->{action}) ], -exitval => 0);
        }

        # decide which command to run for this action
        if ( exists $paramsdef{$mode}{ $cmdargs->{action} }{'run'} ) {
            $cmdargs->{run} = $paramsdef{$mode}{ $cmdargs->{action} }{'run'}; # command to call for action
        }
        else {
            $cmdargs->{run} = $cmdargs->{action};
        }

        # order of priority: 1) --options 2) ENV 3) .linodecli file

        # 1) --options
        # prepare parse options needed to run action
        my @paramstoeat = (
            values %{ $paramsdef{$mode}{ $cmdargs->{action} }{'options'} },
            @paramscommon
        );    # mix action args and common args
        GetOptions( $cmdargs, @paramstoeat );

        # 2) ENV
        if ( defined $ENV{'LINODE_API_KEY'} ) {
            if ( !exists $cmdargs->{'api-key'} ) { # don't override a more important one
                $cmdargs->{'api-key'} = $ENV{'LINODE_API_KEY'};
            }
        }

        if ( defined $ENV{'LINODE_ROOT_PASSWORD'} ) {
            if ( !exists $cmdargs->{password} ) {
                $cmdargs->{password} = $ENV{'LINODE_ROOT_PASSWORD'};
            }
        }

        # 3) .linodecli config files
        my $dir_home = $ENV{HOME} || ( getpwuid($<) )[7];
        my $file_cli = "$dir_home/.linodecli/config";
        if ( exists $cmdargs->{username} ) {
            $file_cli = "$dir_home/.linodecli/config_" . $cmdargs->{username};
        }
        if ( -f $file_cli ) {
            # check user's file permissions
            my $filemode = ( stat( $file_cli ) )[2];
            if ( $filemode & 4 ) {
                die "$file_cli is world readable and contains your API key. Adjust your permissions and try again.\n";
            }
            my $config = load_config($file_cli);
            for my $item ( keys %{$config} ) {
                if ( !exists $cmdargs->{$item} ) { # don't override a more important one
                    $cmdargs->{$item} = $config->{$item};
                }
            }
        }

        # make sure we have the required parameters
        foreach my $eachp (@paramstoeat) {
            if ( $eachp =~ m/=/ ) { # use GetOptions flag (=) to determine a required one
                my @valuesp = split( /\|/, $eachp );
                if ( !exists $cmdargs->{ $valuesp[0] } ) {
                    die "The '$cmdargs->{action}' command requires a --${valuesp[0]} parameter.  Run --help or for usage.\n";
                }
            }
        }
        # perform an special formatting, if specified
        if ( exists $paramsdef{$mode}{ $cmdargs->{action} }{'format'} ) {
            for my $formatoption ( keys %{ $paramsdef{$mode}{ $cmdargs->{action} }{'format'} } ) {
                if ( $paramsdef{$mode}{ $cmdargs->{action} }{'format'}{ $formatoption } eq 'format_squish' ) {
                    $cmdargs->{ $formatoption } = format_squish( $cmdargs->{ $formatoption } );
                }
            }
        }

        if ( exists $cmdargs->{json} || $cmdargs->{output} eq 'json' ) {
            $cmdargs->{output} = 'json';
        }
        else {
            # set it to prevent us from using a user entered value
            $cmdargs->{output} = 'human';
            $| = 1; # allow single character printing, for status updates
        }
    }
    else {
        if ( exists $cmdargs->{help} ) {
            # they asked for help
            pod2usage(-verbose => 99, -exitval => 0, -sections => [ 'SYNOPSIS' ]);
        } else {
            die "Unknown command.  Run --help for usage.\n";
        }
    }

    return $cmdargs;
}

# handles special case argument entry cleanup
sub check_parse {
    my ( $mode, $cmdargs ) = @_;

    if ( exists $cmdargs->{action} ) {
        # domain - create
        if ( $mode eq 'domain' && $cmdargs->{action} eq 'create' ) {
            if (exists $cmdargs->{email} && $cmdargs->{email} eq 'slave' ) {
                $cmdargs->{type} = 'slave';
                delete $cmdargs->{email};
            }
        }
        # domain - record-list / record-show
        if ( $mode eq 'domain' && ( $cmdargs->{action} eq 'record-list' || $cmdargs->{action} eq 'record-show' ) ) {
            # check if the caboose is really a type filter
            if ( exists $cmdargs->{label} ) {
                my $size = scalar( @{ $cmdargs->{label} } );
                my @validtypes = ('ns', 'mx', 'a', 'aaaa', 'cname', 'txt', 'srv');
                if (my @found = grep { $_ eq lc( @{ $cmdargs->{label} }[$size - 1] ) } @validtypes) {
                    $cmdargs->{type} = lc( pop( @{ $cmdargs->{label} } ) );
                    if ( $size == 1 ) {
                        delete $cmdargs->{label};
                    }
                }
            }
        }
    }
    return $cmdargs;
}

sub human_displaymemory {
    my $mem = shift;
    return sprintf( "%.2f", $mem / 1024 ) . 'GB';
}

# converts to lowercase and removes spaces
sub format_squish {
    my $cleanme = shift;
    $cleanme =~ s/\s//g; # goodbye spaces
    return lc($cleanme);
}

# handles true/false enties
sub format_tf {
    my $valin = shift;
    if ( lc($valin) eq 'yes' || lc($valin) eq 'true' || lc($valin) eq '1') {
        return 1;
    } else {
        return 0;
    }
}

# format length - shortens a string if needed and adds a ... at the end
sub format_len {
    my ( $checkme, $sizelimit ) = @_;
    if ( length( $checkme ) > $sizelimit ) {
        return substr( $checkme, 0, ($sizelimit - 3) ) . "...";
    } else {
        return $checkme;
    }
}

sub check_configs {
    # upgrades older configs, if needed
    my ( $cmdargs ) = @_;
    my $dir_home = $ENV{HOME} || ( getpwuid($<) )[7];
    my $dir_cli = "$dir_home/.linodecli";

    unless ( -d $dir_cli ) {
        if ( -f $dir_cli ) {
            # legacy config exists (.linodecli file), convert to new format
            rename $dir_cli, "$dir_home/.linodecli_bak";
            unless( mkdir($dir_cli, 0755) ) {
                die "Unable to create directory '$dir_cli'\n";
            }
            rename "$dir_home/.linodecli_bak", "$dir_cli/config";
        } else {
            unless( mkdir($dir_cli, 0755) ) {
                die "Unable to create directory '$dir_cli'\n";
            }
        }
    }
}

sub load_config {
    my $file = shift;
    my $ret  = {};
    open my $fh, '<', $file or die "Unable to open file '$file': $!\n";

    while ( my $line = <$fh> ) {
        next if $line =~ /^\s*#/;
        next if $line =~ /^\s*$/;
        my ( $key, $value ) = $line =~ /^\s*(\S*)\s(.+)$/;
        unless ( $key && $value ) {
            die "Unable to parse line in $file: '$line' does not conform to standard\n";
        }

        chomp($ret->{$key} = $value);
    }
    return $ret;
}

sub write_config {
    my ($file, $options) = @_;

    open my $fh, '>', $file or die "Unable to open file '$file': $!\n";

    chmod(0640, $fh);

    for my $option (@$options) {
        next if ( !defined $option->[4] || $option->[4] eq '' );
        say $fh "$option->[0] $option->[4]";
    }

    close $fh;
}

sub json_response {
    my $data = shift;
    return JSON->new->pretty->encode($data);
}

sub succeed {
    my ( $self, %args ) = @_;

    my $result = $args{result} || {};

    $result->{ $args{label} } = $args{payload};
    $result->{ $args{label} }{message} = $args{message} if ( $args{message} );
    $result->{ $args{label} }{request_action} = $args{action} || '';
    $result->{ $args{label} }{request_error} = '';

    return $result;
}

sub fail {
    my ( $self, %args ) = @_;

    my $result = $args{result} || {};

    my @death;
    push( @death, $args{message} ) if ( $args{message} );
    push( @death, $Linode::CLI::Util::cli_err )
        if ($Linode::CLI::Util::cli_err);
    push( @death, $WebService::Linode::Base::errstr )
        if ($WebService::Linode::Base::errstr);
    push( @death, 'Unknown error' ) unless (@death);

    my $death_message = join( '. ', @death );

    $result->{ $args{label} } = $args{payload} || {};
    $result->{ $args{label} }{request_action} = $args{action} || '';
    $result->{ $args{label} }{request_error} = $death_message;

    return $result;
}

sub glob_tilde {
    my $path = shift;
    # http://perldoc.perl.org/perlfaq5.html#How-can-I-translate-tildes-(~)-in-a-filename%3f
    $path =~ s{
        ^ ~([^/]*)
    }{
        $1
        ? (getpwnam($1))[7]
        : ( $ENV{HOME} || $ENV{LOGDIR} )
    }ex;
    return $path;
}

sub colorize {
    my $text = shift;

    my $reset = RESET;
    my $word_map = {
        'running'     => GREEN,
        'yes'         => GREEN,
        'master'      => GREEN,
        'powered off' => RED,
        'no'          => RED,
        'brand new'   => YELLOW,
        'slave'       => YELLOW,
    };

    for my $word ( keys %{$word_map} ) {
        my $color = $word_map->{$word};
        $text =~ s/\b$word\b/$color$word$reset/gi;
    };

    return $text;
}

sub version_message {
    say "linode-cli $VERSION";
    say 'Copyright (C) 2014 Linode, LLC';
    exit;
}

1;
