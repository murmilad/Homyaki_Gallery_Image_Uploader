package Homyaki::Interface::Task_Manager::Image_Loader;

use strict;

use Homyaki::Tag;
use Homyaki::HTML;
use Homyaki::HTML::Constants;

use Homyaki::Logger;
use Data::Dumper;

use Homyaki::Task_Manager;
use Homyaki::Task_Manager::DB::Task;
use FreezeThaw qw(freeze thaw);
use Homyaki::Task_Manager::DB::Task_Type;
use Homyaki::Task_Manager::DB::Constants;

use Homyaki::GPS::Log;
use Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory;
use Homyaki::Task_Manager::Task::Image_Loader;

use Homyaki::Interface::Task_Manager;
use base 'Homyaki::Interface::Task_Manager';


use constant TASK_HANDLER => 'Homyaki::Task_Manager::Task::Image_Loader';
use constant PARAMS_MAP  => {
	time_shift   => {name => 'Time shift for GPS (sec)'            , required => 0, type  => &INPUT_TYPE_NUMBER},
	name         => {name => 'Name of photo directory'             , required => 0, type  => &INPUT_TYPE_TEXT},
	device       => {name => 'Device'                              , required => 0, type  => &INPUT_TYPE_LIST},
};

sub get_tag {
	my $self = shift;
	my %h = @_;

	my $params = $h{params};
	my $errors = $h{errors};
	my $user   = $h{user};

	my $body_tag = $self->SUPER::get_tag(
		params => $params,
		errors => $errors,
		user   => $user,
		header => 'Upload new images to photo base',
	);

	my $form = $body_tag->{body};

	Homyaki::HTML->add_login_link(
		user      => $user,
		body      => $form,
		interface => 'task',
		auth      => 'auth',
		params    => $params,
	);

	$form->add_form_element(
		type   => &INPUT_TYPE_DIV,
		name   => 'srarted',
        value  => $params->{started_list},
	);

	if (scalar(@{$params->{device_list}})) {

		$form->add_form_element(
			type   => &INPUT_TYPE_TEXT,
			name   => 'name',
			header => 'Name of photo directory',
			value  => $params->{name},
			error  => $errors->{name},
		);

        $form->add_form_element(
                type   => &INPUT_TYPE_LIST,
                name   => 'device',
                value  => $params->{device},
                header => 'Device',
                list   => $params->{device_list},
        );

		$form->add_form_element(
			type   => &INPUT_TYPE_DIV,
			name   => 'result',
        	value  => $params->{result},
		);
	
	}

	if (is_garmin_connected() && !$params->{started_list}) {
		$form->add_form_element(
			type   => &INPUT_TYPE_TEXT,
			name   => 'time_shift',
			header => 'Time shift for GPS (sec)',
			value  => $params->{time_shift},
			error  => $errors->{time_shift},
		);
	}

	if (scalar(@{$params->{device_list}}) || (is_garmin_connected() && !$params->{started_list})) {
		$form->add_form_element(
			type   => &INPUT_TYPE_SUBMIT,
			name   => 'submit_button',
		);
	}

	my $tasks_form = $body_tag->{body}->add_form(
		interface => $params->{interface},
 		form_name => $params->{form},
 		form_id   => 'tasks_form',
	);

	return {
		root => $body_tag->{root},
		body => $form,
	};
}

sub is_garmin_connected {
	my $gps_path = Homyaki::Task_Manager::Task::Image_Loader->GARMIN_GPX_PATH;

	return `sudo ls $gps_path` ? 1 : 0;
}

sub get_already_active_tasks{
	my $is_started;

	my @task_types = Homyaki::Task_Manager::DB::Task_Type->search(
		handler => &TASK_HANDLER
	);

	my @tasks = Homyaki::Task_Manager::DB::Task->search({
		task_type_id => $task_types[0]->{id},
		status       => &TASK_STATUS_WAIT,
	});
	push(@tasks, (Homyaki::Task_Manager::DB::Task->search({
		task_type_id => $task_types[0]->{id},
		status       => &TASK_STATUS_PROCESSING,
	})));

	foreach my $task (@tasks) {
		($task->{params}) = thaw($task->{params});
	}

	return \@tasks;
}

sub get_helper {
	my $self = shift;
	my %h = @_;

	my $body   = $h{body};
	my $params = $h{params};
	my $errors = $h{errors};

	$body->add_form_element(
		type   => &INPUT_TYPE_LABEL,
		value  => 'This task copies media from camera to photo base',
	);

	return $body;
}


sub set_params {
	my $this = shift;
	my %h = @_;

	my $params      = $h{params};
	my $user        = $h{user};

	my $result = $params;

	$params->{task_handler} = &TASK_HANDLER;

	if ($params->{device} || is_garmin_connected()) {

		my @task_types = Homyaki::Task_Manager::DB::Task_Type->search(
			handler => &TASK_HANDLER
		);

		if (scalar(@task_types) > 0 && $params->{ip_address} =~ /^172\.16\./) {

			my $task = Homyaki::Task_Manager->create_task(
				task_type_id => $task_types[0]->id(),
				ip_address   => $params->{ip_address},
				name         => $params->{name},
				params => {
					time_shift => $params->{time_shift},
					device     => $params->{device},
					dir_name   => $params->{name},
				}
			);

			$params->{task_id} = $task->id();
		}
	}

	my $parrent_result = $this->SUPER::set_params(
		params      => $params,
		user        => $user,
	);

	return $result;
}


sub get_params {
        my $self = shift;
        my %h = @_;

        my $params      = $h{params};
        my $user        = $h{user};
        my $result      = $params;

	$params->{task_handler} = &TASK_HANDLER;
	if ($params->{task_id} && $params->{ip_address} =~ /^172\.16\./){
		my $task = Homyaki::Task_Manager::DB::Task->retrieve($params->{task_id});

		if ($task){
			my ($task_params) = thaw($task->params());
			$result->{result} = "<br><br>Task started:<br>" . join("<br>", map {"$_ = $params->{$_}"} keys %{$task_params});
		}


	}


	my $started_tasks = get_already_active_tasks();
	my $started_ports = {};
	foreach my $task (@{$started_tasks}) {
		$started_ports->{$task->{params}->{device}} = 1;
	}

	my $sources = [];
	foreach my $loader_name (@{&LOADERS_ORDER}) {
		my $loader = Homyaki::Task_Manager::Task::Image_Loader::Loader_Factory->cteate_loader(
			loader_name      => $loader_name,
		);
		if ($loader) {
			my $current_sources =  $loader->get_sources();
			push(@{$sources}, (@{$current_sources}));
		}
	}
	Homyaki::Logger::print_log(Dumper($sources));

	my $device_list = [];
	my $started_list;

	foreach my $source (@{$sources}) {
		if ($started_ports->{$source->{source}}) {
			$started_list .= "$source->{source} $source->{name} $source->{loader} (started) <br>";
		} else {
			push (@{$device_list}, {name => $source->{name}, id => $source->{source}});
		}
	}

	$result->{device_list}  = $device_list;
	$result->{started_list} = $started_list;
	$result->{started_list} = $started_list;
	$result->{task_handler} = ['Homyaki::Task_Manager::Task::Image_Loader', 'Homyaki::Task_Manager::Task::Auto_Rename'];

	my $parrent_result = $self->SUPER::get_params(
		params      => $params,
		user        => $user,
	);

	@{$result}{keys %{$parrent_result}} = values %{$parrent_result};

        return $result;
}

sub check_params {
        my $self = shift;
        my %h = @_;

        my $params      = $h{params};
        my $user        = $h{user};

        my $errors = {};

	unless ($params->{name} =~ /^[_\w]+$/) {
		$errors->{name}->{param_name} =  'Name of photo directory';
		$errors->{name}->{errors}     =  ['Please enter correct directory name (for example Ducky_Party_2003)'];
	}

	my $parrent_errors = {};
	my $parrent_errors = $self->SUPER::check_params(
		params      => $params,
		user        => $user,
	);

       @{$errors}{keys %{$parrent_errors}} = values %{$parrent_errors};

        return $errors;
}


1;
