package Linode::CLI::Object::Account;

use 5.010;
use strict;
use warnings;

use parent 'Linode::CLI::Object';

use Linode::CLI::Util (qw(:basic :json));

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
    my $action = $args{action} || '';

    my $account_info = $args{object_list};
    $account_info->{label} = 'info';

    return $class->SUPER::new_from_list(
        api_obj       => $api_obj,
        action        => $action,
        object_list   => $account_info,
        field_list    => [],
        output_fields => {},
    );
}

sub list {
    my ( $self, %args ) = @_;

    my $output_format = $args{output_format} || 'human';
    my $out_hashref = {};
    my $out_arrayref = [];
    my @colw = ( 14, 18, 18, 18 );

    if ( $output_format eq 'raw' ) {
        return $out_hashref;
    }
    elsif ( $output_format eq 'human' ) {
        push @$out_arrayref, ('+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
            ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' +');
        push @$out_arrayref, sprintf(
            "| %-${colw[0]}s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s |",
            'balance', 'transfer pool', 'transfer used', 'transfer billable');
        push @$out_arrayref, ('| ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
            ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . ' |');
        push @$out_arrayref, sprintf(
            "| \$ %-" . (${colw[0]} - 2) . "s | %-${colw[1]}s | %-${colw[2]}s | %-${colw[3]}s |",
            $self->{object}{info}{balance},
            human_displaymemory( $self->{object}{info}{transfer_pool} * 1024 ),
            human_displaymemory( $self->{object}{info}{transfer_used} * 1024 ),
            human_displaymemory( $self->{object}{info}{transfer_billable} * 1024 ),
        );
        push @$out_arrayref, ('+ ' . ( '-' x $colw[0] ) . ' + ' . ( '-' x $colw[1] ) . ' + ' .
            ( '-' x $colw[2] ) . ' + ' . ( '-' x $colw[3] ) . " +\n");
        return join( "\n", @$out_arrayref );
    }
    elsif ( $output_format eq 'json' ) {
        delete $self->{object}{info}{label};
        delete $self->{object}{info}{active_since};
        return $self->succeed(
            action  => $self->{_action},
            label   => 'info',
            payload => $self->{object}{info},
        );
    }
}

sub show {
    my ( $self, %args ) = @_;

    return sprintf( "%18s %-45s\n%18s \$ %-43.2f\n%18s %-45s\n%18s %-45s\n%18s %-45s\n%18s %-45s\n",
            'managed:', $humanyn{ $self->{object}{info}{managed} },
            'balance:', $self->{object}{info}{balance},
            'transfer pool:', human_displaymemory( $self->{object}{info}{transfer_pool} * 1024 ),
            'transfer used:', human_displaymemory( $self->{object}{info}{transfer_used} * 1024 ),
            'transfer billable:', human_displaymemory( $self->{object}{info}{transfer_billable} * 1024 ),
            'billing method:', $self->{object}{info}{billing_method},
        );
}

1;
