Linode CLI
==========

## Overview

Linode CLI is a simple command-line interface to the Linode platform.

## Installation

Final versions of linode-cli will be packaged up and very easy to install. For now, you'll need to grab a ZIP, tarball, or clone from source and install dependencies manually.

### Debian/Ubuntu

```
$ curl -Lo linode-cli.tar.gz https://github.com/linode/cli/archive/master.tar.gz
$ tar xf linode-cli.tar.gz
$ apt-get install libjson-perl libcrypt-ssleay-perl ca-certificates libtry-tiny-perl libwww-perl
$ ./cli-master/linode
```

### Mac OS X

Installing dependencies on OS X requires either XCode or Command Line Tools for XCode, available from [Apple](https://developer.apple.com/xcode/).

You'll first want to install cpanminus, either using cpan packaged with OS X (`$ cpan App::cpanminus`) or using a one-line install helper: https://github.com/miyagawa/cpanminus#installing-to-system-perl

```
$ cpanm -S Crypt::SSLeay JSON LWP::UserAgent Mozilla::CA Try::Tiny
$ curl -Lo linode-cli.tar.gz https://github.com/linode/cli/archive/master.tar.gz
$ tar xf linode-cli.tar.gz
$ ./cli-master/linode
```

### Others

You'll first want to install cpanminus, either using cpan packaged with your system (`$ cpan App::cpanminus`) or using a one-line install helper: https://github.com/miyagawa/cpanminus#installing-to-system-perl

```
$ cpanm -S Crypt::SSLeay JSON LWP::UserAgent Mozilla::CA Try::Tiny
$ curl -Lo linode-cli.tar.gz https://github.com/linode/cli/archive/master.tar.gz
$ tar xf linode-cli.tar.gz
$ ./cli-master/linode
```

## Examples

Before using linode-cli for the first time, you'll want to drop your API key in a `.linodecli` file in your user's home directory, with the following format:

```
api-key foobarbaz123456
```

The API key can also be set using an environment variable (LINODE_API_KEY).

Alternatively, you can pass an `--api-key` option on the command line.

That's it! Now you're ready to start using linode-cli. If you didn't place linode-cli somewhere in your PATH, you'll need to call it directly: `/path/to/linode-cli/linode`. Otherwise, you can simply use `linode`.

### Listing Linodes

```
$ linode list
$ linode list My-Linode-Label
$ linode list My-Linode-Label1 My-Linode-Label2
```

### Showing details about a single Linode

```
$ linode show My-Linode-Label
```

### Starting, stopping, or restarting a Linode

```
$ linode start My-Linode-Label
$ linode stop My-Linode-Label
$ linode restart My-Linode-Label
```

### Creating a new Linode

**Warning:** This *will* attempt to charge the credit card on file, or use any account credit available, and spin up a new Linode 1GB.

```
$ linode create New-Linode --location dallas --plan 1 --payment-term 1 --distribution 'Debian 7' --group Frontends
```

### Deleting a Linode

**Warning:** This *will* permanently delete a Linode, its disk images and configuration profiles.

```
$ linode delete New-Linode
```
### Working with multiple Linodes

Actions can be performed on multiple Linodes using their labels.  Using multiple --label arguments will accomplish the same thing.

```
$ linode start My-Linode-Label1 My-Linode-Label2
$ linode show --label My-Linode-Label1 --label My-Linode-Label2
```

### JSON output

JSON output is available for most actions.

```
$ linode list --output json
$ linode list --json
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

**-a**, **--action**: An action to perform on one Linode. One of: create, start, stop, restart, rename, group, delete. Read-only operations are available as well: list, show.

Each action has a set of options that apply to it, which are outlined in the section ACTIONS.

**--api-key**: API key to use when communicating with the Linode API. Alternatively, you can specify the API key in a .linodecli file in the working user's home directory, using the format `api-key foobar`.

**-j**, **--json**: Optional. JSON output.

**-w**, **--wait**: Optional. Waits and provides feedback while the task(s) run.

**-h**, **--help**: Brief help message.

**-m**, **--man**: Full documentation.

### Actions

#### Create

Create and start a new Linode. This action prompts for a password which will be used as the root password on the newly-created Linode.

**-d**, **--distribution**: Distribution name or DistributionID to deploy.

**-g**, **--group**: Optional. Linode Manager display group to place this Linode under. Default: none.

**-L**, **--location**: City name or DatacenterID to deploy to.

**-l**, **--label**: A Linode to operate on.

**-p**, **--plan**: A PlanID to deploy.

**-t**, **--payment-term**: Optional. Payment term, one of 1, 12, or 24 (months). Default: 1.

#### Start, stop, restart

Stop, start, or restart a Linode.

**-l**, **--label**: A Linode to operate on.

#### Rename

Change a Linode's label.

**-l**, **--label**: A Linode to operate on.

**--new-label**: New label to apply to this Linode.

#### Group

Set a Linode's display group.

**-g**, **--group**: Linode Manager display group to place this Linode under.

**-l**, **--label**: A Linode to operate on.

#### Delete

Delete a Linode, its disk image(s), and configuration profile(s).

**-l**, **--label**: A Linode to operate on.

#### List

List information about one or more Linodes.

**-l**, **--label**: A Linode to list.

#### Show

Display detailed information about a single Linode.

**-l**, **--label**: Label of the Linode to show information about.