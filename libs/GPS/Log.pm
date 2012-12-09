package Homyaki::GPS::Log;

use XML::Simple qw(XMLin);
use Data::Dumper;
use Image::ExifTool;
use File::Find;
use Imager;
use DateTime;
use POSIX qw(floor);
use Homyaki::Logger;

use constant EXIF_GPS_DATA_MAP => {
		GPSLatitude         => 'GPS',
		GPSLatitudeRef      => 'GPS',
		GPSLongitude        => 'GPS',
		GPSLongitudeRef     => 'GPS',
		GPSAltitude         => 'GPS',
		GPSAltitudeRef      => 'GPS',
		GPSMapDatum         => 'GPS',
		GPSImgDirection     => 'GPS',
		GPSImgDirectionRef  => 'GPS',
		GPSDateTime         => 'XMP'
};

use constant LOCAL_TIME_SHIFT => 3;

use constant STAY_PERIOD_HOUR         => 6;
use constant MAX_INTARVAL_PERIOD_HOUR => 7;

sub dd2dms {
	my $dd = shift;
	# print "$dd\n";
	my $minutes = ($dd - floor($dd)) * 60.0;
	my $seconds = ($minutes - floor($minutes)) * 60.0;
	$minutes = floor($minutes);
	my $degrees = floor($dd);
	return $degrees.",".$minutes.",".$seconds;
}

sub dt_to_DateTimeOriginal($){
	my ($dt) = @_;
	return undef unless defined $dt;

	my $DateTimeOriginal = $dt;
	$DateTimeOriginal =~ s/T/ /;
	$DateTimeOriginal =~ s/Z$//;
	$DateTimeOriginal =~ s/-/:/g;
	return $DateTimeOriginal;
}

sub improve_time_gps_hash {
	my $time_gps_hash = shift;


	my $prev_time_epoch = 0;
	foreach my $time_epoch (sort {$a <=> $b} keys %{$time_gps_hash}){
		$prev_time_epoch = $time_epoch-1 unless $prev_time_epoch;

		if ($time_epoch != $prev_time_epoch + 1) {
			my $ele_str   = $time_gps_hash->{$prev_time_epoch}->{ele};
			my $lat_str   = $time_gps_hash->{$prev_time_epoch}->{lat};
			my $lon_str   = $time_gps_hash->{$prev_time_epoch}->{lon};
			my $speed_str = $time_gps_hash->{$prev_time_epoch}->{speed};
			my $dt_str    = $time_gps_hash->{$prev_time_epoch}->{dt};
			my $big_range_time_epoch = 0;
			if (&STAY_PERIOD_HOUR && $time_epoch - $prev_time_epoch > &STAY_PERIOD_HOUR * 60 * 60){
				$big_range_time_epoch = $time_epoch;
				$time_epoch = $prev_time_epoch + &STAY_PERIOD_HOUR * 60 * 60;
			}

			if ($time_epoch - $prev_time_epoch < &MAX_INTARVAL_PERIOD_HOUR * 60 * 60) {
				for (1; $time_epoch != $prev_time_epoch; $prev_time_epoch++){
					$time_gps_hash->{$prev_time_epoch}->{ele}   = $ele_str;
					$time_gps_hash->{$prev_time_epoch}->{lat}   = $lat_str;
					$time_gps_hash->{$prev_time_epoch}->{lon}   = $lon_str;
					$time_gps_hash->{$prev_time_epoch}->{speed} = $speed_str;
					$time_gps_hash->{$prev_time_epoch}->{dt}    = $dt_str;
				}
			}

			if ($big_range_time_epoch) {
				$time_epoch = $big_range_time_epoch;
			}
			$prev_time_epoch = $time_epoch;

		}
	}

	return $time_gps_hash;
}

sub create_time_gps_hash {
	my $gpx_path      = shift;
	my $time_gps_hash = shift;
	my $time_shift    = shift;


	my $str_gpx;

	if (open (HOSTS, $gpx_path)){
		while (my $str = <HOSTS>) {
			$str_gpx .= $str;
		};
		close HOSTS;

		my $content_xml;
		eval {$content_xml = XMLin($str_gpx)};	
		if ($@){
			print $@;
		}
		if ($content_xml){
			my $time = DateTime->new(
			year   => 1964,
			month  => 10,
			day    => 16,
			hour   => 16,
			minute => 12,
			second => 47,
			);
			my $tracks = [];
			if ($content_xml->{trk}->{trkseg}) {
				$content_xml->{trk}->{'the_first'}->{trkseg} = $content_xml->{trk}->{trkseg};
			}
			foreach my $track (keys %{$content_xml->{trk}}){


				foreach my $track_seg (ref($content_xml->{trk}->{$track}->{trkseg}) eq 'HASH' ? ($content_xml->{trk}->{$track}->{trkseg}) : @{$content_xml->{trk}->{$track}->{trkseg}}){
				foreach my $track_point (ref($track_seg->{trkpt}) eq 'HASH' ? ($track_seg->{trkpt}) : @{$track_seg->{trkpt}}){
					my $time_str  = $track_point->{'time'};
					my $ele_str   = $track_point->{'ele'};
					my $lat_str   = $track_point->{'lat'};
					my $lon_str   = $track_point->{'lon'};
					my $speed_str = $track_point->{'speed'};
#					Homyaki::Logger::print_log('Track = ' . Dumper($track_point));

					#2010-05-07T16:29:02Z
					if ($time_str =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d{3})?Z/) {
						$time->set(
							year   => $1,
							month  => $2,
							day    => $3,
							hour   => $4,
							minute => $5,
							second => $6,
						)->add( hours => &LOCAL_TIME_SHIFT );


						$time_gps_hash->{$time->epoch() + $time_shift} = {
							ele   => $ele_str,
							lat   => $lat_str,
							lon   => $lon_str,
							speed => $speed_str,
							dt    => $time_str
						};
					}
				}
			}
			}
		}
	} else {
		print $@;
	}

	return $time_gps_hash;
}

sub copy_gps_tags {
	my $image_path   = shift;
	my $exifTool     = shift;
	my $nefExifTool  = shift;

	my $nef_path = $image_path;
	$nef_path =~ s/\.jpg$/\.NEF/i;
	$nef_path =~ s/acoll_\d{7}_//;

	if (-f $nef_path){
		my $ImageInfo = $exifTool->ImageInfo($image_path);
		$exifTool->ExtractInfo($image_path, $ImageInfo);

		my $nefInfo = $nefExifTool->ImageInfo($nef_path);
		$nefExifTool->ExtractInfo($nef_path, $nefImageInfo);
	
		my $updated = 0;
		foreach my $exif_param (keys %{&EXIF_GPS_DATA_MAP}) {
			if ($ImageInfo->{$exif_param}) {
				$updated = 1;
				print qq{write $nef_path EXIF $exif_param:} . $ImageInfo->{$exif_param} . qq{\n};
				$nefExifTool->SetNewValue(
					$exif_param,
					$ImageInfo->{$exif_param},
					&EXIF_GPS_DATA_MAP->{$exif_param}
				);
			}
		}
	
		if ($updated) {
			$nefExifTool->WriteInfo($nef_path);
		}
		
	}
}

sub set_gps_tag_to_jpeg {
	my $gpx_data   = shift;
	my $image_path = shift;
	my $exifTool   = shift;

	if ($gpx_data && scalar(keys %{$gpx_data}) > 0) {

		my $ImageInfo = $exifTool->ImageInfo($image_path);
		$exifTool->ExtractInfo($image_path, $ImageInfo);
		
#		print Dumper($ImageInfo);

		my $img_date = $ImageInfo->{DateTimeOriginal};
		if ($img_date =~ /(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})/) {
			my $time = DateTime->new(
				year   => $1,
				month  => $2,
				day    => $3,
				hour   => $4,
				minute => $5,
				second => $6,
			);

			my $gpx_image_data = $gpx_data->{$time->epoch()};

			if ($gpx_image_data) {
				print Dumper($gpx_image_data);

print $image_path  . " GPSLatitude: " . $ImageInfo->{GPSLatitude} . "\n";
				if (exists($ImageInfo->{GPSLatitude})){
					$exifTool->SetNewValue('GPSLatitude',dd2dms(abs($gpx_image_data->{lat})),'GPS');
					if ($gpx_image_data->{lat} > 0) {
						$exifTool->SetNewValue('GPSLatitudeRef','N','GPS');
					} else {
						$exifTool->SetNewValue('GPSLatitudeRef','S','GPS');
					}
				} else {
					$exifTool->SetNewValue('GPSLatitude',dd2dms(abs($gpx_image_data->{lat})),'GPS');
					if ($gpx_image_data->{lat} > 0) {
						$exifTool->SetNewValue('GPSLatitudeRef','N','GPS');
					} else {
						$exifTool->SetNewValue('GPSLatitudeRef','S','GPS');
					}
				}
print $image_path  . " GPSLongitude: " . $ImageInfo->{GPSLongitude} . "\n";
				if (exists($ImageInfo->{GPSLongitude})){
					$exifTool->SetNewValue('GPSLongitude',dd2dms(abs($gpx_image_data->{lon})),'GPS');
					if ($gpx_image_data->{lon} > 0) {
						$exifTool->SetNewValue('GPSLongitudeRef','E','GPS');
					} else {
						$exifTool->SetNewValue('GPSLongitudeRef','W','GPS');
					}
				} else {
					$exifTool->SetNewValue('GPSLongitude',dd2dms(abs($gpx_image_data->{lon})),'GPS');
					if ($gpx_image_data->{lon} > 0) {
						$exifTool->SetNewValue('GPSLongitudeRef','E','GPS');
					} else {
						$exifTool->SetNewValue('GPSLongitudeRef','W','GPS');
					}
				}
				$exifTool->SetNewValue('GPSDateTime', dt_to_DateTimeOriginal($gpx_image_data->{dt}) ,'XMP');
				$exifTool->SetNewValue('GPSAltitude', $gpx_image_data->{ele}, 'GPS');
				if ($gpx_image_data->{ele} > 0){
					$exifTool->SetNewValue('GPSAltitudeRef', 'Above Sea Level', 'GPS');
				} else {
					$exifTool->SetNewValue('GPSAltitudeRef', 'Below Sea Level', 'GPS');
				}

				# Write map datum to WGS84.
				$exifTool->SetNewValue('GPSMapDatum','WGS-84','GPS');

				# Write destination bearing.
				$exifTool->SetNewValue('GPSImgDirection',0,'GPS');
				$exifTool->SetNewValue('GPSImgDirectionRef','T','GPS');

				$exifTool->WriteInfo($image_path);
				print "Updated $image_path\n";
			} else {
				print "There are no GPX data for $image_path\n";
			}
		}
	}
}

sub get_images_list {
	my $source_path = shift;
	my $mask        = shift;

	print $source_path . "\n";

	my $file_list = [];
	find(
		{
			wanted => sub {
				my $image_path = $File::Find::name;
				if (-f $image_path && $image_path =~ /$mask/i) {
					push(@{$file_list}, $image_path);
				}
			},
			follow => 1
		},
		$source_path
	);

	return $file_list;
}

sub get_tag_data {
	my $tags     = shift;
	my $tag_name = shift;

	return unless $tags;

	foreach (@{$tags}){
		return $_->[1] if $_->[0] eq $tag_name
	}
}

sub load_gpx_dir {
	my $current_path   = shift;
	my $gpx_data       = shift;
	my $time_shift     = shift;

	if (-f $current_path) {
		create_time_gps_hash($current_path, $gpx_data, $time_shift);
	} elsif (-d $current_path) {
		opendir(my $dh, $current_path);
		foreach my $sub_path (grep { !/^\.\./ && !/^\./ } readdir($dh)){
			load_gpx_dir($current_path . '/' . $sub_path, $gpx_data, $time_shift);
		}
	}
}

sub update_images{
	my $gpx_data_path = shift;
	my $images_path   = shift;
	my $time_shift    = shift;

	my $gpx_data = {}; 

	load_gpx_dir($gpx_data_path, $gpx_data, $time_shift);
	improve_time_gps_hash($gpx_data);


	if (scalar(keys(%{$gpx_data})) > 0) {
		my $images_list = get_images_list($images_path, '\.jpg$|\.nef$');
		my $exifTool    = new Image::ExifTool;

		foreach my $image_path (@{$images_list}) {
			print "begin $image_path\n";
			set_gps_tag_to_jpeg($gpx_data, $image_path, $exifTool);
		}
	}
}

sub update_exif_gps_data {
	my $images_path   = shift;

	my $images_list = get_images_list($images_path, '\.jpg$');
	my $exifTool    = new Image::ExifTool;
	my $nefExifTool = new Image::ExifTool;

	foreach my $image_path (@{$images_list}) {
		copy_gps_tags($image_path, $exifTool, $nefExifTool);
	}
	
}

1;
__END__

my $command     = $ARGV[0];

if ($command eq '-g'){

	my $gpx_path    = $ARGV[1];
	my $images_path = $ARGV[2];

	update_images($gpx_path, $images_path);
} elsif ($command eq '-u'){
	
	my $images_path = $ARGV[1];

	update_exif_gps_data($images_path);
}

