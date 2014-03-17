package WebService::Linode::DNS;

use strict;
use warnings;

use Carp;
use WebService::Linode::Base;

=head1 NAME

WebService::Linode::DNS - Deprecated Perl Interface to the Linode.com API DNS methods.

=cut

our $VERSION = '0.20';
our @ISA = ("WebService::Linode::Base");

sub getDomainIDbyName {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my $self = shift;
	my $name = shift;
	$self->_debug(10, 'getDomainIDbyName called for: ' . $name);

	if ($self->{_nocache}) {
		$self->_debug(10, 'Cache disabled calling domainList');
		my $domains = $self->domainList();
		foreach my $domain (@$domains) {
			return $domain->{domainid} if $domain->{domain} eq $name;
		}
	}
	else {
		$self->domainList unless exists($self->{_domains}{$name});
		return $self->{_domains}{$name} if exists($self->{_domains}{$name});
	}

	return;
}

sub domainList {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my $self = shift;
	$self->_debug(10, 'domainList called');

	my $data = $self->do_request( api_action => 'domain.list' );
	if (defined($data)) {
		my @domains;
		for my $domain (@$data) {
			# lower case the keys (they come all caps)
			my $domain_data = $self->_lc_keys($domain);
			# store zone id in $self->{_domains}{[name]}
			$self->{_domains}{$domain_data->{domain}} = 
				$domain_data->{domainid} unless $self->{_nocache};
			push @domains, $domain_data;
		}
		return \@domains;
	}
	return;
}

sub domainGet {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainGet called');
	my $domainid;

	if ($args{domain}) {
		$domainid = $self->getDomainIDbyName($args{domain});
		$self->_error(-1, "$args{domain} not found") unless $domainid;
		return unless $domainid;
	}
	else {
		$domainid = $args{domainid}
	}

	unless (defined ($domainid)) {
		$self->_error(-1, 'Must pass domainid or domain to domainGet');
		return;
	}

	my $data = $self->do_request(
		api_action => 'domain.list', domainid => $domainid
	);

	return $self->_lc_keys(@$data);
}

sub domainCreate {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainCreate called');

	my $data = $self->do_request( api_action => 'domain.create', %args);

	return unless exists ($data->{DomainID});
	return $data->{DomainID};
}

sub domainSave {
    carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
    my ($self, %args) = @_;
    carp "Deprecated use of domainSave, use domainCreate";
    return $self->domainCreate(%args);
}

sub domainUpdate {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainUpdate called');

	if (!exists ($args{domainid})) {
		$self->_error(-1, "Must pass domainid to domainUpdate");
		return;
	}

	my %data = %{ $self->domainGet(domainid => $args{domainid}) };

	# overwrite changed items
	$data{$_} = $args{$_} for keys (%args);


    return $self->do_request( api_action => 'domain.update', %args);
}

sub domainDelete {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainDelete called');

	if (!exists ($args{domainid})) {
		$self->_error(-1, "Must pass domainid to domainDelete");
		return;
	}

	my $data = $self->do_request( api_action => 'domain.delete', %args);

	return unless exists ($data->{DomainID});
	return $data->{DomainID};
}

sub domainResourceList {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainResourceList called');
	my $domainid;

	if ($args{domain}) {
		$domainid = $self->getDomainIDbyName($args{domain});
		$self->_error(-1, "$args{domain} not found") unless $domainid;
		return unless $domainid;
	}
	else {
		$domainid = $args{domainid}
	}

	unless (defined ($domainid)) {
		$self->_error(-1, 'Must pass domainid or domain to domainResourceList');
		return;
	}

	my $data = $self->do_request(
		api_action => 'domain.resource.list', domainid => $domainid
	);

	if (defined($data)) {
		my @RRs;
		push @RRs, $self->_lc_keys($_) for (@$data);
		return \@RRs;
	}

	return;
}

sub domainResourceGet {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainResourceGet called');

	my $domainid;
	if ($args{domain}) {
		$domainid = $self->getDomainIDbyName($args{domain});
		$self->_error(-1, "$args{domain} not found") unless $domainid;
		return unless $domainid;
	}
	else {
		$domainid = $args{domainid}
	}

	unless ( exists( $args{resourceid} ) && exists( $args{domainid} ) ) {
		$self->_error(-1,
			'Must pass domain id or domain and resourceid to domainResourceGet');
		return;
	}

	my $data = $self->do_request(
		api_action => 'domain.resource.list',
		domainid => $domainid,
		resourceid => $args{resourceid},
	);

	return unless defined ($data);

	return $self->_lc_keys($data);
}

sub getResourceIDbyName {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'getResourceIDbyName called');

	my $domainid = $args{domainid};
	if (!exists ($args{domainid}) && exists($args{domain}) ) {
		$domainid = $self->getDomainIDbyName($args{domain});
	}

	if (!(defined($domainid) && exists($args{name}))) {
		$self->_error(-1,
			'Must pass domain or domainid and (resource) name to getResourceIDbyName');
		return;
	}

	for my $rr ( @{ $self->domainResourceList(domainid => $domainid) } ) {
		return $rr->{resourceid} if $rr->{name} eq $args{name};
	}
}

sub domainResourceCreate {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainResourceCreate called');

	my $data = $self->do_request( api_action => 'domain.resource.create', %args);

	return unless exists ($data->{ResourceID});
	return $data->{ResourceID};
}

sub domainResourceSave {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainResourceCreate called');

    carp "Depricated use of domainResourceSave, use domainResourceCreate";

    return $self->domainResourceCreate(%args);
}

sub domainResourceUpdate {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainResourceUpdate called');

	if (!exists ($args{resourceid})) {
		$self->_error(-1, "Must pass resourceid to domainResourceUpdate");
		return;
	}

    return $self->do_request( api_action => 'domain.resource.update', %args);
}

sub domainResourceDelete {
	carp "WebService::Linode::DNS is deprecated, use WebService::Linode instead!";
	my ($self, %args) = @_;
	$self->_debug(10, 'domainResourceDelete called');

	if (!exists ($args{resourceid})) {
		$self->_error(-1, "Must pass resourceid to domainResourceDelete");
		return;
	}

	my $data = $self->do_request( api_action => 'domain.resource.delete', %args);

	return unless exists ($data->{ResourceID});
	return $data->{ResourceID};
}

=head1 SYNOPSIS

THIS MODULE IS DEPRECATED, DON'T USE IT, USE L<WebService::Linode>

=head1 METHODS

If you are still reading, you are doing it wrong! Go here L<WebService::Linode>


=head1 AUTHOR

Michael Greb, C<< <mgreb@linode.com> >>

=head1 BUGS

This module does not yet support the Linode API batch method, patches welcome.

Please report any bugs or feature requests to C<bug-webservice-linode
at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WebService-Linode>.  I will
be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::Linode::DNS


You can also look for information at:

=over 4

=item * Module Repo

L<http://git.thegrebs.com/?p=WebService-Linode;a=summary>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WebService-Linode>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WebService-Linode>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WebService-Linode>

=item * Search CPAN

L<http://search.cpan.org/dist/WebService-Linode>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Linode, LLC, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of WebService::Linode::DNS
