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
	my $prev_incr;
	my $new_incr;
	my @snapshots = `zfs list -r -t snapshot $fs`;
	@snapshots = sort grep { /^${fs}\@backup-usb/ } @snapshots;
	
	unless grep { /${SNAPSHOT_PREFIX}-full/ } @snapshots {
		warn "no full backup!";
		print "Would make full backup and delete any incrementals here!\n";
	}
	
	if ( my @incrs = grep { /${SNAPSHOT_PREFIX}-incr/ } @snapshots ) {
		$incrs[$#incrs] =~ /${SNAPSHOT_PREFIX}-incr-(\d{4});
		$prev_incr = $1;
		$new_incr = $prev_incr + 1;
		$new_incr = sprintf ("%05d", $new_incr);
	}
	else {
		$new_incr = "0001"
	}
	
	
}

sub snapshot_and_send {
	my $ss_name = shift;
	
}