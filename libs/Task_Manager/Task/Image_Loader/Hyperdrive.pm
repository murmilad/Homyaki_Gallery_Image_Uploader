#
#===============================================================================
#
#         FILE: Camera.pm
#
#  DESCRIPTION: Camera media loader
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Alexey Kosarev (murmilad), 
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 29.09.2013 22:01:39
#     REVISION: ---
#===============================================================================
package Homyaki::Task_Manager::Task::Image_Loader::Hyperdrive;

use base 'Homyaki::Task_Manager::Task::Image_Loader::Abstract_Loader';

use POSIX;
use File::Find;

use strict;
use warnings;
 
use constant LOADER_NAME => 'hyperdrive';
use constant SOURCE_PATH => '/media/BIGBASE_';

sub new {
	my $class = shift;

	my %h = @_;
	my $params = $h{params};

	my $self = $class->SUPER::new(params => $params);


	my $source_dir = &SOURCE_PATH;
	my $result_dirs = [];

	if (opendir(my $dh, $source_dir)({
		my @source_dirs = grep { /^SOURCE_(\d+)/ && -d "$source_dir/$_" } readdir($dh);
    	closedir $dh;
		foreach $dir (@source_dirs) {

			push(@{$result_dirs},{
				source => $dir,
				date   => POSIX::strftime("%d%m%y",localtime((stat $dir)[9])),
				size   => $size,
			});
		}
	}

	
	return $result_dirs;  
}

sub is_ready_for_load {
	my $self = shift;
	my $port = shift;

	my $size;
	find(sub{ -f and ( $size += -s ) }, &SOURCE_PATH . '/' . $port);
	$size = sprintf("%.02f",$size / 1024);

	my $free_space = `df --block-size=1K /home/ | awk '{print \$4}' | tail -1`;

	my $not_enough = $size + 500000 - $free_space;

	if ($not_enough > 0) {
		$self->{error} = "Not enough free space $not_enough Kb";
		return 0;
	} else {
		return 1;
	}
}

sub get_errors {
	my $self = shift;

	return join("\n", @{$self->{errors}});
}

sub get_sources {
	my $self = shift;

	my $sources = [];
	if (scalar(@{$self->{ports}}) > 0){
		$sources = map {{name => $_->{name}, source => $_->{port}, loader => &LOADER_NAME}} @{$self->{ports}};
	}

	return $sources;
}

sub download {
	my $self = shift;

	my %h          = @_;

	my $directory    = $h{directory};
	my $source       = $h{source};
	Homyaki::Logger::print_log("USBport: $source");	

	if ($source =~ /^usb:((\d{3}),(\d{3}))?/){
		my $bus    = $2 || '\d+';
		my $device = $3 || '\d+';
		my $processes = `lsof | grep /dev/bus/usb`;
		foreach my $process_str (split("\n", $processes)){
			if ($process_str =~ /[\w-]+\s+(\d+)\s+.*\/dev\/bus\/usb\/$bus\/$device/){

				#gvfsd-gph 20535       alex    7r      CHR    189,147        0t0     261134 /dev/bus/usb/002/020
				#lsof | grep usb

				Homyaki::Logger::print_log("sudo kill -9 $1");	
				`sudo kill -9 $1`;
			}
		}
	}

	my $files_count = `gphoto2 -L --port '$source' | tail -n 1 | awk '{print \$1}'`;
	$files_count =~ s/\D//g;


	for (my $i = 1; $i <= $files_count; $i++){
		my $i_string = sprintf("%05d", $i);
		`cd $directory; sudo gphoto2 --filename=${i_string}_\%f.\%C --get-file $i-$i --port '$source';`;
		if ($self->{progress_handler}){
			$self->{progress_handler}(sprintf("%d", $i/$files_count*70));
		}
	}

	return 1;
}

1;