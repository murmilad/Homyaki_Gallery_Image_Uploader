package Homyaki::System::USB;
#
#===============================================================================
#
#         FILE: USB.pm
#
#  DESCRIPTION: Load usb devices data
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Alexey Kosarev (murmilad), 
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 23.10.2012 22:27:06
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use	Homyaki::Logger;
sub new {
	my $this = shift;

	my %h = @_;

	my $self = {};

	my $class = ref($this) || $this;
	bless $self, $class;

	return $self;
}

sub load_devices {
	my $self = shift;

	my $devices_txt  = `lsusb -v`;
	my $devices_hash = {};

	my $bus    = '';
	my $device = '';
	my $path   = [];
	foreach my $devices_str (split("\n", $devices_txt)) {
		#Bus 003 Device 003: ID 09da:000a A4 Tech Co., Ltd Port Mouse
		if ($devices_str =~ /^Bus\s+(\d{3})\s+Device\s+(\d{3}):\s+ID\s+([a-fA-F0-9:]{9})\s+(.*)$/){
			$bus    = $1;
			$device = $2;
			$devices_hash->{$bus}->{$device}->{id}     = $3;
			$devices_hash->{$bus}->{$device}->{name}   = $4;
			$devices_hash->{$bus}->{$device}->{bus}    = $bus;
			$devices_hash->{$bus}->{$device}->{device} = $device;
		} elsif ($devices_str =~ /^(\s*)(.+):$/ ){
			my $spaces     = length($1);
			my $level_name = $2;
			my $value      = $3;
			if ($spaces > scalar(@{$path})) {
				push(@{$path}, $level_name);
			} elsif ($spaces < scalar(@{$path})) {
				for(my $i = 0; $i < scalar(@{$path}) - $spaces; $i++){
					pop(@{$path});
				}
			}
		}

		if (
			$devices_str =~ /^\s+(.+):\s+(.+)\s*$/ 
			|| $devices_str =~ /^\s+(\w+(\s\w+)*)\s\s+(.+)\s*$/
		){
			if (scalar(@{$path}) > 0){
				eval '$devices_hash->{$bus}->{$device}->{\'' .join('\'}->{\'', @{$path}) . '\'}->{$1} = $3 || $2;';
			} else {
				$devices_hash->{$bus}->{$device}->{$1} = $3 || $2;
			}
		}
	}
#	push (@{$self->{devices}}, {});

	$self->{devices} = $devices_hash;
}

sub get_device_by_parameter {
	my $self       = shift;
	my %h          = @_;

	my $parameters = $h{parameters};
	my $result     = [];

	foreach my $bus (keys %{$self->{devices}}){
		foreach my $device (keys %{$self->{devices}->{$bus}}){
			my $absent_parameters = \%{$parameters};

			$self->absent_parameters(
				parameters => $absent_parameters,
				node       => $self->{devices}->{$bus}->{$device},
			);

			if (scalar(keys %{$absent_parameters}) == 0) {
				push(@{$result}, {bus => $bus, device => $device});
			}
		}
	}

	return $result;
}

sub absent_parameters {
	my $self       = shift;
	my %h          = @_;

	my $parameters = $h{parameters};
	my $node       = $h{node};

	if (keys %{$parameters}) {
		foreach my $param_name (keys %{$node}){
			if (ref $node->{$param_name} eq 'HASH') {
				$self->absent_parameters(
					parameters => $parameters,
					node       => $node->{$param_name}
				);
			} elsif (defined($parameters->{$param_name})){
				if ($node->{$param_name} eq $parameters->{$param_name}){
					delete($parameters->{$param_name})
				}
			}	
		}
	}
}

sub get_camera_ports {
	my $self       = shift;
	my %h          = @_;

	my $port_list = [];

	my $ports_str =  `sudo gphoto2  --auto-detect`;

	foreach my $port_str (split("\n", $ports_str)) {
		if ($port_str =~ /(disk|usb|serial):(.+[^\s])\s*$/){
			my $port_name = "$1:$2";
			
			push(@{$port_list}, {
				name => $port_name,
				port => $port_name,
			});
		}
	}

	if (scalar(@{$port_list}) == 0){
		foreach my $port_str (split("\n", $ports_str)) {
			if ($port_str =~ /(disk|usb|serial):\s*$/){
				my $port_name = "$1:";
				push(@{$port_list}, {
					name => $port_name,
					port => $port_name,
				});
			}

		}
	}

	return $port_list;
}


sub download_photo {
	my $self       = shift;
	my %h          = @_;

	my $directory    = $h{directory};
	my $port         = $h{port};
	Homyaki::Logger::print_log("USBport: $port");	

	if ($port =~ /^usb:((\d{3}),(\d{3}))?/){
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

	return `cd $directory; sudo gphoto2 --force-overwrite --get-all-files --port '$port';`;
}

1;

__END__

use Data::Dumper; 
use Homyaki::System::USB;

my $devices = Homyaki::System::USB->new();
$devices->load_devices();

my $ports = $devices->get_camera_ports();

print Dumper($ports);
$devices->download_photo(directory=>"/tmp", port=>$ports->[0]->{port});

