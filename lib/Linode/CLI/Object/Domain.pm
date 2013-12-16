package Linode::CLI::Object::Domain;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));
use Try::Tiny;

sub new {
    my ( $class, %args ) = @_;

    my $api_obj   = $args{api_obj};
    my $domain_id = $args{domainid};

    return $class->new_from_list(
        api_obj     => $api_obj,
        object_list => $api_obj->domain_list( domainid => $domain_id ),
    );
}

sub new_from_list {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $action = $args{action} || '';

    my $domain_list = $args{object_list};
    my $field_list = [qw(domain type soa status masterips axfrips)];

    my $output_fields = {
        domain        => 'domain',
        type          => 'type',
        soa_email     => 'soa',
        status        => 'status',
        master_ips    => 'masterips',
        axfr_ips      => 'axfrips',
    };

    return $class->SUPER::new_from_list(
        api_obj       => $api_obj,
        action        => $action,
        object_list   => $domain_list,
        field_list    => $field_list,
        output_fields => $output_fields,
    );
}

sub list {
    my ( $self, %args ) = @_;
    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_recordsarrayref = [];
    my $out_hashref = {};
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};

    my $grouped_objects = {};

    my %domainstatus = (
        '0' => 'disabled',
        '1' => 'active',
        '2' => 'edit mode',
    );

    # Group into display groups
    for my $object ( keys %{ $self->{object} } ) {
        next if ( $label && $object ne $label );
        my $display_group = $self->{object}{$object}->{lpm_displaygroup};
        $grouped_objects->{$display_group}{$object}
            = $self->{object}{$object};
    }
    my $groupcount = scalar( keys %{ $grouped_objects } );
    my $groupspacer = '';
    if ( $groupcount > 1 ) {
        $groupspacer = ' + ' . ( '-' x 24 );
    }

    if ( $output_format eq 'human' ) {
        push @$out_arrayref, (
            '+ ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' + ' .
            ( '-' x 32 ) . $groupspacer . ' +');
        if ( $groupcount > 1 ) {
            push @$out_arrayref, sprintf(
                "| %-32s | %-8s | %-32s | %-24s |",
                'domain', 'type', 'soa', 'group');
        } else {
            push @$out_arrayref, sprintf(
                "| %-32s | %-8s | %-32s |",
                'domain', 'type', 'soa');
        }
        push @$out_arrayref, (
            '| ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' + ' .
            ( '-' x 32 ) . $groupspacer . ' |');
    }

    for my $group ( keys %{ $grouped_objects } ) {

        for my $object ( keys %{ $grouped_objects->{$group} } ) {
            if ( $output_format eq 'human' ) {
                if ( $groupcount > 1 ) {
                    push @$out_arrayref, sprintf(
                        "| %-32s | %-8s | %-32s | %-24s |",
                        $grouped_objects->{$group}{$object}{domain},
                        $grouped_objects->{$group}{$object}{type},
                        $grouped_objects->{$group}{$object}{soa_email},
                        $group,
                    );
                } else {
                    push @$out_arrayref, sprintf(
                        "| %-32s | %-8s | %-32s |",
                        $grouped_objects->{$group}{$object}{domain},
                        $grouped_objects->{$group}{$object}{type},
                        $grouped_objects->{$group}{$object}{soa_email},
                    );
                }
            }
            else {
                # json output
                for my $key ( keys %{ $grouped_objects->{$group}{$object} } ) {
                    next unless (
                        my @found = grep { $_ eq $key } %{ $self->{_output_fields} }
                    );
                    if ( $key eq 'status' ) {
                        $out_hashref->{$object}{$key} =  $domainstatus{
                            $grouped_objects->{$group}{$object}{$key}
                        };
                    }
                    else {
                        $out_hashref->{$object}{$key}
                            = $grouped_objects->{$group}{$object}{$key};
                    }
                }
            }
        }

    }
    push @$out_arrayref, ( '+ ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' + ' .
        ( '-' x 32 ) . $groupspacer . " +\n") if ($output_format eq 'human');

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    }
    elsif ( $output_format eq 'json' ) {
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
    }
    else {
        return join( "\n", @$out_arrayref, @$out_recordsarrayref);
    }

}

sub show {
    my ( $self, %args ) = @_;
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};

    my $return = '';

    for my $object_label ( keys %{ $self->{object} } ) {

        $return .= sprintf( "%12s %-45s\n%12s %-45s\n%12s %-45s\n%12s %-45s\n%12s %-45s\n%12s %-45s\n%12s %-45s\n%12s %-45s\n\n",
            'domain:', $self->{object}->{$object_label}->{domain},
            'type:',  $self->{object}->{$object_label}->{type},
            'soa:', $self->{object}->{$object_label}->{soa_email},
            'master ips:', $self->{object}->{$object_label}->{master_ips},
            'retry:', $self->{object}->{$object_label}->{retry_sec},
            'expire:', $self->{object}->{$object_label}->{expire_sec},
            'refresh:', $self->{object}->{$object_label}->{refresh_sec},
            'ttl:', $self->{object}->{$object_label}->{ttl_sec},
        );
    }

    return $return;
}

sub create {
    my ( $self, %args ) = @_;

    my $api     = $args{api};
    my $options = $args{options};
    my $format  = $args{format};
    my $wait    = $args{wait};

    # Required Create parameters
    # - label (domain)
    # - type
    # - email (master type only)

    my $d_label = @{ $options->{label} }[0];
    my $d_type = $options->{type} ? $options->{type} : 'master';
    my $params = {
        domain_create => {
            domain  => $d_label,
            type    => $d_type,
        }
    };

    if ( exists $options->{email} ) {
        $params->{domain_create}{soa_email} = $options->{email};
    }
    if ( $d_type eq 'master' && !exists $options->{email} ) {
        # master domains require an soa email
        return $self->fail(
            action  => 'create',
            label   => $d_label,
            message => "Master domains require an administer's email address (SOA - Start of Authority).",
        );
    }
    if ( $d_type eq 'slave' && !exists $options->{masterip} ) {
        # a slave requires master IPs
        return $self->fail(
            action  => 'create',
            label   => $d_label,
            message => "Slave domains require at least one master DNS server IP address for this zone.",
        );
    }

    # Optional Create parameters
    # - description
    # - refresh
    # - retry
    # - expire
    # - ttl
    # - group
    # - status
    # - masterip
    # - axfrip
    if ( exists $options->{description} ) {
        $params->{domain_create}{description} = $options->{description};
    }
    $params->{domain_create}{refresh_sec} = $options->{refresh} ? $options->{refresh} : '0';
    $params->{domain_create}{retry_sec}   = $options->{retry} ? $options->{retry} : '0';
    $params->{domain_create}{expire_sec}  = $options->{expire} ? $options->{expire} : '0';
    $params->{domain_create}{ttl_sec}     = $options->{ttl} ? $options->{ttl} : '0';

    if ( exists $options->{group} ) {
        $params->{domain_create}{lpm_displaygroup} = $options->{group};
    }
    if ( exists $options->{status} ) {
        if ( lc($options->{status}) eq 'disabled' || lc($options->{status}) eq 'disable') {
            $params->{domain_create}{status} = '0';
        } elsif ( $options->{status} eq 'edit' ) {
            $params->{domain_create}{status} = '2';
        } else {
            $params->{domain_create}{status} = '1'; # active
        }
    }
    if ( exists $options->{masterip} ) {
        if ( ref($options->{masterip}) eq 'ARRAY' ) {
            $params->{domain_create}{master_ips} = join (";", @{ $options->{masterip} });
        } else {
            # a seeknext read can cause a non-array scalar
            $params->{domain_create}{master_ips} = $options->{masterip};
        }
    }
    if ( exists $options->{axfrip} ) {
        $params->{domain_create}{axfr_ips} = join (";", @{ $options->{axfrip} });
    }

    # Create the Domain
    my $create_result = try {
        $api->domain_create( %{ $params->{domain_create} } );
    };

    if ($create_result) {
        return $self->succeed(
            action  => 'create',
            label   => $d_label,
            message => "Created domain $d_label",
            payload => { action => 'create' },
        );
    }
    else {
        return $self->fail(
            action  => 'create',
            label   => $d_label,
            message => "Unable to create domain $d_label",
            payload => { action => 'create' },
        );
    }
}

sub update {
    my ( $self, $args ) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object ( keys %{ $self->{object} } ) {
        # Required Update parameters
        # - domainid
        my $params = {
            domain_update => {
                domainid      => $self->{object}->{$object}->{domainid},
            }
        };

        # Optional Update parameters
        # - new-label
        # - type
        # - email (master type only)
        # - description
        # - refresh
        # - retry
        # - expire
        # - ttl
        # - group
        # - status
        # - masterip
        # - axfrip
        if ( exists $args->{'new-label'} ) {
            $params->{domain_update}{domain} = $args->{'new-label'};
        }
        if ( exists $args->{'email'} ) {
            $params->{domain_update}{soa_email} = $args->{'email'};
        }
        if ( exists $args->{'type'} ) {
            $params->{domain_update}{type} = $args->{'type'};
            if ( $args->{'type'} eq 'master' ) {
                # a master requires an soa email
                if ( !exists $args->{'email'} && $self->{object}->{$object}->{soa_email} eq '' ) {
                    return $self->fail(
                        action  => 'update',
                        label   => $self->{object}->{$object}->{domain},
                        message => "Master domains require an administer's email address (SOA - Start of Authority).",
                    );
                }
            } elsif ( $args->{'type'} eq 'slave' ) {
                # a slave requires master IPs
                if ( !exists $args->{'masterip'} && $self->{object}->{$object}->{'master_ips'} eq '' ) {
                    return $self->fail(
                        action  => 'update',
                        label   => $self->{object}->{$object}->{domain},
                        message => "Slave domains require at least one master DNS server IP address for this zone.",
                    );
                }
            }
        }
        if ( exists $args->{description} ) {
            $params->{domain_update}{description} = $args->{description};
        }
        if ( exists $args->{refresh} ) {
            $params->{domain_update}{refresh_sec} = $args->{refresh};
        }
        if ( exists $args->{retry} ) {
            $params->{domain_update}{retry_sec} = $args->{retry};
        }
        if ( exists $args->{expire} ) {
            $params->{domain_update}{expire_sec} = $args->{expire};
        }
        if ( exists $args->{ttl} ) {
            $params->{domain_update}{ttl_sec} = $args->{ttl};
        }
        if ( exists $args->{group} ) {
            $params->{domain_update}{lpm_displaygroup} = $args->{group};
        }
        if ( exists $args->{status} ) {
            if ( lc($args->{status}) eq 'disabled' || lc($args->{status}) eq 'disable') {
                $params->{domain_update}{status} = '0';
            } elsif ( $args->{status} eq 'edit' ) {
                $params->{domain_update}{status} = '2';
            } else {
                $params->{domain_update}{status} = '1'; # active
            }
        }
        if ( exists $args->{masterip} ) {
            $params->{domain_update}{master_ips} = join (";", @{ $args->{masterip} });
        }
        if ( exists $args->{axfrip} ) {
            $params->{domain_update}{axfr_ips} = join (";", @{ $args->{axfrip} });
        }

        # Update the Domain
        my $update_result = try {
            $api_obj->domain_update( %{ $params->{domain_update} } );
        };

        if ($update_result) {
            $self->{_result} = $self->succeed(
                action  => 'update',
                label   => $self->{object}->{$object}->{domain},
                message => "Updated domain $self->{object}->{$object}->{domain}",
                payload => { action => 'update' },
            );
        }
        else {
            $self->{_result} = $self->fail(
                action  => 'update',
                label   => $self->{object}->{$object}->{domain},
                message => "Unable to update domain $self->{object}->{$object}->{domain}",
                payload => { action => 'update' },
            );
        }
    }
    return $self->{_result};
}

sub delete {
    my ( $self, $args ) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object ( keys %{ $self->{object} } ) {
        my $d_id    = $self->{object}->{$object}->{domainid};
        my $d_label = $self->{object}->{$object}->{domain};

        my $delete_params = {
            domainid   => $self->{object}->{$object}->{domainid},
        };

        my $delete_result = try {
            $api_obj->domain_delete(%$delete_params);
        };

        if ($delete_result) {
            $self->{_result} = $self->succeed(
                action  => 'delete',
                label   => $d_label,
                message => "Deleted domain $d_label",
                payload => { action => 'delete' },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->fail(
                action  => 'delete',
                label   => $d_label,
                message => "Unable to delete domain $d_label",
                payload => { action => 'delete' },
            );
        }
    }

    return $self->{_result};
}

sub recordcreate {
    my ( $self, %args ) = @_;

    my $api_obj    = $args{api_obj};
    my $options    = $args{options};
    my $domain_obj = $args{domain_obj};

    my $d_id    = $domain_obj->{domainid};
    my $d_label = $domain_obj->{domain};

    my $r_type = $options->{type};
    # validate the type
    my @validtypes = ('ns', 'mx', 'a', 'aaaa', 'cname', 'txt', 'srv');
    unless (my @found = grep { $_ eq lc($options->{type}) } @validtypes) {
        return $self->fail(
            action  => 'record-create',
            label   => $d_label,
            message => "The record type must be one of the following: NS, MX, A, AAAA, CNAME, TXT, or SRV.",
        );
    }
    # Required Create parameters
    # - domainid (label/domain)
    # - type (NS, MX, A, AAAA, CNAME, TXT, or SRV)
    my $params = {
        domainr_create => {
            domainid => $d_id ,
            type     => $r_type,
        }
    };

    # Optional Create parameters
    # - name
    # - target
    # - priority
    # - weight
    # - port
    # - protocol
    # - ttl
    if ( exists $options->{name} ) {
        $params->{domainr_create}{name} = $options->{name};
    }
    if ( exists $options->{target} ) {
        $params->{domainr_create}{target} = $options->{target};
    }
    $params->{domainr_create}{priority} = $options->{priority} ? $options->{priority} : '10';
    $params->{domainr_create}{weight}   = $options->{weight} ? $options->{weight} : '5';
    $params->{domainr_create}{port}     = $options->{priority} ? $options->{port} : '80';
    $params->{domainr_create}{protocol} = $options->{protocol} ? $options->{protocol} : '';
    $params->{domainr_create}{ttl_sec}  = $options->{ttl} ? $options->{ttl} : '0';

    # Create the Domain Resource
    my $create_result = try {
        $api_obj->domain_resource_create( %{ $params->{domainr_create} } );
    };

    if ($create_result) {
        return $self->succeed(
            action  => 'record-create',
            label   => $d_label,
            message => "Created Domain Record $d_label $r_type",
            payload => { action => 'record-create' },
        );
    }
    else {
        return $self->fail(
            action  => 'record-create',
            label   => $d_label,
            message => "Unable to create Domain Record $d_label $r_type",
            payload => { action => 'record-create' },
        );
    }
}

sub recordupdate {
    my ( $self, %args ) = @_;

    my $api_obj    = $args{api_obj};
    my $options    = $args{options};
    my $domain_obj = $args{domain_obj};

    my $d_id    = $domain_obj->{domainid};
    my $d_label = $domain_obj->{domain};

    # look for record to update
    my $records = $api_obj->domain_resource_list( domainid => $d_id );
    if ( @$records != 0 ) {
        for my $record ( @$records ) {
            if ( lc($options->{type}) eq lc($record->{type}) &&
               ( lc($options->{match}) eq lc($record->{name}) || lc($options->{match}) eq lc($record->{target}) ) ) {

                # Required Update parameters
                # - domainid (label/domain)
                # - recordid
                my $params = {
                    domainr_update => {
                        domainid   => $d_id,
                        resourceid => $record->{resourceid},
                    }
                };

                # Optional Update parameters
                # - name
                # - target
                # - priority
                # - weight
                # - port
                # - protocol
                # - ttl
                if ( exists $options->{name} ) {
                    $params->{domainr_update}{name} = $options->{name};
                }
                if ( exists $options->{target} ) {
                    $params->{domainr_update}{target} = $options->{target};
                }
                if ( exists $options->{priority} ) {
                    $params->{domainr_update}{priority} = $options->{priority};
                }
                if ( exists $options->{weight} ) {
                    $params->{domainr_update}{weight} = $options->{weight};
                }
                if ( exists $options->{port} ) {
                    $params->{domainr_update}{port} = $options->{port};
                }
                if ( exists $options->{protocol} ) {
                    $params->{domainr_update}{protocol} = $options->{protocol};
                }
                if ( exists $options->{ttl} ) {
                    $params->{domainr_update}{ttl_sec} = $options->{ttl};
                }

                # Update the Domain Resource
                my $update_result = try {
                    $api_obj->domain_resource_update( %{ $params->{domainr_update} } );
                };

                if ($update_result) {
                    return $self->succeed(
                        action  => 'record-update',
                        label   => $d_label,
                        message => "Updated Domain Record $d_label $options->{type} $options->{match}",
                        payload => { action => 'record-update' },
                    );
                }
                else {
                    return $self->fail(
                        action  => 'record-update',
                        label   => $d_label,
                        message => "Unable to update Domain Record $d_label $options->{type} $options->{match}",
                        payload => { action => 'record-update' },
                    );
                }
            }
        }
    }

    return $self->fail(
        action  => 'record-update',
        label   => $d_label,
        message => "Unable to find domain record $d_label $options->{type} $options->{match}",
    );
}

sub recorddelete {
    my ( $self, %args ) = @_;

    my $api_obj    = $args{api_obj};
    my $options    = $args{options};
    my $domain_obj = $args{domain_obj};

    my $d_id    = $domain_obj->{domainid};
    my $d_label = $domain_obj->{domain};

    # look for record to destroy
    my $records = $api_obj->domain_resource_list( domainid => $d_id );
    if ( @$records != 0 ) {
        for my $record ( @$records ) {
            if ( lc($options->{type}) eq lc($record->{type}) &&
               ( lc($options->{match}) eq lc($record->{name}) || lc($options->{match}) eq lc($record->{target}) ) ) {

                my $params = {
                    domainid   => $d_id,
                    resourceid => $record->{resourceid},
                };

                my $delete_result = try {
                    $api_obj->domain_resource_delete(%$params);
                };

                if ($delete_result) {
                    return $self->succeed(
                        action  => 'record-delete',
                        label   => $d_label,
                        message => "Deleted domain record $d_label $options->{type} $options->{match}",
                        payload => { action => 'record-delete' },
                    );
                }
                else {
                    return $self->fail(
                        action  => 'record-delete',
                        label   => $d_label,
                        message => "Unable to delete domain record $d_label $options->{type} $options->{match}",
                    );
                }
            }
        }
    }

    return $self->fail(
        action  => 'record-delete',
        label   => $d_label,
        message => "Unable to find domain record $d_label $options->{type} $options->{match}",
    );
}

sub recordshow {
    my ( $self, %args ) = @_;
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};

    my $return = '';

    for my $object_label ( keys %{ $self->{object} } ) {

        $return .= sprintf( "%10s %-45s\n",
            'domain:',
            $self->{object}->{$object_label}->{domain},
        );

        my $records = $api_obj->domain_resource_list( domainid => $self->{object}->{$object_label}->{domainid} );
        if ( @$records != 0 ) {

            if ( exists $options->{type} ) { # check for a filter
                for my $record ( @$records ) {
                    if ( lc($options->{type}) eq lc($record->{type}) ) {
                        $return .= sprintf( "\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n",
                            'type:', uc($record->{type}),
                            'name:', $record->{name},
                            'target:', $record->{target},
                            'port:', $record->{port},
                            'weight:', $record->{weight},
                            'priority:',$record->{priority},
                            'ttl:',$record->{ttl_sec} );
                    }
                }
            } else {
                for my $record ( sort { uc($a->{type}) cmp uc($b->{type}) } @$records ) {
                    $return .= sprintf( "\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n%10s %-35s\n",
                        'type:', uc($record->{type}),
                        'name:', $record->{name},
                        'target:', $record->{target},
                        'port:', $record->{port},
                        'weight:', $record->{weight},
                        'priority:',$record->{priority},
                        'ttl:',$record->{ttl_sec} );
                }
            }
        }
        $return .= "\n";
    }

    return $return;
}

sub recordlist {
    my ( $self, %args ) = @_;
    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_recordsarrayref = [];
    my $out_hashref = {};
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};


    for my $object_label ( keys %{ $self->{object} } ) {
        if ( $output_format eq 'human' ) {

            # add records
            my $records = $api_obj->domain_resource_list( domainid => $self->{object}{$object_label}->{domainid} );
            if ( @$records != 0 ) {
                if ( exists $options->{type} ) { # check for a filter
                    my $out_recordsfilteredarrayref = [];
                    my $filterhits = 0;
                    for my $record ( @$records ) {
                        if ( lc($options->{type}) eq lc($record->{type}) ) {
                            push @$out_recordsfilteredarrayref, sprintf(
                                "| %-8s | %-24s | %-32s | %-8s |",
                                uc($record->{type}),
                                $record->{name},
                                $record->{target},
                                $record->{port});
                            $filterhits++;
                        }
                    }
                    if ( $filterhits > 0 ) {
                        push @$out_recordsarrayref, (
                            "Domain records for $self->{object}{$object_label}->{domain}\n+ " .
                             ( '-' x 8 ) . ' + ' . ( '-' x 24 ) . ' + ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' +');
                        push @$out_recordsarrayref, sprintf(
                            "| %-8s | %-24s | %-32s | %-8s |",
                            'type', 'name', 'target', 'port' );
                        push @$out_recordsarrayref, (
                            '| ' . ( '-' x 8 ) . ' + ' . ( '-' x 24 ) . ' + ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' |');
                        map { push @$out_recordsarrayref, $_ } @$out_recordsfilteredarrayref;
                        push @$out_recordsarrayref, (
                            '+ ' . ( '-' x 8 ) . ' + ' . ( '-' x 24 ) . ' + ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . " +\n");
                    }
                } else {
                    push @$out_recordsarrayref, (
                        "Domain records for $self->{object}{$object_label}->{domain}\n+ " .
                         ( '-' x 8 ) . ' + ' . ( '-' x 24 ) . ' + ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' +');
                    push @$out_recordsarrayref, sprintf(
                        "| %-8s | %-24s | %-32s | %-8s |",
                        'type', 'name', 'target', 'port' );
                    push @$out_recordsarrayref, (
                        '| ' . ( '-' x 8 ) . ' + ' . ( '-' x 24 ) . ' + ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . ' |');
                    for my $record ( sort { uc($a->{type}) cmp uc($b->{type}) } @$records ) {
                        push @$out_recordsarrayref, sprintf(
                            "| %-8s | %-24s | %-32s | %-8s |",
                            uc($record->{type}),
                            $record->{name},
                            $record->{target},
                            $record->{port});
                    }
                    push @$out_recordsarrayref, (
                    '+ ' . ( '-' x 8 ) . ' + ' . ( '-' x 24 ) . ' + ' . ( '-' x 32 ) . ' + ' . ( '-' x 8 ) . " +\n");
                }
            }
        }
        else {
            # json output
            $out_hashref->{$object_label}{records} = [];
            # add records
            my $records = $api_obj->domain_resource_list( domainid => $self->{object}{$object_label}->{domainid} );
            if ( @$records != 0 ) {
                if ( exists $options->{type} ) { # check for a filter
                    for my $record ( @$records ) {
                        if ( lc($options->{type}) eq lc($record->{type}) ) {
                           push( @{ $out_hashref->{$object_label}{records} }, {
                                type     => uc($record->{type}),
                                name     => $record->{name},
                                target   => $record->{target},
                                port     => $record->{port},
                                weight   => $record->{weight},
                                priority => $record->{priority},
                                ttl      => $record->{ttl_sec},
                            });
                        }
                    }
                } else {
                    for my $record ( sort { uc($a->{type}) cmp uc($b->{type}) } @$records ) {
                        # no filter, type sorted by alphabetical order
                        push( @{ $out_hashref->{$object_label}{records} }, {
                            type     => uc($record->{type}),
                            name     => $record->{name},
                            target   => $record->{target},
                            port     => $record->{port},
                            weight   => $record->{weight},
                            priority => $record->{priority},
                            ttl      => $record->{ttl_sec},
                        });
                    }
                }
            }
        }
    }

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    }
    elsif ( $output_format eq 'json' ) {
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
    }
    else {
        return join( "\n", @$out_arrayref, @$out_recordsarrayref);
    }

}

1;
