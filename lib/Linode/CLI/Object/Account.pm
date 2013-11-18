package Linode::CLI::Object::Account;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));
use JSON;
use Try::Tiny;

sub new {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};

    return $class->new_from_list(
        api_obj     => $api_obj,
        object_list => $api_obj->account_info,
    );
}

sub new_from_list {
    my ( $class, %args ) = @_;

    my $api_obj = $args{api_obj};

    my $account_info = $args{object_list};
    $account_info->{label} = 'info';
    my $field_list = [qw(
        active_since transfer_pool transfer_used transfer_billable
        manaaged balance
    )];

    my $output_fields = {
        active_since      => 'active since',
        transfer_pool     => 'transfer pool',
        transfer_used     => 'transfer used',
        transfer_billable => 'transfer billable',
        managed           => 'managed',
        balance           => 'balance',
    };

    return $class->SUPER::new_from_list(
        api_obj       => $api_obj,
        object_list   => $account_info,
        field_list    => $field_list,
        output_fields => $output_fields,
    );
}

sub list {
    my ( $self, %args ) = @_;

    my $output_format = $args{output_format} || 'human';
    my $out_hashref = {};

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    }
    elsif ( $output_format eq 'json' ) {
        delete $self->{object}{info}{label};
        return $self->succeed(
            label   => 'info',
            payload => $self->{object}{info},
        );
    }
}

sub show {
    my ( $self, %args ) = @_;
    delete $self->{object}{info}{label};

    my $return;
    for my $key ( keys %{ $self->{object}{info} } ) {
        if ( $self->{_output_fields}{$key} =~ m/^transfer/ ) {
            $return .= sprintf( "%18s %-32s\n",
                $self->{_output_fields}{$key},
                human_displaymemory( $self->{object}{info}{$key} * 1024 ) );
        }
        elsif ( $self->{_output_fields}{$key} eq 'balance' ) {
            $return .= sprintf(
                "%18s \$ %-32.2f\n",
                $self->{_output_fields}{$key},
                $self->{object}{info}{$key} );
        }
        else {
            $return .= sprintf( "%18s %-32s\n",
                $self->{_output_fields}{$key},
                $self->{object}{info}{$key} );
        }
    }

    return $return;
}

1;
