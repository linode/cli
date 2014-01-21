package Linode::CLI::Object::Nodebalancer;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));
use Try::Tiny;

sub new {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $nb_id   = $args{nodebalancerid};

    return $class->new_from_list(
        api_obj     => $api_obj,
        object_list => $api_obj->nodebalancer_list( nodebalancerid => $nb_id ),
    );
}

sub new_from_list {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $action = $args{action} || '';

    my $nodebalancer_list = $args{object_list};

    return $class->SUPER::new_from_list(
        api_obj       => $api_obj,
        action        => $action,
        object_list   => $nodebalancer_list,
        field_list    => [],
        output_fields => {},
    );
}


sub create {
    my ( $self, %args ) = @_;

    my $api     = $args{api};
    my $options = $args{options};
    my $format  = $args{format};

    # Required Create parameters
    # - label (name)
    # - datacenter
    # - paymentterm

    my $nb_label = @{ $options->{label} }[0];
    # check if this label is already in use
    my $nbobjects = $api->nodebalancer_list();
    for my $nbobject (@$nbobjects) {
        if ( $nbobject->{label} eq $nb_label ) {
            return $self->fail(
                action  => 'create',
                label   => $nb_label,
                message => "The name $nb_label is already in use by another NodeBalancer.",
            );
        }
    }

    my $params = {
        set => {
            label        => $nb_label,
            datacenterid => $options->{datacenterid},
            paymentterm  => 1
        }
    };
    if ( exists $options->{'payment-term'} ) {
        if ( $options->{'payment-term'} == 1 || $options->{'payment-term'} == 12 || $options->{'payment-term'} == 24 ) {
            $params->{set}{paymentterm} = $options->{'payment-term'};
        } else {
            return $self->fail(
                action  => 'create',
                label   => $options->{name},
                message => "Payment term must be 1, 12, or 24.",
            );
        }
    }

    # Create the NodeBalancer
    my $create_result = try {
        $api->nodebalancer_create( %{ $params->{set} } );
    };

    if ( $create_result ) {
        # Name the NodeBalancer (we are actually renaming it here)
        my $name_result = try {
            $api->nodebalancer_update( nodebalancerid => $create_result->{nodebalancerid}, label => $nb_label );
        };
        if ( $name_result ) {
            return $self->succeed(
                action  => 'create',
                label   => $nb_label,
                message => "Created NodeBalancer $nb_label",
                payload => { action => 'create' },
            );
        } else {
            return $self->fail(
                action  => 'create',
                label   => $nb_label,
                message => "NodeBalancer was created, but was given a default name.",
                payload => { action => 'create' },
            );
        }
    }
    else {
        return $self->fail(
            action  => 'create',
            label   => $nb_label,
            message => "Unable to create NodeBalancer $nb_label",
            payload => { action => 'create' },
        );
    }
}

sub update {
    # update handles both rename and throttle
    my ( $self, $args ) = @_;

    my $api_obj = $self->{_api_obj};
    my $options = $args;

    for my $object ( keys %{ $self->{object} } ) {
        my $nb_id     = $self->{object}->{$object}->{nodebalancerid};
        my $nb_label  = $self->{object}->{$object}->{label};

        my $params = {
            set => {
                nodebalancerid => $nb_id
            }
        };

        if ( $self->{_action} eq 'rename' ) {
            # check if this label is already in use
            my $nbobjects = $api_obj->nodebalancer_list();
            for my $nbobject (@$nbobjects) {
                if ( ($nbobject->{label} eq $options->{'new-label'}) && ($nb_id != $nbobject->{nodebalancerid}) ) {
                    return $self->fail(
                        action  => $self->{_action},
                        label   => $nb_label,
                        message => "The name '" . $options->{'new-label'} . "' is already in use by another NodeBalancer.",
                    );
                }
            }
            $params->{set}{label} = $options->{'new-label'};
        }

        if ( $self->{_action} eq 'throttle' ) {
            if ( $options->{connections} >= 0 && $options->{connections} <= 20 ) {
                $params->{set}{clientconnthrottle} = $options->{connections};
                $params->{set}{label} = $nb_label; # label required
            } else {
                return $self->fail(
                    action  => $self->{_action},
                    label   => $nb_label,
                    message => "Throttle connections must be 1-20.  0 to disable.",
                );
            }
        }

        # Update the NodeBalancer
        my $update_result = try {
            $api_obj->nodebalancer_update( %{ $params->{set} } );
        };

        if ( $update_result ) {
            return $self->succeed(
                action  => $self->{_action},
                label   => $nb_label,
                message => "Updated NodeBalancer $nb_label",
                payload => { action => $self->{_action} },
            );
        }
        else {
            return $self->fail(
                action  => $self->{_action},
                label   => $nb_label,
                message => "Unable to update NodeBalancer $nb_label",
                payload => { action => $self->{_action} },
            );
        }
    }
}

sub delete {
    my ( $self, $args ) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object ( keys %{ $self->{object} } ) {
        my $nb_label = $self->{object}->{$object}->{label};

        my $delete_params = {
            nodebalancerid   => $self->{object}->{$object}->{nodebalancerid},
        };

        my $delete_result = try {
            $api_obj->nodebalancer_delete(%$delete_params);
        };

        if ($delete_result) {
            $self->{_result} = $self->succeed(
                action  => 'delete',
                label   => $nb_label,
                message => "Deleted NodeBalancer $nb_label",
                payload => { action => 'delete' },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->fail(
                action  => 'delete',
                label   => $nb_label,
                message => "Unable to delete NodeBalancer $nb_label",
                payload => { action => 'delete' },
            );
        }
    }

    return $self->{_result};
}

sub list {
    my ( $self, %args ) = @_;

    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_hashref = {};
    my @colw = ( 40, 14 );

    if ( $output_format eq 'human' ) {
        push @$out_arrayref, (
            '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' +');
        push @$out_arrayref, sprintf(
            "| %-${colw[0]}s | %-${colw[1]}s |",
            'label', 'datacenter');
        push @$out_arrayref, (
            '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' |');
    }

    for my $object ( keys %{ $self->{object}} ) {
        if ( $output_format eq 'human' ) {
            push @$out_arrayref, sprintf(
                "| %-${colw[0]}s | %-${colw[1]}s |",
                format_len( $self->{object}{$object}{label}, $colw[0] ),
                $humandc{ $self->{object}{$object}{datacenterid} },
            );
        }
        else {
            $out_hashref->{$object}{label}      = $self->{object}{$object}{label},
            $out_hashref->{$object}{datacenter} = $humandc{ $self->{object}{$object}{datacenterid} },
            $out_hashref->{$object}{ipv4}       = $self->{object}{$object}{address4},
            $out_hashref->{$object}{ipv6}       = $self->{object}{$object}{address6},
            $out_hashref->{$object}{hostname}   = $self->{object}{$object}{hostname},
            $out_hashref->{$object}{throttle}   = $self->{object}{$object}{clientconnthrottle},
        }
    }

    push @$out_arrayref, ( '+ ' . ( '-' x $colw[0] ) . ' + ' .
        ( '-' x $colw[1] ) . " +\n" ) if ($output_format eq 'human');

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    }
    elsif ( $output_format eq 'json' ) {
        if ( scalar( keys %{ $out_hashref }) > 0 ) {
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
                message => "No Nodebalancers to list.",
                format  => $self->{output_format},
            );
        }
    }
    else {
        return join( "\n", @$out_arrayref );
    }

}

sub show {
    my ( $self, %args ) = @_;
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};

    my $return = '';

    for my $object_label ( keys %{ $self->{object} } ) {
        $return .= sprintf( "%11s %-50s\n%11s %-50s\n%11s %-50s\n%11s %-50s\n%11s %-50s\n%11s %-50s\n\n",
            'label:', $self->{object}->{$object_label}->{label},
            'datacenter:', $humandc{ $self->{object}->{$object_label}->{datacenterid} },
            'ipv4:', $self->{object}->{$object_label}->{address4},
            'ipv6:', $self->{object}->{$object_label}->{address6},
            'hostname:', $self->{object}->{$object_label}->{hostname},
            'throttle:', $self->{object}->{$object_label}->{clientconnthrottle},
        );
    }

    return $return;
}

sub configcreate {
    my ( $self, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $options = $args{options};
    my $set_obj = $args{set_obj};

    my $nb_id    = $set_obj->{nodebalancerid};
    my $nb_label = $set_obj->{label};

    # Required parameters
    # - nodebalancerid
    my $params = {
        set => {
            nodebalancerid => $nb_id
        }
    };

    # Optional parameters
    # - port
    # - protocol
    # - algorithm
    # - stickiness
    # - check-health
    # - check-interval
    # - check-timeout
    # - check-attempts
    # - check-path
    # - check-body
    # - ssl-cert
    # - ssl-key

    if ( exists $options->{port} ) {
        if ( $options->{port} >= 1 && $options->{port} <= 65534 ) {
            $params->{set}{port} = $options->{port};
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "The config port must be 1-65534.  Default is 80.",
            );
        }
    } else {
        $params->{set}{port} = 80; # default port
    }
    # load the configs for this nodebalancer, look for matching port to check if port is already in use
    my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $nb_id );
    if ( @$configs != 0 ) {
        for my $config ( @$configs ) {
            if ( $params->{set}{port} eq $config->{port} ) { # config match
                return $self->fail(
                    action  => 'config-create',
                    label   => $nb_label,
                    message => "Port $params->{set}{port} is already in use.",
                );
            }
        }
    }

    if ( exists $options->{protocol} ) {
        my @validchoices = ('tcp', 'http', 'https');
        if (my @found = grep { $_ eq lc($options->{protocol}) } @validchoices) {
            $params->{set}{protocol} = lc($options->{protocol});
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "Invalid protocol.  Options are 'tcp', 'http', and 'https'.",
            );
        }
    }
    if ( exists $options->{algorithm} ) {
        my @validchoices = ('roundrobin', 'leastconn', 'source');
        if (my @found = grep { $_ eq lc($options->{algorithm}) } @validchoices) {
            $params->{set}{algorithm} = lc($options->{algorithm});
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "Invalid algorithm.  Options are 'roundrobin', 'leastconn', and 'source'.",
            );
        }
    }
    if ( exists $options->{'stickiness'} ) {
        my @validchoices = ('none', 'table', 'http_cookie');
        if (my @found = grep { $_ eq lc($options->{'stickiness'}) } @validchoices) {
            $params->{set}{check} = lc($options->{'stickiness'});
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "Invalid stickiness option.  Options are 'none', 'table', and 'http_cookie'.",
            );
        }
    }
    if ( exists $options->{'check-health'} ) {
        my @validchoices = ('connection', 'http', 'http_body');
        if (my @found = grep { $_ eq lc($options->{'check-health'}) } @validchoices) {
            $params->{set}{check} = lc($options->{'check-health'});
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "Invalid health check method.  Options are 'connection', 'http', and 'http_body'.",
            );
        }
    }
    if ( exists $options->{'check-interval'} ) {
        if ( $options->{'check-interval'} >= 2 && $options->{'check-interval'} <= 3600 ) {
            $params->{set}{check_interval} = $options->{'check-interval'};
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "The check interval must be 2-3600.  Default is 5.",
            );
        }
    }
    if ( exists $options->{'check-timeout'} ) {
        if ( $options->{'check-timeout'} >= 1 && $options->{'check-timeout'} <= 30 ) {
            $params->{set}{check_timeout} = $options->{'check-timeout'};
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "The check timeout must be 1-30.  Default is 3.",
            );
        }
    }
    if ( exists $options->{'check-attempts'} ) {
        if ( $options->{'check-attempts'} >= 1 && $options->{'check-attempts'} <= 30 ) {
            $params->{set}{check_attempts} = $options->{'check-attempts'};
        } else {
            return $self->fail(
                action  => 'config-create',
                label   => $nb_label,
                message => "The check attempts must be 1-30.  Default is 2.",
            );
        }
    }
    $params->{set}{check_path} = $options->{'check-path'} if $options->{'check-path'};
    $params->{set}{check_body} = $options->{'check-body'} if $options->{'check-body'};
    $params->{set}{ssl_cert}   = $options->{'ssl-cert'} if $options->{'ssl-cert'};
    $params->{set}{ssl_key}    = $options->{'ssl-key'} if $options->{'ssl-key'};

    # Create the NodeBlanacer Node
    my $create_result = try {
        $api_obj->nodebalancer_config_create( %{ $params->{set} } );
    };

    if ($create_result) {
        return $self->succeed(
            action  => 'config-create',
            label   => $nb_label,
            message => "Created NodeBalancer config $nb_label $params->{set}{port}",
            payload => { action => 'config-create' },
        );
    }
    else {
        return $self->fail(
            action  => 'config-create',
            label   => $nb_label,
            message => "Unable to create NodeBalancer config for $nb_label",
            payload => { action => 'config-create' },
        );
    }
}

sub configupdate {
    my ( $self, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $options = $args{options};
    my $set_obj = $args{set_obj};

    my $nb_id     = $set_obj->{nodebalancerid};
    my $nb_label  = $set_obj->{label};
    my $config_id = 0;

    # Required parameters
    # - nodebalancerid
    # - port (to get the configid)

    # load the configs, look for the matching port to get the id
    my $configs = $api_obj->nodebalancer_config_list(nodebalancerid => $nb_id);
    if ( @$configs != 0 ) {
        for my $config ( @$configs ) {
            if ( $options->{port} eq $config->{port} ) {
                $config_id = $config->{configid};
                last;
            }
        }
    }
    if ( $config_id == 0 ) {
        return $self->fail(
            action  => 'config-update',
            label   => $nb_label,
            message => "Unable to find NodeBalancer config $nb_label $options->{port}"
        );
    }

    my $params = {
        set => {
            configid       => $config_id
        }
    };

    # Optional parameters
    # - new-port
    # - protocol
    # - algorithm
    # - stickiness
    # - check-health
    # - check-interval
    # - check-timeout
    # - check-attempts
    # - check-path
    # - check-body
    # - ssl-cert
    # - ssl-key

    if ( exists $options->{'new-port'} ) {
        if ( $options->{'new-port'} >= 1 && $options->{'new-port'} <= 65534 ) {
            $params->{set}{port} = $options->{'new-port'};
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "The config port must be 1-65534.  Default is 80.",
            );
        }
        # load the configs for this nodebalancer, look for matching port to check if port is already in use
        if ( @$configs != 0 ) {
            for my $config ( @$configs ) {
                if ( $params->{set}{port} eq $config->{port} ) { # config/port match
                    return $self->fail(
                        action  => 'config-update',
                        label   => $nb_label,
                        message => "Port $params->{set}{port} is already in use.",
                    );
                }
            }
        }
    }

    if ( exists $options->{protocol} ) {
        my @validchoices = ('tcp', 'http', 'https');
        if (my @found = grep { $_ eq lc($options->{protocol}) } @validchoices) {
            $params->{set}{protocol} = lc($options->{protocol});
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "Invalid protocol.  Options are 'tcp', 'http', and 'https'.",
            );
        }
    }
    if ( exists $options->{algorithm} ) {
        my @validchoices = ('roundrobin', 'leastconn', 'source');
        if (my @found = grep { $_ eq lc($options->{algorithm}) } @validchoices) {
            $params->{set}{algorithm} = lc($options->{algorithm});
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "Invalid algorithm.  Options are 'roundrobin', 'leastconn', and 'source'.",
            );
        }
    }
    if ( exists $options->{'stickiness'} ) {
        my @validchoices = ('none', 'table', 'http_cookie');
        if (my @found = grep { $_ eq lc($options->{'stickiness'}) } @validchoices) {
            $params->{set}{check} = lc($options->{'stickiness'});
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "Invalid stickiness option.  Options are 'none', 'table', and 'http_cookie'.",
            );
        }
    }
    if ( exists $options->{'check-health'} ) {
        my @validchoices = ('connection', 'http', 'http_body');
        if (my @found = grep { $_ eq lc($options->{'check-health'}) } @validchoices) {
            $params->{set}{check} = lc($options->{'check-health'});
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "Invalid health check method.  Options are 'connection', 'http', and 'http_body'.",
            );
        }
    }
    if ( exists $options->{'check-interval'} ) {
        if ( $options->{'check-interval'} >= 2 && $options->{'check-interval'} <= 3600 ) {
            $params->{set}{check_interval} = $options->{'check-interval'};
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "The check interval must be 2-3600.  Default is 5.",
            );
        }
    }
    if ( exists $options->{'check-timeout'} ) {
        if ( $options->{'check-timeout'} >= 1 && $options->{'check-timeout'} <= 30 ) {
            $params->{set}{check_timeout} = $options->{'check-timeout'};
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "The check timeout must be 1-30.  Default is 3.",
            );
        }
    }
    if ( exists $options->{'check-attempts'} ) {
        if ( $options->{'check-attempts'} >= 1 && $options->{'check-attempts'} <= 30 ) {
            $params->{set}{check_attempts} = $options->{'check-attempts'};
        } else {
            return $self->fail(
                action  => 'config-update',
                label   => $nb_label,
                message => "The check attempts must be 1-30.  Default is 2.",
            );
        }
    }
    $params->{set}{check_path} = $options->{'check-path'} if $options->{'check-path'};
    $params->{set}{check_body} = $options->{'check-body'} if $options->{'check-body'};
    $params->{set}{ssl_cert}   = $options->{'ssl-cert'} if $options->{'ssl-cert'};
    $params->{set}{ssl_key}    = $options->{'ssl-key'} if $options->{'ssl-key'};

    # Update the NodeBlanacer Config
    my $update_result = try {
        $api_obj->nodebalancer_config_update( %{ $params->{set} } );
    };

    if ($update_result) {
        return $self->succeed(
            action  => 'config-update',
            label   => $nb_label,
            message => "Updated NodeBalancer config $nb_label $options->{port}",
            payload => { action => 'config-update' },
        );
    }
    else {
        return $self->fail(
            action  => 'config-update',
            label   => $nb_label,
            message => "Unable to update NodeBalancer config $nb_label $options->{port}",
            payload => { action => 'config-update' },
        );
    }
}

sub configdelete {
    my ( $self, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $options = $args{options};
    my $nb_obj  = $args{set_obj};

    my $nb_label  = $nb_obj->{label};
    my $nb_id     = $nb_obj->{nodebalancerid};
    my $config_id = 0;

    # load the configs, look for the matching port to get the id
    my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $nb_id );
    if ( @$configs != 0 ) {
        for my $config ( @$configs ) {
            if ( $options->{port} eq $config->{port} ) {
                $config_id = $config->{configid};
                last;
            }
        }
    }

    if ( $config_id != 0 ) {
        my $delete_result = try {
            $api_obj->nodebalancer_config_delete( configid => $config_id );
        };
        if ($delete_result) {
            return $self->succeed(
                action  => 'config-delete',
                label   => $nb_label,
                message => "Deleted NodeBalancer config $nb_label $options->{port}",
                payload => { action => 'config-delete' },
            );
        } else {
            return $self->fail(
                action  => 'config-delete',
                label   => $nb_label,
                message => "Unable to delete NodeBalancer config $nb_label $options->{port}",
                payload => { action => 'config-delete' },
            );
        }
    } else {
        return $self->fail(
            action  => 'config-delete',
            label   => $nb_label,
            message => "Unable to find NodeBalancer config $nb_label $options->{port}"
        );
    }
}

sub configlist {
    my ( $self, %args ) = @_;
    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_recordsarrayref = [];
    my $out_hashref = {};
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};
    my @colw = (6, 8, 10, 11, 10); # port, protocol, algorithm, stickiness, check

    for my $object_label ( keys %{ $self->{object} } ) {

        if ( $output_format eq 'human' ) {
            push @$out_recordsarrayref, ("Configs for $object_label");
            my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $self->{object}->{$object_label}->{nodebalancerid} );
            if ( @$configs != 0 ) {
                push @$out_recordsarrayref, (
                    "+ " . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                    ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' . ( '-' x $colw[4] ) . ' +');
                push @$out_recordsarrayref, sprintf(
                    "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s | %-${colw[4]}s |",
                    'port', 'protocol', 'algorithm', 'stickiness', 'check' );
                push @$out_recordsarrayref, (
                    '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                    ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' . ( '-' x $colw[4] ) . ' |');
                for my $config ( sort { $a->{port} cmp $b->{port} } @$configs ) {
                    push @$out_recordsarrayref, sprintf(
                        "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s | %-${colw[4]}s |",
                        $config->{port},
                        $config->{protocol},
                        $config->{algorithm},
                        $config->{stickiness},
                        $config->{check});
                }
                push @$out_recordsarrayref, (
                    '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
                     ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' + ' . ( '-' x $colw[4] ) . " +\n");
            } else {
                push @$out_recordsarrayref, ("No configs to list.\n");
            }
        } else {
            # json output
            $out_hashref->{$object_label}{configs} = [];
            my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $self->{object}->{$object_label}->{nodebalancerid} );
            if ( @$configs != 0 ) {
                if ( exists $options->{port} ) { # check for a filter
                    for my $config ( @$configs ) {
                        if ( $options->{port} eq $config->{port} ) {
                            push( @{ $out_hashref->{$object_label}{configs} }, {
                                port             => $config->{port},
                                protocol         => $config->{protocol},
                                algorithm        => $config->{algorithm},
                                stickiness       => $config->{stickiness},
                                'check-health'   => $config->{check},
                                'check-interval' => $config->{check_interval},
                                'check-timeout'  => $config->{check_timeout},
                                'check-attempts' => $config->{check_attempts},
                                'check-path'     => $config->{check_path},
                                'check-body'     => $config->{check_body},
                            });
                        }
                    }
                } else {
                    for my $config ( @$configs ) {
                        push( @{ $out_hashref->{$object_label}{configs} }, {
                            port             => $config->{port},
                            protocol         => $config->{protocol},
                            algorithm        => $config->{algorithm},
                            stickiness       => $config->{stickiness},
                            'check-health'   => $config->{check},
                            'check-interval' => $config->{check_interval},
                            'check-timeout'  => $config->{check_timeout},
                            'check-attempts' => $config->{check_attempts},
                            'check-path'     => $config->{check_path},
                            'check-body'     => $config->{check_body},
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
        return join("\n", @$out_arrayref, @$out_recordsarrayref);
    }

}

sub configshow {
    my ( $self, %args ) = @_;
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};

    my $return = '';

    for my $object_label ( keys %{ $self->{object} } ) {
        # load the configs
        my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $self->{object}->{$object_label}->{nodebalancerid} );
        if ( @$configs != 0 ) {
            for my $config ( @$configs ) {
                if ( $options->{port} eq $config->{port} ) {
                    $return .= sprintf( "%15s %-55s\n%15s %-55s\n%15s %-55s\n%15s %-55s\n%15s %-55s\n%15s %-55s\n%15s %-55s\n%15s %-55s\n%15s %-55s\n%15s %-55s\n",
                        'port:', $config->{port},
                        'protocol:', $config->{protocol},
                        'algorithm:', $config->{algorithm},
                        'stickiness:', $config->{stickiness},
                        'check-health:', $config->{check},
                        'check-interval:', $config->{check_interval},
                        'check-timeout:', $config->{check_timeout},
                        'check-attempts:', $config->{check_attempts},
                        'check-path:', $config->{check_path},
                        'check-body:', $config->{check_body},
                    ) . "\n";
                    last;
                }
            }
        }
    }

    return $return;

}

sub nodecreate {
    my ( $self, %args ) = @_;

    my $api_obj   = $args{api_obj};
    my $options   = $args{options};
    my $nb_obj    = $args{set_obj};
    my $config_id = 0;

    my $nb_label = $nb_obj->{label};
    my $nb_id    = $nb_obj->{nodebalancerid};

    # load the configs, look for a nodebalancer with a matching port to get the config id
    my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $nb_id );
    if ( @$configs != 0 ) {
        for my $config ( @$configs ) {
            if ( $options->{port} eq $config->{port} ) { # config match
                $config_id = $config->{configid};
                last;
            }
        }
    }
    if ($config_id == 0) {
        return $self->fail(
            action  => 'node-create',
            label   => $nb_label,
            message => "Unable to find NodeBalancer config $nb_label $options->{port}",
        );
    }

    # Required parameters
    # - configid (via lookup)
    # - label
    # - address

    # make sure the name isn't already in use by another node
    my $nodes = $api_obj->nodebalancer_node_list( configid => $config_id );
    if ( @$nodes != 0 ) {
        for my $node ( @$nodes ) {
            if ( $options->{name} eq $node->{label} ) { # name already taken
                return $self->fail(
                    action  => 'node-create',
                    label   => $nb_label,
                    message => "The node name '$options->{name}' is already in use.",
                );
            }
        }
    }

    my $params = {
        set => {
            configid => $config_id,
            label    => $options->{name},
            address  => $options->{address},
        }
    };

    # Optional parameters
    # - weight
    # - mode
    if ( exists $options->{weight} ) {
        if ( $options->{weight} >= 1 && $options->{weight} <= 255 ) {
            $params->{set}{weight} = $options->{weight};
        } else {
            return $self->fail(
                action  => 'node-update',
                label   => $options->{name},
                message => "Load balancing weight must be 1-255.  Default is 100.",
            );
        }
    }
    if ( exists $options->{mode} ) {
        my @validchoices = ('accept', 'reject', 'drain');
        if (my @found = grep { $_ eq lc($options->{mode}) } @validchoices) {
            $params->{set}{mode} = lc($options->{mode});
        } else {
            return $self->fail(
                action  => 'node-update',
                label   => $options->{name},
                message => "Invalid mode.  Options are 'accept', 'reject', and 'drain'.",
            );
        }
    }

    # Create the NodeBalancer Node
    my $create_result = try {
        $api_obj->nodebalancer_node_create( %{ $params->{set} } );
    };

    if ($create_result) {
        return $self->succeed(
            action  => 'node-create',
            label   => $nb_label,
            message => "Created NodeBalancer node $options->{name}",
            payload => { action => 'node-create' },
        );
    }
    else {
        return $self->fail(
            action  => 'node-create',
            label   => $nb_label,
            message => "Unable to create NodeBalancer node $options->{name}",
            payload => { action => 'node-create' },
        );
    }

}

sub nodeupdate {
    my ( $self, %args ) = @_;

    my $api_obj   = $args{api_obj};
    my $options   = $args{options};
    my $nb_obj    = $args{set_obj};

    my $nb_label = $nb_obj->{label};
    my $nb_id    = $nb_obj->{nodebalancerid};
    my $node_id  = 0;
    my $nodes;

    # load the configs, look for the matching port to get the configid
    my $configs = $api_obj->nodebalancer_config_list(nodebalancerid => $nb_id);
    if ( @$configs != 0 ) {
        for my $config ( @$configs ) {
            if ( $options->{port} eq $config->{port} ) {
                $nodes = $api_obj->nodebalancer_node_list( configid => $config->{configid} );
                if ( @$nodes != 0 ) {
                    # look at the node labels to find the node id
                    for my $node ( @$nodes ) {
                        if ( $node->{label} eq $options->{name} ) {
                            $node_id = $node->{nodeid};
                            last;
                        }
                    }
                }
                last;
            }
        }
    }

    if ($node_id == 0) {
        return $self->fail(
            action  => 'node-update',
            label   => $nb_label,
            message => "Unable to find NodeBalancer node $nb_label $options->{port} $options->{name}",
        );
    }

    # Required parameters
    # - nodeid (via lookup)
    my $params = {
        set => {
            nodeid => $node_id
        }
    };

    # Optional parameters
    # - new-name (new-label)
    # - address
    # - weight
    # - mode
    if ( exists $options->{'new-name'} ) {
        # look at the node labels make sure the new name isn't already taken
        for my $node ( @$nodes ) {
            if ( ($node->{label} eq $options->{'new-name'}) && ($node_id != $node->{nodeid}) ) {
                return $self->fail(
                    action  => 'node-update',
                    label   => $nb_label,
                    message => "The node name '" . $options->{'new-name'} . "' is already in use.",
                );
            }
        }
        $params->{set}{label} = $options->{'new-name'};
    }
    if ( exists $options->{address} ) {
        $params->{set}{address} = $options->{address};
    }
    if ( exists $options->{weight} ) {
        if ( $options->{weight} >= 1 && $options->{weight} <= 255 ) {
            $params->{set}{weight} = $options->{weight};
        } else {
            return $self->fail(
                action  => 'node-update',
                label   => $options->{name},
                message => "Load balancing weight must be 1-255.  Default is 100.",
            );
        }
    }
    if ( exists $options->{mode} ) {
        my @validmodes = ('accept', 'reject', 'drain');
        if (my @found = grep { $_ eq lc($options->{mode}) } @validmodes) {
            $params->{set}{mode} = lc($options->{mode});
        } else {
            return $self->fail(
                action  => 'node-update',
                label   => $options->{name},
                message => "Invalid mode.  Options are 'accept', 'reject', and 'drain'.",
            );
        }
    }

    # Create the NodeBalancer Node
    my $update_result = try {
        $api_obj->nodebalancer_node_update( %{ $params->{set} } );
    };

    if ($update_result) {
        return $self->succeed(
            action  => 'node-update',
            label   => $options->{name},
            message => "Updated NodeBalancer node $options->{name}",
            payload => { action => 'node-update' },
        );
    }
    else {
        return $self->fail(
            action  => 'node-update',
            label   => $options->{name},
            message => "Unable to update NodeBalancer node $options->{name}",
            payload => { action => 'node-update' },
        );
    }

}

sub nodedelete {
    my ( $self, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $options = $args{options};
    my $nb_obj  = $args{set_obj};

    my $nb_label = $nb_obj->{label};
    my $nb_id    = $nb_obj->{nodebalancerid};
    my $node_id  = 0;

    # load the configs, look for the matching port to get the id
    my $configs = $api_obj->nodebalancer_config_list(nodebalancerid => $nb_id);
    if ( @$configs != 0 ) {
        for my $config ( @$configs ) {
            if ( $options->{port} eq $config->{port} ) {
                my $nodes = $api_obj->nodebalancer_node_list( configid => $config->{configid} );
                if ( @$nodes != 0 ) {
                    # look at the node labels to find the node id
                    for my $node ( @$nodes ) {
                        if ( $node->{label} eq $options->{name} ) {
                            $node_id = $node->{nodeid};
                            last;
                        }
                    }
                }
                last;
            }
        }
    }
    if ( $node_id == 0 ) {
        return $self->fail(
            action  => 'node-delete',
            label   => $nb_label,
            message => "Unable to find NodeBalancer node $nb_label $options->{port} $options->{name}"
        );
    }

    my $delete_result = try {
        $api_obj->nodebalancer_node_delete( nodeid => $node_id );
    };
    if ($delete_result) {
        return $self->succeed(
            action  => 'node-delete',
            label   => $nb_label,
            message => "Deleted NodeBalancer node $nb_label $options->{port} $options->{name}",
            payload => { action => 'node-delete' },
        );
    } else {
        return $self->fail(
            action  => 'node-delete',
            label   => $nb_label,
            message => "Unable to delete NodeBalancer node $nb_label $options->{port} $options->{name}",
            payload => { action => 'node-delete' },
        );
    }
}

sub nodelist {
    my ( $self, %args ) = @_;
    my $label         = $args{label};
    my $output_format = $args{output_format} || 'human';
    my $out_arrayref = [];
    my $out_recordsarrayref = [];
    my $out_hashref = {};
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};
    my @colw = ( 32, 12, 32 ); # name (node label), status, address

    for my $object_label ( keys %{ $self->{object} } ) {

        # load the configs, look for a nodebalancer with a matching port to get the config id
        my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $self->{object}->{$object_label}->{nodebalancerid} );
        if ( @$configs != 0 ) {
            for my $config ( @$configs ) {
                if ( $options->{port} eq $config->{port} ) { # config match
                    if ( $output_format eq 'human' ) {
                        push @$out_recordsarrayref, ("Nodes for $object_label port $options->{port}");
                        my $nodes = $api_obj->nodebalancer_node_list( configid => $config->{configid} );
                        if ( @$nodes != 0 ) {
                            push @$out_recordsarrayref, (
                                "+ " . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) . ' +');
                            push @$out_recordsarrayref, sprintf(
                                "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s |",
                                'name', 'status', 'address' );
                            push @$out_recordsarrayref, (
                                '| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) . ' |');
                            for my $node ( sort { $a->{label} cmp $b->{label} } @$nodes ) {
                                push @$out_recordsarrayref, sprintf(
                                    "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s |",
                                    format_len( $node->{label}, $colw[0] ),
                                    $node->{status},
                                    format_len( $node->{address}, $colw[2] ) );
                            }
                            push @$out_recordsarrayref, (
                                '+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' . ( '-' x $colw[2] ) . " +\n");
                        } else {
                            push @$out_recordsarrayref, ("No nodes to list.\n");
                        }
                    } else {
                        # json output
                        $out_hashref->{$object_label}{ $config->{port} }{nodes} = [];
                        my $nodes = $api_obj->nodebalancer_node_list( configid => $config->{configid} );
                        if ( @$nodes != 0 ) {
                            if ( exists $options->{name} ) { # check for a filter
                                for my $node ( @$nodes ) {
                                    if ( $options->{name} eq $node->{label} ) {
                                        push( @{ $out_hashref->{$object_label}{ $config->{port} }{nodes} }, {
                                            name    => $node->{label},
                                            address => $node->{address},
                                            status  => $node->{status},
                                            mode    => $node->{mode},
                                            weight  => $node->{weight}
                                        });
                                    }
                                }
                            } else {
                                for my $node ( @$nodes ) {
                                    push( @{ $out_hashref->{$object_label}{ $config->{port} }{nodes} }, {
                                        name    => $node->{label},
                                        address => $node->{address},
                                        status  => $node->{status},
                                        mode    => $node->{mode},
                                        weight  => $node->{weight}
                                    });
                                }
                            }
                        }
                    }
                    last;
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
        return join("\n", @$out_arrayref, @$out_recordsarrayref);
    }

}

sub nodeshow {
    my ( $self, %args ) = @_;
    my $api_obj = $self->{_api_obj};
    my $options = $args{options};

    my $return = '';

    for my $object_label ( keys %{ $self->{object} } ) {
        # load the configs, look for a nodebalancer with a matching port to get the config id
        my $configs = $api_obj->nodebalancer_config_list( nodebalancerid => $self->{object}->{$object_label}->{nodebalancerid} );
        if ( @$configs != 0 ) {
            for my $config ( @$configs ) {
                if ( $options->{port} eq $config->{port} ) {
                    my $nodes = $api_obj->nodebalancer_node_list( configid => $config->{configid} );
                    if ( @$nodes != 0 ) {
                        for my $node ( @$nodes ) {
                            if ( $options->{name} eq $node->{label} ) {
                                $return .= sprintf( "%10s %-45s\n%10s %-45s\n%10s %-45s\n%10s %-45s\n%10s %-45s\n",
                                    'name:', $node->{label},
                                    'address:', $node->{address},
                                    'status:', $node->{status},
                                    'mode:', $node->{mode},
                                    'weight:', $node->{weight}
                                ) . "\n";
                                last;
                            }
                        }
                    }
                    last;
                }
            }
        }
    }

    return $return;
}

1;
