package Linode::CLI::Object::Stackscript;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));
use Try::Tiny;

sub new {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $ss_id   = $args{stackscriptid};

    return $class->new_from_list(
        api_obj     => $api_obj,
        object_list => $api_obj->stackscript_list( stackscriptid => $ss_id ),
    );
}

sub new_from_list {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};
    my $action = $args{action} || '';

    my $stackscript_list = $args{object_list};
    my $field_list = [qw(label description created ispublic revision stackscriptid)];

    my $output_fields = {
        label         => 'label',
        description   => 'description',
        create_dt     => 'created',
        ispublic      => 'ispublic',
        rev_note      => 'revision',
        stackscriptid => 'id',
    };

    return $class->SUPER::new_from_list(
        api_obj       => $api_obj,
        action        => $action,
        object_list   => $stackscript_list,
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

    if ( $output_format eq 'human' ) {
        push @$out_arrayref, (
            ( ' ' x 4 ) . '+ ' . ( '-' x 32 ) . ' + ' . ( '-' x 10 ) . ' + ' .
            ( '-' x 10 ) . ' + ');
        push @$out_arrayref, sprintf(
            ( ' ' x 4 ) . "| %-32s | %-10s | %-10s |",
            'label', 'id', 'revision' );

        push @$out_arrayref, (
            ( ' ' x 4 ) . '| ' . ( '-' x 32 ) . ' + ' . ( '-' x 10 ) . ' + ' .
            ( '-' x 10 ) . ' | ');
    }

    for my $object ( keys %{ $self->{object}} ) {
        if ( $output_format eq 'human' ) {
            push @$out_arrayref, sprintf(
                ( ' ' x 4 )
                . "| %-32s | %-10s | %-10s |",
                $self->{object}{$object}{label},
                $self->{object}{$object}{stackscriptid},
                $self->{object}{$object}{rev_note},
            );
        }
        else {
            $out_hashref->{$object}{label}   = $self->{object}{$object}{label};
            $out_hashref->{$object}{id}      = $self->{object}{$object}{stackscriptid};
            $out_hashref->{$object}{revnote} = $self->{object}{$object}{rev_note};
        }
    }

    push @$out_arrayref, ( ( ' ' x 4 ) . '+ ' . ( '-' x 32 ) . ' + ' .
        ( '-' x 10 ) . ' + ' . ( '-' x 10 ) . " +\n" ) if ($output_format eq 'human');

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
            if ( $key eq 'ispublic' ) {
                $return .= sprintf( "\n%12s %-32s",
                    $self->{_output_fields}->{$key},
                    $humanyn{ $self->{object}->{$object_label}->{$key} }
                );
            }
            else {
                if ( $self->{object}->{$object_label}->{$key} ne '' ) {
                    $return .= sprintf( "\n%12s %-32s",
                        $self->{_output_fields}->{$key},
                        $self->{object}->{$object_label}->{$key} );
                }
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

    # Required Create parameters
    # - label
    # - distributionidlist
    # - script
    my $ss_label = $options->{label};
    # build Distribution ID List
    my $ss_distidlist = join (",", values %{ $options->{distributionid} } ); # x,y,z...
    # load in the source code from the file.
    my $ss_scriptcontents = '';
    if ( -e $options->{codefile} ) {
        open my $fh, '<', $options->{codefile} or do {
            die "CRITICAL: Unable to open $options->{codefile}.\n"; # permissions?
        };
        while ( my $eachline = <$fh> ) {
            $ss_scriptcontents .= $eachline;
        }
        close ($fh);
    } else {
        die "CRITICAL: Unable to open $options->{codefile}.\n"; # doesn't exist
    }

    my $params = {
        stackscript_create => {
            label              => $ss_label,
            distributionidlist => $ss_distidlist,
            script             => $ss_scriptcontents,
        }
    };

    # Optional Create parameters
    # - ispublic
    # - rev_note
    # - description
    if ( exists $options->{ispublic} ) {
        $params->{stackscript_create}{ispublic} = format_tf( $options->{ispublic} );
    }
    if ( exists $options->{revnote} ) {
        $params->{stackscript_create}{rev_note} = $options->{revnote};
    }
    if ( exists $options->{description} ) {
        $params->{stackscript_create}{description} = $options->{description};
    }

    # Create the Stackscript
    my $create_result = try {
        $api->stackscript_create( %{ $params->{stackscript_create} } );
    };

    if ($create_result) {
        return $self->succeed(
            action  => 'create',
            label   => $ss_label,
            message => "Created StackScript $ss_label",
            payload => { action => 'create' },
        );
    }
    else {
        return $self->fail(
            action  => 'create',
            label   => $ss_label,
            message => "Unable to create StackScript $ss_label",
            payload => { action => 'create' },
        );
    }
}

sub update {
    my ( $self, $args ) = @_;
    my $api_obj = $self->{_api_obj};

    for my $object ( keys %{ $self->{object} } ) {
        # Required Update parameters
        # - stackscriptid
        my $params = {
            stackscript_update => {
                stackscriptid      => $self->{object}->{$object}->{stackscriptid},
            }
        };

        # Optional Update parameters
        # - description
        # - distributionidlist
        # - ispublic
        # - label
        # - rev_note
        # - script
        if ( exists $args->{description} ) {
            $params->{stackscript_update}{description} = $args->{description};
        }
        if ( exists $args->{distributionid} ) {
            # x,y,z...
            $params->{stackscript_update}{distributionidlist}
                = join (",", values %{ $args->{distributionid} });
        }
        if ( exists $args->{ispublc} ) {
            $params->{stackscript_update}{ispublic} = format_tf($args->{ispublic});
        }
        if ( exists $args->{'new-label'} ) {
            $params->{stackscript_update}{label} = $args->{'new-label'};
        }
        if ( exists $args->{revnote} ) {
            $params->{stackscript_update}{rev_note} = $args->{revnote};
        }
        if ( exists $args->{codefile} ) {
            # load in the source code from the file.
            my $ss_scriptcontents = '';
            if ( exists $args->{codefile} ) {
                if ( -e $args->{codefile} ) {
                    open my $fh, '<', $args->{codefile} or do {
                        die "CRITICAL: Unable to open $args->{codefile}.\n"; # permissions?
                    };
                    while ( my $eachline = <$fh> ) {
                        $ss_scriptcontents .= $eachline;
                    }
                    close ($fh);
                } else {
                    die "CRITICAL: Unable to open $args->{codefile}.\n"; # doesn't exist
                }
            }
            $params->{stackscript_update}{script} = $ss_scriptcontents;
        }

        # Update the Stackscript
        my $update_result = try {
            $api_obj->stackscript_update( %{ $params->{stackscript_update} } );
        };

        if ($update_result) {
            $self->{_result} = $self->succeed(
                action  => $self->{_action},
                label   => $self->{object}->{$object}->{label},
                message => "Updated StackScript $self->{object}->{$object}->{label}",
                payload => { action => 'update' },
            );
        }
        else {
            $self->{_result} = $self->fail(
                action  => $self->{_action},
                label   => $self->{object}->{$object}->{label},
                message => "Unable to update StackScript $self->{object}->{$object}->{label}",
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
        my $ss_id    = $self->{object}->{$object}->{stackscriptid};
        my $ss_label = $self->{object}->{$object}->{label};

        my $delete_params = {
            stackscriptid   => $self->{object}->{$object}->{stackscriptid},
        };

        my $delete_result = try {
            $api_obj->stackscript_delete(%$delete_params);
        };

        if ($delete_result) {
            $self->{_result} = $self->succeed(
                action  => $self->{_action},
                label   => $ss_label,
                message => "Deleted $ss_label",
                payload => { action => 'delete' },
                result  => $self->{_result},
            );
        }
        else {
            $self->{_result} = $self->{_result} = $self->fail(
                action  => $self->{_action},
                label   => $ss_label,
                message => "Unable to delete $ss_label",
            );
        }
    }

    return $self->{_result};
}

1;
