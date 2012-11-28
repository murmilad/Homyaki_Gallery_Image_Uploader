package Homyaki::Task_Manager::Task::Image_Loader;

use strict;

use File::stat;

use Homyaki::Task_Manager;
use Homyaki::Task_Manager::DB::Task_Type;

use Homyaki::Task_Manager::DB::Task;
use Homyaki::Task_Manager::DB::Constants;

use Homyaki::GPS::Log;
use Homyaki::System::USB;

use Homyaki::Gallery::Group_Processing;

use Homyaki::Logger;

use constant BASE_IMAGE_PATH      => '/home/alex/Share/Photo/';
use constant GARMIN_GPX_PATH      => '/media/GARMIN/Garmin/GPX/';
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
	
		`sudo chown -R alex:alex $directory_path`;

		if (-d &GARMIN_GPX_PATH) {
			Homyaki::GPS::Log::update_images(&GARMIN_GPX_PATH, $directory_path);
		}

		my @task_types = Homyaki::Task_Manager::DB::Task_Type->search(
			handler => 'Homyaki::Task_Manager::Task::Auto_Rename'
		);

		if (scalar(@task_types) > 0) {

			my $task = Homyaki::Task_Manager->create_task(
				task_type_id => $task_types[0]->id(),
				modal        => 1,
			);
		}

	}

	$result->{task} = {
		params => $params,
	};

	return $result;
}

1;

