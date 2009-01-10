#!/usr/bin/perl -w
use strict;

my $MAIN_POOL =		"tank";
my $GPG_CMD =		"/opt/csw/bin/gpg";
my $SNAPSHOT_PREFIX =	"backup-usb";
my $BACKUP_PATH	=	"/backup-usb-1/filerbak"

my @EXCLUDE = qw| tank/swap tank/iscsi tank/tmp |;

my @filesystems = `zfs list -o name -H -r tank`;

foreach (@EXCLUDE) {
	@filesystems = grep { ! /$_/ } @filesystems;
}

FS: foreach my $fs (@filesystems) {
	my $prev_incr = "";
	my $new_incr;
	my @snapshots = `zfs list -r -t snapshot $fs`;
	@snapshots = sort grep { /^${fs}\@backup-usb/ } @snapshots;
	
	unless ( grep { /\@${SNAPSHOT_PREFIX}-full/ } @snapshots ) {
		warn "no full backup!";
		print "Would make full backup snapshot and delete any incrementals here!\n";
		next FS;
	}
	
	if ( my @incrs = sort grep { /\@${SNAPSHOT_PREFIX}-incr/ } @snapshots ) {
		$incrs[$#incrs] =~ /\@${SNAPSHOT_PREFIX}-incr-(\d{4})/;
		$prev_incr = $1;
		$new_incr = $prev_incr + 1;
		$new_incr = sprintf ("%05d", $new_incr);
	}
	else {
		$new_incr = "0001"
	}
	
	my $new_snapshot = "${SNAPSHOT_PREFIX}-incr-${new_incr}";
	snapshot_and_send($fs, $new_snapshot, $prev_incr || 'full');
	
	
	
}

sub snapshot_and_send {
	my $fs = shift;
	my $snapshot = shift;
	my $prev_incr = shift || 0;
	
	syscmd("zfs snapshot $fs\@$snapshot");
	
	my $zfs_send;
	if ($prev_incr) {
		$zfs_send = "zfs send -i $fs\@${SNAPSHOT_PREFIX}-incr-$prev_incr $fs\@$snapshot";
		
	}
	else {
		$zfs_send = "zfs send $fs\@snapshot";
	}
	
	my $backup_file = "$fs\@$snapshot" =~ s|/|_|g;
	$cmd = "$zfs_send | $GPG_CMD > $backup_path/$backup_file";
	
}