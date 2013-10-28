package Linode::CLI;

use strict;
use warnings;
use 5.010;

use Linode::CLI::Object;
use Linode::CLI::Object::Linode;
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

    $self->_warm_cache if ( $self->{_opts}->{action} eq 'create' );
    $self->_distill_options;

    return $self;
}

sub create {
    my $self = shift;

    $self->{_result} = Linode::CLI::Object::Linode->create(
        api     => $self->{_api_obj},
        options => $self->{_distilled_options},
        format  => $self->{output_format},
        wait    => $self->{wait},
    );
}

sub update {
    my $self = shift;

    my $linodes = Linode::CLI::Object::Linode->new_from_list(
        api_obj     => $self->{_api_obj},
        linode_list => $self->_get_object_list(
            'linode', $self->{_distilled_options}{label}
        ),
    );

    $self->{_result} = $linodes->update( $self->{_distilled_options} );
}

sub change_state {
    my $self = shift;

    my $new_state = $self->{_distilled_options}->{new_state};

    my $linodes = Linode::CLI::Object::Linode->new_from_list(
        api_obj     => $self->{_api_obj},
        linode_list => $self->_get_object_list(
            'linode', $self->{_distilled_options}{label}
        ),
    );

    $self->{_result} = $linodes->change_state(
        format => $self->{output_format},
        wait   => $self->{wait},
        state  => $new_state,
    );
}

sub list {
    my $self = shift;

    if ( $self->{output_format} eq 'json' ) {
        $self->{_result} = Linode::CLI::Object::Linode->new_from_list(
            api_obj     => $self->{_api_obj},
            linode_list => $self->_get_object_list(
                'linode', $self->{_distilled_options}{label}
            ),
        )->list( output_format => $self->{output_format}, );
    }
    else {
        print Linode::CLI::Object::Linode->new_from_list(
            api_obj     => $self->{_api_obj},
            linode_list => $self->_get_object_list(
                'linode', $self->{_distilled_options}{label}
            ),
        )->list( output_format => $self->{output_format}, );
    }
}

sub show {
    my $self = shift;

    # Eventually, 'show' will have more comprehensive JSON output than 'list'
    if ( $self->{output_format} eq 'json' ) {
        $self->{_result} = Linode::CLI::Object::Linode->new_from_list(
            api_obj     => $self->{_api_obj},
            linode_list => $self->_get_object_list(
                'linode', $self->{_distilled_options}{label}
            ),
        )->list( output_format => $self->{output_format}, );
    }
    else {
        print Linode::CLI::Object::Linode->new_from_list(
            api_obj       => $self->{_api_obj},
            output_format => $self->{output_format},
            linode_list   => $self->_get_object_list(
                'linode', $self->{_distilled_options}{label}
            ),
        )->show;
    }
}

sub delete {
    my $self   = shift;
    my $object = {};

    my $linode = Linode::CLI::Object::Linode->new_from_list(
        api_obj     => $self->{_api_obj},
        linode_list => $self->_get_object_list(
            'linode', $self->{_distilled_options}{label}
        ),
    );

    $self->{_result} = $linode->delete( $self->{_distilled_options} );
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

    # In case we're flushing output
    delete $self->{_result};
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

    $self->_fuzzy_match($_) foreach (qw(datacenter distribution kernel));

    $self->{_distilled_options}->{planid}
        = $self->{_opts}->{plan} if ( $self->{_opts}->{plan} );
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
            elsif ( lc $object_label eq lc $param ) {
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
            || $self->_die("Unable to fuzzy match $object: $param");
    }
}

sub _test_api {
    my $self = shift;

    # Check for API availability and verify the provided API key
    my $api_availability_test = try {
        $self->{_api_obj}->api_spec();
    };
    die "API unavailable" unless $api_availability_test;

    my $api_key_test = try {
        $self->{_api_obj}->test_echo();
    };
    die "API key invalid" unless $api_key_test;

    return 1;
}

1;
