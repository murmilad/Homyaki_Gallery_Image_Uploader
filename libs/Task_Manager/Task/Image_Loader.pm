package Homyaki::Task_Manager::Task::Image_Loader;

use strict;

use File::stat;

use Homyaki::Task_Manager::DB::Task;
use Homyaki::Task_Manager::DB::Constants;
use Homyaki::System::USB;

use Homyaki::Gallery::Group_Processing;

use Homyaki::Logger;

use constant BASE_IMAGE_PATH      => '/home/alex/Share/Photo/';
use constant DOWNLOAD_IMAGE_PATH  => &BASE_IMAGE_PATH . '/0New';

sub start {
	my $class = shift;
	my %h = @_;
	
	my $params = $h{params};
	my $task   = $h{task};

	my $result = {};

	
	my $devices = Homyaki::System::USB->new();
	$devices->load_devices();

	my $ports = $devices->get_camera_ports();

	if (scalar(@{$ports}) > 0 && $params->{device}) {
	
		my $index;
		while (-d &DOWNLOAD_IMAGE_PATH . "/$params->{dir_name}$index"){
			$index++;
		}

		my $directory_path = &DOWNLOAD_IMAGE_PATH . "/$params->{dir_name}$index";

		mkdir($directory_path);

		$devices->download_photo(
			directory => $directory_path,
			port      => $params->{device},
		);

		Homyaki::Gallery::Group_Processing->process(
			handler => 'Homyaki::Processor::Gallery_Unic_Name',
			params  => {
				images_path   => &BASE_IMAGE_PATH,
			},
		);

		`sudo chown -R alex:alex $directory_path`;
	}

	$result->{task} = {
		params => $params,
	};

	return $result;
}

1;

