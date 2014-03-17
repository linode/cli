package WebService::Linode;

require 5.006000;

use warnings;
use strict;

use Carp;
use List::Util qw(first);
use WebService::Linode::Base;

our $VERSION = '0.20';
our @ISA     = ("WebService::Linode::Base");
our $AUTOLOAD;

my %validation = (
    account => {
        estimateinvoice => [ [ 'mode' ], [qw( linodeid paymentterm planid )] ],
        info => [ [], [] ],
        paybalance => [ [], [] ],
        updatecard => [ [qw( ccexpmonth ccexpyear ccnumber )], [] ],
    },
    api => {
        spec => [ [], [] ],
    },
    avail => {
        datacenters => [ [], [] ],
        distributions => [ [], [ 'distributionid' ] ],
        kernels => [ [], [ 'isxen', 'kernelid' ] ],
        linodeplans => [ [], [ 'planid' ] ],
        stackscripts => [ [], [qw( distributionid distributionvendor keywords )] ],
    },
    domain => {
        create => [ [ 'domain', 'type' ], [qw( axfr_ips description expire_sec lpm_displaygroup master_ips refresh_sec retry_sec soa_email status ttl_sec )] ],
        delete => [ [ 'domainid' ], [] ],
        list => [ [], [ 'domainid' ] ],
        update => [ [ 'domainid' ], [qw( axfr_ips description domain expire_sec lpm_displaygroup master_ips refresh_sec retry_sec soa_email status ttl_sec type )] ],
    },
    domain_resource => {
        create => [ [ 'domainid', 'type' ], [qw( name port priority protocol target ttl_sec weight )] ],
        delete => [ [ 'domainid', 'resourceid' ], [] ],
        list => [ [ 'domainid' ], [ 'resourceid' ] ],
        update => [ [ 'resourceid' ], [qw( domainid name port priority protocol target ttl_sec weight )] ],
    },
    linode => {
        boot => [ [ 'linodeid' ], [ 'configid' ] ],
        clone => [ [qw( datacenterid linodeid planid )], [ 'paymentterm' ] ],
        create => [ [ 'datacenterid', 'planid' ], [ 'paymentterm' ] ],
        delete => [ [ 'linodeid' ], [ 'skipchecks' ] ],
        list => [ [], [ 'linodeid' ] ],
        mutate => [ [ 'linodeid' ], [] ],
        reboot => [ [ 'linodeid' ], [ 'configid' ] ],
        resize => [ [ 'linodeid', 'planid' ], [] ],
        shutdown => [ [ 'linodeid' ], [] ],
        update => [ [ 'linodeid' ], [qw( alert_bwin_enabled alert_bwin_threshold alert_bwout_enabled alert_bwout_threshold alert_bwquota_enabled alert_bwquota_threshold alert_cpu_enabled alert_cpu_threshold alert_diskio_enabled alert_diskio_threshold backupweeklyday backupwindow label lpm_displaygroup ms_ssh_disabled ms_ssh_ip ms_ssh_port ms_ssh_user watchdog )] ],
        webconsoletoken => [ [ 'linodeid' ], [] ],
    },
    linode_config => {
        create => [ [qw( kernelid label linodeid )], [qw( comments devtmpfs_automount disklist helper_depmod helper_disableupdatedb helper_xen ramlimit rootdevicecustom rootdevicenum rootdevicero runlevel )] ],
        delete => [ [ 'configid', 'linodeid' ], [] ],
        list => [ [ 'linodeid' ], [ 'configid' ] ],
        update => [ [ 'configid' ], [qw( comments devtmpfs_automount disklist helper_depmod helper_disableupdatedb helper_xen kernelid label linodeid ramlimit rootdevicecustom rootdevicenum rootdevicero runlevel )] ],
    },
    linode_disk => {
        create => [ [qw( label linodeid size type )], [] ],
        createfromdistribution => [ [qw( distributionid label linodeid rootpass size )], [ 'rootsshkey' ] ],
        createfromstackscript => [ [qw( distributionid label linodeid rootpass size stackscriptid stackscriptudfresponses )], [] ],
        delete => [ [ 'diskid', 'linodeid' ], [] ],
        duplicate => [ [ 'diskid', 'linodeid' ], [] ],
        list => [ [ 'linodeid' ], [ 'diskid' ] ],
        resize => [ [qw( diskid linodeid size )], [] ],
        update => [ [ 'diskid' ], [qw( isreadonly label linodeid )] ],
    },
    linode_ip => {
        addprivate => [ [ 'linodeid' ], [] ],
        addpublic => [ [ 'linodeid' ], [] ],
        list => [ [ 'linodeid' ], [ 'ipaddressid' ] ],
        swap => [ [ 'ipaddressid' ], [ 'tolinodeid', 'withipaddressid' ] ],
    },
    linode_job => {
        list => [ [ 'linodeid' ], [ 'jobid', 'pendingonly' ] ],
    },
    nodebalancer => {
        create => [ [ 'datacenterid', 'paymentterm' ], [ 'clientconnthrottle', 'label' ] ],
        delete => [ [ 'nodebalancerid' ], [] ],
        list => [ [], [ 'nodebalancerid' ] ],
        update => [ [ 'nodebalancerid' ], [ 'clientconnthrottle', 'label' ] ],
    },
    nodebalancer_config => {
        create => [ [ 'nodebalancerid' ], [qw( algorithm check check_attempts check_body check_interval check_path check_timeout port protocol ssl_cert ssl_key stickiness )] ],
        delete => [ [ 'configid', 'nodebalancerid' ], [] ],
        list => [ [ 'nodebalancerid' ], [ 'configid' ] ],
        update => [ [ 'configid' ], [qw( algorithm check check_attempts check_body check_interval check_path check_timeout port protocol ssl_cert ssl_key stickiness )] ],
    },
    nodebalancer_node => {
        create => [ [qw( address configid label )], [ 'mode', 'weight' ] ],
        delete => [ [ 'nodeid' ], [] ],
        list => [ [ 'configid' ], [ 'nodeid' ] ],
        update => [ [ 'nodeid' ], [qw( address label mode weight )] ],
    },
    stackscript => {
        create => [ [qw( distributionidlist label script )], [qw( description ispublic rev_note )] ],
        delete => [ [ 'stackscriptid' ], [] ],
        list => [ [], [ 'stackscriptid' ] ],
        update => [ [ 'stackscriptid' ], [qw( description distributionidlist ispublic label rev_note script )] ],
    },
    test => {
        echo => [ [], [] ],
    },
    user => {
        getapikey => [ [ 'password', 'username' ], [qw( expires label token )] ],
    },
);

sub AUTOLOAD {
    ( my $name = $AUTOLOAD ) =~ s/.+:://;
    return if $name eq 'DESTROY';
    if ( $name =~ m/^(.*?)_([^_]+)$/ ) {
        my ( $thing, $action ) = ( $1, $2 );
        if ( exists $validation{$thing} && exists $validation{$thing}{$action} )
        {   no strict 'refs';
            *{$AUTOLOAD} = sub {
                my ( $self, %args ) = @_;
                for my $req ( @{ $validation{$thing}{$action}[0] } ) {
                    if ( !exists $args{$req} ) {
                        carp
                            "Missing required argument $req for ${thing}_${action}";
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
                ( my $apiAction = "${thing}_${action}" ) =~ s/_/./g;
                my $data = $self->do_request( api_action => $apiAction, %args );
                return [ map { $self->_lc_keys($_) } @$data ]
                    if ref $data eq 'ARRAY';
                return $self->_lc_keys($data) if ref $data eq 'HASH';
                return $data;
            };
            goto &{$AUTOLOAD};
        }
        else {
            carp "Can't call ${thing}_${action}";
            return;
        }
        return;
    }
    croak "Undefined subroutine \&$AUTOLOAD called";
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

=head1 Constructor

For documentation of possible arguments to the constructor, see
L<WebService::Linode::Base>.

=head1 Methods from the Linode API

=head3 avail_stackscripts

Optional Parameters:

=over 4

=item * distributionid

=item * distributionvendor

=item * keywords

=back

=head3 avail_kernels

Optional Parameters:

=over 4

=item * isxen

=item * kernelid

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

=item * domain

=item * type

=back

Optional Parameters:

=over 4

=item * axfr_ips

=item * description

=item * expire_sec

=item * lpm_displaygroup

=item * master_ips

=item * refresh_sec

=item * retry_sec

=item * soa_email

=item * status

=item * ttl_sec

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

=item * axfr_ips

=item * description

=item * domain

=item * expire_sec

=item * lpm_displaygroup

=item * master_ips

=item * refresh_sec

=item * retry_sec

=item * soa_email

=item * status

=item * ttl_sec

=item * type

=back

=head3 domain_list

Optional Parameters:

=over 4

=item * domainid

=back

=head3 domain_resource_create

Required Parameters:

=over 4

=item * domainid

=item * type

=back

Optional Parameters:

=over 4

=item * name

=item * port

=item * priority

=item * protocol

=item * target

=item * ttl_sec

=item * weight

=back

=head3 domain_resource_delete

Required Parameters:

=over 4

=item * domainid

=item * resourceid

=back

=head3 domain_resource_update

Required Parameters:

=over 4

=item * resourceid

=back

Optional Parameters:

=over 4

=item * domainid

=item * name

=item * port

=item * priority

=item * protocol

=item * target

=item * ttl_sec

=item * weight

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

=back

Optional Parameters:

=over 4

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

=item * datacenterid

=item * linodeid

=item * planid

=back

Optional Parameters:

=over 4

=item * paymentterm

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

=item * alert_bwin_enabled

=item * alert_bwin_threshold

=item * alert_bwout_enabled

=item * alert_bwout_threshold

=item * alert_bwquota_enabled

=item * alert_bwquota_threshold

=item * alert_cpu_enabled

=item * alert_cpu_threshold

=item * alert_diskio_enabled

=item * alert_diskio_threshold

=item * backupweeklyday

=item * backupwindow

=item * label

=item * lpm_displaygroup

=item * ms_ssh_disabled

=item * ms_ssh_ip

=item * ms_ssh_port

=item * ms_ssh_user

=item * watchdog

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

=item * label

=item * linodeid

=back

Optional Parameters:

=over 4

=item * comments

=item * devtmpfs_automount

=item * disklist

=item * helper_depmod

=item * helper_disableupdatedb

=item * helper_xen

=item * ramlimit

=item * rootdevicecustom

=item * rootdevicenum

=item * rootdevicero

=item * runlevel

=back

=head3 linode_config_delete

Required Parameters:

=over 4

=item * configid

=item * linodeid

=back

=head3 linode_config_update

Required Parameters:

=over 4

=item * configid

=back

Optional Parameters:

=over 4

=item * comments

=item * devtmpfs_automount

=item * disklist

=item * helper_depmod

=item * helper_disableupdatedb

=item * helper_xen

=item * kernelid

=item * label

=item * linodeid

=item * ramlimit

=item * rootdevicecustom

=item * rootdevicenum

=item * rootdevicero

=item * runlevel

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

=item * linodeid

=item * size

=item * type

=back

=head3 linode_disk_createfromstackscript

Required Parameters:

=over 4

=item * distributionid

=item * label

=item * linodeid

=item * rootpass

=item * size

=item * stackscriptid

=item * stackscriptudfresponses

=back

=head3 linode_disk_createfromdistribution

Required Parameters:

=over 4

=item * distributionid

=item * label

=item * linodeid

=item * rootpass

=item * size

=back

Optional Parameters:

=over 4

=item * rootsshkey

=back

=head3 linode_disk_resize

Required Parameters:

=over 4

=item * diskid

=item * linodeid

=item * size

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

=item * diskid

=item * linodeid

=back

=head3 linode_disk_update

Required Parameters:

=over 4

=item * diskid

=back

Optional Parameters:

=over 4

=item * isreadonly

=item * label

=item * linodeid

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

=head3 linode_ip_swap

Required Parameters:

=over 4

=item * ipaddressid

=back

Optional Parameters:

=over 4

=item * tolinodeid

=item * withipaddressid

=back

=head3 linode_ip_addprivate

Required Parameters:

=over 4

=item * linodeid

=back

=head3 linode_ip_addpublic

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

=item * jobid

=item * pendingonly

=back

=head3 stackscript_create

Required Parameters:

=over 4

=item * distributionidlist

=item * label

=item * script

=back

Optional Parameters:

=over 4

=item * description

=item * ispublic

=item * rev_note

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

=item * description

=item * distributionidlist

=item * ispublic

=item * label

=item * rev_note

=item * script

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

=item * algorithm

=item * check

=item * check_attempts

=item * check_body

=item * check_interval

=item * check_path

=item * check_timeout

=item * port

=item * protocol

=item * ssl_cert

=item * ssl_key

=item * stickiness

=back

=head3 nodebalancer_config_delete

Required Parameters:

=over 4

=item * configid

=item * nodebalancerid

=back

=head3 nodebalancer_config_update

Required Parameters:

=over 4

=item * configid

=back

Optional Parameters:

=over 4

=item * algorithm

=item * check

=item * check_attempts

=item * check_body

=item * check_interval

=item * check_path

=item * check_timeout

=item * port

=item * protocol

=item * ssl_cert

=item * ssl_key

=item * stickiness

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

=item * address

=item * configid

=item * label

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

=item * address

=item * label

=item * mode

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

=item * password

=item * username

=back

Optional Parameters:

=over 4

=item * expires

=item * label

=item * token

=back

=head1 AUTHORS

=over

=item * Michael Greb, C<< <mgreb@linode.com> >>

=item * Stan "The Man" Schwertly C<< <stan@linode.com> >>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Linode, LLC, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

