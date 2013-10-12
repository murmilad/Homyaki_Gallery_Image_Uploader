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
use File::Copy;

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

	if (opendir(my $dh, $source_dir)){
		my @source_dirs = grep { /^SOURCE_(\d+)/ && -d "$source_dir/$_" } readdir($dh);
    	closedir $dh;
		foreach my $dir (@source_dirs) {

			push(@{$result_dirs},{
				source => $dir,
				date   => POSIX::strftime("%d%m%y",localtime((stat $dir)[9])),
			});
		}
		$self->{sorces} = $result_dirs;
	}

	
	return $self;  
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
		$sources = map {{name => "$_->{source} ($_->{date})", source => $_->{source}, loader => &LOADER_NAME}} @{$self->{sources}};
	}

	return $sources;
}

sub download {
	my $self = shift;

	my %h          = @_;

	my $directory    = $h{directory};
	my $source       = $h{source};
	Homyaki::Logger::print_log("Path: $source");	

	my $path = &SOURCE_PATH;

	if (-d "$path/$source"){
		my $files_count = 0;
		find(sub{ -f and ( $files_count++ ) }, &SOURCE_PATH . '/' . $source);

		my $index = 0;
		find(sub{
			if (-f) {
				$index++;
				my $filename = $File::Find::name;
				copy($_, "$directory/${index}_$filename");
				if ($self->{progress_handler}){
					$self->{progress_handler}(sprintf("%d", $index/$files_count*70));
				}
			}
		}, "$path/$source");
	}

	return 1;
}

1;
