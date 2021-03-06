#!/usr/bin/perl
#
# Rsnapshot run script
# Rootnode, http://rootnode.net
#
# Copyright (C) 2012 Marcin Hlybin
# All rights reserved.
#

use warnings;
use strict;
use Readonly;
use Getopt::Long;
use POSIX qw(isdigit);
use File::Basename qw(basename);
use Data::Validate::Domain qw(is_domain);
use Smart::Comments;

# Configuration
Readonly my $RSNAPSHOT_BIN         => '/usr/bin/rsnapshot';
Readonly my $RSNAPSHOT_ROOT_DIR    => '/home/rsnapshot';
Readonly my $RSNAPSHOT_CONF_DIR    => '/etc/rsnapshot';
Readonly my $SNAPSHOT_CONF_SCRIPT  => "$RSNAPSHOT_CONF_DIR/snapshot/snapshot-conf.pl";
Readonly my $MYSQLDUMP_CONF_SCRIPT => "$RSNAPSHOT_CONF_DIR/mysqldump/mysqldump-conf.pl";

Readonly my $SNAPSHOT_CONF_DIR  => "$RSNAPSHOT_ROOT_DIR/snapshot.d";
Readonly my $MYSQLDUMP_CONF_DIR => "$RSNAPSHOT_ROOT_DIR/mysqldump.d";

# Check paths
-d $RSNAPSHOT_CONF_DIR    or die "Root directory \$RSNAPSHOT_CONF_DIR ($RSNAPSHOT_CONF_DIR) not found.\n";
-f $SNAPSHOT_CONF_SCRIPT  or die "Snapshot configuration script \$SNAPSHOT_CONF_SCRIPT ($SNAPSHOT_CONF_SCRIPT) not found.\n";
-f $MYSQLDUMP_CONF_SCRIPT or die "Mysqldump configuration script \$MYSQLDUMP_CONF_SCRIPT ($MYSQLDUMP_CONF_SCRIPT) not found.\n";

Readonly my $BASENAME => basename($0);
Readonly my $USAGE    => <<END_OF_USAGE;
Rsnapshot cron script
Usage: 
	$BASENAME [ --mysql ] [ --snapshot ] --host <hostname> <backup_level>

Available backup levels are: hourly, daily, weekly, monthly
END_OF_USAGE

# Get options
my ($ssh_host, $run_snapshot_backup, $run_mysql_backup);
GetOptions(
	'host=s'   => \$ssh_host,
	'snapshot' => \$run_snapshot_backup,
	'mysql'    => \$run_mysql_backup,
);

# Get arguments
my $backup_level = shift or die $USAGE;

# Validate SSH host
defined $ssh_host    or die "Host not specified.\n";
is_domain($ssh_host) or die "Host '$ssh_host' must be a domain.\n";

# Run snapshot-conf generator
system("$SNAPSHOT_CONF_SCRIPT -h $ssh_host");
die $! if $?;

# Run mysqldump-conf generator
system("$MYSQLDUMP_CONF_SCRIPT -h $ssh_host");
die $! if $?;

# Snapshot backup
if (defined $run_snapshot_backup) {
	my @snapshot_conf_files = glob("$SNAPSHOT_CONF_DIR/*");
	foreach my $conf_file (@snapshot_conf_files) {
		print "snapshot: $conf_file\n";
		system("$RSNAPSHOT_BIN -c $conf_file $backup_level");
	}
}

# Mysqldump backup
if (defined $run_mysql_backup) {
	my @mysqldump_conf_files = glob("$MYSQLDUMP_CONF_DIR/*");
	foreach my $conf_file (@mysqldump_conf_files) {
		print "mysqldump: $conf_file\n";
		system("$RSNAPSHOT_BIN -c $conf_file $backup_level");
	}
}
