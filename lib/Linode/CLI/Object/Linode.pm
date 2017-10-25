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
        create_dt      => 'create_dt'
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
    my $out_arrayref  = [];
    my $out_hashref   = {};

    my @colw = ( 32, 14, 10, 8, 10, 10, 22 );
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
                ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . ' + ' . ( '-' x $colw[6] ) . ' +');
            push @$out_arrayref, sprintf(
                "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s | %-${colw[4]}s | %-${colw[5]}s | %-${colw[6]}s |",
                'label', 'status', 'location', 'backups', 'disk', 'ram' , 'create_dt' );
            push @$out_arrayref, (
                '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' .
                ( '-' x $colw[4] ) . ' + ' . ( '-' x $colw[5] ) . ' + ' . ( '-' x $colw[6] ) . ' |');
        }

        for my $object ( keys %{ $grouped_objects->{$group} } ) {
            if ( $output_format eq 'human' ) {
                my $line = sprintf(
                    "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s | %-${colw[4]}s | %-${colw[5]}s | %-${colw[6]}s |",
                    format_len( $grouped_objects->{$group}{$object}{label}, $colw[0] ),
                    $humanstatus{ $grouped_objects->{$group}{$object}{status} },
                    $humandc{ $grouped_objects->{$group}{$object}{datacenterid} },
                    $humanyn{ $grouped_objects->{$group}{$object}{backupsenabled} },
                    human_displaymemory( $grouped_objects->{$group}{$object}{totalhd} ),
                    human_displaymemory( $grouped_objects->{$group}{$object}{totalram} ),
                    format_len( $grouped_objects->{$group}{$object}{create_dt} ),
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
                    elsif ( $key eq 'create_dt' ) {
                        $out_hashref->{$object}{$key}
                            = $grouped_objects->{$group}{$object}{$key};
                    }
                    else {
                        $out_hashref->{$object}{$key}
                            = $grouped_objects->{$group}{$object}{$key};
                    }
                }

                $out_hashref->{$object}{group} = $group;
            }
        }

        if ($output_format eq 'human') {
            push @$out_arrayref, ( '+ ' . ( '-' x $colw[0] ) . ' + ' .
                ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) . ' + ' .
                ( '-' x $colw[3] ) . ' + ' . ( '-' x $colw[4] ) . ' + ' .
                ( '-' x $colw[5] ) . ' + ' . ( '-' x $colw[6] ) . " +\n" );
        }
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
                ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) . ' + ' .
                ( '-' x $colw[3] ) . ' + ' . ( '-' x $colw[4] ) . ' + ' .
                ( '-' x $colw[5] ) . ( '-' x $colw[6] ) . ' + ' .
                " +\n" );
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
        $return .= sprintf( "%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n%9s %-45s\n",
            'label:', $self->{object}->{$object_label}->{label},
            'status:', $humanstatus{ $self->{object}{$object_label}{status} },
            'location:', $humandc{ $self->{object}{$object_label}{datacenterid} },
            'backups:', $humanyn{ $self->{object}{$object_label}{backupsenabled} },
            'disk:',human_displaymemory( $self->{object}{$object_label}{totalhd} ),
            'ram:', human_displaymemory( $self->{object}{$object_label}{totalram} ),
            'ips:', join(' ', @ips),
            'create_dt', $self->{object}->{$object_label}->{create_dt}
        ) . "\n";
    }

    return $return;
}

sub create {
    my ( $self, %args ) = @_;

    my $api     = $args{api_obj};
    my $options = $args{options};
    my $format  = $args{format};

    my $linode_label = @{ $options->{label} }[0];

    # from distribution/image check
    if ( !exists $options->{distribution} && !exists $options->{imageid} ) {
        return $self->fail(
            action  => 'create',
            label   => $linode_label,
            message => "A distribution or an imageid must be provided.",
        );
    }

    # check if this label is already in use
    my $linodeobjects = $api->linode_list();
    for my $lobject (@$linodeobjects) {
        if ( $lobject->{label} eq $linode_label ) {
            return $self->fail(
                action  => 'create',
                label   => $linode_label,
                message => "The name $linode_label is already in use by "
                         . "another Linode.",
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
        label   => $linode_label,
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
    my $linode_disk_createtype;

    # from distribution/image check
    if ( !exists $options->{distribution} && !exists $options->{imageid} ) {
        return $self->fail(
            action  => $options->{action},
            label   => $linode_label,
            message => "A distribution or an imageid must be provided.",
        );
    }

    my $kernel = 138; #  latest 64 bit
    if ( exists $options->{kernelid} ) {
        $kernel = $options->{kernelid};
    }

    my $params = {
         linode_disk_create => {
            linodeid        => $linode_id,
            label           => "${linode_label}-swap",
            type            => 'swap',
            size            => 256
        },
        linode_config_create => {
            linodeid        => $linode_id,
            kernelid        => $kernel,
            label           => "${linode_label}-config"
        }
    };


    if ( exists $options->{imageid} ) {
        # create from image
        $linode_disk_createtype = 'linode_disk_createfromimage';

        $params->{ $linode_disk_createtype } = {
            linodeid        => $linode_id,
            imageid         => $options->{imageid}
        };
        # optional
        if ( exists $options->{password} ) {
            $params->{ $linode_disk_createtype }{rootpass} = $options->{password};
        }

    } else {
        # create from distribution or stackscript
        $linode_disk_createtype = 'linode_disk_createfromx';

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

        $params->{ $linode_disk_createtype } = {
            linodeid        => $linode_id,
            distributionid  => $options->{distributionid},
            label           => "${linode_label}-disk",
            rootpass        => $options->{password}
        };

        if ( exists $options->{stackscript} ) {
            # create from stackscript args

            # stackscript ID handling
            if ( $options->{stackscript} =~ m/^\d+$/ ) { # look like an ID?
                $params->{ $linode_disk_createtype }{stackscriptid} = $options->{stackscript};
            } else {
                # If the provided is not an ID, try to match it to one of the users StackScripts
                my $objects = $api->stackscript_list();
                for my $object ( @$objects ) {
                    if ( $object->{ 'label' } =~ m/$options->{stackscript}/i ) {
                        $params->{ $linode_disk_createtype }{stackscriptid} = $object->{ 'stackscriptid' };
                        last;
                    }
                }
                return $self->fail(
                    action  => $options->{action},
                    label   => $linode_label,
                    message => "Unable to find StackScript $options->{stackscript}."
                             . $error_ins,
                ) unless $params->{ $linode_disk_createtype }{stackscriptid};
            }

            # UDF Responses in JSON format
            if ( exists $options->{stackscriptjson} ) {
                my $jsonin = $options->{stackscriptjson};
                $jsonin =~ s/^\s+//; # remove any leading whitespace
                $jsonin =~ s/\s+$//; # remove any trailing whitespace

                if ( length($jsonin) > 1 && substr($jsonin, 0, 1) ne '{' ) {
                    # assume a file path, read in the contents of the file
                    if ( -e $jsonin ) {
                        $params->{ $linode_disk_createtype }{stackscriptudfresponses} = do {
                            local $/ = undef;
                            open my $fh, '<', $jsonin or do {
                                return $self->fail(
                                    action  => $options->{action},
                                    label   => $linode_label,
                                    message => "Unable to open file '$jsonin': $!"
                                             . $error_ins,
                                );
                            };
                            <$fh>;
                        };
                    } else {
                        return $self->fail(
                            action  => $options->{action},
                            label   => $linode_label,
                            message => "File '$jsonin' does not exist."
                                     . $error_ins,
                        );
                    }
                } else {
                    # assume JSON
                    $params->{ $linode_disk_createtype }{stackscriptudfresponses} = $jsonin;
                }
                my $test_json = try {
                    decode_json( $params->{ $linode_disk_createtype }{stackscriptudfresponses} );
                };
                return $self->fail(
                    action  => $options->{action},
                    label   => $linode_label,
                    message => "The JSON provided is invalid." . $error_ins,
                ) unless $test_json;

            } else {
                return $self->fail(
                    action  => $options->{action},
                    label   => $linode_label,
                    message => "StackScripts require JSON (stackscriptjson) with"
                             . " user defined fields." . $error_ins,
                );
            }

        }
    }

    if ( exists $options->{pubkeyfile} ) {
        $options->{pubkeyfile} = glob_tilde($options->{pubkeyfile});

        if ( $options->{pubkeyfile} && -f $options->{pubkeyfile} ) {
            $params->{ $linode_disk_createtype }->{rootsshkey} = do {
                local $/ = undef;
                open my $fh, '<', $options->{pubkeyfile} or do {
                    return $self->fail(
                        action  => $options->{action},
                        label   => $linode_label,
                        message => "Unable to open file "
                                 . "'$options->{pubkeyfile}': $!" . $error_ins,
                    );
                };
                <$fh>;
            };
        } else {
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "File '$options->{pubkeyfile}' does not exist."
                         . $error_ins,
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

        my $linode_job_result = $self->_poll_and_wait(
            $api, $linode_id, $stop_job->{jobid}, $format, $wait
        );
        return $self->fail(
            action  => $options->{action},
            label   => $linode_label,
            message => "Timed out waiting for linode to stop '$linode_label'."
                      . $error_ins,
        ) unless $linode_job_result;
    }
    # Destroy any existings disks
    my $existdisks = $api->linode_disk_list( linodeid => $linode_id );
    if ( @$existdisks != 0 ) {
        for my $eachdisk ( @$existdisks ) {

            my $disk;
            my $delete_result = try {
                if ( $format eq 'human' ) {
                    print "Removing existing disk '$eachdisk->{label}'.";
                }
                $disk = $api->linode_disk_delete(
                    linodeid => $linode_id, diskid => $eachdisk->{diskid}
                );
            };
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Unable to delete existing disk "
                          . "'$eachdisk->{label}'." . $error_ins,
            ) unless $delete_result;

            my $disk_job_result = $self->_poll_and_wait(
                $api, $linode_id, $disk->{jobid}, $format, $wait
            );
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Timed out waiting for disk to delete "
                         . "'$eachdisk->{label}'." . $error_ins,
            ) unless $disk_job_result;
        }
    }
    # Destroy any existings configs
    my $existconfigs = $api->linode_config_list( linodeid => $linode_id);
    if ( @$existconfigs != 0 ) {
        for my $eachconfig ( @$existconfigs) {
            my $delete_result = try {
                $api->linode_config_delete(
                    linodeid => $linode_id, configid => $eachconfig->{configid}
                );
            };
            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Unable to delete existing config "
                         . "$eachconfig->{label}." . $error_ins,
            ) unless $delete_result;
        }
    }


    # calculate disk space
    my $linode_hd_space = $api->linode_list( linodeid => $linode_id )->[0]->{totalhd};
    $params->{ $linode_disk_createtype }->{size}
        = ( $linode_hd_space - $params->{linode_disk_create}{size} );

    my @disk_list;
    my $disk = {};
    # Deploy main disk image
    my $maindisk_result = try {
        if ( exists $options->{imageid} ) {
            $disk = $api->linode_disk_createfromimage(
                %{ $params->{ $linode_disk_createtype } } );
        } elsif ( exists $options->{stackscript} ) {
            $disk = $api->linode_disk_createfromstackscript(
                %{ $params->{ $linode_disk_createtype } } );
        } else {
            $disk = $api->linode_disk_createfromdistribution(
                %{ $params->{ $linode_disk_createtype } } );
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
        message => "Completed. Booting $linode_label...",
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
            my $boot_job_result = $self->_poll_and_wait(
                $api, $linode_id, $jobid, $format, $wait
            );

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

        my $ip_address;
        my $add_ip_result = try {
            my $ip_id;
            if ($private) {
                $ip_id = $api->linode_ip_addprivate(
                    linodeid => $linode_id
                )->{ipaddressid};
            } else {
                $ip_id = $api->linode_ip_addpublic(
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

sub disklist {
    my ( $self, %args ) = @_;
    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_recordsarrayref = [];
    my $out_hashref = {};
    my $api_obj = $self->{_api_obj};
    my @colw = ( 48, 12, 12, 12 ); # name (disk label), diskid, type, size

    for my $object_label ( keys %{ $self->{object} } ) {
        if ( $output_format eq 'human' ) {
            my $disks = $api_obj->linode_disk_list( linodeid => $self->{object}->{$object_label}->{linodeid} );
            if ( @$disks != 0 ) {
                push @$out_recordsarrayref, (
                    "+ " . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) .
                    ' + ' . ( '-' x $colw[3] ) . ' +');
                push @$out_recordsarrayref, sprintf(
                    "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s |",
                    'name', 'diskid', 'type', 'size' );
                push @$out_recordsarrayref, (
                    '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) .
                    ' + ' . ( '-' x $colw[3] ) . ' |');
                for my $disk ( @$disks ) {
                    push @$out_recordsarrayref, sprintf(
                        "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s |",
                        format_len( $disk->{label}, $colw[0] ),
                        $disk->{diskid},
                        $disk->{type},
                        $disk->{size});
                }
                push @$out_recordsarrayref, (
                    '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) .
                    ' + ' . ( '-' x $colw[3] ) . " +\n");
            } else {
                push @$out_recordsarrayref, ("No disks to list.\n");
            }
        } else {
            # json output
            my $disks = $api_obj->linode_disk_list( linodeid => $self->{object}->{$object_label}->{linodeid} );
            if ( @$disks != 0 ) {
                for my $disk ( @$disks ) {
                    push( @{ $out_hashref->{$object_label}{disks} }, $disk);
                }
            }
        }
    }

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    } elsif ( $output_format eq 'json' ) {
       if (scalar( keys %{ $out_hashref }) > 0) {
            for my $object ( keys %$out_hashref ) {
                $self->{_result} = $self->succeed(
                    action  => $self->{_action},
                    label   => $object,
                    payload => $out_hashref->{$object},
                    result  => $self->{_result},
                    format  => $output_format,
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
                message => "No Disks to list.",
                format  => $self->{output_format},
            );
        }
    } else {
        return join("\n", @$out_arrayref, @$out_recordsarrayref);
    }
}

sub imagelist {
    my ( $self, %args ) = @_;

    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_recordsarrayref = [];
    my $out_hashref = {};
    my $api_obj = $self->{_api_obj};
    my @colw = ( 48, 12, 12, 12 ); # name (disk label), imageid, fs type, size

    if ( $output_format eq 'human' ) {
        my $images = $api_obj->image_list();
        if ( @$images != 0 ) {
            push @$out_recordsarrayref, (
                "+ " . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) .
                ' + ' . ( '-' x $colw[3] ) . ' +');
            push @$out_recordsarrayref, sprintf(
                "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s |",
                'image name', 'imageid', 'fs_type', 'size' );
            push @$out_recordsarrayref, (
                '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) .
                ' + ' . ( '-' x $colw[3] ) . ' |');
            for my $image ( @$images ) {
                push @$out_recordsarrayref, sprintf(
                    "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s |",
                    format_len( $image->{label}, $colw[0] ),
                    $image->{imageid},
                    $image->{fs_type},
                    $image->{minsize});
            }
            push @$out_recordsarrayref, (
                '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) .
                ' + ' . ( '-' x $colw[3] ) . " +\n");
        } else {
            push @$out_recordsarrayref, ("No images to list.\n");
        }
    } else {
        # json output
        $out_hashref->{images} = [];
        my $images = $api_obj->image_list();
        if ( @$images != 0 ) {
            for my $image ( @$images ) {
                push( @{ $out_hashref->{images} }, $image);
            }
        }
    }

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    } elsif ( $output_format eq 'json' ) {
        return $self->succeed(
            action  => $self->{_action},
            label   => 'youraccount',
            payload => $out_hashref,
            result  => $self->{_result},
            format  => $args{output_format}
        );
    } else {
        return join("\n", @$out_arrayref, @$out_recordsarrayref);
    }
}

sub iplist {
    my ( $self, %args ) = @_;
    my $api             = $self->{_api_obj};
    my $private         = exists $args{options}{private} ? 1 : 0;
    my $label           = $args{label};
    my $output_format   = $args{output_format} || 'human';
    my $out_arrayref    = [];
    my $out_hashref     = {};

    my @colw = ( 32, 16 );      # name (label), IP address(es)

    for my $object ( keys %{ $self->{object} } ) {
        my $linode_id    = $self->{object}{$object}{linodeid};

        my @ips = map { $_->{ipaddress} } @{$api->linode_ip_list(linodeid => $linode_id)};
        if ( $private ) {
            @ips = grep /^192\.168/, @ips;
        }

        $self->{object}{$object}{ips} = \@ips;
    }

    for my $object_label ( keys %{ $self->{object} } ) {
        my $ips = $self->{object}{$object_label}{ips};

        if ( $output_format eq 'human' ) {
            if ( @$ips != 0 ) {
                push @$out_arrayref, (
                    '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' +');
                push @$out_arrayref, sprintf(
                    "| %-${colw[0]}s | %-${colw[1]}s |",
                    'name', 'ips' );
                push @$out_arrayref, (
                    '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' +');
                for my $ip ( @$ips ) {
                    push @$out_arrayref, sprintf(
                        "| %-${colw[0]}s | %-${colw[1]}s |",
                        format_len( $object_label, $colw[0] ),
                        $ip);
                }
                push @$out_arrayref, (
                    '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . " +\n");
            }
        } else {
            # json output
            if ( @$ips != 0 ) {
                for my $ip ( @$ips ) {
                    push @{ $out_hashref->{$object_label}{ips} }, $ip;
                }
            }
        }
    }

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    } elsif ( $output_format eq 'json' ) {
        for my $object ( keys %$out_hashref ) {
            $self->{_result} = $self->succeed(
                action  => $self->{_action},
                label   => $object,
                payload => $out_hashref->{$object},
                result  => $self->{_result},
                format  => $output_format,
            );
        }
        return $self->{_result};
    } else {
        return join "\n" => @$out_arrayref;
    }
}

sub imagecreate {
    my ( $self, %args ) = @_;

    my $api_obj   = $args{api_obj};
    my $options   = $args{options};
    my $match_obj = $args{match_obj};
    my $found = 0;
    my $linode_label = $match_obj->{label};
    my $disk_name = '';

    my $wait = 0;
    if ( defined $options->{wait} && $options->{wait} == 0 ) {
        $wait = 5;
    } elsif ( defined $options->{wait} ) {
        $wait = $options->{wait};
    }

    # lookup disk
    my $disks = $api_obj->linode_disk_list( linodeid => $match_obj->{linodeid} );
    if ( @$disks != 0 ) {
        for my $disk ( @$disks ) {
            if ( $options->{diskid} eq $disk->{diskid} ) {
                $found = 1;
                last;
            }
        }
    }
    if ( !$found ) {
        return $self->fail(
            action  => $options->{action},
            label   => $linode_label,
            message => "Unable to find disk $options->{diskid}."
        );
    }

    my $params = {
        set => {
            linodeid => $match_obj->{linodeid}, diskid => $options->{diskid}
        }
    };
    # Optional parameters
    # - description
    # - label/name
    if ( exists $options->{description} ) {
        $params->{set}{description} = $options->{description};
    }
    if ( exists $options->{name} ) {
        $params->{set}{label} = $options->{name};
    }

    my $imagecreate;
    my $imagecreate_result = try {
        $imagecreate = $api_obj->linode_disk_imagize( %{ $params->{set} } );
    };

    return $self->fail(
        action  => $options->{action},
        label   => $linode_label,
        message => "Unable to create image from disk $options->{diskid}.",
        payload => { action => $options->{action} },
    ) unless $imagecreate_result;

    if ($wait) {
        say "Creating image from disk $options->{diskid}..." if ( $args{format} eq 'human' );
        my $imagecomplete_job_result
            = $self->_poll_and_wait( $api_obj, $match_obj->{linodeid}, $imagecreate->{jobid},
            $args{format}, $wait );

            return $self->succeed(
                action  => $options->{action},
                label   => $linode_label,
                message => "Imagized disk $options->{diskid}.",
                payload => { jobid => $imagecreate->{jobid}, job => $options->{action}, imageid => $imagecreate->{imageid} },
            ) if $imagecomplete_job_result;

            return $self->fail(
                action  => $options->{action},
                label   => $linode_label,
                message => "Timed out waiting for create image from disk $options->{diskid} to complete.",
                payload => { jobid => $imagecreate->{jobid}, job => $options->{action} },
            );
    }

    return $self->succeed(
        action  => $options->{action},
        label   => $linode_label,
        message => "Created image from disk $options->{diskid}.",
        payload => { jobid => $imagecreate->{jobid}, imageid => $imagecreate->{imageid} },
    );
}

sub imageupdate {
    my ( $self, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $options = $args{options};
    my $found = 0;

    # lookup image
    my $images = $api_obj->image_list();
    if ( @$images != 0 ) {
        for my $image ( @$images ) {
            if ( $options->{imageid} eq $image->{imageid} ) {
                $found = 1;
                last;
            }
        }
    }

    if ( !$found ) {
        return $self->fail(
        action  => 'image-update',
        imageid => $options->{imageid},
        message => "Unable to find Image $options->{imageid} to update."
        );
    }

    my $params = {
        set => {
            imageid => $options->{imageid}
        }
    };

    # Optional parameters
    # - description
    # - label/name
    if ( exists $options->{description} ) {
        $params->{set}{description} = $options->{description};
    }
    if ( exists $options->{name} ) {
        $params->{set}{label} = $options->{name};
    }

    my $update_result = try {
        $api_obj->image_update( %{ $params->{set} } );
    };
    if ($update_result) {
        return $self->succeed(
        action  => 'image-update',
        label   => $options->{imageid},
        message => "Updated Image $options->{imageid}.",
        payload => { action => 'image-update' },
        );
    } else {
        return $self->fail(
        action  => 'image-update',
        label   => $options->{imageid},
        message => "Unable to update Image $options->{imageid}.",
        payload => { action => 'image-update' },
        );
    }
}

sub imagedelete {
    my ( $self, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $options = $args{options};
    my $found = 0;

    # lookup image
    my $images = $api_obj->image_list();
    if ( @$images != 0 ) {
        for my $image ( @$images ) {
            if ( $options->{imageid} eq $image->{imageid} ) {
                $found = 1;
                last;
            }
        }
    }

    if ( !$found ) {
        return $self->fail(
            action  => 'image-delete',
            imageid => $options->{imageid},
            message => "Unable to find Image $options->{imageid} to delete."
        );
    }

    my $delete_result = try {
        $api_obj->image_delete( imageid => $options->{imageid} );
    };
    if ($delete_result) {
        return $self->succeed(
            action  => 'image-delete',
            label   => $options->{imageid},
            message => "Deleted Image $options->{imageid}.",
            payload => { action => 'image-delete' },
        );
    } else {
        return $self->fail(
            action  => 'image-delete',
            label   => $options->{imageid},
            message => "Unable to delete Image $options->{imageid}.",
            payload => { action => 'image-delete' },
        );
    }
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
