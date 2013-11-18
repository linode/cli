package Linode::CLI::Object::Linode;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));
use Try::Tiny;

sub new {
    my ( $class, %args ) = @_;

    my $api_obj   = $args{api_obj};
    my $linode_id = $args{linodeid};

    return $class->new_from_list(
        api_obj     => $api_obj,
        object_list => $api_obj->linode_list( linodeid => $linode_id ) );
}

sub new_from_list {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};

    my $linode_list = $args{object_list};
    my $field_list
        = [qw(label linodeid status backupsenabled totalhd totalram)];

    my $output_fields = {
        label          => 'label',
        linodeid       => 'id',
        status         => 'status',
        datacenterid   => 'location',
        backupsenabled => 'backups',
        totalhd        => 'disk',
        totalram       => 'ram',
    };

    return $class->SUPER::new_from_list(
        api_obj       => $api_obj,
        object_list   => $linode_list,
        field_list    => $field_list,
        output_fields => $output_fields,
    );
}

sub list {
    my ( $self, %args ) = @_;
    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_hashref = {};

    my $grouped_objects = {};

    # Group into display groups
    for my $object ( keys %{ $self->{object} } ) {
        next if ( $label && $object ne $label );
        my $display_group = $self->{object}{$object}->{lpm_displaygroup};
        $grouped_objects->{$display_group}{$object}
            = $self->{object}{$object};
    }


    for my $group ( keys %{ $grouped_objects } ) {
        my ( $longestlabel, $longestid );
        if ( $output_format eq 'human' ) {
            push @$out_arrayref, $group if $group;
            push @$out_arrayref, (
                ( ' ' x 4 ) . '+ ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' + ' .
                ( '-' x 12 ) . ' + ' . ( '-' x 8 ) . ' + ' . ( '-' x 10 ) . ' + ' .
                ( '-' x 10 ) . ' + ');
            push @$out_arrayref, sprintf(
                ( ' ' x 4 ) . "| %-32s | %-8s | %-12s | %-8s | %-10s | %-10s |",
                'label', 'id', 'status', 'backups', 'disk', 'ram' );
            push @$out_arrayref, (
                ( ' ' x 4 ) . '| ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' + ' .
                ( '-' x 12 ) . ' + ' . ( '-' x 8 ) . ' + ' . ( '-' x 10 ) . ' + ' .
                ( '-' x 10 ) . ' | ');
        }

        for my $object ( keys %{ $grouped_objects->{$group} } ) {
            if ( $output_format eq 'human' ) {
                push @$out_arrayref, sprintf(
                    ( ' ' x 4 )
                    . "| %-32s | %-8s | %-12s | %-8s | %-10s | %-10s |",
                    $grouped_objects->{$group}{$object}{label},
                    $grouped_objects->{$group}{$object}{linodeid},
                    $humanstatus{ $grouped_objects->{$group}{$object}{status} },
                    $humanyn{ $grouped_objects->{$group}{$object}{backupsenabled} },
                    human_displaymemory( $grouped_objects->{$group}{$object}{totalhd} ),
                    human_displaymemory( $grouped_objects->{$group}{$object}{totalram} ),
                );
            }
            else {
                for my $key ( keys %{ $grouped_objects->{$group}{$object} } ) {
                    next unless (
                        my @found = grep { $_ eq $key } %{ $self->{_output_fields} }
                    );
                    if ( $key eq 'totalhd' || $key eq 'totalram' ) {
                        $out_hashref->{$object}{$key} = human_displaymemory(
                            $grouped_objects->{$group}{$object}{$key}
                        );
                    }
                    elsif ( $key eq 'status' ) {
                        $out_hashref->{$object}{$key} = $humanstatus{
                            $grouped_objects->{$group}{$object}{$key}
                        };
                    }
                    elsif ( $key eq 'backupsenabled' ) {
                        $out_hashref->{$object}{$key}
                            = ( $grouped_objects->{$group}{$object}{$key} )
                            ? \1
                            : \0;
                    }
                    else {
                        $out_hashref->{$object}{$key}
                            = $grouped_objects->{$group}{$object}{$key};
                    }
                }
            }
        }


        push @$out_arrayref, ( ( ' ' x 4 ) . '+ ' . ( '-' x 32 ) . ' + ' .
            ( '-' x 8 ) . ' + ' . ( '-' x 12 ) . ' + ' . ( '-' x 8 ) . ' + ' .
            ( '-' x 10 ) . ' + ' . ( '-' x 10 ) . " +\n" ) if ($output_format eq 'human');
    }

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    }
    elsif ( $output_format eq 'json' ) {
        for my $object ( keys %$out_hashref ) {
            $self->{_result} = $self->succeed(
                label   => $object,
                payload => $out_hashref->{$object},
                result  => $self->{_result},
                format  => $self->{output_format},
            );
        }
        return $self->{_result};
    }
    else {
        return join( "\n", @$out_arrayref );
    }

}

sub show {
    my ( $self, $label ) = @_;
    $label ||= 0;

    my $return = '';
    for my $object_label ( keys %{ $self->{object} } ) {
        next if ( $label && $object_label ne $label );
        for my $key ( keys %{ $self->{object}->{$object_label} } ) {
            next unless ( my @found = grep { $_ eq $key } %{ $self->{_output_fields} } );
            if ( $key eq 'totalhd' || $key eq 'totalram' ) {
                $return .= sprintf(
                    "\n%8s %-32s",
                    $self->{_output_fields}->{$key},
                    human_displaymemory(
                        $self->{object}->{$object_label}->{$key} ) );
            }
            elsif ( $key eq 'status' ) {
                $return .= sprintf( "\n%8s %-32s",
                    $self->{_output_fields}->{$key},
                    $humanstatus{ $self->{object}->{$object_label}->{$key} }
                );
            }
            elsif ( $key eq 'backupsenabled' ) {
                $return .= sprintf( "\n%8s %-32s",
                    $self->{_output_fields}->{$key},
                    $humanyn{ $self->{object}->{$object_label}->{$key} } );
            }
            elsif ( $key eq 'datacenterid' ) {
                $return .= sprintf( "\n%8s %-32s",
                    $self->{_output_fields}->{$key},
                    $humandc{ $self->{object}->{$object_label}->{$key} } );
            }
            else {
                $return .= sprintf( "\n%8s %-32s",
                    $self->{_output_fields}->{$key},
                    $self->{object}->{$object_label}->{$key} );
            }
        }

        $return .= "\n";
    }

    return $return . "\n";
}

sub create {
    my ( $self, %args ) = @_;

    my $api     = $args{api};
    my $options = $args{options};
    my $format  = $args{format};
    my $wait    = $args{wait};

    # For now, only create one Linode at a time
    $options->{label} = pop @{ $options->{label} };

    my $params = {
        linode_create => {
            datacenterid    => delete $options->{datacenterid},
            paymentterm     => delete $options->{paymentterm},
            planid          => delete $options->{planid},
        },
        linode_disk_createfromdistribution => {
            distributionid  => delete $options->{distributionid},
            label           => "$options->{label}-disk",
        },
        linode_disk_create => {
            label           => "$options->{label}-swap",
            type            => 'swap',
            size            => 256,
        },
        linode_config_create => {
            kernelid        => delete $options->{kernelid},
            label           => "$options->{label}-config",
        },
        linode_update       => $options,
    };

    if ( !exists $params->{linode_disk_createfromdistribution}{rootpass} ) {
        print 'Root password for this Linode: ';
        system( 'stty', '-echo' );
        chop( $params->{linode_disk_createfromdistribution}{rootpass} = <STDIN> );
        system( 'stty', 'echo' );
        say '';
    }

    # Create the Linode
    my $linode_id;
    my $create_result = try {
        $linode_id = $api->linode_create(
            %{ $params->{linode_create} }
        )->{linodeid};
    };
    return $self->fail(
        label   => $params->{linode_update}{label},
        message => "Unable to create $options->{label}",
    ) unless $create_result;

    $params->{linode_disk_createfromdistribution}{linodeid} = $linode_id;
    $params->{linode_disk_create}{linodeid}                 = $linode_id;
    $params->{linode_update}{linodeid}                      = $linode_id;
    $params->{linode_config_create}{linodeid}               = $linode_id;

    # Update Linode
    my $update_result = try {
        $api->linode_update( %{ $params->{linode_update} } );
    };
    return $self->fail(
        label   => $params->{linode_update}{label},
        message => "Unable to update $options->{label} after initial creation",
    ) unless $update_result;

    my @disk_list;

    # Deploy main disk image
    my $disk                = {};
    my $distribution_result = try {
        my $linode_hd_space
            = $api->linode_list( linodeid => $linode_id )->[0]->{totalhd};

        $params->{linode_disk_createfromdistribution}->{size}
            = ( $linode_hd_space - $params->{linode_disk_create}{size} );
        $disk = $api->linode_disk_createfromdistribution(
            %{ $params->{linode_disk_createfromdistribution} } );
    };
    return $self->fail(
        label   => $params->{linode_update}{label},
        message => 'Unable to create primary disk image',
    ) unless $distribution_result;

    push @disk_list, $disk->{diskid};

    # Deploy swap disk image
    my $swap_disk   = {};
    my $swap_result = try {
        $swap_disk = $api->linode_disk_create( %{ $params->{linode_disk_create} } );
    };
    return $self->fail(
        label   => $params->{linode_update}{label},
        message => 'Unable to create swap image',
    ) unless $swap_result;

    push @disk_list, $swap_disk->{diskid};

    # Create config profile
    my $config_result = try {
        $params->{linode_config_create}{disklist} = join ',', @disk_list;
        $disk = $api->linode_config_create(
            %{ $params->{linode_config_create} } );
    };
    return $self->fail(
        label   => $params->{linode_update}{label},
        message => 'Unable to create configuration profile',
    ) unless $config_result;

    # Boot!
    my $boot;
    my $boot_result = try {
        $boot = $api->linode_boot( linodeid => $linode_id );
    };

    return $self->fail(
        label   => $params->{linode_update}{label},
        message => "Unable to issue boot job for $options->{label}",
    ) unless $boot_result;

    if ($wait) {
        my $boot_job_result
            = $self->_poll_and_wait( $api, $linode_id, $boot->{jobid},
            $format );
        return $self->fail(
            label   => $params->{linode_update}{label},
            message => "Timed out waiting for boot to complete for $params->{linode_update}{label}",
            payload => { jobid => $boot->{jobid}, job => 'start' },
        ) unless $boot_job_result;
    }

    return $self->succeed(
        label   => $params->{linode_update}{label},
        message => "Creating and booting $options->{label}...",
        payload => { jobid => $boot->{jobid}, job => 'start' },
    );
}

sub change_state {
    my ( $self, %args ) = @_;

    my $api    = $self->{_api_obj};
    my $format = $args{format};
    my $state  = $args{state};
    my $wait   = $args{wait};

    my $map = {
        start   => [ 'Starting',   'Started' ],
        stop    => [ 'Stopping',   'Stopped' ],
        restart => [ 'Restarting', 'Restarted' ],
    };
    my $queue = {};

    for my $object ( keys %{ $self->{object} } ) {
        my $linode_label = $self->{object}->{$object}->{label};
        my $linode_id    = $self->{object}->{$object}->{linodeid};

        my $state_change;
        my $state_change_result = try {
            $state_change
                = $state eq 'start'
                ? $api->linode_boot( linodeid => $linode_id )
                : $state eq 'stop'
                ? $api->linode_shutdown( linodeid => $linode_id )
                : $api->linode_reboot( linodeid => $linode_id );
        };

        if ( !$state_change_result ) {
            $self->{_result} = $self->fail(
                label   => $linode_label,
                message => "Unable to $state $linode_label",
                result  => $self->{_result},
            );
            next;
        }

        if ($wait) {
            say "$map->{$state}[0] $linode_label..." if ( $format eq 'human' );
            $queue->{ $state_change->{jobid} }
                = [ $linode_id, $linode_label, $state ];
            next;
        }

        $self->{_result} = $self->succeed(
            label   => $linode_label,
            message => "$map->{$state}[0] $linode_label...",
            payload => { jobid => $state_change->{jobid}, job => $state },
            result  => $self->{_result},
            format  => $self->{output_format},
        );
    }

    if ($wait) {
        print "waiting..." if ( $format eq 'human' );

        for my $job ( keys %$queue ) {
            my $jobid        = $job;
            my $linode_id    = $queue->{$job}[0];
            my $linode_label = $queue->{$job}[1];
            my $boot_job_result
                = $self->_poll_and_wait( $api, $linode_id, $jobid, $format );

            if ( !$boot_job_result ) {
                $self->{_result} = $self->fail(
                    label   => $linode_label,
                    message => "Unable to $state $linode_label",
                    payload => { jobid => $jobid, job => $state },
                    result  => $self->{_result},
                );
                next;
            }

            $self->{_result} = $self->succeed(
                label   => $linode_label,
                message => "$map->{$state}[1] $linode_label",
                payload => { jobid => $jobid, job => $state },
                result  => $self->{_result},
            );
        }
    }

    return $self->{_result};
}

sub resize {
    my ( $self, %args ) = @_;

    my $api     = $self->{_api_obj};
    my $options = $args{options};
    my $format  = $args{format};
    my $wait    = $args{wait};

    my $queue = {};

    for my $object ( keys %{ $self->{object} } ) {
        my $id     = $self->{object}->{$object}->{linodeid};
        my $label  = $self->{object}->{$object}->{label};
        my $params = {
            linodeid => $id,
            planid   => $options->{planid},
        };

        my ( $resize, $boot );
        my $resize_result = try {
            $resize = $api->linode_resize(%$params);
            $boot = $api->linode_boot( linodeid => $id );
        };

        if ( !$resize_result ) {
            $self->{_result} = $self->fail(
                label   => $label,
                message => "Unable to resize and boot $label",
                result  => $self->{_result},
            );
            next;
        }

        if ($wait) {
            say "Resizing and booting $label..." if ( $format eq 'human' );
            $queue->{ $boot->{jobid} } = [ $id, $label ];
            next;
        }

        $self->{_result} = $self->succeed(
            label   => $label,
            message => "Resizing and booting $label...",
            payload => { jobid => $resize->{jobid}, job => 'resize' },
            result  => $self->{_result},
        );
    }

    if ($wait && scalar keys %$queue) {
        print 'waiting...' if ( $format eq 'human' );

        for my $job ( keys %$queue ) {
            my $jobid = $job;
            my $id    = $queue->{$job}[0];
            my $label = $queue->{$job}[1];
            my $job_result
                = $self->_poll_and_wait( $api, $id, $jobid, $format, 240 );

            if ( !$job_result ) {
                $self->{_result} = $self->fail(
                    label   => $label,
                    message => "Unable to resize and boot $label",
                    payload => { jobid => $jobid, job => 'resize' },
                    result  => $self->{_result},
                );
                next;
            }

            $self->{_result} = $self->succeed(
                label   => $label,
                message => "Resized and booted $label",
                payload => { jobid => $jobid, job => 'resize' },
                result  => $self->{_result},
            );
        }
    }

    return $self->{_result};
}

sub update {
    my ( $self, $args ) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object ( keys %{ $self->{object} } ) {
        my $update_params = {
            linodeid => $self->{object}->{$object}->{linodeid},
            label    => $args->{'new-label'}
                || $self->{object}->{$object}->{label},
            lpm_displaygroup => $args->{lpm_displaygroup}
                || $self->{object}->{$object}->{lpm_displaygroup},
        };
        my $linode_label = $self->{object}->{$object}->{label};

        my $update_result = try {
            $api_obj->linode_update(%$update_params);
        };

        if ($update_result) {
            $self->{_result} = $self->succeed(
                label   => $linode_label,
                message => "Updated $linode_label",
                payload => { action => 'update' },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->{_result} = $self->fail(
                label   => $linode_label,
                message => "Unable to update $linode_label",
            );
        }
    }

    return $self->{_result};
}

sub delete {
    my ( $self, $args ) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object ( keys %{ $self->{object} } ) {
        my $linode_id    = $self->{object}->{$object}->{linodeid};
        my $linode_label = $self->{object}->{$object}->{label};

        my $delete_params = {
            skipchecks => $args->{skipchecks},
            linodeid   => $self->{object}->{$object}->{linodeid},
        };

        my $delete_result = try {
            $api_obj->linode_delete(%$delete_params);
        };

        if ($delete_result) {
            $self->{_result} = $self->succeed(
                label   => $linode_label,
                message => "Deleted $linode_label",
                payload => { action => 'delete' },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->{_result} = $self->fail(
                label   => $linode_label,
                message => "Unable to delete $linode_label",
            );
        }
    }

    return $self->{_result};
}

sub _poll_and_wait {
    my ( $self, $api_obj, $linode_id, $job_id, $output_format, $timeout ) = @_;
    $timeout ||= 60;

    my $poll_result = try {
        for ( my $i = 0; $i <= $timeout; $i++ ) {
            my $job = $api_obj->linode_job_list(
                linodeid => $linode_id,
                jobid    => $job_id,
            )->[0];

            my $job_complete = $job->{host_finish_dt};
            my $job_success  = $job->{host_success};

            if ( ( $job_complete && $job_success ) || ( $i == $timeout && !$job_complete ) ) {
                print STDOUT "\n" if ( $output_format eq 'human' );
            }

            return 1 if ( $job_complete && $job_success );
            return 0 if ( $i == $timeout || ( $job_complete && !$job_success ) );

            print STDOUT '.' if ( $output_format eq 'human' );
            sleep 5;
        }
    };
}

1;
