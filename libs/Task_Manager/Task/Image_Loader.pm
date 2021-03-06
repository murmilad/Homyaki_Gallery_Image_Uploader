package Homyaki::Task_Manager::Task::Image_Loader;

use strict;

use File::stat;
use DateTime; 
use Data::Dumper;
use File::Find;

use Homyaki::Task_Manager;
use Homyaki::Task_Manager::DB::Task_Type;

use Homyaki::Task_Manager::DB::Task;
use Homyaki::Task_Manager::DB::Constants;

use Homyaki::GPS::Log;

use Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory;

use Homyaki::Gallery::Group_Processing;

use Homyaki::Logger;

use constant BASE_IMAGE_PATH      => '/home/alex/Share/Photo/';
use constant GARMIN_GPX_PATH      => '/Garmin/GPX/';
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
		my $progress_changed;
		my $loader = Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory->create_loader(
			loader_name      => $loader_name,
			progress_handler => sub {
				my $current_percent = shift;

				if ($progress_changed != $current_percent) {
					$task->set('progress', $current_percent);
					$task->update();
					$progress_changed = $current_percent;
				}
			},
		);
		if ($loader) {
			push(@{$loaders}, $loader);


			my $current_sources =  $loader->get_sources();


			map {$sources->{$_->{source}} = {source => $_, loader => $loader}} @{$current_sources};
		}
	}

	my $directory_path;

	Homyaki::Logger::print_log('load_dvice: ' . $params->{device});
	Homyaki::Logger::print_log('load_dvice: ' . Dumper($sources));
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
		Homyaki::Logger::print_log('loader: ' . Dumper($loader));

		if ($loader) {
			if ($loader->is_ready_for_load($params->{device})) {
				my $source_files_count = $loader->get_source_files_count($params->{device}); 
				my $source_files_size  = $loader->get_source_files_size($params->{device}); 
				if ($source_files_count && $source_files_count > 0) {
					$loader->download(
						directory        => $directory_path,
						source           => $params->{device},
					);
					my $files_count = 0;
					find(sub{ -f and ( $files_count++ ) }, $directory_path);
					if ($source_files_count != $files_count) {
						return {
							error  => 'Not all files was copied! ' . $source_files_count - $files_count . ' files was lost.',
							result => {
								params => $params,
							}
						};
					} elsif ($source_files_size) {
						my $sizes = `ls -kl $directory_path | awk '{print \$5}'`;
						my $size; $size += $_ for grep { /^\d+$/}  split("\n", $sizes);
						
						if ($size < $source_files_size){
							return {
								error  => 'Not all files was correctly copied! ' . $source_files_size - $size . 'Kb was lost.',
								result => {
									params => $params,
								}
							};
						}
					}
				} else {
					return {
						error  => 'Cant get files count!',
						result => {
							params => $params,
						}
					};
				}
			} else {
				return {
					error  => $loader->get_errors(),
					result => {
						params => $params,
					}
				};
			}
		}
	
		`sudo chown -R alex:alex $directory_path`;
		`sudo chmod -R 775 $directory_path`;


	}

	for (my $i=0; $i <= 10; $i++){
		if (-d "/media/usb$i" . &GARMIN_GPX_PATH) {
			Homyaki::GPS::Log::update_images( "/media/usb$i" . &GARMIN_GPX_PATH, $directory_path || &DOWNLOAD_IMAGE_PATH, $params->{time_shift});
		}
	}

	if ($params->{device}) {

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

#Homyaki::GPS::Log::update_images( "/media/usb1" . &GARMIN_GPX_PATH, '/home/alex/Share/Photo/zzd_2013_Canarias_Autumn/2013_10_15__16_53_37_Canarias_1/', -4 * 60);
