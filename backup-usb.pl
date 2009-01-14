#!/usr/bin/perl -w
use strict;

my $MAIN_POOL 		= "tank";
my $GPG_CMD 		= "/opt/csw/bin/gpg -e --recipient EB1968E0";
my $SNAPSHOT_PREFIX	= "backup-usb";
my $backup_path		= "/backup-usb-1/filerbak";

my @EXCLUDE = qw|
tank/iscsi
tank/swap
tank/tmp
|;

unless (-d $backup_path) {
	die "$backup_path does not exist! quitting..";
}

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
		warn "no full backup of $fs, making one now..\n";
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
		my $prev_fs_s = ($prev_incr eq 'full') ? "$fs\@${SNAPSHOT_PREFIX}-full" : "$fs\@${SNAPSHOT_PREFIX}-incr-$prev_incr";
		$zfs_send = "zfs send -i $prev_fs_s $fs\@$snapshot";
		unless (check_all_incrs_present($fs, $prev_incr, $backup_path)) {
			warn "Not all incrementals are present on $backup_path. Skipping backup!";
			return 0;
		}
	}
	else {
		$zfs_send = "zfs send $fs\@${snapshot}";
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

sub send_snap {
	my $fs = shift;
	my $incr = shift;
	my $prev_incr = shift || 0;
	
}

sub syscmd {
	my $cmd = shift;
	print "running: $cmd\n\n";
	system($cmd)==0 || die $!;
}

sub check_all_incrs_present {
	my $fs = shift;
	my $highest_expected = shift;
	my $backup_path = shift;
	
	my $ret = 1;
	
	my $fs_s = "$fs\@${SNAPSHOT_PREFIX}";
	
	unless (-e "$backup_path/${fs_s}-full.zfs.gpg") {
		warn "Full backup file for $fs does not exist on $backup_path";
		$ret = 0;
	}
	
	if ($highest_expected eq 'full') {
		return $ret;
	}
	
	foreach (0001 .. $highest_expected) {
		my $incr = sprintf ("%05d", $_);
		
		unless (-e "$backup_path/${fs_s}-incr-${incr}.zfs.gpg") {
			warn "Increment $incr does not exist for $fs on $backup_path";
			$ret = 0;	
		}
	}
	
	return $ret;
}
