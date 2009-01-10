#!/usr/bin/perl -w
use strict;

my $MAIN_POOL 		= "tank";
my $GPG_CMD 		= "/opt/csw/bin/gpg";
my $SNAPSHOT_PREFIX	= "backup-usb";
my $backup_path		= "/backup-usb-1/filerbak";

my @EXCLUDE = qw|
tank/iscsi
tank/swap
tank/tmp
|;

my @filesystems = `zfs list -o name -H -r tank`;
chomp @filesystems;
print join (', ', @filesystems); print "\n";

foreach my $exc (@EXCLUDE) {
#	print "_: $_\n";
#	print grep { ! m|^$_| } @filesystems;
	@filesystems = grep { ! m|^$exc| } @filesystems;	
}
print "\n";
print @filesystems;

FS: foreach my $fs (@filesystems) {
	#print "fs: $fs";
	my $prev_incr = "";
	my $new_incr;
	my @snapshots = `zfs list -r -t snapshot $fs`;
	@snapshots = sort grep { /^${fs}\@backup-usb/ } @snapshots;
	
	unless ( grep { /\@${SNAPSHOT_PREFIX}-full/ } @snapshots ) {
		warn "no full backup!";
		snapshot_and_send($fs, "${SNAPSHOT_PREFIX}-full");
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
	
	my $backup_file = "$fs\@$snapshot";
	$backup_file =~ s|/|_|g;
	$backup_file .= ".zfs.gpg";
	
	if (-e "$backup_path/$backup_file") {
		warn "snapshot $backup_path/$backup_file already exists, skipping..";
		return 0;
	}
	syscmd ("$zfs_send | $GPG_CMD > $backup_path/$backup_file");
	
}

sub syscmd {
	my $cmd = shift;
	#system($cmd)==0 || die $!;
	print "would execute: $cmd\n\n";
}