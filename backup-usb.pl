#!/usr/bin/perl -w
use strict;

my $MAIN_POOL =		"tank";
my $GPG_CMD =		"/opt/csw/bin/gpg";
my $SNAPSHOT_PREFIX =	"backup-usb";

my @EXClUDE = qw| tank/swap tank/iscsi tank/tmp |;

my @filesystems = `zfs list -o name -H -r tank`;

foreach (@EXCLUDE) {
	@filesystems = grep { ! /$_/ } @filesystems;
}

FS: foreach my $fs (@filesystems) {
	my @snapshots = `zfs list -r -t snapshot $fs`;
	@snapshots = sort grep { /^${fs}\@backup-usb/ } @snapshots;
	
	unless grep { /backup-usb-full/ } @snapshots {
		warn "no full backup!";
		print "Would make full backup and delete any incrementals here!\n";
	}
	
	
	
}