#
#===============================================================================
#
#         FILE: Abstract_Loader.pm
#
#  DESCRIPTION: Abstract class for media loaders
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
package Homyaki::Task_Manager::Task::Image_Loader::Abstract_Loader;


use strict;
use warnings;
 
sub new {

	my $this = shift;
	my %h = @_;

	my $params = $h{params};

	my $self = {};
	my $class = ref($this) || $this;

	bless $self, $class;

	$self->{progress_handler} = $params->{progress_handler};
	$self->{errors}           = [];

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

	return [];
}

sub download {
	my $self = shift;

	if ($self->{progress_handler}){
		$self->{progress_handler}('100%');
	}

	return 1;
}

1;
