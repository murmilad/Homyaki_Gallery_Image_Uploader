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

use base 'Homyaki::Task_Manager::Task::Image_Loader::USB_Storage';

use POSIX;
use File::Find;
use File::Copy;

use Homyaki::Logger;
use Data::Dumper;

use strict;
use warnings;
 
use constant LOADER_NAME       => 'hyperdrive';
use constant SOURCE_PATH       => '';
use constant SOURCE_DIR_REGEXP => '^SPACE\d+$';

1;
