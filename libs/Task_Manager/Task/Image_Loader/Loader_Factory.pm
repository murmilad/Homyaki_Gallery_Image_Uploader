package Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory;

use strict;

use Exporter;

use Data::Dumper;

use base 'Homyaki::Factory';

use constant LOADERS_ORDER => [
	'hyperdrive',
	'camera',
];

use constant LOADER_HANDLER_MAP   => {
	camera     => 'Homyaki::Task_Manager::Task::Image_Loader::Camera',
	hyperdrive => 'Homyaki::Task_Manager::Task::Image_Loader::Hyperdrive',
};

@Homyaki::Tag::ISA = qw(Exporter);
@Homyaki::Tag::EXPORT = qw{
	&LOADERS_ORDER
	&LOADER_HANDLER_MAP
};

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
			$this->require_handler(&LOADER_HANDLER_MAP->{$loader_name});
		};

		$loader = &LOADER_HANDLER_MAP->{$loader_name}->new(
			params => $params,
		) unless $@;
	}

	return $loader;
}
1;
