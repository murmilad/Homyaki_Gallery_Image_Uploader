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
package Homyaki::Task_Manager::Task::Image_Loader::Camera;

use base 'Homyaki::Task_Manager::Task::Image_Loader::Abstract_Loader';

use strict;
use warnings;
 
use Homyaki::System::USB;

use constant LOADER_NAME => 'camera';

sub new {
	my $class = shift;

	my %h = @_;
	my $params = $h{params};

	my $self = $class->SUPER::new(params => $params);


	my $devices = Homyaki::System::USB->new();
	$devices->load_devices();

	my $ports = $devices->get_camera_ports();
	$self->{ports} =  $ports;

	return $self;  
}

sub is_ready_for_load {
	my $self = shift;

	return 1;
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
