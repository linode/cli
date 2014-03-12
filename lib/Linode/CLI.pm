package Linode::CLI;

use strict;
use warnings;
use 5.010;

use Linode::CLI::Object;
use Linode::CLI::Object::Linode;
use Linode::CLI::Object::Account;
use Linode::CLI::Object::Stackscript;
use Linode::CLI::Object::Domain;
use Linode::CLI::Object::Nodebalancer;
use Linode::CLI::Util (qw(:basic :config :json));
use Linode::CLI::SystemInfo;
use Sys::Hostname;
use Try::Tiny;
use WebService::Linode;

sub new {
    my ( $class, %args ) = @_;

    my $self = bless {}, $class;

    $self->{api_key}       = $args{api_key};
    $self->{mode}          = $args{mode};
    $self->{output_format} = $args{output_format};
    $self->{wait}          = $args{wait};
    $self->{_result}       = {};

    $self->{_opts} = $args{opts};

    my $system_info = system_info();

    $self->{_api_obj} = WebService::Linode->new(
        apikey    => $self->{api_key},
        fatal     => 1,
        useragent => "linode-cli/$VERSION ($system_info)",
    );

    $self->_test_api unless $self->{_opts}{action} eq 'configure';
    $self->_warm_cache unless $self->{_opts}{action} eq 'configure';

    $self->{_distilled_options} = $args{opts};
    $self->_distill_options unless $self->{_opts}{action} eq 'configure';

    return $self;
}

sub create {
    my $self = shift;

    my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"->create(
        api_obj => $self->{_api_obj},
        options => $self->{_distilled_options},
        format  => $self->{output_format},
        wait    => $self->{wait},
    );
    my %combined = ( %$result, %{ $self->{_result} } );
    %{ $self->{_result} } = %combined;
}

sub rebuild {
    my $self = shift;

    my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"->buildrebuild(
        api_obj    => $self->{_api_obj},
        options    => $self->{_distilled_options},
        # single object
        set_obj => @{ $self->_get_object_list(
            $self->{mode}, $self->{_distilled_options}{label}
        ) }[0],
        format     => $self->{output_format},
        wait       => $self->{wait},
    );
    my %combined = (%$result, %{$self->{_result}});
    %{$self->{_result}} = %combined;
}

sub update {
    my $self = shift;

    my $update_result = try {
        my $uobj = "Linode::CLI::Object::$correct_case{$self->{mode}}"->new_from_list(
            api_obj     => $self->{_api_obj},
            object_list => $self->_get_object_list(
                $self->{mode}, $self->{_distilled_options}{label}
            ),
            action => $self->{_opts}->{action},
        );

        my $result = $uobj->update( $self->{_distilled_options} );
        my %combined = (%$result, %{$self->{_result}});
        %{$self->{_result}} = %combined;
    };

    $self->{_result} = $self->fail(
        label   => 'Generic error',
        message => "Problem while trying to run '$self->{mode} update'",
        result  => $self->{_result},
    ) unless $update_result;
}

sub change_state {
    my $self = shift;

    my $change_state_result = try {
        my $new_state = $self->{_distilled_options}->{new_state};

        my $linodes = Linode::CLI::Object::Linode->new_from_list(
            api_obj     => $self->{_api_obj},
            object_list => $self->_get_object_list(
                'linode', $self->{_distilled_options}{label}
            ),
            action => $self->{_opts}->{action},
        );

        my $result = $linodes->change_state(
            format => $self->{output_format},
            wait   => $self->{wait},
            state  => $new_state,
        );
        my %combined = ( %$result, %{ $self->{_result} } );
        %{ $self->{_result} } = %combined;
    };

    $self->{_result} = $self->fail(
        label   => 'Generic error',
        message => "Problem while trying to run '$self->{mode} change_state'",
        result  => $self->{_result},
    ) unless $change_state_result;
}

sub resize {
    my $self = shift;

    my $resize_result = try {
        my $linodes = Linode::CLI::Object::Linode->new_from_list(
            api_obj     => $self->{_api_obj},
            object_list => $self->_get_object_list(
                'linode', $self->{_distilled_options}{label}
            ),
            action => $self->{_opts}->{action},
        );

        my $result = $linodes->resize(
            options => $self->{_distilled_options},
            format  => $self->{output_format},
            wait    => $self->{wait},
        );
        my %combined = ( %$result, %{ $self->{_result} } );
        %{ $self->{_result} } = %combined;
    };

    $self->{_result} = $self->fail(
        label   => 'Generic error',
        message => "Problem while trying to run '$self->{mode} resize'",
        result  => $self->{_result},
    ) unless $resize_result;
}

sub list {
    my $self = shift;

    my $sub = 'list';
    if ( $self->{mode} eq 'domain' && $self->{_opts}{action} eq 'record-list' ) {
        $sub  = 'recordlist';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'config-list') {
        $sub = 'configlist';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'node-list') {
        $sub = 'nodelist';
    }

    my $list_result = try {
        if ( $self->{output_format} eq 'json' ) {
            my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"
                ->new_from_list(
                    api_obj     => $self->{_api_obj},
                    object_list => $self->_get_object_list(
                        $self->{mode}, $self->{_distilled_options}{label}
                    ),
                    action => $self->{_opts}->{action},
                )->$sub( output_format => $self->{output_format},
                         options => $self->{_distilled_options} );
            my %combined = ( %$result, %{ $self->{_result} } );
            %{ $self->{_result} } = %combined;
        }
        else {
            print "Linode::CLI::Object::$correct_case{$self->{mode}}"
                ->new_from_list(
                    api_obj     => $self->{_api_obj},
                    object_list => $self->_get_object_list(
                        $self->{mode}, $self->{_distilled_options}{label}
                    ),
                    action => $self->{_opts}->{action},
                )->$sub( output_format => $self->{output_format},
                         options => $self->{_distilled_options} );
        }
    };

    $self->{_result} = $self->fail(
        label   => 'Generic error',
        message => "Problem while trying to run '$self->{mode} list'",
        result  => $self->{_result},
    ) unless $list_result;
}

sub show {
    my $self = shift;

    my $subhum  = 'show';
    my $subjson = 'list';
    if ( $self->{mode} eq 'domain' && $self->{_opts}{action} eq 'record-show' ) {
        $subhum  = 'recordshow';
        $subjson = 'recordlist';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'config-show') {
        $subhum  = 'configshow';
        $subjson = 'configlist';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'node-show') {
        $subhum  = 'nodeshow';
        $subjson = 'nodelist';
    }

    # Eventually, 'show' will have more comprehensive JSON output than 'list'
    if ( $self->{output_format} eq 'json' ) {
        my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"
            ->new_from_list(
                api_obj     => $self->{_api_obj},
                object_list => $self->_get_object_list(
                    $self->{mode}, $self->{_distilled_options}{label}
                ),
                action => $self->{_opts}{action},
            )->$subjson( output_format => $self->{output_format},
                     options => $self->{_distilled_options} );
        my %combined = ( %$result, %{ $self->{_result} } );
        %{ $self->{_result} } = %combined;
    }
    else {
        print "Linode::CLI::Object::$correct_case{$self->{mode}}"->new_from_list(
                api_obj       => $self->{_api_obj},
                output_format => $self->{output_format},
                object_list   => $self->_get_object_list(
                    $self->{mode}, $self->{_distilled_options}{label}
                ),
                action => $self->{_opts}{action},
            )->$subhum( options => $self->{_distilled_options} );
    }
}

sub delete {
    my $self = shift;

    my $delete_result = try {
        my $dobj = "Linode::CLI::Object::$correct_case{$self->{mode}}"->new_from_list(
            api_obj     => $self->{_api_obj},
            object_list => $self->_get_object_list(
                $self->{mode}, $self->{_distilled_options}{label}
            ),
            action => $self->{_opts}->{action},
        );

        my $result = $dobj->delete( $self->{_distilled_options} );
        my %combined = ( %$result, %{ $self->{_result} } );
        %{ $self->{_result} } = %combined;
    };

    $self->{_result} = $self->fail(
        label   => 'Generic error',
        message => "Problem while trying to run '$self->{mode} delete'",
        result  => $self->{_result},
    ) unless $delete_result;
}

sub add_ip {
    my $self = shift;

    my $add_ip_result = try {
        my $linodes = Linode::CLI::Object::Linode->new_from_list(
            api_obj     => $self->{_api_obj},
            object_list => $self->_get_object_list(
                'linode', $self->{_distilled_options}{label}
            ),
            action => $self->{_opts}->{action},
        );

        my $result = $linodes->add_ip( $self->{_distilled_options} );
        my %combined = ( %$result, %{ $self->{_result} } );
        %{ $self->{_result} } = %combined;
    };

    $self->{_result} = $self->fail(
        label   => 'Generic error',
        message => "Problem while trying to run '$self->{mode} ip-add'",
        result  => $self->{_result},
    ) unless $add_ip_result;
}

sub domainrecord {
    my $self = shift;

    my $sub = 'recordcreate';
    if ( $self->{mode} eq 'domain' && $self->{_opts}{action} eq 'record-update' ) {
        $sub  = 'recordupdate';
    }
    elsif ( $self->{mode} eq 'domain' && $self->{_opts}{action} eq 'record-delete' ) {
        $sub  = 'recorddelete';
    }

    my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"->$sub(
        api_obj    => $self->{_api_obj},
        options    => $self->{_distilled_options},
        # single domain object
        domain_obj => @{ $self->_get_object_list(
            $self->{mode}, $self->{_distilled_options}{label}
        ) }[0],
        format     => $self->{output_format},
        wait       => $self->{wait},
    );
    my %combined = ( %$result, %{ $self->{_result} } );
    %{ $self->{_result} } = %combined;
}

sub nodebalancer {
    my $self = shift;

    my $sub = 'configcreate';
    if ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'config-update') {
        $sub  = 'configupdate';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'config-delete') {
        $sub  = 'configdelete';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'node-create') {
        $sub  = 'nodecreate';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'node-update') {
        $sub  = 'nodeupdate';
    } elsif ($self->{mode} eq 'nodebalancer' && $self->{_opts}->{action} eq 'node-delete') {
        $sub  = 'nodedelete';
    }

    my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"->$sub(
        api_obj    => $self->{_api_obj},
        options    => $self->{_distilled_options},
        # single object
        set_obj => @{ $self->_get_object_list(
            $self->{mode}, $self->{_distilled_options}{label}
        ) }[0],
        format     => $self->{output_format},
        wait       => $self->{wait},
    );
    my %combined = (%$result, %{$self->{_result}});
    %{$self->{_result}} = %combined;
}


sub showoptions {
    my $self = shift;

    if ($self->{mode} eq 'linode' && $self->{_opts}->{action} eq 'locations') {
        my $cache = $self->_use_cache('datacenter');
        for my $object_label ( sort keys %$cache ) {
            print "$humandc{ $cache->{$object_label}{datacenterid} }\n";
        }
    } elsif ($self->{mode} eq 'linode' && $self->{_opts}->{action} eq 'distros') {
        my $cache = $self->_use_cache('distribution');
        for my $object_label ( sort keys %$cache ) {
            print "$cache->{$object_label}{label}\n";
        }
    } elsif ($self->{mode} eq 'linode' && $self->{_opts}->{action} eq 'plans') {
        my $cache = $self->_use_cache('plan');
        for my $object_label ( sort { (split ' ', $a)[1] <=> (split ' ', $b)[1] } keys %$cache ) {
            print "$object_label\n";
        }
    }
}


sub configure {
    my $self = shift;
    my $api_key;

    say "This will walk you through setting default values for common options.\n";

    say 'Linode Manager user name';
    print '>> ';
    chop ( my $lpm_username = <STDIN> );

    say "\nLinode Manager password for $lpm_username";
    print '>> ';
    system( 'stty', '-echo' );
    chop ( my $lpm_password = <STDIN> );
    system( 'stty', 'echo' );

    say "\n";

    my $system_info = system_info();

    my $api_params = {
        username => $lpm_username,
        password => $lpm_password,
        label    => 'Linode CLI - ' . hostname,
        expires  => 0,
    };

    my $lpm_2fa;
    my $tries = 0;
    while ($tries <= 1) {
        $WebService::Linode::Base::err = undef;
        $WebService::Linode::Base::errstr = undef;
        my $api_response = WebService::Linode->new(
            nowarn    => 1,
            useragent => "linode-cli/$VERSION ($system_info)",
        )->user_getapikey(%{ $api_params });

        my $err = $WebService::Linode::Base::err || 0;
        if ($err == 4) {
            die "Authentication failed for user $lpm_username\n";
        }
        elsif ($err == 44) {
            say 'Two-factor authentication code';
            print '>> ';
            chop ( $lpm_2fa = <STDIN> );
            $api_params->{token} = $lpm_2fa || '0';
            say '';
            $tries++;
            next;
        }
        elsif ($err == 443) {
            die "$WebService::Linode::Base::errstr\n";
        }
        elsif ($err) {
            die "Unexpected error obtaining API key for user $lpm_username: "
             . $WebService::Linode::Base::errstr . "\n";
        }
        else {
            $api_key = $api_response->{api_key};
            last;
        }
    }

    die "Authentication failed for user $lpm_username\n" unless $api_key;

    my $cli_cache = Linode::CLI->new(
        api_key => $api_key,
        mode    => 'linode',
        opts    => { action => 'create' }
    );
    $cli_cache->_warm_cache;

    my @options = (
        [
            'distribution',
            'Default distribution when deploying a new Linode or'
             . ' rebuilding an existing one. (Optional)',
            sub {
                my $distro = shift;
                my $cli = Linode::CLI->new(
                    api_key => $api_key,
                    mode    => 'linode',
                    opts    => { action => 'create', distribution => $distro }
                );
            },
            sub {
                my $cache = $cli_cache->_use_cache('distribution');
                print "Valid options are:\n";
                my ( $selections, $i ) = ( [], 1 );
                for my $object_label ( sort keys %$cache ) {
                    print " " . sprintf( "%2s", $i ) . " - $cache->{$object_label}{label}\n";
                    push @$selections, $cache->{$object_label}{label};
                    $i++;
                }
                return $selections;
            }
        ],
        [
            'datacenter',
            'Default datacenter when deploying a new Linode. (Optional)',
            sub {
                my $datacenter = shift;
                my $cli = Linode::CLI->new(
                    api_key => $api_key,
                    mode    => 'linode',
                    opts    => { action => 'create', datacenter => $datacenter }
                );
            },
            sub {
                my $cache = $cli_cache->_use_cache('datacenter');
                print "Valid options are:\n";
                my ( $selections, $i ) = ( [], 1 );
                for my $object_label ( sort keys %$cache ) {
                    print " " . sprintf( "%2s", $i ) . " - $humandc{ $cache->{$object_label}{datacenterid} }\n";
                    push @$selections, $humandc{ $cache->{$object_label}{datacenterid} };
                    $i++;
                }
                return $selections;
            }
        ],
        [
            'plan',
            'Default plan when deploying a new Linode. (Optional)',
            sub {
                my $plan = shift;
                my $cli = Linode::CLI->new(
                    api_key => $api_key,
                    mode    => 'linode',
                    opts    => { action => 'create', plan => $plan }
                );
            },
            sub {
                my $cache = $cli_cache->_use_cache('plan');
                print "Valid options are:\n";
                my ( $selections, $i ) = ( [], 1 );
                for my $object_label ( sort { (split ' ', $a)[1] <=> (split ' ', $b)[1] } keys %$cache ) {
                    print " " . sprintf( "%2s", $i ) . " - $object_label\n";
                    push @$selections, $object_label;
                    $i++;
                }
                return $selections;
            }
        ],
        [
            'pubkey-file',
            'Path to an SSH public key to install when deploying a new Linode.'
             . ' (Optional)',
            sub {
                my $file = shift;
                $file = glob_tilde($file);
                die if ( $file ne '' && ! -f $file );
                return 1;
            },
            sub {
            }
        ],
    );

    for my $i ( 0 .. $#options ) {
        my $retry = 1;
        while ( $retry ) {
            say $options[$i][1];
            my $menu = $options[$i][3]->();
            my $response;
            if ( defined $menu ) {
                print 'Choose[ 1-' . scalar(@$menu) . ' ] or Enter to skip>> ';
                chop ( $response = <STDIN> );

                if ( $response =~ m/^\d+$/ && $response >= 1 && $response <= scalar(@$menu) ) {
                    $response = @$menu[$response - 1];
                }
            } else {
                print '>> ';
                chop ( $response = <STDIN> );
            }

            try {
                if ( $response eq '0' ) {
                    die;
                } elsif ( $options[$i][2]->($response) ) {
                    push @{ $options[$i] }, $response;
                    say '';
                }
                $retry = 0;
            }
            catch {
                say STDERR "\nBad $options[$i][0]: $response\n";
            };
        }
    }

    push @options, ['api-key', '', '', '', $api_key];

    my $dir_home = $ENV{HOME} || ( getpwuid($<) )[7];
    my $file_cli = "$dir_home/.linodecli/config";
    if ( exists $self->{_opts}{username} ) {
        $file_cli = "$dir_home/.linodecli/config_" . $self->{_opts}{username};
    }
    write_config( $file_cli, \@options );
    say "Config written to $file_cli";
}

sub response {
    my $self = shift;
    my $status = 0;

    for my $key ( keys %{ $self->{_result} } ) {
        $status ||= $self->{_result}{$key}{request_error} ? 1 : 0;
        if ( $self->{output_format} eq 'human' ) {
            $self->{_result}{$key}{request_error}
                ? say STDERR $self->{_result}{$key}{request_error}
                : say $self->{_result}{$key}{message};
        }
    }

    if ( $self->{output_format} eq 'json' ) {
        print json_response( $self->{_result} );
    }

    exit $status;
}

sub _warm_cache {
    my $self   = shift;
    my $expire = time + 60;

    $self->{_cache}{$_} = {} foreach (@MODES);

    if ( exists $paramsdef{ $self->{mode} }{ $self->{_opts}{action} }{'warmcache'} ) {
        foreach ( @{ $paramsdef{ $self->{mode} }{ $self->{_opts}{action} }{'warmcache'} } ) {
            if ( $_ eq 'datacenter' ) {
                $self->{_cache}{datacenter}{$expire} =
                    Linode::CLI::Object->new_from_list(
                        api_obj     => $self->{_api_obj},
                        object_list => $self->{_api_obj}->avail_datacenters(),
                    )->list( output_format => 'raw' );
            }
            elsif ( $_ eq 'distribution' ) {
                $self->{_cache}{distribution}{$expire} =
                    Linode::CLI::Object->new_from_list(
                        api_obj     => $self->{_api_obj},
                        object_list => $self->{_api_obj}->avail_distributions(),
                    )->list( output_format => 'raw' );
            }
            elsif ( $_ eq 'kernel' ) {
                $self->{_cache}{kernel}{$expire} =
                    Linode::CLI::Object->new_from_list(
                        api_obj     => $self->{_api_obj},
                        object_list => $self->{_api_obj}->avail_kernels(),
                    )->list( output_format => 'raw' );
            }
            elsif ( $_ eq 'plan' ) {
                $self->{_cache}{plan}{$expire} =
                    Linode::CLI::Object->new_from_list(
                        api_obj     => $self->{_api_obj},
                        object_list => $self->{_api_obj}->avail_linodeplans(),
                    )->list( output_format => 'raw' );
            }
        }
    }
}

sub _use_or_evict_cache {
    my ( $self, $mode ) = @_;

    return 0 unless ( scalar keys %{ $self->{_cache}->{$mode} } );

    my $now = time;

    for my $key ( sort keys %{ $self->{_cache}->{$mode} } ) {
        if ( $key < $now ) {
            delete $self->{_cache}->{$mode}->{$key};
        }
        else {
            return $self->{_cache}->{$mode}->{$key};
        }
    }

    return 0;
}

sub _use_cache {
    # use cache without possible time eviction
    my ( $self, $mode ) = @_;

    return 0 unless ( scalar keys %{ $self->{_cache}->{$mode} } );

    for my $key ( sort keys %{ $self->{_cache}->{$mode} } ) {
        return $self->{_cache}->{$mode}->{$key};
    }

    return 0;
}

sub _get_object_list {
    my ( $self, $object, $labels ) = @_;

    my $api  = $self->{_api_obj};
    my $mode = $self->{mode};

    # These are objects that have labels and should be filtered based on the
    # label(s) passed in. Other objects (account) are returned blindly, or need
    # special treatment.

    my @should_filter = (qw(linode stackscript domain nodebalancer));

    if ( my @found = grep { $_ eq $mode } @should_filter ) {
        my $objects = [];
        my $objectunique = '';
        if ( $mode eq 'stackscript' ) {
            $objects      = $api->stackscript_list();
            $objectunique = 'label';
        }
        elsif ( $mode eq 'domain' ) {
            $objects      = $api->domain_list();
            $objectunique = 'domain';
        }
        elsif ( $mode eq 'nodebalancer' ) {
            $objects      = $api->nodebalancer_list();
            $objectunique = 'label';
        }
        else {
            $objects      = $api->linode_list();
            $objectunique = 'label';
        }

        return $objects if ( !$labels );

        my $filtered = ();
        my %targets = map { $_ => 1 } @$labels;

        # look for matches
        for my $eachlabel (@$labels) {
            my $left_char = substr( $eachlabel, length($eachlabel) - 1, 1 );
            my $right_char = substr( $eachlabel, 0, 1 );

            if ( $left_char eq '*' && $right_char ne '*' ) { # left match
                my $findme = substr( $eachlabel, 0, length($eachlabel) - 1 ); # remove *'s from *findme
                # collect matches
                for my $object ( @$objects ) {
                    my $object_label = $object->{ $objectunique };
                    if ( $object_label =~ /^${findme}/i ) { # left partial match
                        unless ( my @found = grep { $_ eq $object_label } @$filtered ) {
                            # new hit
                            push @$filtered, $object;
                            if ( exists $targets{$eachlabel} ) {
                                delete $targets{$eachlabel};
                            }
                        }
                    }
                }
            }
            elsif ( $left_char ne '*' && $right_char eq '*' ) { # right match
                my $findme = substr( $eachlabel, 1, length($eachlabel) - 1 ); # remove *'s from findme*
                # collect matches
                for my $object ( @$objects ) {
                    my $object_label = $object->{ $objectunique };
                    if ( $object_label =~ /${findme}$/i ) { # right partial match
                        unless ( my @found = grep { $_ eq $object_label } @$filtered ) {
                            # new hit
                            push @$filtered, $object;
                            if ( exists $targets{$eachlabel} ) {
                                delete $targets{$eachlabel};
                            }
                        }
                    }
                }
            }
            elsif ( $left_char eq '*' && $right_char eq '*' ) {
                my $findme = substr( $eachlabel, 1, length($eachlabel) - 2 ); # remove *'s from *findme*
                # collect matches
                for my $object ( @$objects ) {
                    my $object_label = $object->{ $objectunique };
                    if ( $object_label =~ /^\S*${findme}\S*$/i ) { # partial match
                        unless ( my @found = grep { $_ eq $object_label } @$filtered ) {
                            # new hit
                            push @$filtered, $object;
                            if ( exists $targets{$eachlabel} ) {
                                delete $targets{$eachlabel};
                            }
                        }
                    }
                }
            }
            else {
                # exact match check
                for my $object ( @$objects ) {
                    my $object_label = $object->{ $objectunique };
                    if ( $object_label eq $eachlabel ) {
                        unless ( my @found = grep { $_ eq $object_label } @$filtered ) {
                            push @$filtered, $object;
                            if ( exists $targets{$eachlabel} ) {
                                delete $targets{$eachlabel};
                            }
                        }
                    }
                }
            }
        }

        for my $mismatch ( keys %targets ) {
            $self->{_result} = $self->fail(
                label   => $mismatch,
                message => "Couldn't find $mismatch",
                result  => $self->{_result},
                action  => $self->{_distilled_options}{action},
            );
        }

        if ( keys %targets ) {
            $self->response($self->{_result});
            exit 1;
        }

        return $filtered;
    }
    elsif ( $mode eq 'account' ) {
        return $api->account_info();
    }
}

sub _get_id_by_label {
    my ( $self, $object, $label ) = @_;
    my $items = {};

    $items = "Linode::CLI::Object::$correct_case{$object}"->new_from_list(
        api_obj => $self->{_api_obj},
    )->list( output_format => 'raw', label => $label );

    for my $item ( %$items ) {
        return $items->{$item}{ $object . 'id' } if ( $label eq $item );
    }

    return 0;
}

sub _distill_options {
    my $self = shift;

    foreach ( @{ $paramsdef{ $self->{mode} }{ $self->{_opts}{action} }{'warmcache'} } ) {
        $self->_fuzzy_match($_);
    }

    $self->{_distilled_options}{pubkeyfile}
        = $self->{_opts}{'pubkey-file'} if ( $self->{_opts}{'pubkey-file'} );
    $self->{_distilled_options}{paymentterm}
        = $self->{_opts}{'payment-term'} if ( $self->{_opts}{'payment-term'} );
    $self->{_distilled_options}{label}
        = $self->{_opts}{label} if ( $self->{_opts}{label} );
    $self->{_distilled_options}{'new-label'}
        = $self->{_opts}{'new-label'} if ( $self->{_opts}{'new-label'} );
    $self->{_distilled_options}{lpm_displaygroup}
        = $self->{_opts}{group} if ( $self->{_opts}{group} );

    $self->{_distilled_options}{new_state}
        = 'start' if ( $self->{_opts}{action} eq 'boot' || $self->{_opts}{action} eq 'start' );
    $self->{_distilled_options}{new_state}
        = 'stop' if ( $self->{_opts}{action} eq 'shutdown' || $self->{_opts}{action} eq 'stop' );
    $self->{_distilled_options}{new_state}
        = 'restart' if ( $self->{_opts}{action} eq 'reboot' || $self->{_opts}{action} eq 'restart' );

    $self->{_distilled_options}{skipchecks}
        = 1 if ( $self->{_opts}{action} eq 'delete' );
}

sub _fuzzy_match {
    my ( $self, $object ) = @_;

    my $kernel = [ 137, 138 ];

    if ( $self->{_opts}{$object} ) {
        my $cache = $self->_use_or_evict_cache($object);
        my @params = [];

        if ( ref($self->{_opts}{$object}) ne 'ARRAY' ) {
            @params = $self->{_opts}{$object};
        } else {
            @params = @{$self->{_opts}{$object}};
        }

        foreach my $param (@params) {
            my $found = '';

            # look for an exact match
            for my $object_label ( sort keys %$cache ) {
                if ( ( $param =~ /^\d+$/ && $param == $cache->{$object_label}{ $object . 'id' } ) # numeric id
                    || ( lc( $object_label ) eq lc( $param ) ) # lower case match
                    || ( format_squish( $object_label ) eq $param ) ) { # ex: Linode 1024 as linode1024
                        $found = $object_label;
                        last;
                }
            }
            # not found yet, look for partial match
            if ( $found eq '' ) {
                for my $object_label ( sort keys %$cache ) {
                    if ( $object_label =~ /^$param/i ) { # left partial match
                        $found = $object_label;
                        last;
                    }
                }
            }

           if ( $found ne '' ) {
                if ( $self->{mode} eq 'stackscript' && $object eq 'distribution') {
                    $self->{_distilled_options}{ $object . 'id' }{ $found } = $cache->{ $found }{ $object . 'id' };
                } else {
                    $self->{_distilled_options}{ $object . 'id' } = $cache->{ $found }{ $object . 'id' };
                    if ( $object eq 'distribution' ) {
                        $self->{_distilled_options}{kernelid} = $kernel->[ ( $cache->{ $found }{is64bit} ) ? 1 : 0 ];
                    }
                }
            } else {
                die "Unable to fuzzy match $object: $param\n";
            }
        }
    }
}

sub _test_api {
    my $self = shift;

    # Check for API availability and verify the provided API key
    my $api_availability_test = try {
        $self->{_api_obj}->api_spec();
    };
    die "API unavailable: $WebService::Linode::Base::errstr\n" unless $api_availability_test;

    my $api_key_test = try {
        $self->{_api_obj}->test_echo();
    };
    die "API key invalid\n" unless $api_key_test;

    return 1;
}

1;
