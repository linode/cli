package Linode::CLI::Util;

use 5.010;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw();
our %EXPORT_TAGS = (
    basic   => [(qw(error load_config human_displaymemory %correct_case %humanstatus %humanyn $cli_err @MODES))],
    json    => ['json_response'],
);
our @EXPORT_OK = (qw(json_response error load_config human_displaymemory %correct_case %humanstatus %humanyn $cli_err @MODES));

use Carp;
use JSON;
use Pod::Usage;
use Getopt::Long (qw(:config no_ignore_case bundling pass_through));

our @MODES = (qw(
    linode stackscript domain nodebalancer longview
    account user
));

our $cli_err;

our %correct_case = (
    'linode'    => 'Linode',
);

our %humanstatus = (
    '-2' => 'boot failed',
    '-1' => 'being created',
    '0' => 'brand new',
    '1' => 'running',
    '2' => 'powered off',
    '3' => 'shutting down',
    '4' => 'saved to disk',
);

our %humanyn = (
    '0' => 'no',
    '1' => 'yes',
);

my %paramsdef = (
    'linode' => {
        'create' => {
            'options' => {
                'label' => 'label|l=s',
                'datacenter' => 'datacenter|location|L=s',
                'distribution' => 'distribution|d=s',
                'kernel' => 'kernel|K=s',
                'plan' => 'plan|p=i',
                'payment-term' => 'payment-term|t=i',
                'quantity' => 'quantity|q:i',
                'group' => 'group|g:s'
            },
        },
        'boot' => {
            'alias' => 'start'
        },
        'start' => {
            'options' => {
                'label' => 'label|l=s'
            },
            'run' => 'change_state'
        },
        'shutdown' => {
            'alias' => 'stop'
        },
        'stop' => {
            'options' => {
                'label' => 'label|l=s'
            },
            'run' => 'change_state'
        },
        'reboot' => {
            'alias' => 'restart'
        },
        'restart' => {
            'options' => {
                'label' => 'label|l=s'
            },
            'run' => 'change_state'
        },
        'rename' => {
            'options' => {
                'label' => 'label|l=s',
                'new-label' => 'new-label|n=s'
            },
            'run' => 'update',
        },
        'group' => {
            'options' => {
                'label' => 'label|l=s',
                'group' => 'group|n=s'
            },
            'run' => 'update',
        },
        'list' => {
            'options' => {
                'label' => 'label|l:s',
            },
        },
        'show' => {
            'options' => {
                'label' => 'label|l:s'
            },
        },
        'delete' => {
            'options' => {
                'label' => 'label|l=s'
            },
        },
    },
);


# parses command line arguments, verifies action is valid and enforces required parameters
sub eat_cmdargs {
    my $mode = shift || 'linode';
    my @paramsfirst = qw( action|a:s version|V|v help|h man ); # initial parse of args
    my @paramscommon = qw( api-key|k=s json:s human:s output:s ); # args needed for every action
    my $cmdargs = {};
    $cmdargs->{output} = 'martian';

    my $home_directory = $ENV{HOME} || (getpwuid($<))[7];
    if (-f "$home_directory/.linodecli") {
        my $config = load_config("$home_directory/.linodecli");
        for my $item (keys %{$config}) {
            $cmdargs->{$item} = $config->{$item};
        }
    }

    GetOptions($cmdargs, @paramsfirst);

    if (exists $cmdargs->{help}) {
        pod2usage();
        exit;
    } elsif (exists $cmdargs->{man}) {
        pod2usage(-exitval => 0, -verbose => 2);
    } elsif (exists $cmdargs->{version}) {
        version_message();
    }

    if (!exists $cmdargs->{action} && defined($ARGV[0]) ) {
        # no action parsed, try using $ARGV
        $cmdargs->{action} = lc($ARGV[0]);
        if (defined($ARGV[1]) && $ARGV[1] !~ m/^\-/) {
            $cmdargs->{label} = $ARGV[1]; # assume this is the label
        }
    }

    # action validation
    my @validactions = keys %{$paramsdef{$mode}}; # load valid actions for this mode
    if ($cmdargs->{action} ~~ @validactions) {      # is this a valid action?

        # check if this action is an alias to another action
        if (exists $paramsdef{$mode}{$cmdargs->{action}}{'alias'}) {
            $cmdargs->{action} = $paramsdef{$mode}{$cmdargs->{action}}{'alias'}; # switch to real action
        }
        # decide which command to run for this action
        if (exists $paramsdef{$mode}{$cmdargs->{action}}{'run'}) {
            $cmdargs->{run} = $paramsdef{$mode}{$cmdargs->{action}}{'run'}; # command to call for action
        } else {
            $cmdargs->{run} = $cmdargs->{action};
        }

        # prepare parse options needed to run action
        my @paramstoeat = (values %{$paramsdef{$mode}{$cmdargs->{action}}{'options'}}, @paramscommon); # mix action args and common args
        GetOptions($cmdargs, @paramstoeat);

        # make sure we have the required parameters
        foreach my $eachp (@paramstoeat) {
            if ($eachp =~ m/=/) { # use GetOptions flag (=) to determine a required one
                my @valuesp = split(/\|/, $eachp);
                if (!exists $cmdargs->{$valuesp[0]}) {
                    die "The '$cmdargs->{action}'' command requires a --${valuesp[0]} parameter.  Run --help or --man for usage.\n";
                }
            }
        }
        if (exists $cmdargs->{json} || $cmdargs->{output} eq 'json') {
            $cmdargs->{output} = 'json';
        } else {
            # set it to prevent us from using a user entered value
            $cmdargs->{output} = 'human';
            $|=1; # allow single character printing, for status updates
        }
    } else {
        # TODO: offer some help
        die "Unknown command.  Run --help or --man for usage.\n";
    }

    return $cmdargs;
}

sub human_displaymemory {
    my $mem = shift;
    return ($mem / 1024) . 'GB';
}

sub load_config {
        my $file = shift;
        my $ret  = {};
        open my $fh, '<', $file or do {
                die "Unable to open $file: $!";
                return $ret;
        };
        while (my $line = <$fh>) {
                next if $line =~ /^\s*#/;
                next if $line =~ /^\s*$/;
                my ($key, $value) = $line =~ /^\s*(\S*)\s+(\S*)\s*$/;
                unless ($key && $value) {
                        die "Unable to parse line in $file: '$line' does not conform to standard";
                        next;
                }
                $ret->{$key} = $value;
        }
        return $ret;
}

sub json_response {
    my ($data, $error_text, $error) = @_;
    $data ||= {};
    $error_text ||= '';
    $error ||= 0;

    return JSON->new->pretty->encode([
        {
            error           => ($error ? JSON::true : JSON::false),
            error_message   => $error_text,
        },
        $data,
    ]);
}

sub version_message {
    say 'linode-cli';
    say 'Copyright (C) 2013 Linode, LLC';
    exit;
}

sub error {
    my ($self, $message) = @_;

    $cli_err = $message;
    croak $message;
}

1;
