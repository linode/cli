package Linode::CLI::SystemInfo;

use 5.010;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(system);

# A lot of this is borrowed from:
#   http://search.cpan.org/~chorny/Linux-Distribution-0.21/lib/Linux/Distribution.pm
# with additions for handling Darwin, generic POSIX systems, and Win32.
my $version_match = {
    gentoo     => 'Gentoo Base System release (.*)',
    debian     => '(.+)',
    suse       => 'VERSION = (.*)',
    fedora     => 'Fedora(?: Core)? release (\d+) \(',
    redflag    => 'Red Flag (?:Desktop|Linux) (?:release |\()(.*?)(?: \(.+)?\)',
    redhat     => 'Red Hat(?: Enterprise)? Linux(?: Server)? release (.*) \(',
    enterprise => 'Enterprise Linux Server release (.+) \(',
    slackware  => '^Slackware (.+)$',
    pardus     => '^Pardus (.+)$',
    centos     => '^CentOS(?: Linux)? release (.+)(?:\s\(Final\))',
    scientific => '^Scientific Linux release (.+) \(',
};

sub new {
    my $self = {
        file    => '',
        name    => '',
        pattern => '',
        release => '',
    };

    return bless $self;
}

sub system {
    my $self = shift || new();

    return $^O if ($^O eq 'Win32');

    chomp(my $os_release = qx{uname -r 2>/dev/null} || 'unknown');

    if ($^O eq 'linux') {
        $self->lsb_release() || $self->release_file();
        my $release = [
            $self->{name}    || 'linux',
            $self->{release} || $os_release,
        ];
        return join('/', @$release);
    }
    elsif ($^O eq 'darwin') {
        chomp(my $version = qx{sw_vers -productVersion 2>/dev/null});
        return "os-x/$version" if ($version);
        return "darwin/$os_release";
    }

    return "$^O/$os_release";
}

sub release_file {
    my $self = shift;

    opendir(my $dh, '/etc/') or die "Could not open directory '/etc/': $!\n";
    my @files = readdir $dh;
    closedir($dh);

    for my $distribution (keys %$version_match) {
        my @matches = grep /$distribution(?:-|_)(?:release|version)/, @files;
        if (@matches) {
            $self->{file} = "/etc/$matches[0]";
            $self->{name} = $distribution;
            $self->{pattern} = $version_match->{$distribution};
            $self->{release} = $self->scrape_distro_release();
            return $self->{release};
        }
    }
    undef;
}

sub lsb_release {
    my $self = shift;

    if (-f '/etc/lsb-release') {
        $self->{file} = '/etc/lsb-release';
        $self->{pattern} = 'DISTRIB_ID=(.+)';
        $self->{name} = $self->scrape_distro_release();
        $self->{pattern} = 'DISTRIB_RELEASE=(.+)';
        $self->{release} = $self->scrape_distro_release();
        return $self->{release};
    }
    undef;
}

sub scrape_distro_release {
    my $self = shift;

    my $info = '';
    open my $fh, '<', $self->{file} or die "Could not open file '$self->{file}': $!\n";
    local $_;
    while (<$fh>) {
        chomp $_;
        ($info) = $_ =~ m/$self->{pattern}/;
        return $info if ($info);
    }
    undef;
}
