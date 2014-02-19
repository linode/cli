package Linode::CLI::Object::Linode;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));
use Try::Tiny;
use JSON;

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
    my $action = $args{action} || '';

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
        ips            => 'ips',
    };

    return $class->SUPER::new_from_list(
        api_obj       => $api_obj,
        action        => $action,
        object_list   => $linode_list,
        field_list    => $field_list,
        output_fields => $output_fields,
    );
}

sub list {
    my ( $self, %args ) = @_;
    my $api           = $self->{_api_obj};
    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_hashref = {};
    my @colw = ( 32, 14, 10, 8, 10, 10 );

    my $grouped_objects = {};

    # Group into display groups
    for my $object ( keys %{ $self->{object} } ) {
        next if ( $label && $object ne $label );
        if ( $output_format eq 'json' ) {
            my $linodeid = $self->{object}{$object}{linodeid};
            my @ips = map { $_->{ipaddress} } @{$api->linode_ip_list(linodeid => $linodeid)};
            $self->{object}{$object}{ips} = \@ips;
        }

        my $display_group = $self->{object}{$object}->{lpm_displaygroup};
        $grouped_objects->{$display_group}{$object}
            = $self->{object}{$object};
    }

    for my $group ( keys %{ $grouped_objects } ) {
        if ( $output_format eq 'human' ) {
            push @$out_arrayref, $group if $group;
            push @$out_arrayref, (
                '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' .
                ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . ' +');
            push @$out_arrayref, sprintf(
                "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s | %-${colw[4]}s | %-${colw[5]}s |",
                'label', 'status', 'location', 'backups', 'disk', 'ram' );
            push @$out_arrayref, (
                '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' .
                ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . ' |');
        }

        for my $object ( keys %{ $grouped_objects->{$group} } ) {
            if ( $output_format eq 'human' ) {
                my $line = sprintf(
                    "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s | %-${colw[4]}s | %-${colw[5]}s |",
                    format_len( $grouped_objects->{$group}{$object}{label}, $colw[0] ),
                    $humanstatus{ $grouped_objects->{$group}{$object}{status} },
                    $humandc{ $grouped_objects->{$group}{$object}{datacenterid} },
                    $humanyn{ $grouped_objects->{$group}{$object}{backupsenabled} },
                    human_displaymemory( $grouped_objects->{$group}{$object}{totalhd} ),
                    human_displaymemory( $grouped_objects->{$group}{$object}{totalram} )
                );

                push @$out_arrayref, colorize( $line );
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
                    elsif ( $key eq 'datacenterid' ) {
                        $out_hashref->{$object}{'location'} = $humandc{
                            $grouped_objects->{$group}{$object}{$key}
                        };
                    }
                    else {
                        $out_hashref->{$object}{$key}
                            = $grouped_objects->{$group}{$object}{$key};
                    }
                }

                $out_hashref->{$object}{group} = $group;
            }
        }

        push @$out_arrayref, ( '+ ' . ( '-' x $colw[0] ) . ' + ' .
            ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' .
            ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . " +\n" ) if ($output_format eq 'human');
    }

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    }
    elsif ( $output_format eq 'json' ) {
        if (scalar( keys %{ $out_hashref }) > 0) {
            for my $object ( keys %$out_hashref ) {
                $self->{_result} = $self->succeed(
                    action  => $self->{_action},
                    label   => $object,
                    payload => $out_hashref->{$object},
                    result  => $self->{_result},
                    format  => $self->{output_format},
                );
            }
            return $self->{_result};
        } else {
            # empty
            return $self->succeed(
                action  => $self->{_action},
                label   => '',
                payload => {},
                result  => {},
                message => "No Linodes to list.",
                format  => $self->{output_format},
            );
        }
    }
    else {
        if ( scalar( @$out_arrayref ) == 0 ) {
            # no results, create empty table
            push @$out_arrayref, (
                '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' .
                ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . ' +');
            push @$out_arrayref, sprintf(
                "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s | %-${colw[4]}s | %-${colw[5]}s |",
                'label', 'status', 'location', 'backups', 'disk', 'ram' );
            push @$out_arrayref, (
                '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' .
                ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . ' |');
            push @$out_arrayref, ( '+ ' . ( '-' x $colw[0] ) . ' + ' .
                ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' .
                ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . " +\n" );
        }
        return join( "\n", @$out_arrayref );
    }

}

sub show {
    my ( $self, %args ) = @_;
    my $api    = $self->{_api_obj};
    my $return = '';

    for my $object_label ( keys %{ $self->{object} } ) {
        my $linodeid = $self->{object}{$object_label}{linodeid};
        my @ips = map { $_->{ipaddress} } @{$api->linode_ip_list(linodeid => $linodeid)};
        $return .= sprintf( "%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n",
                'label:', $self->{object}->{$object_label}->{label},
                'status:', $humanstatus{ $self->{object}->{$object_label}->{status} },
                'location:', $humandc{ $self->{object}->{$object_label}->{datacenterid} },
                'backups:', $humanyn{ $self->{object}->{$object_label}->{backupsenabled} },
                'disk:',human_displaymemory( $self->{object}->{$object_label}->{totalhd} ),
                'ram:', human_displaymemory( $self->{object}->{$object_label}->{totalram} ),
                'ips:', join(' ', @ips)
            ) . "\n";
    }

    return $return;
}

sub create {
    my ( $self, %args ) = @_;

    my $api     = $args{api_obj};
    my $options = $args{options};
    my $format  = $args{format};

    # For now, only create one Linode at a time
    my $linode_label = @{ $options->{label} }[0];

    # check if this label is already in use
    my $linodeobjects = $api->linode_list();
    for my $lobject (@$linodeobjects) {
        if ( $lobject->{label} eq $linode_label ) {
            return $self->fail(
                action  => 'create',
                label   => $linode_label,
                message => "The name $linode_label is already in use by another Linode.",
            );
        }
    }

    my $params = {
        linode_create => {
            datacenterid => $options->{datacenterid},
            paymentterm  => $options->{paymentterm} || 1,
            planid       => $options->{planid},
        },
        linode_update => {
            label            => $linode_label,
            lpm_displaygroup => $options->{group} ? $options->{group} : '',
        }
    };

    # Create the Linode
    my $linode_id;
    my $create_result = try {
        $linode_id = $api->linode_create(
            %{ $params->{linode_create} }
        )->{linodeid};
    };
    return $self->fail(
        action  => 'create',
        label   => $params->{linode_update}{label},
        message => "Unable to create $linode_label",
    ) unless $create_result;

    $params->{linode_update}{linodeid} = $linode_id;

    # Update Linode
    my $update_result = try {
        $api->linode_update( %{ $params->{linode_update} } );
    };
    return $self->fail(
        action  => 'create',
        label   => $$linode_label,
        message => "Unable to update $linode_label after initial creation",
    ) unless $update_result;


    # Linode is created, now make disks and configure
    $args{set_obj} = { linodeid => $linode_id };
    $self->buildrebuild( %args );

}


sub buildrebuild {
    my ( $self, %args) = @_;

    my $api     = $args{api_obj};
    my $options = $args{options};
    my $format  = $args{format};
    my $wait    = 0;

    if ( defined $options->{wait} && $options->{wait} == 0 ) {
        $wait = 5;
    } elsif ( defined $options->{wait} ) {
        $wait = $options->{wait};
    }

    my $linode_label = @{ $options->{label} }[0];
    my $linode_id    = $args{set_obj}->{linodeid};
    my $error_ins    = " Re-run with 'linode rebuild $linode_label ...'";

    # Make sure we have the root password
    if ( !exists $options->{password} && $format eq 'human' ) {
        print 'Root password for this Linode: ';
        system( 'stty', '-echo' );
        chop( $options->{password} = <STDIN> );
        system( 'stty', 'echo' );
        say '';
    } elsif ( !exists $options->{password} && $format ne 'human' ) {
        return $self->fail(
            action  => $options->{action},
            label   => $linode_label,
            message => "A root user's password is required.$error_ins",
        );
    }

    my $params = {
        linode_disk_createfromx=> {
            linodeid        => $linode_id,
            distributionid  => $options->{distributionid},
            label           => "${linode_label}-disk",
            rootpass        => $options->{password}
        },
        linode_disk_create => {
            linodeid        => $linode_id,
            label           => "${linode_label}-swap",
            type            => 'swap',
            size            => 256
        },
        linode_config_create => {
            linodeid        => $linode_id,
            kernelid        => $options->{kernelid},
            label           => "${linode_label}-config"
        }
    };


    if ( exists $options->{stackscript} ) {
        # create from stackscript args

        # stackscript ID handling
        if ( $options->{stackscript} =~ m/^\d+$/ ) { # look like an ID?
            $params->{linode_disk_createfromx}->{stackscriptid} = $options->{stackscript};
        } else {
            # If the provided is not an ID, try to match it to one of the users StackScripts
            my $objects = $api->stackscript_list();
            for my $object ( @$objects ) {
                if ( $object->{ 'label' } =~ m/$options->{stackscript}/i ) {
                    $params->{linode_disk_createfromx}->{stackscriptid} = $object->{ 'stackscriptid' };
                    last;
                }
            }
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Unable to find StackScript $options->{stackscript}.$error_ins",
            ) unless $params->{linode_disk_createfromx}->{stackscriptid};
        }

        # UDF Responses in JSON format
        if ( exists $options->{stackscriptjson} ) {
            my $jsonin = $options->{stackscriptjson};
            $jsonin =~ s/^\s+//; # remove any leading whitespace
            $jsonin =~ s/\s+$//; # remove any trailing whitespace

            if ( length($jsonin) > 1 && substr($jsonin, 0, 1) ne '{' ) {
                # assume a file path, read in the contents of the file
                if ( -e $jsonin ) {
                    $params->{linode_disk_createfromx}->{stackscriptudfresponses} = do {
                        local $/ = undef;
                        open my $fh, '<', $jsonin or do {
                            return $self->fail(
                                action  => $options->{action},
                                label   => $linode_label,
                                message => "Unable to open file '$jsonin': $!$error_ins",
                            );
                        };
                        <$fh>;
                    };
                } else {
                    return $self->fail(
                        action  => $options->{action},
                        label   => $linode_label,
                        message => "File '$jsonin' does not exist.$error_ins",
                    );
                }
            } else {
                # assume JSON
                $params->{linode_disk_createfromx}->{stackscriptudfresponses} = $jsonin;
            }
            my $test_json = try {
                decode_json( $params->{linode_disk_createfromx}->{stackscriptudfresponses} );
            };
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "The JSON provided is invalid.$error_ins",
            ) unless $test_json;

        } else {
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "StackScripts require JSON (stackscriptjson) with user defines fields.$error_ins",
            );
        }

    } else {
        # create from distribution args

        $options->{pubkeyfile}
            = glob_tilde($options->{pubkeyfile}) if $options->{pubkeyfile};

        if ( $options->{pubkeyfile} && -f $options->{pubkeyfile} ) {
            $params->{linode_disk_createfromx}->{rootsshkey} = do {
                local $/ = undef;
                open my $fh, '<', $options->{pubkeyfile} or do {
                    return $self->fail(
                        action  => $options->{action},
                        label   => $linode_label,
                        message => "Unable to open file '$options->{pubkeyfile}': $!$error_ins",
                    );
                };
                <$fh>;
            };
        }
        elsif ( $options->{pubkeyfile} ) {
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "File '$options->{pubkeyfile}' does not exist.$error_ins",
            );
        }
    }


    # Required information confirmed, now make sure Linode prepared to be rebuilt
    # 1 - Make sure Linode is powered down.
    # 2 - Remove existing disks so that we can make new ones.
    # 3 - Remove existing configurations so that we can make a new one.

    # Check status of this linode, shutdown if nessesary
    my $linode_status = $api->linode_list( linodeid => $linode_id )->[0]->{status};
    if ( $humanstatus{$linode_status} eq 'running') {
        my $stop_job;
        print "Powering down linode '$linode_label'." if ( $format eq 'human' );
        my $stop_result = try {
            $stop_job = $api->linode_shutdown( linodeid => $linode_id );
        };

        my $linode_job_result = $self->_poll_and_wait( $api, $linode_id, $stop_job->{jobid}, $format, $wait );
        return $self->fail(
            action  => $options->{action},
            label   => $linode_label,
            message => "Timed out waiting for linode to stop '$linode_label'.$error_ins."
        ) unless $linode_job_result;
    }
    # Destroy any existings disks
    my $existdisks = $api->linode_disk_list( linodeid => $linode_id );
    if ( @$existdisks != 0 ) {
        for my $eachdisk ( @$existdisks ) {

            my $disk;
            my $delete_result = try {
                print "Removing existing disk '$eachdisk->{label}'." if ( $format eq 'human' );
                $disk = $api->linode_disk_delete( linodeid => $linode_id, diskid => $eachdisk->{diskid} );
            };
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Unable to delete existing disk '$eachdisk->{label}'.$error_ins",
            ) unless $delete_result;

            my $disk_job_result = $self->_poll_and_wait( $api, $linode_id, $disk->{jobid}, $format, $wait );
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Timed out waiting for disk to delete '$eachdisk->{label}'.$error_ins."
            ) unless $disk_job_result;
        }
    }
    # Destroy any existings configs
    my $existconfigs = $api->linode_config_list( linodeid => $linode_id);
    if ( @$existconfigs != 0 ) {
        for my $eachconfig ( @$existconfigs) {
            my $delete_result = try {
                $api->linode_config_delete( linodeid => $linode_id, configid => $eachconfig->{configid} );
            };
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Unable to delete existing config $eachconfig->{label}.$error_ins",
            ) unless $delete_result;
        }
    }


    # calculate disk space
    my $linode_hd_space = $api->linode_list( linodeid => $linode_id )->[0]->{totalhd};
    $params->{linode_disk_createfromx}->{size}
        = ( $linode_hd_space - $params->{linode_disk_create}{size} );

    my @disk_list;
    my $disk = {};
    # Deploy main disk image
    my $maindisk_result = try {
        if ( exists $options->{stackscript} ) {
            $disk = $api->linode_disk_createfromstackscript(
                %{ $params->{linode_disk_createfromx} } );
        } else {
            $disk = $api->linode_disk_createfromdistribution(
                %{ $params->{linode_disk_createfromx} } );
        }
    };
    return $self->fail(
        action  => $options->{action},
        label   => $linode_label,
        message => "Unable to create primary disk image.$error_ins",
    ) unless $maindisk_result;

    push @disk_list, $disk->{diskid};

    # Deploy swap disk image
    my $swap_disk   = {};
    my $swap_result = try {
        $swap_disk = $api->linode_disk_create( %{ $params->{linode_disk_create} } );
    };
    return $self->fail(
        action  => $options->{action},
        label   => $linode_label,
        message => "Unable to create swap image.$error_ins",
    ) unless $swap_result;

    push @disk_list, $swap_disk->{diskid};

    # Create config profile
    my $config_result = try {
        $params->{linode_config_create}{disklist} = join ',', @disk_list;
        $disk = $api->linode_config_create(
            %{ $params->{linode_config_create} } );
    };
    return $self->fail(
        action  => $options->{action},
        label   => $linode_label,
        message => "Unable to create configuration profile.$error_ins",
    ) unless $config_result;

    # Boot!
    my $boot;
    my $boot_result = try {
        $boot = $api->linode_boot( linodeid => $linode_id );
    };

    return $self->fail(
        action  => $options->{action},
        label   => $linode_label,
        message => "Unable to issue boot job for $linode_label.",
    ) unless $boot_result;

    if ($wait) {
        my $boot_job_result
            = $self->_poll_and_wait( $api, $linode_id, $boot->{jobid},
            $format, $wait );

        return $self->succeed(
            action  => $options->{action},
            label   => $linode_label,
            message => "Completed. Booted $linode_label",
            payload => { jobid => $boot->{jobid}, job => 'start' },
        ) if $boot_job_result;

        return $self->fail(
            action  => $options->{action},
            label   => $linode_label,
            message => "Timed out waiting for boot to complete for $linode_label",
            payload => { jobid => $boot->{jobid}, job => 'start' },
        );
    }

    return $self->succeed(
        action  => $options->{action},
        label   => $linode_label,
        message => "Completed. Booting $linode_label.",
        payload => { jobid => $boot->{jobid}, job => 'start' },
    );

}

sub change_state {
    my ( $self, %args ) = @_;

    my $api    = $self->{_api_obj};
    my $format = $args{format};
    my $state  = $args{state};
    my $wait   = 0;

    my $map = {
        start   => [ 'Starting',   'Started' ],
        stop    => [ 'Stopping',   'Stopped' ],
        restart => [ 'Restarting', 'Restarted' ],
    };
    my $queue = {};

    if ( defined $args{wait} && $args{wait} == 0 ) {
        $wait = 5;
    }
    elsif ( defined $args{wait} ) {
        $wait = $args{wait};
    }

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
                action  => $self->{_action},
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
            action  => $self->{_action},
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
                = $self->_poll_and_wait( $api, $linode_id, $jobid, $format, $wait );

            if ( !$boot_job_result ) {
                $self->{_result} = $self->fail(
                    action  => $self->{_action},
                    label   => $linode_label,
                    message => "Unable to $state $linode_label",
                    payload => { jobid => $jobid, job => $state },
                    result  => $self->{_result},
                );
                next;
            }

            $self->{_result} = $self->succeed(
                action  => $self->{_action},
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
    my $wait    = 0;

    my $queue = {};

    if ( defined $args{wait} && $args{wait} == 0 ) {
        $wait = 20;
    }
    elsif ( defined $args{wait} ) {
        $wait = $args{wait};
    }

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
                action  => $self->{_action},
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
            action  => $self->{_action},
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
                = $self->_poll_and_wait( $api, $id, $jobid, $format, $wait);

            if ( !$job_result ) {
                $self->{_result} = $self->fail(
                    action  => $self->{_action},
                    label   => $label,
                    message => "Unable to resize and boot $label",
                    payload => { jobid => $jobid, job => 'resize' },
                    result  => $self->{_result},
                );
                next;
            }

            $self->{_result} = $self->succeed(
                action  => $self->{_action},
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
                action  => $self->{_action},
                label   => $linode_label,
                message => "Updated $linode_label",
                payload => { action => 'update' },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->fail(
                action  => $self->{_action},
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
                action  => $self->{_action},
                label   => $linode_label,
                message => "Deleted $linode_label",
                payload => { action => 'delete' },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->fail(
                action  => $self->{_action},
                label   => $linode_label,
                message => "Unable to delete $linode_label",
            );
        }
    }

    return $self->{_result};
}

sub add_ip {
    my ( $self, $args ) = @_;
    my $api = $self->{_api_obj};
    my $private = exists $args->{private} ? 1 : 0;

    for my $object ( keys %{ $self->{object} } ) {
        my $linode_id    = $self->{object}->{$object}->{linodeid};
        my $linode_label = $self->{object}->{$object}->{label};

        if (!$private) {
            $self->{_result} = $self->fail(
                action  => $self->{_action},
                label   => $linode_label,
                message => 'Adding public IPs is not yet supported',
                result  => $self->{_result},
            );
            next;
        }

        my $ip_address;
        my $add_ip_result = try {
            my $ip_id;
            if ($private) {
                $ip_id = $api->linode_ip_addprivate(
                    linodeid => $linode_id
                )->{ipaddressid};
            }
            $ip_address = $api->linode_ip_list(
                linodeid    => $linode_id,
                ipaddressid => $ip_id,
            )->[0]->{ipaddress};
        };

        if ($add_ip_result) {
            $self->{_result} = $self->succeed(
                action  => $self->{_action},
                label   => $linode_label,
                message => "Added IP $ip_address to $linode_label",
                payload => { action => 'ip-add', ipaddress => $ip_address },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->fail(
                action  => $self->{_action},
                label   => $linode_label,
                message => "Unable to add IP to $linode_label",
                result  => $self->{_result},
            );
        }
    }

    return $self->{_result};
}

sub _poll_and_wait {
    my ( $self, $api_obj, $linode_id, $job_id, $output_format, $timeout ) = @_;
    $timeout = $timeout ? ($timeout * 12) : 12;

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
