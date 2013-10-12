package Homyaki::Task_Manager::Task::Image_Loader;

use strict;

use File::stat;
use DateTime; 

use Homyaki::Task_Manager;
use Homyaki::Task_Manager::DB::Task_Type;

use Homyaki::Task_Manager::DB::Task;
use Homyaki::Task_Manager::DB::Constants;

use Homyaki::GPS::Log;

use Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory;

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

	my $loaders = [];
	my $sources = {};
	
	foreach my $loader_name (@{&LOADERS_ORDER}) {
		my $loader = Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory->create_loader(
			loader_name      => $loader_name,
			progress_handler => sub {
				my $current_percent = shift;

				$task->set('progress', "uploading: $current_percent");
				$task->update();
			},
		);
		if ($loader) {
			push(@{$loaders}, $loader);


			my $current_sources =  $loader->get_sources();


			map {$sources->{$_->{source}} = {source => $_, loader => $loader}} @{$current_sources};
		}
	}

	my $directory_path;

	if ($params->{device} &&  $sources->{$params->{device}}->{loader}) {
	
		my $index;

		my $now = DateTime->now();
		my $dir_name = $now->ymd("_") . "__" . $now->hms("_") . "_" . $params->{dir_name};

		while (-d &DOWNLOAD_IMAGE_PATH . "/${dir_name}$index"){
			$index++;
		}

		my $directory_path = &DOWNLOAD_IMAGE_PATH . "/${dir_name}$index";

		mkdir($directory_path);
		my $loader = $sources->{$params->{device}}->{loader};

		if ($loader) {
			if ($loader->is_ready_for_load) {
				$loader->download(
					directory        => $directory_path,
					source           => $params->{device},
				);
			} else {
				$params->{error} = $loader->get_errors();
			}
		}
	
		`sudo chown -R alex:alex $directory_path`;
		`sudo chmod -R 775 $directory_path`;


	}

	if (-d &GARMIN_GPX_PATH) {
		Homyaki::GPS::Log::update_images(&GARMIN_GPX_PATH, $directory_path || &DOWNLOAD_IMAGE_PATH, $params->{time_shift});
	}

	if ($params->{device} &&  $sources->{$params->{device}}->{loader}) {

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

