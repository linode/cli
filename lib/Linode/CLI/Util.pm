package Linode::CLI::Util;

use 5.010;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT      = qw();
our %EXPORT_TAGS = (
    basic => [(qw(
        error load_config human_displaymemory succeed fail format_squish format_tf
        %correct_case %humanstatus %humanyn %humandc %paramsdef @MODES
    ))],
    config => ['write_config'],
    json => ['json_response'],
);
our @EXPORT_OK = (qw(
        json_response error load_config write_config human_displaymemory succeed fail
        format_squish format_tf %correct_case %humanstatus %humanyn %humandc
        %paramsdef @MODES
));

use Carp;
use JSON;
use Pod::Usage;
use Getopt::Long (qw(:config no_ignore_case bundling pass_through));

my $VERSION = '0.1.0';

our @MODES = (qw(
    linode stackscript domain nodebalancer longview account user
));

our %correct_case = ( 'linode' => 'Linode', 'account' => 'Account', 'stackscript' => 'Stackscript', 'domain' => 'Domain' );

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
                'label'        => 'label|l=s@',
                'datacenter'   => 'datacenter|location|L=s',
                'distribution' => 'distribution|d=s',
                'plan'         => 'plan|p=s',
                'payment-term' => 'payment-term|t=i',
                'quantity'     => 'quantity|q:i',
                'group'        => 'group|g:s'
            },
            'format'    => { 'plan' => 'format_squish', 'datacenter'  => 'format_squish' },
            'warmcache' => [ 'plan', 'distribution', 'datacenter', 'kernel' ],
        },
        'boot'  => { 'alias' => 'start' },
        'start' => {
            'options' => { 'label' => 'label|l=s@' },
            'run'     => 'change_state'
        },
        'shutdown' => { 'alias' => 'stop' },
        'stop'     => {
            'options' => { 'label' => 'label|l=s@' },
            'run'     => 'change_state'
        },
        'reboot'  => { 'alias' => 'restart' },
        'restart' => {
            'options' => { 'label' => 'label|l=s@' },
            'run'     => 'change_state'
        },
        'rename' => {
            'options' => {
                'label'     => 'label|l=s@',
                'new-label' => 'new-label|n=s'
            },
            'run'      => 'update',
            'seeknext' => 'new-label'
        },
        'resize' => {
            'options' => {
                'label' => 'label|l=s@',
                'plan'  => 'plan|p=s'
            },
            'format' => { 'plan' => 'format_squish' },
            'seeknext'  => 'plan',
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
            'options'   => { 'label' => 'label|l:s@' },
            'warmcache' => [ 'datacenter' ],
         },
        'delete' => { 'options' => { 'label' => 'label|l=s@' }, },
        'configure' => {'run' => 'configure'}
    },
    'account' => {
        'info'  => { 'alias' => 'show' },
        'show'  => { 'run' => 'show' }
    },
    'stackscript' => {
        'create'  => {
            'options' => {
                'label'        => 'label|l=s',
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
        'delete'     => { 'options' => { 'label' => 'label|l=s@' }, },
        'list'       => { 'options' => { 'label' => 'label|l:s@' }, },
        'show'       => { 'options' => { 'label' => 'label|l:s@' }, },
        'source' => {
            'options' => { 'label' => 'label|l:s@' },
            'run'     => 'show',
        },
    },
);

# parses command line arguments, verifies action is valid and enforces required parameters
sub eat_cmdargs {
    my $mode = shift || 'linode';
    my @paramsfirst = qw( action|a:s version|V|v help|h man ); # initial parse of args
    my @paramscommon = qw( json|j:s output:s wait|w ); # args needed for every action
    my $cmdargs = {};
    $cmdargs->{output} = 'martian';

    GetOptions( $cmdargs, @paramsfirst );

    if ( exists $cmdargs->{man} ) {
        pod2usage( -exitval => 0, -verbose => 2 );
    }
    elsif ( exists $cmdargs->{version} ) {
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
                if ( $i == 2 && exists $paramsdef{$mode}{ $cmdargs->{action} }{'seeknext'} ) {
                    # some shortcuts have specific second parameters following the label
                    $cmdargs->{ $paramsdef{$mode}{ $cmdargs->{action} }{'seeknext'} } = $ARGV[$i];
                    $parsing = 0;
                } else {
                    push( @{ $cmdargs->{label} }, $ARGV[$i] ); # assume this is the label
                    $i++;
                }
            }
            else {
                $parsing = 0;
            }
        }
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
            pod2usage(-verbose => 99, -sections => [ 'ACTIONS/' . uc($cmdargs->{action}) ], -exitval => 1);
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

        # 3) .linodecli file
        my $home_directory = $ENV{HOME} || ( getpwuid($<) )[7];
        if ( -f "$home_directory/.linodecli" ) {
            # check user's file permissions
            my $filemode = ( stat( "$home_directory/.linodecli" ) )[2];
            if ( $filemode & 4 ) {
                die "CRITICAL: $home_directory/.linodecli is world readable and contains your API key. Adjust your permissions and try again. Aborting.\n";
            }
            my $config = load_config("$home_directory/.linodecli");
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
                    die "The '$cmdargs->{action}' command requires a --${valuesp[0]} parameter.  Run --help or --man for usage.\n";
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
            pod2usage();
        } else {
            die "Unknown command.  Run --help or --man for usage.\n";
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

sub load_config {
    my $file = shift;
    my $ret  = {};
    open my $fh, '<', $file or do {
        die "Unable to open $file: $!";
        return $ret;
    };
    while ( my $line = <$fh> ) {
        next if $line =~ /^\s*#/;
        next if $line =~ /^\s*$/;
        my ( $key, $value ) = $line =~ /^\s*(\S*)\s([\w\s]+)$/;
        unless ( $key && $value ) {
            die "Unable to parse line in $file: '$line' does not conform to standard";
            next;
        }

        chomp($ret->{$key} = $value);
    }
    return $ret;
}

sub write_config {
    my ($file, $options) = @_;

    open my $fh, '>', $file or do {
        die "Unable to open $file: $!";
    };

    chmod(0640, $fh);

    for my $option (@$options) {
        say $fh "$option->[0] $option->[2]";
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

sub version_message {
    say "linode-cli $VERSION";
    say 'Copyright (C) 2013 Linode, LLC';
    exit;
}

1;
