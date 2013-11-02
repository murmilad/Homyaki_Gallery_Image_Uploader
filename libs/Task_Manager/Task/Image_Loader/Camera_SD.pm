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
package Homyaki::Task_Manager::Task::Image_Loader::Camera_SD;

use base 'Homyaki::Task_Manager::Task::Image_Loader::USB_Storage';

use POSIX;
use File::Find;
use File::Copy;

use Homyaki::Logger;
use Data::Dumper;

use strict;
use warnings;
 
use constant LOADER_NAME       => 'camera_sd';
use constant SOURCE_PATH       => '';
use constant SOURCE_DIR_REGEXP => '^DCIM$|^NCFL$';

1;
