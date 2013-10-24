package WebService::Linode;

require 5.006000;

use warnings;
use strict;

use Carp;
use List::Util qw(first);
use WebService::Linode::Base;

our $VERSION = '0.14';
our @ISA     = ("WebService::Linode::Base");
our $AUTOLOAD;

my %validation = (
    account => {
        estimateinvoice => [ ['mode'], [qw( paymentterm linodeid planid )] ],
        info            => [ [],       [] ],
        paybalance      => [ [],       [] ],
        updatecard => [ [qw( ccexpmonth ccexpyear ccnumber )], [] ],
    },
    api => { spec => [ [], [] ], },
    avail => {
        datacenters   => [ [], [] ],
        distributions => [ [], ['distributionid'] ],
        kernels       => [ [], [ 'kernelid', 'isxen' ] ],
        linodeplans   => [ [], ['planid'] ],
        stackscripts =>
            [ [], [qw( distributionid keywords distributionvendor )] ],
    },
    domain => {
        create => [
            [ 'type', 'domain' ],
            [   qw( refresh_sec retry_sec master_ips expire_sec soa_email axfr_ips description ttl_sec status )
            ]
        ],
        delete => [ ['domainid'], [] ],
        list   => [ [],           ['domainid'] ],
        update => [
            ['domainid'],
            [   qw( refresh_sec retry_sec master_ips type expire_sec domain soa_email axfr_ips description ttl_sec status )
            ]
        ],
    },
    domain_resource => {
        create => [
            [qw( type domainid )],
            [qw( protocol name weight target priority ttl_sec port )]
        ],
        delete => [ [ 'resourceid', 'domainid' ], [] ],
        list => [ ['domainid'], ['resourceid'] ],
        update => [
            ['resourceid'],
            [qw( weight target priority ttl_sec domainid port protocol name )]
        ],
    },
    linode => {
        boot => [ ['linodeid'], ['configid'] ],
        clone => [ [qw( linodeid paymentterm datacenterid planid )], [] ],
        create => [ [qw( datacenterid planid paymentterm )], [] ],
        delete => [ ['linodeid'], ['skipchecks'] ],
        list   => [ [],           ['linodeid'] ],
        mutate => [ ['linodeid'], [] ],
        reboot => [ ['linodeid'], ['configid'] ],
        resize => [ [ 'linodeid', 'planid' ], [] ],
        shutdown => [ ['linodeid'], [] ],
        update => [
            ['linodeid'],
            [   qw( alert_diskio_threshold lpm_displaygroup watchdog alert_bwout_threshold ms_ssh_disabled ms_ssh_ip ms_ssh_user alert_bwout_enabled alert_diskio_enabled ms_ssh_port alert_bwquota_enabled alert_bwin_threshold backupweeklyday alert_cpu_enabled alert_bwquota_threshold backupwindow alert_cpu_threshold alert_bwin_enabled label )
            ]
        ],
        webconsoletoken => [ ['linodeid'], [] ],
    },
    linode_config => {
        create => [
            [qw( kernelid linodeid label )],
            [   qw( rootdevicero helper_disableupdatedb rootdevicenum comments rootdevicecustom devtmpfs_automount ramlimit runlevel helper_depmod helper_xen disklist )
            ]
        ],
        delete => [ [ 'linodeid', 'configid' ], [] ],
        list => [ ['linodeid'], ['configid'] ],
        update => [
            ['configid'],
            [   qw( helper_disableupdatedb rootdevicero comments rootdevicenum rootdevicecustom kernelid runlevel ramlimit devtmpfs_automount helper_depmod linodeid helper_xen disklist label )
            ]
        ],
    },
    linode_disk => {
        create => [ [qw( label size type linodeid )], [] ],
        createfromdistribution => [
            [qw( rootpass linodeid distributionid size label )],
            ['rootsshkey']
        ],
        createfromstackscript => [
            [   qw( size label linodeid stackscriptid distributionid rootpass stackscriptudfresponses )
            ],
            []
        ],
        delete    => [ [ 'linodeid', 'diskid' ],   [] ],
        duplicate => [ [ 'diskid',   'linodeid' ], [] ],
        list => [ ['linodeid'], ['diskid'] ],
        resize => [ [qw( diskid linodeid size )], [] ],
        update => [ ['diskid'], [qw( linodeid label isreadonly )] ],
    },
    linode_ip => {
        addprivate => [ ['linodeid'], [] ],
        list       => [ ['linodeid'], ['ipaddressid'] ],
    },
    linode_job => { list => [ ['linodeid'], [ 'pendingonly', 'jobid' ] ], },
    nodebalancer => {
        create => [
            [ 'paymentterm',        'datacenterid' ],
            [ 'clientconnthrottle', 'label' ]
        ],
        delete => [ ['nodebalancerid'], [] ],
        list   => [ [],                 ['nodebalancerid'] ],
        update => [ ['nodebalancerid'], [ 'label', 'clientconnthrottle' ] ],
    },
    nodebalancer_config => {
        create => [
            ['nodebalancerid'],
            [   qw( protocol check check_path check_interval algorithm check_attempts stickiness check_timeout check_body port )
            ]
        ],
        delete => [ ['configid'],       [] ],
        list   => [ ['nodebalancerid'], ['configid'] ],
        update => [
            ['configid'],
            [   qw( check_body stickiness check_attempts check_timeout algorithm port check protocol check_path check_interval )
            ]
        ],
    },
    nodebalancer_node => {
        create => [ [qw( label address configid )], [ 'mode', 'weight' ] ],
        delete => [ ['nodeid'],                     [] ],
        list   => [ ['configid'],                   ['nodeid'] ],
        update => [ ['nodeid'], [qw( mode label address weight )] ],
    },
    stackscript => {
        create => [
            [qw( label distributionidlist script )],
            [qw( rev_note description ispublic )]
        ],
        delete => [ ['stackscriptid'], [] ],
        list   => [ [],                ['stackscriptid'] ],
        update => [
            ['stackscriptid'],
            [   qw( distributionidlist description script ispublic rev_note label )
            ]
        ],
    },
    test => { echo => [ [], [] ], },
    user => { getapikey => [ [ 'username', 'password' ], [] ], },
);

sub AUTOLOAD {
    (my $name = $AUTOLOAD) =~ s/.+:://;
    return if $name eq 'DESTROY';
    if ($name =~ m/^(.*?)_([^_]+)$/) {
        my ($thing, $action) = ($1, $2);
        if (exists $validation{$thing} && exists $validation{$thing}{$action}) {
            no strict 'refs';
            *{ $AUTOLOAD } = sub {
                my ($self, %args) = @_;
                for my $req ( @{ $validation{$thing}{$action}[0] } ) {
                    if ( !exists $args{$req} ) {
                        carp "Missing required argument $req for ${thing}_${action}";
                        return;
                    }
                }
                for my $given ( keys %args ) {
                    if (!first { $_ eq $given }
                        @{ $validation{$thing}{$action}[0] },
                        @{ $validation{$thing}{$action}[1] } )
                    {   carp "Unknown argument $given for ${thing}_${action}";
                        return;
                    }
                }
                (my $apiAction = "${thing}_${action}") =~ s/_/./g;
                my $data = $self->do_request( api_action => $apiAction, %args);
                return [ map { $self->_lc_keys($_) } @$data ] if ref $data eq 'ARRAY';
                return $self->_lc_keys($data) if ref $data eq 'HASH';
                return $data;
            };
            goto &{ $AUTOLOAD };
        }
        else {
            carp "Can't call ${thing}_${action}";
            return;
        }
        return;
    }
    croak "Undefined subroutine \&$AUTOLOAD called";
}

sub getDomainIDbyName {
    my ($self, $name) = @_;
    foreach my $domain (@{$self->domain_list()}) {
        return $domain->{domainid} if $domain->{domain} eq $name;
    }
    return;
}

sub getDomainResourceIDbyName {
    my ( $self, %args ) = @_;
    $self->_debug( 10, 'getResourceIDbyName called' );

    my $domainid = $args{domainid};
    if ( !exists( $args{domainid} ) && exists( $args{domain} ) ) {
        $domainid = $self->getDomainIDbyName( $args{domain} );
    }

    if ( !( defined($domainid) && exists( $args{name} ) ) ) {
        $self->_error( -1,
            'Must pass domain or domainid and (resource) name to getResourceIDbyName'
        );
        return;
    }

    for my $rr ( @{ $self->domain_resource_list( domainid => $domainid ) } ) {
        return $rr->{resourceid} if $rr->{name} eq $args{name};
    }
}

'mmm, cake';
__END__

=head1 NAME

WebService::Linode - Perl Interface to the Linode.com API.

=head1 SYNOPSIS

    my $api = WebService::Linode->new( apikey => 'your api key here');
    print Dumper($api->linode_list);
    $api->linode_reboot(linodeid=>242);

This module implements the Linode.com api methods.  Linode methods have had
dots replaced with underscores to generate the perl method name.  All keys
and parameters have been lower cased but returned data remains otherwise the
same.  For additional information see L<http://www.linode.com/api/>

=head1 Methods from the Linode API

=head3 avail_stackscripts

Optional Parameters:

=over 4

=item * distributionid

=item * keywords

=item * distributionvendor

=back

=head3 avail_kernels

Optional Parameters:

=over 4

=item * kernelid

=item * isxen

=back

=head3 avail_linodeplans

Optional Parameters:

=over 4

=item * planid

=back

=head3 avail_datacenters

=head3 avail_distributions

Optional Parameters:

=over 4

=item * distributionid

=back

=head3 domain_create

Required Parameters:

=over 4

=item * type

=item * domain

=back

Optional Parameters:

=over 4

=item * refresh_sec

=item * retry_sec

=item * master_ips

=item * expire_sec

=item * soa_email

=item * axfr_ips

=item * description

=item * ttl_sec

=item * status

=back

=head3 domain_delete

Required Parameters:

=over 4

=item * domainid

=back

=head3 domain_update

Required Parameters:

=over 4

=item * domainid

=back

Optional Parameters:

=over 4

=item * refresh_sec

=item * retry_sec

=item * master_ips

=item * type

=item * expire_sec

=item * domain

=item * soa_email

=item * axfr_ips

=item * description

=item * ttl_sec

=item * status

=back

=head3 domain_list

Optional Parameters:

=over 4

=item * domainid

=back

=head3 domain_resource_create

Required Parameters:

=over 4

=item * type

=item * domainid

=back

Optional Parameters:

=over 4

=item * protocol

=item * name

=item * weight

=item * target

=item * priority

=item * ttl_sec

=item * port

=back

=head3 domain_resource_delete

Required Parameters:

=over 4

=item * resourceid

=item * domainid

=back

=head3 domain_resource_update

Required Parameters:

=over 4

=item * resourceid

=back

Optional Parameters:

=over 4

=item * weight

=item * target

=item * priority

=item * ttl_sec

=item * domainid

=item * port

=item * protocol

=item * name

=back

=head3 domain_resource_list

Required Parameters:

=over 4

=item * domainid

=back

Optional Parameters:

=over 4

=item * resourceid

=back

=head3 linode_mutate

Required Parameters:

=over 4

=item * linodeid

=back

=head3 linode_create

Required Parameters:

=over 4

=item * datacenterid

=item * planid

=item * paymentterm

=back

=head3 linode_reboot

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * configid

=back

=head3 linode_webconsoletoken

Required Parameters:

=over 4

=item * linodeid

=back

=head3 linode_boot

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * configid

=back

=head3 linode_resize

Required Parameters:

=over 4

=item * linodeid

=item * planid

=back

=head3 linode_clone

Required Parameters:

=over 4

=item * linodeid

=item * paymentterm

=item * datacenterid

=item * planid

=back

=head3 linode_shutdown

Required Parameters:

=over 4

=item * linodeid

=back

=head3 linode_delete

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * skipchecks

=back

=head3 linode_update

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * alert_diskio_threshold

=item * lpm_displaygroup

=item * watchdog

=item * alert_bwout_threshold

=item * ms_ssh_disabled

=item * ms_ssh_ip

=item * ms_ssh_user

=item * alert_bwout_enabled

=item * alert_diskio_enabled

=item * ms_ssh_port

=item * alert_bwquota_enabled

=item * alert_bwin_threshold

=item * backupweeklyday

=item * alert_cpu_enabled

=item * alert_bwquota_threshold

=item * backupwindow

=item * alert_cpu_threshold

=item * alert_bwin_enabled

=item * label

=back

=head3 linode_list

Optional Parameters:

=over 4

=item * linodeid

=back

=head3 linode_config_create

Required Parameters:

=over 4

=item * kernelid

=item * linodeid

=item * label

=back

Optional Parameters:

=over 4

=item * rootdevicero

=item * helper_disableupdatedb

=item * rootdevicenum

=item * comments

=item * rootdevicecustom

=item * devtmpfs_automount

=item * ramlimit

=item * runlevel

=item * helper_depmod

=item * helper_xen

=item * disklist

=back

=head3 linode_config_delete

Required Parameters:

=over 4

=item * linodeid

=item * configid

=back

=head3 linode_config_update

Required Parameters:

=over 4

=item * configid

=back

Optional Parameters:

=over 4

=item * helper_disableupdatedb

=item * rootdevicero

=item * comments

=item * rootdevicenum

=item * rootdevicecustom

=item * kernelid

=item * runlevel

=item * ramlimit

=item * devtmpfs_automount

=item * helper_depmod

=item * linodeid

=item * helper_xen

=item * disklist

=item * label

=back

=head3 linode_config_list

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * configid

=back

=head3 linode_disk_create

Required Parameters:

=over 4

=item * label

=item * size

=item * type

=item * linodeid

=back

=head3 linode_disk_resize

Required Parameters:

=over 4

=item * diskid

=item * linodeid

=item * size

=back

=head3 linode_disk_createfromdistribution

Required Parameters:

=over 4

=item * rootpass

=item * linodeid

=item * distributionid

=item * size

=item * label

=back

Optional Parameters:

=over 4

=item * rootsshkey

=back

=head3 linode_disk_duplicate

Required Parameters:

=over 4

=item * diskid

=item * linodeid

=back

=head3 linode_disk_delete

Required Parameters:

=over 4

=item * linodeid

=item * diskid

=back

=head3 linode_disk_update

Required Parameters:

=over 4

=item * diskid

=back

Optional Parameters:

=over 4

=item * linodeid

=item * label

=item * isreadonly

=back

=head3 linode_disk_list

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * diskid

=back

=head3 linode_disk_createfromstackscript

Required Parameters:

=over 4

=item * size

=item * label

=item * linodeid

=item * stackscriptid

=item * distributionid

=item * rootpass

=item * stackscriptudfresponses

=back

=head3 linode_ip_addprivate

Required Parameters:

=over 4

=item * linodeid

=back

=head3 linode_ip_list

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * ipaddressid

=back

=head3 linode_job_list

Required Parameters:

=over 4

=item * linodeid

=back

Optional Parameters:

=over 4

=item * pendingonly

=item * jobid

=back

=head3 stackscript_create

Required Parameters:

=over 4

=item * label

=item * distributionidlist

=item * script

=back

Optional Parameters:

=over 4

=item * rev_note

=item * description

=item * ispublic

=back

=head3 stackscript_delete

Required Parameters:

=over 4

=item * stackscriptid

=back

=head3 stackscript_update

Required Parameters:

=over 4

=item * stackscriptid

=back

Optional Parameters:

=over 4

=item * distributionidlist

=item * description

=item * script

=item * ispublic

=item * rev_note

=item * label

=back

=head3 stackscript_list

Optional Parameters:

=over 4

=item * stackscriptid

=back

=head3 nodebalancer_config_create

Required Parameters:

=over 4

=item * nodebalancerid

=back

Optional Parameters:

=over 4

=item * protocol

=item * check

=item * check_path

=item * check_interval

=item * algorithm

=item * check_attempts

=item * stickiness

=item * check_timeout

=item * check_body

=item * port

=back

=head3 nodebalancer_config_delete

Required Parameters:

=over 4

=item * configid

=back

=head3 nodebalancer_config_update

Required Parameters:

=over 4

=item * configid

=back

Optional Parameters:

=over 4

=item * check_body

=item * stickiness

=item * check_attempts

=item * check_timeout

=item * algorithm

=item * port

=item * check

=item * protocol

=item * check_path

=item * check_interval

=back

=head3 nodebalancer_config_list

Required Parameters:

=over 4

=item * nodebalancerid

=back

Optional Parameters:

=over 4

=item * configid

=back

=head3 nodebalancer_node_create

Required Parameters:

=over 4

=item * label

=item * address

=item * configid

=back

Optional Parameters:

=over 4

=item * mode

=item * weight

=back

=head3 nodebalancer_node_delete

Required Parameters:

=over 4

=item * nodeid

=back

=head3 nodebalancer_node_update

Required Parameters:

=over 4

=item * nodeid

=back

Optional Parameters:

=over 4

=item * mode

=item * label

=item * address

=item * weight

=back

=head3 nodebalancer_node_list

Required Parameters:

=over 4

=item * configid

=back

Optional Parameters:

=over 4

=item * nodeid

=back

=head3 user_getapikey

Required Parameters:

=over 4

=item * username

=item * password

=back

=head1 Additional Helper Methods

These methods are deprecated and will be going away.

=head3 getDomainIDbyName( domain => 'example.com' )

Returns the ID for a domain given the name.

=head3 getDomainResourceIDbyName( domainid => 242, name => 'www')

Takes a record name and domainid or domain and returns the resourceid.

=head1 AUTHORS

=over

=item * Michael Greb, C<< <mgreb@linode.com> >>

=item * Stan "The Man" Schwertly C<< <stan@linode.com> >>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Linode, LLC, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

