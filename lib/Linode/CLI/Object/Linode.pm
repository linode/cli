package Linode::CLI::Object::Linode;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));
use JSON;
use Try::Tiny;

sub new {
    my ($class, %args) = @_;

    my $api_obj     = $args{api_obj};
    my $linode_id   = $args{linodeid};

    return $class->new_from_list(
        api_obj     => $api_obj,
        linode_list => $api_obj->linode_list(linodeid => $linode_id)
    );
}

sub new_from_list {
    my ($class, %args) = @_;

    my $api_obj     = $args{api_obj};
    my $linode_list = $args{linode_list} || $api_obj->linode_list();
    my $field_list = [ qw(label linodeid status backupsenabled totalhd totalram) ];

    my $output_fields = {
        label           => 'label',
        linodeid        => 'id',
        status          => 'status',
        datacenterid    => 'location',
        backupsenabled  => 'backups',
        totalhd         => 'disk',
        totalram        => 'ram',
    };

    return $class->SUPER::new_from_list(
        api_obj         => $api_obj,
        object_list     => $linode_list,
        field_list      => $field_list,
        output_fields   => $output_fields,
    );
}

sub list {
    my ($self, %args) = @_;
    my $label = $args{label} || 0;
    my $output_format = $args{output_format} || 'human';
    my $out_hashref;

    for my $object_label (keys %{$self->{object}}) {
        next if ($label && $object_label ne $label);
        for my $key (keys %{$self->{object}->{$object_label}}) {
            next unless $key ~~ %{$self->{_output_fields}};
            if ($key eq 'totalhd' || $key eq 'totalram') {
                $out_hashref->{$object_label}->{$key} = human_displaymemory($self->{object}->{$object_label}->{$key});
            }
            elsif ($key eq 'status') {
                $out_hashref->{$object_label}->{$key} = $humanstatus{$self->{object}->{$object_label}->{$key}};
            }
            elsif ($key eq 'backupsenabled') {
                if ($args{output_format} eq 'json') {
                    $out_hashref->{$object_label}->{$key} = ($self->{object}->{$object_label}->{$key} ? JSON::true : JSON::false)
                }
                else {
                    $out_hashref->{$object_label}->{$key} = $humanyn{$self->{object}->{$object_label}->{$key}};
                }
            }
            else {
                $out_hashref->{$object_label}->{$key} = $self->{object}->{$object_label}->{$key};
            }
        }
    }
    if ($output_format eq 'raw') {
        return $out_hashref;
    }
    elsif ($output_format eq 'json') {
        return json_response($out_hashref);
    }
    else {
        my $return;
        my $longestlabel = 0;
        my $longestid = 0;
        # find the longest label and id, so we can format the output to look pretty - (label is max 32)
        for my $object_label (keys %{$out_hashref}) {
            if (length($object_label) > $longestlabel) {
                $longestlabel = length($object_label);
            }
            if (length($out_hashref->{$object_label}->{linodeid}) > $longestid) {
                $longestid = length($out_hashref->{$object_label}->{linodeid});
            }
        }
        $longestlabel += 2; # pad
        $longestid += 2;
        $return .= sprintf("%-${longestlabel}s %-${longestid}s %-12s %-8s %-6s %-6s\n", 'label', 'id', 'status', 'backups', 'disk', 'ram');
        $return .= ('=' x (36 + $longestlabel + $longestid)) . "\n";
        for my $object_label (keys %{$out_hashref}) {
            $return .= sprintf(
                "%-${longestlabel}s %-${longestid}s %-12s %-8s %-6s %-6s\n",
                $out_hashref->{$object_label}->{label},
                $out_hashref->{$object_label}->{linodeid},
                $out_hashref->{$object_label}->{status},
                $out_hashref->{$object_label}->{backupsenabled},
                $out_hashref->{$object_label}->{totalhd},
                $out_hashref->{$object_label}->{totalram},
            );
        }
        $return .= ('=' x (36 + $longestlabel + $longestid)) . "\n";
        return $return;
    }
}

sub show {
    my ($self, $label) = @_;
    $label ||= 0;

    my $return = '';
    for my $object_label (keys %{$self->{object}}) {
        next if ($label && $object_label ne $label);
        for my $key (keys %{$self->{object}->{$object_label}}) {
            next unless $key ~~ %{$self->{_output_fields}};
            if ($key eq 'totalhd' || $key eq 'totalram') {
                $return .= sprintf("\n%8s %-32s", $self->{_output_fields}->{$key}, human_displaymemory($self->{object}->{$object_label}->{$key}));
            }
            elsif ($key eq 'status') {
                $return .= sprintf("\n%8s %-32s", $self->{_output_fields}->{$key}, $humanstatus{$self->{object}->{$object_label}->{$key}});
            }
            elsif ($key eq 'backupsenabled') {
                $return .= sprintf("\n%8s %-32s", $self->{_output_fields}->{$key}, $humanyn{$self->{object}->{$object_label}->{$key}});
            }
            else {
                $return .= sprintf("\n%8s %-32s", $self->{_output_fields}->{$key}, $self->{object}->{$object_label}->{$key});
            }
        }

        $return .= "\n";
    }

    return $return . "\n";
}

sub create {
    my ($self, $api_obj, $args, $output_format) = @_;

    my $params = {
        linode_create => {
            datacenterid        => delete $args->{datacenterid},
            paymentterm         => delete $args->{paymentterm},
            planid              => delete $args->{planid},
        },
        linode_disk_createfromdistribution => {
            distributionid      => delete $args->{distributionid},
            label               => "$args->{label}-disk",
        },
        linode_disk_create => {
            label               => "$args->{label}-swap",
            type                => "swap",
            size                => 256,
        },
        linode_config_create => {
            kernelid            => delete $args->{kernelid},
            label               => "$args->{label}-config",
        },
        linode_update           => $args,
    };

    if (!exists $params->{linode_disk_createfromdistribution}{rootpass}) {
        print 'Root password for this Linode: ';
        system('stty','-echo');
        chop($params->{linode_disk_createfromdistribution}{rootpass}=<STDIN>);
        system('stty','echo');
        say '';
    }

    # Create the Linode
    my $linode_id;
    my $create_result = try {
        $linode_id = $api_obj->linode_create(%{$params->{linode_create}})->{linodeid};
    };
    $self->error("Unable to create Linode") unless $create_result;

    $params->{linode_disk_createfromdistribution}->{linodeid} = $linode_id;
    $params->{linode_disk_create}->{linodeid} = $linode_id;
    $params->{linode_update}->{linodeid} = $linode_id;
    $params->{linode_config_create}->{linodeid} = $linode_id;

    # Update Linode
    my $update_result = try {
        $api_obj->linode_update(%{$params->{linode_update}});
    };
    $self->error("Unable to update Linode after initial creation") unless $update_result;

    my @disk_list;

    # Deploy main disk image
    my $disk = {};
    my $distribution_result = try {
        my $linode_hd_space = $api_obj->linode_list(linodeid => $linode_id)->[0]->{totalhd};

        $params->{linode_disk_createfromdistribution}->{size} = ($linode_hd_space - $params->{linode_disk_create}->{size});
        $disk = $api_obj->linode_disk_createfromdistribution(%{$params->{linode_disk_createfromdistribution}});
    };
    $self->error("Unable to create primary disk image") unless $distribution_result;

    push @disk_list, $disk->{diskid};

    # Deploy swap disk image
    my $swap_disk = {};
    my $swap_result = try {
        $swap_disk = $api_obj->linode_disk_create(%{$params->{linode_disk_create}});
    };
    $self->error("Unable to create swap image") unless $swap_result;

    push @disk_list, $swap_disk->{diskid};

    # Create config profile
    my $config_result = try {
        $params->{linode_config_create}->{disklist} = join ',', @disk_list;
        $disk = $api_obj->linode_config_create(%{$params->{linode_config_create}});
    };
    $self->error("Unable to create configuration profile") unless $config_result;

    # Boot!
    my $boot;
    my $boot_result = try {
        $boot = $api_obj->linode_boot(linodeid => $linode_id);
    };
    $self->error("Unable to issue boot job") unless $boot_result;

    my $boot_job_result = $self->SUPER::_poll_and_wait($api_obj, $linode_id, $boot->{jobid}, $output_format);
    $self->error("Timed out waiting for boot to complete") unless $boot_job_result;

    return $linode_id;
}

sub start {
    my ($self, $params, $output_format) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object (keys %{$self->{object}}) {
        my $linode_label = $self->{object}->{$object}->{label};
        my $linode_id = $self->{object}->{$object}->{linodeid};

        # Skip if we're already started
        if ($self->{object}->{$object}->{status} == 1) {
            $self->{object}->{$object} = $api_obj->linode_list(linodeid => $linode_id)->[0];
            next;
        }

        my $boot;
        my $boot_result = try {
            $boot = $api_obj->linode_boot(linodeid => $linode_id);
        };
        $self->error("Unable to issue boot job for $linode_label") unless $boot_result;

        my $boot_job_result = $self->SUPER::_poll_and_wait($api_obj, $linode_id, $boot->{jobid}, $output_format);
        $self->error("Timed out waiting for start to complete on $linode_label") unless $boot_job_result;

        $self->{object}->{$object} = $api_obj->linode_list(linodeid => $linode_id)->[0];
    }

    return 1;
}

sub stop {
    my ($self, $params, $output_format) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object (keys %{$self->{object}}) {
        my $linode_label = $self->{object}->{$object}->{label};
        my $linode_id = $self->{object}->{$object}->{linodeid};

        # Skip if we're already stopped
        if ($self->{object}->{$object}->{status} != 1) {
            $self->{object}->{$object} = $api_obj->linode_list(linodeid => $linode_id)->[0];
            next;
        }

        my $boot;
        my $stop_result = try {
            $boot = $api_obj->linode_shutdown(linodeid => $linode_id);
        };
        $self->error("Unable to issue boot job for $linode_label") unless $stop_result;

        my $stop_job_result = $self->SUPER::_poll_and_wait($api_obj, $linode_id, $boot->{jobid}, $output_format);
        $self->error("Timed out waiting for stop to complete on $linode_label") unless $stop_job_result;

        $self->{object}->{$object} = $api_obj->linode_list(linodeid => $linode_id)->[0];
    }

    return 1;
}

sub restart {
    my ($self, $params, $output_format) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object (keys %{$self->{object}}) {
        my $linode_label = $self->{object}->{$object}->{label};
        my $linode_id = $self->{object}->{$object}->{linodeid};

        my $boot;
        my $restart_result = try {
            $boot = $api_obj->linode_reboot(linodeid => $linode_id);
        };
        $self->error("Unable to issue boot job for $linode_label") unless $restart_result;

        my $restart_job_result = $self->SUPER::_poll_and_wait($api_obj, $linode_id, $boot->{jobid}, $output_format);
        $self->error("Timed out waiting for restart to complete on $linode_label") unless $restart_job_result;

        $self->{object}->{$object} = $api_obj->linode_list(linodeid => $linode_id)->[0];
    }

    return 1;
}

sub update {
    my ($self, $args) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object (keys %{$self->{object}}) {
        my $update_params = {
            linodeid            => $self->{object}->{$object}->{linodeid},
            label               => $args->{label}               || $self->{object}->{$object}->{label},
            lpm_displaygroup    => $args->{lpm_displaygroup}    || $self->{object}->{$object}->{lpm_displaygroup},
        };
        my $linode_label = $self->{object}->{$object}->{label};

        my $update_result = try {
            $api_obj->linode_update(%$update_params);
        };
        $self->error("Unable to update $linode_label") unless $update_result;

        $self->{object}->{$object} = $api_obj->linode_list(
            linodeid => $self->{object}->{$object}->{linodeid},
        )->[0];
    }

    return 1;
}

sub delete {
    my ($self, $args) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object (keys %{$self->{object}}) {
        my $linode_id = $self->{object}->{$object}->{linodeid};
        my $linode_label = $self->{object}->{$object}->{label};

        my $delete_params = {
            skipchecks  => $args->{skipchecks},
            linodeid    => $self->{object}->{$object}->{linodeid},
        };

        my $delete_result = try {
            $api_obj->linode_delete(%$delete_params);
        };
        $self->error("Unable to delete $linode_label") unless $delete_result;

        $self->{object}->{$object} = $api_obj->linode_list(linodeid => $linode_id)->[0];
    }

    return 1;
}

1;
