package Linode::CLI::Object;

use 5.010;
use strict;
use warnings;

use Linode::CLI::Util (qw(:basic :json));
use Try::Tiny;

sub new {
    my ( $class, $attrs ) = @_;

    my $self = bless {}, $class;

    my $label = delete $attrs->{label};
    $self->{object}->{$label} = {};

    for my $attr ( keys %$attrs ) {
        $self->{object}->{$label}->{$attr} = $attrs->{$attr};
    }

    return $self;
}

sub new_from_list {
    my ( $class, %args ) = @_;

    my $self = bless {}, $class;
    my $object_list = [];

    ref($args{object_list}) eq 'ARRAY'
    ? $object_list = $args{object_list}
    : push @$object_list, $args{object_list};

    for my $object_item (@$object_list) {
        my $object_label = $object_item->{label} || $object_item->{abbr};
        $self->{object}->{$object_label} = $object_item;
    }

    $self->{_api_obj}       = $args{api_obj};
    $self->{_field_list}    = $args{field_list};
    $self->{_output_fields} = $args{output_fields};
    $self->{_result}        = {};

    return $self;
}

# sub list {
#     my ( $self, %args ) = @_;
#     my $label         = $args{label}         || 0;
#     my $output_format = $args{output_format} || 'human';
#     my $out_hashref;

#     for my $object_label ( keys %{ $self->{object} } ) {
#         next if ( $label && $object_label ne $label );
#         for my $key ( keys %{ $self->{object}->{$object_label} } ) {
#             $out_hashref->{$object_label}->{$key}
#                 = $self->{object}->{$object_label}->{$key};
#         }
#     }

#     return
#           $args{output_format} eq 'raw'  ? $out_hashref
#         : $args{output_format} eq 'json' ? json_response($out_hashref)
#         : 'Not implemented.';
# }

sub show {
    my ( $self, $label ) = @_;
    $label ||= 0;

    my $return = ( '=' x 72 );
    for my $object_label ( keys %{ $self->{object} } ) {
        next if ( $label && $object_label ne $label );
        for my $key ( keys %{ $self->{object}->{$object_label} } ) {
            $return .= sprintf( "\n%24s %-32s",
                $key, $self->{object}->{$object_label}->{$key} );
        }

        $return .= "\n";
    }

    return $return . ( '=' x 72 ) . "\n";
}

1;
