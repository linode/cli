package Linode::CLI;

use strict;
use warnings;
use 5.010;

use Linode::CLI::Object;
use Linode::CLI::Object::Linode;
use Linode::CLI::Object::Account;
use Linode::CLI::Object::Stackscript;
use Linode::CLI::Util (qw(:basic :json));
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
        apikey => $self->{api_key},
        fatal  => 1,
    );

    $self->_test_api;

    if (   $self->{_opts}->{action} eq 'create'
        || $self->{_opts}->{action} eq 'show'
        || $self->{_opts}->{action} eq 'update'
        || $self->{_opts}->{action} eq 'resize' ) {
        $self->_warm_cache;
    }

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

    my $list_result = try {
        if ( $self->{output_format} eq 'json' ) {
            my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"
                ->new_from_list(
                    api_obj     => $self->{_api_obj},
                    object_list => $self->_get_object_list(
                        $self->{mode}, $self->{_distilled_options}{label}
                    ),
                    action => $self->{_opts}->{action},
                )->list( output_format => $self->{output_format}, );
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
                )->list( output_format => $self->{output_format}, );
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

    # Eventually, 'show' will have more comprehensive JSON output than 'list'
    if ( $self->{output_format} eq 'json' ) {
        my $result = "Linode::CLI::Object::$correct_case{$self->{mode}}"
            ->new_from_list(
                api_obj     => $self->{_api_obj},
                object_list => $self->_get_object_list(
                    $self->{mode}, $self->{_distilled_options}{label}
                ),
                action => $self->{_opts}->{action},
            )->list( output_format => $self->{output_format}, );
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
            )->show;
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

    my $datacenters = Linode::CLI::Object->new_from_list(
        api_obj     => $self->{_api_obj},
        object_list => $self->{_api_obj}->avail_datacenters(),
    )->list( output_format => 'raw' );
    $self->{_cache}->{datacenter}->{$expire} = $datacenters;

    my $distributions = Linode::CLI::Object->new_from_list(
        api_obj     => $self->{_api_obj},
        object_list => $self->{_api_obj}->avail_distributions(),
    )->list( output_format => 'raw' );
    $self->{_cache}->{distribution}->{$expire} = $distributions;

    my $kernels = Linode::CLI::Object->new_from_list(
        api_obj     => $self->{_api_obj},
        object_list => $self->{_api_obj}->avail_kernels(),
    )->list( output_format => 'raw' );
    $self->{_cache}->{kernel}->{$expire} = $kernels;

    my $plans = Linode::CLI::Object->new_from_list(
        api_obj     => $self->{_api_obj},
        object_list => $self->{_api_obj}->avail_linodeplans(),
    )->list( output_format => 'raw' );
    $self->{_cache}->{plan}->{$expire} = $plans;
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

    if ($self->{mode} eq 'linode') {
        my $linodes = $self->{_api_obj}->linode_list();

        return $linodes if ( !$labels );

        my $filtered = ();
        my %targets = map { $_ => 1 } @$labels;

        for my $linode (@$linodes) {
            my $linode_label = $linode->{label};
            if ( exists( $targets{$linode_label} ) ) {
                push @$filtered, $linode;
                delete $targets{$linode_label};
            }
        }

        for my $mismatch ( keys %targets ) {
            $self->{_result} = $self->fail(
                label   => $mismatch,
                message => "Couldn't find $mismatch",
                result  => $self->{_result},
            );
        }

        return $filtered;
    }
    elsif ($self->{mode} eq 'account') {
        return $self->{_api_obj}->account_info();
    }
    elsif ($self->{mode} eq 'stackscript') {
        my $stackscripts = $self->{_api_obj}->stackscript_list();

        return $stackscripts if ( !$labels );

        my $filtered = ();
        my %targets = map { $_ => 1 } @$labels;

        for my $ss (@$stackscripts) {
            my $ss_label = $ss->{label};
            if ( exists( $targets{$ss_label} ) ) {
                push @$filtered, $ss;
                delete $targets{$ss_label};
            }
        }

        for my $mismatch ( keys %targets ) {
            $self->{_result} = $self->fail(
                label   => $mismatch,
                message => "Couldn't find $mismatch",
                result  => $self->{_result},
            );
        }

        return $filtered;
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

    $self->_fuzzy_match($_) foreach (qw(datacenter distribution kernel plan));

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
        my $param = $self->{_opts}->{$object};
        my $cache = $self->_use_or_evict_cache($object);

        for my $object_label ( keys %$cache ) {
            if ( $param =~ /^\d+$/ && $param == $cache->{$object_label}->{ $object . 'id' } ) {
                $self->{_distilled_options}->{ $object . 'id' } = $param;
                if ( $object eq 'distribution' ) {
                    $self->{_distilled_options}->{kernelid}
                        = $kernel->[ ( $cache->{$object_label}->{is64bit} ) ? 1 : 0 ];
                }
                last;
            }
            elsif ( lc( $object_label ) eq lc( $param ) ) {
                $self->{_distilled_options}->{ $object . 'id' }
                    = $cache->{$object_label}->{ $object . 'id' };
                if ( $object eq 'distribution' ) {
                    $self->{_distilled_options}->{kernelid}
                        = $kernel->[ ( $cache->{$object_label}->{is64bit} ) ? 1 : 0 ];
                }
                last;
            }
            elsif ( format_squish( $object_label ) eq $param ) { # ex: Linode 1024 as linode1024
                $self->{_distilled_options}->{ $object . 'id' }
                    = $cache->{$object_label}->{ $object . 'id' };
                if ( $object eq 'distribution' ) {
                    $self->{_distilled_options}->{kernelid}
                        = $kernel->[ ( $cache->{$object_label}->{is64bit} ) ? 1 : 0 ];
                }
                last;
            }
            elsif ( $object_label =~ /^$param/i ) {
                $self->{_distilled_options}->{ $object . 'id' }
                    = $cache->{$object_label}->{ $object . 'id' };
                if ( $object eq 'distribution' ) {
                    $self->{_distilled_options}->{kernelid}
                        = $kernel->[ ( $cache->{$object_label}->{is64bit} ) ? 1 : 0 ];
                }
            }
        }

        $self->{_distilled_options}->{ $object . 'id' }
            || die "Unable to fuzzy match $object: $param\n";
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
