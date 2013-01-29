use strict;
use warnings;

use Getopt::Long;
use Data::Dump qw(pp);

use Chart::StarCoordinates;

my $draw_cv;
my $draw_circle;
my $input_filename;
my $output_filename;
my $dimension_labels_first_row;
my $arg_result=GetOptions ("draw_cv"=>\$draw_cv, "draw_circle"=>\$draw_circle, 
                           "in_file=s" => \$input_filename, "out_file=s" => \$output_filename,
                            "dimension_labels_first_row"=>\$dimension_labels_first_row);

my $sv=Chart::StarCoordinates->new({"draw_cv"=>$draw_cv, "draw_circle"=>$draw_circle, 
                                "input_filename" => $input_filename, "output_filename" => $output_filename,
                                "dimension_labels_first_row"=>$dimension_labels_first_row});