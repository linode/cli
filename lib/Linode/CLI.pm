package Linode::CLI;

use strict;
use warnings;
use 5.010;

use Linode::CLI::Object;
use Linode::CLI::Object::Linode;
use Linode::CLI::Object::Account;
use Linode::CLI::Object::Stackscript;
use Linode::CLI::Object::Domain;
use Linode::CLI::Util (qw(:basic :config :json));
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

    $self->{_api_obj} = WebService::Linode->new(
        apikey    => $self->{api_key},
        fatal     => 1,
        useragent => "linode-cli/$VERSION",
    );

    $self->_test_api unless $self->{_opts}{action} eq 'configure';
    $self->_warm_cache;

    $self->{_distilled_options} = $args{opts};
    $self->_distill_options;

    return $self;
}

sub create {
    my $self = shift;

    my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"->create(
        api     => $self->{_api_obj},
        options => $self->{_distilled_options},
        format  => $self->{output_format},
        wait    => $self->{wait},
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
        my %combined = (%$result, %{$self->{_result}});
        %{$self->{_result}} = %combined;
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
        my %combined = (%$result, %{$self->{_result}});
        %{$self->{_result}} = %combined;
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
    if ($self->{mode} eq 'domain' && $self->{_opts}->{action} eq 'record-list') {
        $sub  = 'recordlist';
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
                         options => $self->{_distilled_options});
            my %combined = (%$result, %{$self->{_result}});
            %{$self->{_result}} = %combined;
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
                         options => $self->{_distilled_options});
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
    if ($self->{mode} eq 'domain' && $self->{_opts}->{action} eq 'record-show') {
        $subhum  = 'recordshow';
        $subjson = 'recordlist';
    }

    # Eventually, 'show' will have more comprehensive JSON output than 'list'
    if ( $self->{output_format} eq 'json' ) {
        my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"
            ->new_from_list(
                api_obj     => $self->{_api_obj},
                object_list => $self->_get_object_list(
                    $self->{mode}, $self->{_distilled_options}{label}
                ),
                action => $self->{_opts}->{action},
            )->$subjson( output_format => $self->{output_format},
                     options => $self->{_distilled_options});
        my %combined = (%$result, %{$self->{_result}});
        %{$self->{_result}} = %combined;
    }
    else {
        print "Linode::CLI::Object::$correct_case{$self->{mode}}"->new_from_list(
                api_obj       => $self->{_api_obj},
                output_format => $self->{output_format},
                object_list   => $self->_get_object_list(
                    $self->{mode}, $self->{_distilled_options}{label}
                ),
                action => $self->{_opts}->{action},
            )->$subhum( options => $self->{_distilled_options} );
    }
}

sub delete {
    my $self   = shift;

    my $delete_result = try {
        my $dobj = "Linode::CLI::Object::$correct_case{$self->{mode}}"->new_from_list(
            api_obj     => $self->{_api_obj},
            object_list => $self->_get_object_list(
                $self->{mode}, $self->{_distilled_options}{label}
            ),
            action => $self->{_opts}->{action},
        );

        my $result = $dobj->delete( $self->{_distilled_options} );
        my %combined = (%$result, %{$self->{_result}});
        %{$self->{_result}} = %combined;
    };

    $self->{_result} = $self->fail(
        label   => 'Generic error',
        message => "Problem while trying to run '$self->{mode} delete'",
        result  => $self->{_result},
    ) unless $delete_result;
}

sub domainrecord {
    my $self = shift;

    my $sub = 'recordcreate';
    if ($self->{mode} eq 'domain' && $self->{_opts}->{action} eq 'record-update') {
        $sub  = 'recordupdate';
    } elsif ($self->{mode} eq 'domain' && $self->{_opts}->{action} eq 'record-delete') {
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
    my %combined = (%$result, %{$self->{_result}});
    %{$self->{_result}} = %combined;
}

sub configure {
    my $self = shift;

    my @options = (
        [
            'api-key',
            'API key for accessing the Linode API.'
        ],
        [
            'distribution',
            'Default distribution to deploy when creating a new Linode or'
             . ' rebuilding an existing one.'
        ],
        [
            'datacenter', 'Default datacenter to deploy new Linodes within.'
        ],
        [
            'plan', 'Default plan when deploying a new Linode.'
        ],
        [
            'payment-term', 'Default payment term when deploying a new Linode.'
        ],
    );

    say 'This will walk you through setting default values for common options.';

    for my $i (0 .. $#options) {
        say $options[$i][1];
        print '>> ';
        chop ( my $response = <STDIN> );
        push @{$options[$i]}, $response;
        say '';
    }

    my $home_directory = $ENV{HOME} || ( getpwuid($<) )[7];
    write_config("$home_directory/.linodecli", \@options);
}

sub response {
    my $self = shift;

    if ( $self->{output_format} eq 'human' ) {
        for my $key ( keys %{ $self->{_result} } ) {
            $self->{_result}{$key}{request_error}
                ? say STDERR $self->{_result}{$key}{request_error}
                : say $self->{_result}{$key}{message};
        }
    }
    else {
        print json_response( $self->{_result} );
    }
}

sub _warm_cache {
    my $self   = shift;
    my $expire = time + 60;

    $self->{_cache}->{$_} = {} foreach (@MODES);

    if ( exists $paramsdef{ $self->{mode} }{ $self->{_opts}->{action} }{'warmcache'} ) {
        foreach ( @{$paramsdef{ $self->{mode} }{ $self->{_opts}->{action} }{'warmcache'}} ) {
            if ( $_ eq 'datacenter' ) {
                $self->{_cache}->{datacenter}->{$expire} =
                    Linode::CLI::Object->new_from_list(
                        api_obj     => $self->{_api_obj},
                        object_list => $self->{_api_obj}->avail_datacenters(),
                    )->list( output_format => 'raw' );
            } elsif ( $_ eq 'distribution' ) {
                $self->{_cache}->{distribution}->{$expire} =
                    Linode::CLI::Object->new_from_list(
                        api_obj     => $self->{_api_obj},
                        object_list => $self->{_api_obj}->avail_distributions(),
                    )->list( output_format => 'raw' );
            } elsif ( $_ eq 'kernel' ) {
                $self->{_cache}->{kernel}->{$expire} =
                    Linode::CLI::Object->new_from_list(
                        api_obj     => $self->{_api_obj},
                        object_list => $self->{_api_obj}->avail_kernels(),
                    )->list( output_format => 'raw' );
            } elsif ( $_ eq 'plan' ) {
                $self->{_cache}->{plan}->{$expire} =
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

sub _get_object_list {
    my ( $self, $object, $labels ) = @_;

    my $api = $self->{_api_obj};
    my $mode = $self->{mode};

    # These are objects that have labels and should be filtered based on the
    # label(s) passed in. Other objects (account) are returned blindly, or need
    # special treatment.
    my @should_filter = ('linode', 'stackscript', 'domain');

    if (my @found = grep { $_ eq $mode } @should_filter) {
        my $objects = [];
        my $objectunique = '';
        if ( $mode eq 'stackscript' ) {
            $objects = $api->stackscript_list();
            $objectunique = 'label';
        } elsif ( $mode eq 'domain' ) {
            $objects = $api->domain_list();
            $objectunique = 'domain';
        } else {
            $objects = $api->linode_list();
            $objectunique = 'label';
        }

        return $objects if ( !$labels );

        my $filtered = ();
        my %targets = map { $_ => 1 } @$labels;

        # look for matches
        for my $eachlabel (@$labels) {
            if ( substr($eachlabel, length($eachlabel) - 1, 1) eq '*' && substr($eachlabel, 0, 1) ne '*' ) { # left match
                my $findme = substr($eachlabel, 0, length($eachlabel) - 1); # remove *'s from *findme
                # collect matches
                for my $object (@$objects) {
                    my $object_label = $object->{ $objectunique };
                    if ( $object_label =~ /^${findme}/i ) { # left partial match
                        unless (my @found = grep { $_ eq $object_label } @$filtered) {
                            # new hit
                            push @$filtered, $object;
                            if ( exists( $targets{$eachlabel} ) ) {
                                delete $targets{$eachlabel};
                            }
                        }
                    }
                }
            } elsif ( substr($eachlabel, length($eachlabel) - 1, 1) ne '*' && substr($eachlabel, 0, 1) eq '*' ) { # right match
                my $findme = substr($eachlabel, 1, length($eachlabel) - 1); # remove *'s from findme*
                # collect matches
                for my $object (@$objects) {
                    my $object_label = $object->{ $objectunique };
                    if ( $object_label =~ /${findme}$/i ) { # right partial match
                        unless (my @found = grep { $_ eq $object_label } @$filtered) {
                            # new hit
                            push @$filtered, $object;
                            if ( exists( $targets{$eachlabel} ) ) {
                                delete $targets{$eachlabel};
                            }
                        }
                    }
                }
            } elsif ( substr($eachlabel, length($eachlabel) - 1, 1) eq '*' && substr($eachlabel, 0, 1) eq '*' ) {
                my $findme = substr($eachlabel, 1, length($eachlabel) - 2); # remove *'s from *findme*
                # collect matches
                for my $object (@$objects) {
                    my $object_label = $object->{ $objectunique };
                    if ( $object_label =~ /^\S*${findme}\S*$/i ) { # partial match
                        unless (my @found = grep { $_ eq $object_label } @$filtered) {
                            # new hit
                            push @$filtered, $object;
                            if ( exists( $targets{$eachlabel} ) ) {
                                delete $targets{$eachlabel};
                            }
                        }
                    }
                }
            } else {
                # exact match check
                for my $object (@$objects) {
                    my $object_label = $object->{ $objectunique };
                    if ( exists( $targets{$object_label} ) ) {
                        unless (my @found = grep { $_ eq $object_label } @$filtered) {
                            push @$filtered, $object;
                            if ( exists( $targets{$eachlabel} ) ) {
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
                action  => $self->{_distilled_options}->{action},
            );
        }

        return $filtered;
    }
    elsif ($mode eq 'account') {
        return $api->account_info();
    }
}

sub _get_id_by_label {
    my ( $self, $object, $label ) = @_;
    my $items = {};

    $items
        = "Linode::CLI::Object::$correct_case{$object}"->new_from_list(
            api_obj => $self->{_api_obj},
        )->list( output_format => 'raw', label => $label );

    for my $item (%$items) {
        return $items->{$item}->{ $object . 'id' } if ( $label eq $item );
    }

    return 0;
}

sub _distill_options {
    my $self = shift;

    $self->_fuzzy_match($_) foreach ( @{$paramsdef{ $self->{mode} }{ $self->{_opts}->{action} }{'warmcache'}} );

    $self->{_distilled_options}->{paymentterm}
        = $self->{_opts}->{'payment-term'} if ( $self->{_opts}->{'payment-term'} );
    $self->{_distilled_options}->{label}
        = $self->{_opts}->{label} if ( $self->{_opts}->{label} );
    $self->{_distilled_options}->{'new-label'}
        = $self->{_opts}->{'new-label'} if ( $self->{_opts}->{'new-label'} );
    $self->{_distilled_options}->{lpm_displaygroup}
        = $self->{_opts}->{group} if ( $self->{_opts}->{group} );

    $self->{_distilled_options}->{new_state}
        = 'start' if ( $self->{_opts}->{action} eq 'boot' || $self->{_opts}->{action} eq 'start' );
    $self->{_distilled_options}->{new_state}
        = 'stop' if ( $self->{_opts}->{action} eq 'shutdown' || $self->{_opts}->{action} eq 'stop' );
    $self->{_distilled_options}->{new_state}
        = 'restart' if ( $self->{_opts}->{action} eq 'reboot' || $self->{_opts}->{action} eq 'restart' );

    $self->{_distilled_options}->{skipchecks}
        = 1 if ( $self->{_opts}->{action} eq 'delete' );
}

sub _fuzzy_match {
    my ( $self, $object ) = @_;

    my $kernel = [ 137, 138 ];

    if ( $self->{_opts}->{$object} ) {
        my $cache = $self->_use_or_evict_cache($object);
        my @params = [];

        if ( ref($self->{_opts}->{$object}) ne 'ARRAY' ) {
            @params = $self->{_opts}->{$object};
        } else {
            @params = @{$self->{_opts}->{$object}};
        }

        foreach my $param (@params) {
            my $found = '';

            # look for an exact match
            for my $object_label ( keys %$cache ) {
                if ( ( $param =~ /^\d+$/ && $param == $cache->{$object_label}->{ $object . 'id' } ) || # numeric id
                     ( lc( $object_label ) eq lc( $param ) ) ||       # lower case match
                     ( format_squish( $object_label ) eq $param ) ) { # ex: Linode 1024 as linode1024
                    $found = $object_label;
                    last;
                }
            }
            # not found yet, look for partial match
            if ( $found eq '' ) {
                for my $object_label ( keys %$cache ) {
                    if ( $object_label =~ /^$param/i ) { # left partial match
                        $found = $object_label;
                        last;
                    }
                }
            }

           if ( $found ne '' ) {
                if ( $self->{mode} eq 'stackscript' && $object eq 'distribution') {
                    $self->{_distilled_options}->{ $object . 'id' }{ $found } = $cache->{ $found }->{ $object . 'id' };
                } else {
                    $self->{_distilled_options}->{ $object . 'id' } = $cache->{ $found }->{ $object . 'id' };
                    if ( $object eq 'distribution' ) {
                        $self->{_distilled_options}->{kernelid} = $kernel->[ ( $cache->{ $found }->{is64bit} ) ? 1 : 0 ];
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
    die 'API unavailable' unless $api_availability_test;

    my $api_key_test = try {
        $self->{_api_obj}->test_echo();
    };
    die 'API key invalid' unless $api_key_test;

    return 1;
}

1;
