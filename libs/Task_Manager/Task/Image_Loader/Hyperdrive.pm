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

use Homyaki::Logger;
use Data::Dumper;

use strict;
use warnings;
 
use constant LOADER_NAME => 'hyperdrive';

sub new {
	my $class = shift;

	my %h = @_;
	my $params = $h{params};

	my $self = $class->SUPER::new(params => $params);


	my $result_dirs = [];

	for (my $i=0; $i <= 10; $i++){
		my $source_dir = "/media/usb$i";
		if (-d $source_dir) {
			if (opendir(my $dh, $source_dir)){
				Homyaki::Logger::print_log('source_dir: ' . $source_dir);
				my @source_dirs = grep { /SPACE\d+/ && -d "$source_dir/$_" } readdir($dh);
		    	closedir $dh;
				foreach my $dir (@source_dirs) {

					push(@{$result_dirs},{
						source => "$source_dir/$dir",
						date   => POSIX::strftime("%d.%m.%y",localtime((stat "$source_dir/$dir")[9])),
						name   => "($i)$dir"
					});
				}
				$self->{sources} = $result_dirs;
			} else {
				Homyaki::Logger::print_log('dir open error: ' . $!);
			}
		}
	}
	Homyaki::Logger::print_log('sources: ' . Dumper($self->{sources}));
	
	return $self;  
}

sub is_ready_for_load {
	my $self = shift;
	my $port = shift;

	my $size;
	find(sub{ -f and ( $size += -s ) }, $port);
	$size = sprintf("%.02f",$size / 1024);

	Homyaki::Logger::print_log('source size: ' . $size);
	my $free_space = `df --block-size=1K /home/ | awk '{print \$4}' | tail -1`;

	Homyaki::Logger::print_log('free_space: ' . $free_space);
	my $not_enough = $size + 500000 - $free_space;

	if ($not_enough > 0) {
		push(@{$self->{errors}}, "Not enough free space $not_enough Kb");
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

	my @sources;
	if ($self->{sources} && scalar(@{$self->{sources}}) > 0){
		@sources = map {{name => "$_->{name} ($_->{date})", source => $_->{source}, loader => &LOADER_NAME}} @{$self->{sources}};
	}

	return \@sources;
}

sub download {
	my $self = shift;

	my %h          = @_;

	my $directory    = $h{directory};
	my $source       = $h{source};
	Homyaki::Logger::print_log("Path: $source");	


	if (-d $source){
		my $files_count = 0;
		find(sub{ -f and ( $files_count++ ) }, $source);

		my $index = 0;
		find(sub{
			if (-f) {
				$index++;
				my $filename = $_;
				copy($File::Find::name, "$directory/${index}_$filename");
				print 'ph' . $self->{progress_handler};
				if ($self->{progress_handler}){
					$self->{progress_handler}(sprintf("%d", $index/$files_count*70));
				}
			}
		}, $source);
	}

	return 1;
}

1;
