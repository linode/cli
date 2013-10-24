package Linode::CLI;

use strict;
use warnings;

use Linode::CLI::Object;
use Linode::CLI::Object::Linode;
use Linode::CLI::Util (qw(:basic :json));
use Try::Tiny;
use WebService::Linode;

sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    $self->{api_key}        = $args{api_key};
    $self->{mode}           = $args{mode};
    $self->{output_format}  = $args{output_format};

    $self->{_opts}          = $args{opts};

    $self->{_api_obj} = WebService::Linode->new(
        apikey  => $self->{api_key},
        fatal   => 1,
    );

    $self->_test_api;

    $self->_warm_cache if ($self->{_opts}->{action} eq 'create');
    $self->_distill_options;

    return $self;
}

sub create {
    my $self = shift;
    my $object = {};

    if ($self->{mode} eq 'linode') {
        my $create_result = try {
            my $linode_id = Linode::CLI::Object::Linode->create(
                $self->{_api_obj},
                $self->{_distilled_options},
                $self->{output_format},
            );
            $object = Linode::CLI::Object::Linode->new_from_list(
                api_obj         => $self->{_api_obj},
                linode_list     => $self->{_api_obj}->linode_list(linodeid => $linode_id),
            );
        };

        $self->_die("Create failed") unless $create_result;
    }

    $object->list(output_format => $self->{output_format});
}

sub update {
    my $self = shift;
    my $updated_object = {};

    if ($self->{mode} eq 'linode') {
        my $update_result = try {
            my $linode_id = $self->_get_id_by_label('linode', $self->{_distilled_options}->{label}) || return 0;
            $self->{_distilled_options}->{label} = $self->{_opts}->{'new-label'} if ($self->{_opts}->{'new-label'});

            my $linode = Linode::CLI::Object::Linode->new(
                api_obj         => $self->{_api_obj},
                linodeid        => $linode_id,
            );

            $linode->update($self->{_distilled_options});

            $updated_object = Linode::CLI::Object::Linode->new(
                api_obj         => $self->{_api_obj},
                linodeid        => $linode_id,
            );
        };

        $self->_die("Update failed") unless $update_result;
    }

    $updated_object->list(output_format => $self->{output_format});
}

sub change_state {
    my $self = shift;
    my $object = {};

    my $linode_id = $self->_get_id_by_label('linode', $self->{_distilled_options}->{label}) || return 0;
    my $linode = Linode::CLI::Object::Linode->new(
        api_obj         => $self->{_api_obj},
        linodeid        => $linode_id,
    );

    my $state_result = try {
        if ($self->{_distilled_options}->{new_state} eq 'running') {
            $linode->start($self->{_distilled_options}, $self->{output_format});
        }
        elsif ($self->{_distilled_options}->{new_state} eq 'stopped') {
            $linode->stop($self->{_distilled_options}, $self->{output_format});
        }
        elsif ($self->{_distilled_options}->{new_state} eq 'restarting') {
            $linode->restart($self->{_distilled_options}, $self->{output_format});
        }
    };
    $self->_die("Unable to change state to $self->{_distilled_options}->{new_state}") unless $state_result;

    my $updated_linode = Linode::CLI::Object::Linode->new(
        api_obj         => $self->{_api_obj},
        linodeid        => $linode_id,
    );
    return $updated_linode->list(output_format => $self->{output_format});
}

sub list {
    my $self = shift;

    if ($self->{mode} eq 'linode') {
        return Linode::CLI::Object::Linode->new_from_list(
            api_obj         => $self->{_api_obj},
        )->list(
            label           => $self->{_opts}->{label},
            output_format   => $self->{output_format},
        );
    }
    else {
        return Linode::CLI::Object->new_from_list(
            api_obj         => $self->{_api_obj},
        )->list(
            label           => $self->{_opts}->{label},
            output_format   => $self->{output_format},
        );
    }
}

sub show {
    my $self = shift;
    my $return = "";

    if ($self->{mode} eq 'linode') {
        return Linode::CLI::Object::Linode->new_from_list(
            api_obj         => $self->{_api_obj},
            output_format   => $self->{output_format},
        )->show($self->{_opts}->{label});
    }

    return 0;
}

sub delete {
    my $self = shift;
    my $object = {};

    if ($self->{mode} eq 'linode') {
        my $delete_result = try {
            my $linode_id = $self->_get_id_by_label('linode', $self->{_distilled_options}->{label}) || return 0;

            my $linode = Linode::CLI::Object::Linode->new(
                api_obj         => $self->{_api_obj},
                linodeid        => $linode_id,
                output_format   => $self->{output_format},
            );

            $linode->delete($self->{_distilled_options});
            $object = $linode;
        };

        $self->_die("Delete failed") unless $delete_result;
    }

    $object->list(output_format => $self->{output_format});
}

sub _warm_cache {
    my $self = shift;
    my $time = time;

    $self->{_cache}->{$_} = {} foreach (@MODES);

    my $datacenter_objects = Linode::CLI::Object->new_from_list(
        api_obj         => $self->{_api_obj},
        object_list     => $self->{_api_obj}->avail_datacenters(),
    )->list(output_format => 'raw');
    $self->{_cache}->{datacenter}->{($time + 60)} = $datacenter_objects;

    my $distribution_objects = Linode::CLI::Object->new_from_list(
        api_obj         => $self->{_api_obj},
        object_list     => $self->{_api_obj}->avail_distributions(),
    )->list(output_format => 'raw');
    $self->{_cache}->{distribution}->{($time + 60)} = $distribution_objects;

    my $kernel_objects = Linode::CLI::Object->new_from_list(
        api_obj         => $self->{_api_obj},
        object_list     => $self->{_api_obj}->avail_kernels(),
    )->list(output_format => 'raw');
    $self->{_cache}->{kernel}->{($time + 60)} = $kernel_objects;
}

sub _use_or_evict_cache {
    my ($self, $mode) = @_;

    return 0 unless (scalar keys %{$self->{_cache}->{$mode}});

    my $now = time;

    for my $key (sort keys %{$self->{_cache}->{$mode}}) {
        if ($key < $now) {
            delete $self->{_cache}->{$mode}->{$key};
        }
        else {
            return $self->{_cache}->{$mode}->{$key};
        }
    }

    return 0;
}

sub _get_id_by_label {
    my ($self, $object, $label) = @_;
    my $items = {};

    $items = "Linode::CLI::Object::$correct_case{$object}"->new_from_list(
        api_obj         => $self->{_api_obj},
    )->list(output_format => 'raw', label => $label);

    for my $item (%$items) {
        return $items->{$item}->{$object . 'id'} if ($label eq $item);
    }

    return 0;
}

sub _distill_options {
    my $self = shift;

    $self->_fuzzy_match($_) foreach (qw(datacenter distribution kernel));

    $self->{_distilled_options}->{planid}           = $self->{_opts}->{plan} if ($self->{_opts}->{plan});
    $self->{_distilled_options}->{paymentterm}      = $self->{_opts}->{'payment-term'} if ($self->{_opts}->{'payment-term'});
    $self->{_distilled_options}->{label}            = $self->{_opts}->{label} if ($self->{_opts}->{label});
    $self->{_distilled_options}->{lpm_displaygroup} = $self->{_opts}->{group} if ($self->{_opts}->{group});

    $self->{_distilled_options}->{new_state}        = 'running' if ($self->{_opts}->{action} eq 'boot' || $self->{_opts}->{action} eq 'start');
    $self->{_distilled_options}->{new_state}        = 'stopped' if ($self->{_opts}->{action} eq 'shutdown' || $self->{_opts}->{action} eq 'stop');
    $self->{_distilled_options}->{new_state}        = 'restarting' if ($self->{_opts}->{action} eq 'reboot' || $self->{_opts}->{action} eq 'restart');

    $self->{_distilled_options}->{skipchecks}       = 1 if ($self->{_opts}->{action} eq 'delete');
}

sub _fuzzy_match {
    my ($self, $object) = @_;

    if ($self->{_opts}->{$object}) {
        my $param = $self->{_opts}->{$object};
        my $cache = $self->_use_or_evict_cache($object);
        for my $object_label (keys %$cache) {
            if ($param =~ /^\d+$/ && $param == $cache->{$object_label}->{$object . 'id'}) {
                $self->{_distilled_options}->{$object . 'id'} = $param;
                last;
            }
            elsif (lc $object_label eq lc $param) {
                $self->{_distilled_options}->{$object . 'id'} = $cache->{$object_label}->{$object . 'id'};
                last;
            }
            elsif ($object_label =~ /^$param/i) {
                $self->{_distilled_options}->{$object . 'id'} = $cache->{$object_label}->{$object . 'id'};
            }
        }

        $self->{_distilled_options}->{$object . 'id'} || $self->_die("Unable to fuzzy match $object: $param");
    }
}

sub _test_api {
    my $self = shift;

    # Check for API availability and verify the provided API key
    my $api_availability_test = try {
        $self->{_api_obj}->api_spec();
    };
    $self->_die("API unavailable: $WebService::Linode::Base::errstr") unless $api_availability_test;

    my $api_key_test = try {
        $self->{_api_obj}->test_echo();
    };
    $self->_die() unless $api_key_test;

    return 1;
}

sub _die {
    my ($self, $message) = @_;
    my @death;
    push(@death, $message) if ($message);
    push(@death, $Linode::CLI::Util::cli_err) if ($Linode::CLI::Util::cli_err);
    push(@death, $WebService::Linode::Base::errstr) if ($WebService::Linode::Base::errstr);
    push(@death, 'Unknown error') unless (@death);

    my $death_message = join('. ', @death);

    if ($self->{output_format} eq 'human') {
        print "$death_message.\n";
        exit 1;
    }
    else {
        print json_response({}, "$death_message.", 1);
        exit 1;
    }
}

1;
