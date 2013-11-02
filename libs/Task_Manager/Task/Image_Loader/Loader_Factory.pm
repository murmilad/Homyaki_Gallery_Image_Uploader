package Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory;

use strict;

use Exporter;
use vars qw(@ISA @EXPORT $VERSION);

use Data::Dumper;
use Homyaki::Logger;

use Homyaki::Factory;

use constant LOADERS_ORDER => [
	'usb_storage',
	'hyperdrive',
	'camera_sd',
	'camera',
];

use constant LOADER_HANDLER_MAP   => {
	camera      => 'Homyaki::Task_Manager::Task::Image_Loader::Camera',
	usb_storage => 'Homyaki::Task_Manager::Task::Image_Loader::USB_Storage',
	camera_sd   => 'Homyaki::Task_Manager::Task::Image_Loader::Camera_SD',
	hyperdrive  => 'Homyaki::Task_Manager::Task::Image_Loader::Hyperdrive',
};

@ISA    = qw(Exporter);
@EXPORT = qw(
	&LOADERS_ORDER
	&LOADER_HANDLER_MAP
);

sub create_loader{
    my $this = shift;

	my %h = @_;
	my $loader_name      = $h{loader_name};
	my $progress_handler = $h{progress_handler};
	my $loader;

	if (&LOADER_HANDLER_MAP->{$loader_name}){

		my $params = {
			progress_handler => $progress_handler
		};

		eval {
			Homyaki::Factory->require_handler(&LOADER_HANDLER_MAP->{$loader_name});
		};
		Homyaki::Logger::print_log('loader error:' . $@) if $@;
		$loader = &LOADER_HANDLER_MAP->{$loader_name}->new(
			params => $params,
		) unless $@;
	}

	return $loader;
}
1;
