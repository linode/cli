Linode CLI
==========

## Overview

Linode CLI is a simple command-line interface to the Linode platform.

## Installation

Linode CLI is currently packaged for Debian and Ubuntu. Final versions of linode-cli will be packaged up and very easy to install for major distributions.

### Debian/Ubuntu

```
echo "deb http://apt.linode.com/ stable main" > /etc/apt/sources.list.d/linode.list
wget -O- https://apt.linode.com/linode.gpg | apt-key add -
apt-get update
apt-get install linode-cli
```

### Mac OS X

Installing dependencies on OS X requires either XCode or Command Line Tools for XCode, available from [Apple](https://developer.apple.com/xcode/).

You'll first want to install cpanminus, either using cpan packaged with OS X (`$ cpan App::cpanminus`) or using a one-line install helper: https://github.com/miyagawa/cpanminus#installing-to-system-perl

```
cpanm -S Crypt::SSLeay JSON LWP::UserAgent Mozilla::CA Try::Tiny
curl -Lo linode-cli.tar.gz https://github.com/linode/cli/archive/master.tar.gz
tar xf linode-cli.tar.gz
./cli-master/linode
```

### Others

You'll first want to install cpanminus, either using cpan packaged with your system (`$ cpan App::cpanminus`) or using a one-line install helper: https://github.com/miyagawa/cpanminus#installing-to-system-perl

```
cpanm -S Crypt::SSLeay JSON LWP::UserAgent Mozilla::CA Try::Tiny
curl -Lo linode-cli.tar.gz https://github.com/linode/cli/archive/master.tar.gz
tar xf linode-cli.tar.gz
./cli-master/linode
```

## Initial configuration

You can configure defaults, including your API key and common deployment options, by running the configuration helper:

```
linode configure
This will walk you through setting default values for common options.
API key for accessing the Linode API.
>>
...
```

This will write (or overwrite existing) options into a `.linodecli` file in your user's home directory.

Options are in the format of `option value`, for example:

```
api-key foobarbaz123456
```

The API key can also be set using an environment variable (LINODE_API_KEY). Alternatively, you can pass an `--api-key` option on the command line.

## Examples

If you didn't place linode-cli somewhere in your PATH, you'll need to call it directly: `/path/to/linode-cli/linode`. Otherwise, you can simply use `linode`.

### Listing Linodes

```
linode list
linode list My-Linode-Label
linode list My-Linode-Label1 My-Linode-Label2
```

### Showing details about a single Linode

```
linode show My-Linode-Label
```

### Starting, stopping, or restarting a Linode

```
linode start My-Linode-Label
linode stop My-Linode-Label
linode restart My-Linode-Label
```

### Renaming a Linode

```
linode rename mylinodename mylinodenewname
```

### Creating a new Linode

**Warning:** This *will* attempt to charge the credit card on file, or use any account credit available, and spin up a new Linode 1GB.

```
linode create New-Linode --location dallas --plan linode1024 --payment-term 1 --distribution 'Debian 7' --group Frontends
```

### Resizing a Linode

**Warning:** This *will* shut the Linode down, charge/credit the account, and issue a migration to another host server.

This example resizes a Linode 1024 to a Linode 2048.

```
linode resize mylinode linode2048
```

### Deleting a Linode

**Warning:** This *will* permanently delete a Linode, its disk images and configuration profiles.

```
linode delete New-Linode
```

### Working with multiple Linodes

Actions can be performed on multiple Linodes using their labels.  Using multiple --label arguments will accomplish the same thing.

```
linode start My-Linode-Label1 My-Linode-Label2
linode show --label My-Linode-Label1 --label My-Linode-Label2
```

### Working with Domains

Create a master domain (requires an SOA email address).

```
linode domain create example.com admin@example.com
```

Create a slave domain (requires a master DNS server ip).

```
linode domain create example.com slave X.X.X.X
```

Displaying domains.

```
linode domain list
linode domain show example.com
```

Updating a domain.

```
linode domain update example.com --group main
```

Creating domain records.

```
linode domain record-create example.com A www2 X.X.X.X
linode domain record-create example.com MX subdomain mail.example.com
```

Updating a domain record.

```
linode domain record-update example.com MX mail.example.com --priority 20
```

Removing a domain record.

```
linode domain record-delete example.com A www2
```

Displaying domain records.

```
linode domain record-list example.com
linode domain record-list example.com MX
linode domain record-show example.com
linode domain record-show example.com example.com MX
```

### Working with StackScripts

Actions can be performed on StackScripts.

```
linode stackscript create --label "StackScript Name" --codefile "/path/myscript.sh" --distribution "Debian 7"
linode stackscript show My-StackScript-Label
linode stackscript source mystackscript > myscript.sh
```

### Displaying account information

Account information, including the current account balance and network transfer pool usage, can be queried with the `linode-account` tool.

```
linode account show
```

```
          managed true
          balance $ 0.00
    transfer pool 7527.00GB
transfer billable 0.00GB
     active since 2013-09-10 14:44:27.0
    transfer used 1.00GB
```

### JSON output

JSON output is available for actions.

```
linode list --output json
linode list --json
```

```
{
   "linodefrontend1" : {
      "datacenterid" : 2,
      "status" : "powered off",
      "backupsenabled" : false,
      "totalram" : "1GB",
      "request_error" : "",
      "totalhd" : "24GB",
      "label" : "linodefrontend1",
      "linodeid" : 900001
   },
   "linodebackend1" : {
      "datacenterid" : 2,
      "status" : "running",
      "backupsenabled" : true,
      "totalram" : "1GB",
      "request_error" : "",
      "totalhd" : "48GB",
      "label" : "linodebackend1",
      "linodeid" : 900002
   }
}
```

## Usage

### Options

**-a**, **--action**: An action to perform on one Linode. One of: create, start, stop, restart, rename, group, resize, delete. Read-only operations are available as well: list, show.

Each action has a set of options that apply to it, which are outlined in the section ACTIONS.

**--api-key**: API key to use when communicating with the Linode API. Alternatively, you can specify the API key in a .linodecli file in the working user's home directory, using the format `api-key foobar`.

**-j**, **--json**: Optional. JSON output.

**-w**, **--wait**: Optional. Waits and provides feedback while the task(s) run.

**-h**, **--help**: Brief help message.

**-m**, **--man**: Full documentation.

### Linode Actions

#### Create

Create and start a new Linode. This action prompts for a password which will be used as the root password on the newly-created Linode.

**-d**, **--distribution**: Distribution name or DistributionID to deploy.

**-g**, **--group**: Optional. Linode Manager display group to place this Linode under. Default: none.

**-L**, **--location**: City name or DatacenterID to deploy to.

**-l**, **--label**: A Linode to operate on.

**-p**, **--plan**: The Plan to deploy. Plans are linode1024, linode2048, linode4096, linode8192, linode16384, linode24576, linode32768, and linode40960.

**-t**, **--payment-term**: Optional. Payment term, one of 1, 12, or 24 (months). Default: 1.

#### Start, stop, restart

Stop, start, or restart a Linode.

**-l**, **--label**: A Linode to operate on.

#### Rename

Change a Linode's label.

**-l**, **--label**: A Linode to operate on.

**-n**, **--new-label**: New label to apply to this Linode.

#### Group

Set a Linode's display group.

**-g**, **--group**: Linode Manager display group to place this Linode under.

**-l**, **--label**: A Linode to operate on.

#### Resize

Resize a Linode to a new plan size, and issue a boot job.

**-l**, **--label**: A Linode to operate on.

**-p**, **--plan**: The Plan to resize to. Plans are linode1024, linode2048, linode4096, linode8192, linode16384, linode24576, linode32768, and linode40960.

#### Delete

Delete a Linode, its disk image(s), and configuration profile(s).

**-l**, **--label**: A Linode to operate on.

#### List

List information about one or more Linodes. Linodes are grouped by their display group.

**-l**, **--label**: Optional. A specific Linode to list.

#### Show

Display detailed information about one or more Linodes.

**-l**, **--label**: Required. A specific Linode to show.

### Domain Actions

#### Create

Create a Domain.

**-l**, **--label**: The Domain (name). The zone's name.

**-t**, **--type**: Either master or slave. Default: master

**-e**, **--email**: SOA email address. Required for master domains.

**-D**, **--description**: Optional. Notes describing details about the Domain.

**-R**, **--refresh**: Optional. Default: 0

**-Y**, **--retry**: Optional. Default: 0

**-E**, **--expire**: Optional. Default: 0

**-T**, **--ttl**: Optional. Default: 0

**-g**, **--group**: Optional. Linode Manager display group to place this Domain under.

**-s**, **--status**: Optional. Statuses are active, edit, or disabled. Default: active

**-m**, **--masterip**: Optional. Accepts multiple entries. When the domain is a slave, this is the zone's master DNS servers list.

**-x**, **--axfrip**: Optional. Accepts multiple entries. IP addresses allowed to AXFR the entire zone.

#### Update

Update a Domain.

**-l**, **--label**: The Domain (name) to update.

**-n**, **--new-label**: Optional.  Renames the Domain.

**-t**, **--type**: Optional. Either master or slave. Default: master

**-e**, **--email**: Optional. SOA email address. Required for master domains.

**-D**, **--description**: Optional. Notes describing details about the Domain.

**-R**, **--refresh**: Optional. Default: 0

**-Y**, **--retry**: Optional. Default: 0

**-E**, **--expire**: Optional. Default: 0

**-T**, **--ttl**: Optional. Default: 0

**-g**, **--group**: Optional. Linode Manager display group to place this Domain under.

**-s**, **--status**: Optional. Statuses are active, edit, or disabled. Default: active

**-m**, **--masterip**: Optional. Accepts multiple entries. When the domain is a slave, this is the zone's master DNS servers list.

**-x**, **--axfrip**: Optional. Accepts multiple entries. IP addresses allowed to AXFR the entire zone.

#### Delete

Delete a Domain.

**-l**, **--label**: The Domain to delete.

#### List

List information about one or more Domains.

**-l**, **--label**: Optional. A specific Domain to list.

#### Show

Display detailed information about one or more Domains.

**-l**, **--label**: Required. A specific Domain to show.


#### Domain Record Create (record-create)

Create a Domain record.

**-l**, **--label**: The Domain (name). The zone's name.

**-t**, **--type**: Required. One of: NS, MX, A, AAAA, CAME, TXT, or SRV

**-n**, **--name**: Optional. The hostname or FQDN. When Type=MX the subdomain to delegate to the Target MX server. Default: blank.

**-p**, **--port**: Optional. Default: 80

**-R**, **--target**: Optional. When Type=MX the hostname. When Type=CNAME the target of the alias. When Type=TXT the value of the record. When Type=A or AAAA the token of '[remote_addr]' will be substituted with the IP address of the request.

**-P**, **--priority**: Optional. Priority for MX and SRV records, 0-255 Default: 10

**-W**, **--weight**: Optional. Default: 5

**-L**, **--protocol**: Optional. The protocol to append to an SRV record. Ignored on other record types. Default: blank.

**-T**, **--ttl**: Optional. Default: 0

#### Domain Record Update (record-update)

Update a Domain record.

**-l**, **--label**: The Domain containing the record to update.

**-t**, **--type**: Required. The type of the record to delete. One of: NS, MX, A, AAAA, CAME, TXT, or SRV

**-m**, **--match**: Required. The match for the record to delete. Match to a name or target.

**-n**, **--name**: Optional. The hostname or FQDN. When Type=MX the subdomain to delegate to the Target MX server. Default: blank.

**-p**, **--port**: Optional. Default: 80

**-R**, **--target**: Optional. When Type=MX the hostname. When Type=CNAME the target of the alias. When Type=TXT the value of the record. When Type=A or AAAA the token of '[remote_addr]' will be substituted with the IP address of the request.

**-P**, **--priority**: Optional. Priority for MX and SRV records, 0-255 Default: 10

**-W**, **--weight**: Optional. Default: 5

**-L**, **--protocol**: Optional. The protocol to append to an SRV record. Ignored on other record types. Default: blank.

**-T**, **--ttl**: Optional. Default: 0

#### Domain Record Delete (record-delete)

Delete a Domain record.

**-l**, **--label**: The Domain containing the record to delete.

**-t**, **--type**: Required. The type of the record to delete. One of: NS, MX, A, AAAA, CAME, TXT, or SRV

**-m**, **--match**: Required. The match for the record to delete. Match to a name or target.

#### Domain Record List (record-list)

List Domain Record information for one or more Domains.

**-l**, **--label**: Optional. A specific Domain to list.

**-t**, **--type**: Optional. Allows domain record filtering by type. One of: NS, MX, A, AAAA, CAME, TXT, or SRV


#### Domain Record Show (record-show)

Display detailed Domain Record information for one or more Domains.

**-l**, **--label**: Required. A specific Domain to show.

**-t**, **--type**: Optional. Allows domain record filtering by type. One of: NS, MX, A, AAAA, CAME, TXT, or SRV


### StackScript Actions

#### Create

Create a StackScript.

**-l**, **--label**: The label (name) for the StackScript.

**-d**, **--distribution**: Distribution name or DistributionID to deploy.

**-c**, **--codefile**: The script file name (including the path) containing the source code.

**-p**, **--ispublic**: Optional. Whether this StackScript is published in the Library, for everyone to use.   Options are yes, no, true, and false. Default is false.

**-D**, **--description**: Optional. Notes describing details about the StackScript.

**-r**, **--revnote**: Optional. Note for describing the version.

#### Update

Update a StackScript.

**-l**, **--label**: The label (name) of the StackScript to update.

**-n**, **--new-label**: Optional.  Renames the StackScript.

**-d**, **--distribution**: Optional. Distribution name or DistributionID to deploy.

**-c**, **--codefile**: Optional. The script file name (including the path) containing the source code.

**-p**, **--ispublic**: Optional. Whether this StackScript is published in the Library, for everyone to use.   Options are yes, no, true, and false. Default is false.

**-D**, **--description**: Optional. Notes describing details about the StackScript.

**-r**, **--revnote**: Optional. Note for describing the version.

#### Delete

Delete a StackScript.

**-l**, **--label**: The StackScript to delete.

#### List

List information about one or more StackScripts.

**-l**, **--label**: Optional. A specific StackScript to list.

#### Show

Display detailed information about one or more StackScripts.

**-l**, **--label**: Required. A specific StackScript to show.

#### Source

Display the source code for a StackScript.

**-l**, **--label**: Required. A specific StackScript to show.
