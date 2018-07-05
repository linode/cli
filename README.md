Linode CLI
==========

## Overview

Linode CLI is a simple command-line interface to the Linode platform.
**Note: There is a newer version of the Linode CLI ([linode-cli](https://github.com/linode/linode-cli)) that uses the new Linode [API V4](https://developers.linode.com/v4/introduction).**

## Installation

Linode CLI is currently packaged for Debian, Ubuntu, CentOS, Fedora, NixOS and through Homebrew on Mac OS X. Final versions of linode-cli will be packaged up and very easy to install for major distributions.

### Debian/Ubuntu

```
sudo bash -c 'echo "deb http://apt.linode.com/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/linode.list'
wget -O- https://apt.linode.com/linode.gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get install linode-cli
```

### Fedora

Fedora's official repositories include Linode CLI (in F24 and newer). To install,

```
sudo dnf install linode-cli
```

### CentOS

Installing Linode CLI on CentOS requires the EPEL repository to be installed and enabled, before installing Linode CLI.

```
sudo yum install epel-release
sudo yum install linode-cli
```

### NixOS/Nix

Linode CLI is included in NixPkgs, so installation should be straightforward

```
# Using symbolic name. 
nix-env -i perl-linode-cli
# Using attribute name. (Channel name is derived using $() here)
nix-env -iA $(nix-channel --list | head -n1 | cut -d' ' -f1).linode-cli
```

### Mac OS X

Installing the packaged version of Linode CLI on Mac OS X requires Homebrew: http://brew.sh

```
brew install linode/cli/linode-cli
```

#### Mac OS X segmentation faults

Linode-cli must be built using the system perl, so if you end up with segmentation faults when running `linode` on OSX, try 

```
brew unlink perl
brew uninstall linode-cli
brew install linode-cli
```

### Others

You'll need the following Perl modules. They can be installed from the CPAN using your preferred method.

* JSON
* LWP
* Mozilla::CA
* Try::Tiny
* WebService::Linode

To install with root:

```
sudo cpan -i JSON LWP Mozilla::CP Try::Tiny WebService::Linode
```

To install with local::lib:

```
perl -MCPAN -Mlocal::lib -e 'CPAN::install(JSON, LWP, Mozilla::CA, Try::Tiny, WebService::Linode)'
```

Then, download the Linode CLI tarball, extract it, and install:

```
curl -Lo linode-cli.tar.gz https://github.com/linode/cli/archive/master.tar.gz
tar xf linode-cli.tar.gz
cd cli-master && perl Makefile.PL && sudo make install
```

## Initial configuration

You can configure defaults, including your API key and common deployment options, by running the configuration helper:

```
linode configure
This will walk you through setting default values for common options.

Linode Manager username
>>
...
```

By default, this will (over)write `$HOME/.linodecli/config`. If you specify a username (`-u`), it will (over)write `$HOME/.linodecli/config_username`.

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

**Warning:** This *will* attempt to charge the credit card on file, or use any account credit available, and spin up a new Linode 2GB.

```
linode create New-Linode --location dallas --plan linode2G --payment-term 1 --distribution 'Debian 9' --group Frontends
```

### Resizing a Linode

**Warning:** This *will* shut the Linode down, charge/credit the account, and issue a migration to another host server.

This example resizes a Linode 2GB to a Linode 4GB.

```
linode resize mylinode linode4GB
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

### Working with NodeBalancers

Create a NodeBalancer in your datacenter of choice.

```
linode nodebalancer create mynodebalancer dallas
```

Set the NodeBalancer up to handle traffic on a port (configuration).

```
linode nodebalancer config-create mynodebalancer 80
```

Create NodeBlanacer Nodes, balancing the incoming traffic between your Linodes.

```
linode nodebalancer node-create mynodebalancer 80 mylinode1 xx.xx.xx.1:80
linode nodebalancer node-create mynodebalancer 80 mylinode2 xx.xx.xx.2:80
linode nodebalancer node-create mynodebalancer 80 mylinode3 xx.xx.xx.3:80
```

Displaying NodeBalancers.

```
linode nodebalancer list
```

Displaying the Nodes, which will list the Linodes handing traffic on the port requested.

```
linode nodebalancer node-list mynodebalancer 80
```

### Working with StackScripts

Actions can be performed on StackScripts.

```
linode stackscript list
linode stackscript create --label "StackScript Name" --codefile "/path/myscript.sh" --distribution "Debian 9"
linode stackscript show My-StackScript-Label
linode stackscript source mystackscript > myscript.sh
```

### Working with Linode Images

Listing a Linode's disks (displays disk names and disk IDs)

```
linode disk-list mylinodelabel
```

Creating a Linode Image

```
linode image-create mylinodelabel --diskid diskid
```

Listing your Linode Images

```
linode image-list
```

Updating or removing your Linode Images

```
linode image-update --imageid imageid --name newname
linode image-delete --imageid imageid
```

### Displaying account information

Account information, including the current account balance and network transfer pool usage, can be queried with the `linode-account` tool.

```
linode account show
```

```
          managed yes
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
      "location" : "dallas",
      "group" : "",
      "status" : "powered off",
      "backupsenabled" : false,
      "totalram" : "2GB",
      "request_error" : "",
      "totalhd" : "24GB",
      "label" : "linodefrontend1",
      "linodeid" : 900001
   },
   "linodebackend1" : {
      "location" : "dallas",
      "group" : "backend",
      "status" : "running",
      "backupsenabled" : true,
      "totalram" : "4GB",
      "request_error" : "",
      "totalhd" : "48GB",
      "label" : "linodebackend1",
      "linodeid" : 900002
   }
}
```

### Using with multiple accounts

Multiple accounts and configuration files can be accomplished with the username option.

```
linode list -u username1
linode list -u username2

linode configure -u username1
linode configure -u username2
...
```

## Usage

### Options

**-a**, **--action**: An action to perform on one Linode. One of: create, start, stop, restart, rename, group, resize, delete. Read-only operations are available as well: list, show.

Each action has a set of options that apply to it, which are outlined in the section ACTIONS.

**--api-key**: API key to use when communicating with the Linode API. Alternatively, you can specify the API key in `$HOME/.linodecli/config`, using the format `api-key foobar`.

**-u**, **--username**: Optional. Allows users to specify the username, if using with multiple accounts and configuration files.

**-j**, **--json**: Optional. JSON output.

**-h**, **--help**: Displays help documentation.

---

### Linode Actions

#### Create

Create and start a new Linode.

**-l**, **--label**: Required. A Linode to operate on.

**-L**, **--location**, **--datacenter**: Required. The datacenter to use for deployment. Locations are Atlanta, Dallas, Frankfurt, Fremont, London, Newark, Singapore, Shinagawa.

**-d**, **--distribution**: Required when not using imageid. Distribution name or DistributionID to deploy.

**-i**, **--imageid**: Required when not using distribution. The ID of the gold-master image to use for deployment.

**-p**, **--plan**: Required. The Plan to deploy. Plans are:

    Standard Instances:
    linode2GB, linode4GB, linode8GB, linode16GB, linode32GB, linode64GB, linode96GB, linode128GB, linode192GB

    High Memory Instances:
    linode24GB, linode48GB, linode90GB, linode150GB, linode300GB

    Nanode Instances:
    nanode1GB

**-P**, **--password**: Required. The root user's password.  Needs to be at least 6 characters and contain at least two of these four character classes: lower case letters, upper case letters, numbers, and punctuation.

**-t**, **--payment-term**: Optional. Payment term, one of 1, 12, or 24 (months). Default: 1. This is ignored when using metered.

**-g**, **--group**: Optional. Linode Manager display group to place this Linode under. Default: none.

**-K**, **--pubkey-file**: Optional. A public key file to install at `/root/.ssh/authorized_keys` when creating this Linode.

**-S**, **--stackscript**: Optional when creating with a distribution. Personal or public StackScript ID to use for deployment.  Names of personal StackScripts are accepted.

**-J**, **--stackscriptjson**: The JSON encoded name/value pairs, answering the StackScript's User Defined Fields (UDF). A path to a JSON file is also accepted.

**-w**, **--wait**: Optional. Amount of time (in minutes) to wait for human output. Using the flag only, will use the default of 5.

#### Rebuild

Rebuild an existing Linode.

**-l**, **--label**: Required. A Linode to operate on.

**-d**, **--distribution**: Required when not using imageid. Distribution name or DistributionID to deploy.

**-i**, **--imageid**: Required when not using distribution. The ID of the gold-master image to use for deployment.

**-P**, **--password**: Required. The root user's password.  Needs to be at least 6 characters and contain at least two of these four character classes: lower case letters, upper case letters, numbers, and punctuation.

**-K**, **--pubkey-file**: Optional. A public key file to install at `/root/.ssh/authorized_keys` when creating this Linode.

**-S**, **--stackscript**: Optional when rebuilding with a distribution. Personal or public StackScript ID to use for deployment.  Names of personal StackScripts are accepted.

**-J**, **--stackscriptjson**: The JSON encoded name/value pairs, answering the StackScript's User Defined Fields (UDF). A path to a JSON file is also accepted.

**-w**, **--wait**: Optional. Amount of time (in minutes) to wait for human output. Using the flag only, will use the default of 5.

#### Start, stop, restart

Stop, start, or restart a Linode.

**-l**, **--label**: A Linode to operate on.

**-w**, **--wait**: Optional. Amount of time (in minutes) to wait for human output. Using the flag only, will use the default of 5.

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

**-p**, **--plan**: The Plan to resize to. Plans are:

    Standard Instances:
    linode2GB, linode4GB, linode8GB, linode16GB, linode32GB, linode64GB, linode96GB, linode128GB, linode192GB

    High Memory Instances:
    linode24GB, linode48GB, linode90GB, linode150GB, linode300GB

    Nanode Instances:
    nanode1GB

**-w**, **--wait**: Optional. Amount of time (in minutes) to wait for human output. Using the flag only, will use the default of 20.

#### IP-Add

Add an IP address to a Linode.

**-l**, **--label**: A Linode to operate on.

**--private**: Add a private IP address instead of a public one.

#### Delete

Delete a Linode, its disk image(s), and configuration profile(s).

**-l**, **--label**: A Linode to operate on.

#### List

List information about one or more Linodes. Linodes are grouped by their display group.

**-l**, **--label**: Optional. A specific Linode to list.

#### Show

Display detailed information about one or more Linodes.

**-l**, **--label**: Required. A specific Linode to show.

#### Locations

List all available datacenters.

#### Distros

List all available distributions.

#### Plans

List all available Linode plans.

#### Disk-List

Lists disks associated with a specific Linode.

**-l**, **--label**: Required. The Linode to display.

#### Image-List

Lists available gold-master images.

#### Image-Create

Creates a gold-master image for future deployments.

**-l**, **--label**: Required. Specifies the source Linode to create the image from.

**-d**, **--diskid**: Required. Specifies the source Disk ID to create the image from.

**-D**, **--description**: Optional. An optional description of the created image.

**-n**, **--name**: Optional. Sets the name of the image. If not provided, the name defaults to the source image label.

**-w**, **--wait**: Optional. Amount of time (in minutes) to wait for human output. Using the flag only, will use the default of 5.

#### Image-Update

Updates a gold-master image.

**-i**, **--imageid**: Required. The ID of the gold-master image to update.

**-D**, **--description**: Optional. The new image description.

**-n**, **--name**: Optional. The new image name.

#### Image-Delete

Deletes a gold-master image.

**-i**, **--imageid**: Required. The ID of the gold-master image to delete.

---

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

**-t**, **--type**: Required. One of: NS, MX, A, AAAA, CNAME, TXT, or SRV

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

**-t**, **--type**: Required. The type of the record to delete. One of: NS, MX, A, AAAA, CNAME, TXT, or SRV

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

**-t**, **--type**: Required. The type of the record to delete. One of: NS, MX, A, AAAA, CNAME, TXT, or SRV

**-m**, **--match**: Required. The match for the record to delete. Match to a name or target.

#### Domain Record List (record-list)

List Domain Record information for one or more Domains.

**-l**, **--label**: Optional. A specific Domain to list.

**-t**, **--type**: Optional. Allows domain record filtering by type. One of: NS, MX, A, AAAA, CNAME, TXT, or SRV

#### Domain Record Show (record-show)

Display detailed Domain Record information for one or more Domains.

**-l**, **--label**: Required. A specific Domain to show.

**-t**, **--type**: Optional. Allows domain record filtering by type. One of: NS, MX, A, AAAA, CNAME, TXT, or SRV

---

### NodeBalancer Actions

#### Create

Create a NodeBalancer.

**-l**, **--label**: Required. The name of the NodeBalancer.

**-L**, **--location**: Required. The datacenter to use for deployment. Locations are Dallas, Fremont, Atlanta, Newark, London, and Tokyo.

**-t**, **--payment-term**: Optional. Payment term, one of 1, 12, or 24 (months). Default: 1. This is ignored when using metered.

#### Rename

Rename a NodeBalancer.

**-l**, **--label**: Required. The name of the NodeBalancer.

**-n**, **--new-label**: Required. The new name for the NodeBalancer.

#### Throttle

Adjust the connections per second allowed per client IP for a NodeBalancer, to help mitigate abuse.

**-l**, **--label**: Required. The name of the NodeBalancer.

**-c**, **--connections**: Required. To help mitigate abuse, throttle connections per second, per client IP. 0 to disable. Max of 20.

#### Delete

Delete a NodeBalancer.

**-l**, **--label**: Required. The NodeBalancer to delete.

#### List

List information about one or more NodeBalancers.

**-l**, **--label**: Optional. A specific NodeBalancer to list.

#### Show

Display detailed information about one or more NodeBalancers.

**-l**, **--label**: Required. A specific NodeBalancer to show.

### NodeBalancer Config Actions

#### Create NodeBalancer Config/Port (config-create)

Create a NodeBalancer config (port).

**-l**, **--label**: Required. The NodeBalancer name to add the config/port.

**-p**, **--port**: Optional. The NodeBalancer config port to bind on (1-65534). Default is 80.

**-L**, **--protocol**: Optional. Options are 'tcp', 'http', and 'https'. Default is 'http'.

**-A**, **--algorithm**: Optional. Balancing algorithm. Options are 'roundrobin', 'leastconn', and 'source'. Default is 'roundrobin'.

**-S**, **--stickiness**: Optional. Session persistence. Options are 'none', 'table', and 'http_cookie'. Default is 'table'.

**-H**, **--check-health**: Optional. Perform active health checks on the backend nodes. One of 'connection', 'http', 'http_body'. Default is 'connection'.

**-I**, **--check-interval**: Optional. Seconds between health check probes (2-3600). Default is 5.

**-T**, **--check-timeout**: Optional. Seconds to wait before considering the probe a failure (1-30). Must be less than check_interval. Default is 3.

**-X**, **--check-attempts**: Optional. Number of failed probes before taking a node out of rotation (1-30). Default is 2.

**-P**, **--check-path**: Optional. When check-health='http', the path to request. Default is '/'.

**-B**, **--check-body**: Optional. When check-health='http_body', a regex against the expected result body.

**-C**, **--ssl-cert**: Optional. SSL certificate served by the NodeBalancer when the protocol is 'https'. A path to the file is also accepted.

**-K**, **--ssl-key**: Optional. Unpassphrased private key for the SSL certificate when protocol is 'https'. A path to the file is also accepted.

#### Update NodeBalancer Config/Port (config-update)

Update a NodeBalancer config (port).

**-l**, **--label**: Required. The NodeBalancer name.

**-p**, **--port**: Required. The NodeBalancer config port.

**-N**, **--new-port**: Optional. Changes the config port to bind on (1-65534).

**-L**, **--protocol**: Optional. Protocol. Options are 'tcp', 'http', and 'https'.

**-A**, **--algorithm**: Optional. Balancing algorithm. Options are 'roundrobin', 'leastconn', and 'source'.

**-S**, **--stickiness**: Optional. Session persistence. Options are 'none', 'table', and 'http_cookie'.

**-H**, **--check-health**: Optional. Perform active health checks on the backend nodes. One of 'connection', 'http', 'http_body'.

**-I**, **--check-interval**: Optional. Seconds between health check probes (2-3600).

**-T**, **--check-timeout**: Optional. Seconds to wait before considering the probe a failure (1-30). Must be less than check_interval.

**-X**, **--check-attempts**: Optional. Number of failed probes before taking a node out of rotation (1-30).

**-P**, **--check-path**: Optional. When check-health='http', the path to request.

**-B**, **--check-body**: Optional. When check-health='http_body', a regex against the expected result body.

**-C**, **--ssl-cert**: Optional. SSL certificate served by the NodeBalancer when the protocol is 'https'. A path to the file is also accepted.

**-K**, **--ssl-key**: Optional. Unpassphrased private key for the SSL certificate when protocol is 'https'. A path to the file is also accepted.

#### Delete NodeBalancer Config/Port (config-delete)

Delete a NodeBalancer config (port).

**-l**, **--label**: The NodeBalancer name.

**-p**, **--port**: The NodeBalancer config port to delete.

#### List NodeBalancer Config/Port (config-list)

List all configs (ports) for a specific NodeBalancer.

**-l**, **--label**: Required. A specific NodeBalancer to list.

#### Show NodeBalancer Config/Port (config-show)

Display detailed information about a specific NodeBalancer config/port.

**-l**, **--label**: Required. A specific NodeBalancer to show.

**-p**, **--port**: Required. The NodeBalancer config port to show.

### NodeBalancer Node Actions

#### Create NodeBalancer Node (node-create)

Create a NodeBalancer Node.

**-l**, **--label**: Required. The label (name) of the NodeBalancer.

**-p**, **--port**: Required. The NodeBalancer port or config port.

**-n**, **--name**: Required. The Node name to update.

**-A**, **--address**: Required. The address:port combination used to communicate with this Node.

**-W**, **--weight**: Optional. Load balancing weight, 1-255. Higher means more connections. Default is 100.

**-M**, **--mode**: Optional. The connections mode to use. Options are 'accept', 'reject', and 'drain'. Default is 'accept'.

#### Update NodeBalancer Node (node-update)

Update a NodeBalancer Node.

**-l**, **--label**: Required. The label (name) of the NodeBalancer.

**-p**, **--port**: Required. The NodeBalancer port or config port.

**-n**, **--name**: Required. The Node name to update.

**-N**, **--new-name**: Optional. New name for the Node (rename).

**-A**, **--address**: Optional. The address:port combination used to communicate with this Node.

**-W**, **--weight**: Optional. Load balancing weight, 1-255. Higher means more connections.

**-M**, **--mode**: Optional. The connections mode to use. Options are 'accept', 'reject', and 'drain'.

#### Delete NodeBalancer Node (node-delete)

Delete a NodeBalancer Node.

**-l**, **--label**: The NodeBalancer name.

**-p**, **--port**: The NodeBalancer port or config port.

**-n**, **--name**: The specific Node name to delete.

#### List NodeBalancer Node (node-list)

List all Nodes for a specific NodeBalancer port.

**-l**, **--label**: Required. A specific NodeBalancer.

**-p**, **--port**: Required. The NodeBalancer port or config port.

#### Show NodeBalancer Node (node-show)

Show detailed information about a specific Node for a specific NodeBalancer port.

**-l**, **--label**: Required. A specific NodeBalancer.

**-p**, **--port**: Required. The NodeBalancer port or config port.

**-n**, **--name**: Required. The name of the Node to show.

---

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
