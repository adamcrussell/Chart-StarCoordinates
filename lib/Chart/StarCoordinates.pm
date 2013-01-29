=begin lip

=head1 NAME

Chart::StarCoordinates - Generate StarCoordinates plots 

=head1 IMPLEMENTATION

=head2 OVERVIEW

Data is transformed using the StarCoordinates algorithm:

=over 4

=item 0

Calculate the minimum and maximum values for each dimension.

=item 1

Dimensional anchors placed

In the most basic case anchors are placed equidistantly on a unit circle. Here we also allow for 
arbitrary placement.

=item 2

Scaling transformation

Scale each of the dimensional vectors.

=item 3

Star Coordinates plot

A plot is created. This is done via Chart-Gnuplot.

=back 4

=head2 CODE

=cut 

=head3 Package Chart::StarCoordinates;

=cut

package Chart::StarCoordinates;

=head3 Includes

Note that B<Lip::Pod> is not used directly but, rather, necessary for generating the internal documentation.
However, it is explicitly use-d to make sure anyone using this module gets it.

C<COLORS>  and the other "color" constants are based on colors which have been defined by gnuplot 
and are used when creating the plot.

=cut

use 5.006;
use strict;
use warnings; 
use Lip::Pod;

use FileHandle;
use List::MoreUtils;
use Data::Dump qw(pp);  
use Chart::Gnuplot .16; 
use List::Util qw(reduce);
use Math::Trig qw(deg2rad rad2deg);
use constant MAXINT => 2**32;
use constant MININT => -1*MAXINT;
use constant PI     => 4 * atan2(1, 1);

use constant LINE_TYPE  => 1;
use constant POINT_TYPE => 26;#5;
use constant DATA_COLOR => "green";#"orange";
use constant CIRCLE_COLOR => "black";
use constant LABEL_POINTTYPE => 26;
use constant COLORS => ("yellow","steelblue","turquoise","red","purple","orchid","olive","bisque","chartreuse");

=head3 Exported Symbols

No symbols are exported. The entire interface to this module is the constructor new()
and it is best to use the full package specification when calling this: C<Chart::StarCoordinates-E<gt>new()>.

=cut

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw();
our $VERSION = '0.01';

=head3 new()

The constructor C<new()> sets the attributes as defined (most default to empty or undef). Also, most
importantly, data is read in and normalized. Then the C<create()> subroutine is called to generate 
the plot.

=cut

sub new{
    my ($pkg,$attr)=@_;
    my %attributes=%$attr;

    my $self={};
    
    $self->{data}=[];#raw data
    $self->{scaled}=[];
    $self->{scaled_vectors}={};#scaled coordinate vectors
    $self->{anchors}={};#The locations of the dimensional anchors keyed by dimension (or dimension label)
    $self->{maximums}=[];#max value for each dimension
    $self->{minimums}=[];#min value for each dimension
    $self->{dimension}=undef;#of dimensions
    
    bless($self,$pkg);
    %$self=%attributes;
    
    $self->create;
    
    return $self;

}

=head3 create()

Rather than place this code in the constructor C<new()> it has been put in its own subroutine in order
to break out logic surrounding the creation of the plots from the basic setup code.

=cut

sub create{
    my($self)=@_;
    $self->read_data;
    $self->find_local_minimums_maximums;
    $self->place_dimensional_anchors_equidistant_on_unit_circle;
    $self->scale_dimensional_vectors;
    $self->transform_data;
    $self->plot_starcoordinates;
}

=head3 read_data()

Read data in from a file. The only acceptable file format is strictly defined as:

=over 8

=item *

The data file must be tab seperated with data in columns. That is, each colum represents a dimension.

Missing data is not handled by this module. Data is assumed to be exactly as specified. It is the user's
responsibility to ensure data is correctly formatted before it is passed to this module.

=item *

The first row may be dimension labels and the first column may be class labels.

=item *

Element 0,0 may be anything (usually descriptive text) and is ignored.

=back 8

Data in any other format will cause errors and/or incorrect results.

=cut

sub read_data{
    my ($self)=@_;

    my @u;#raw data 
    my $n=-1;#count of records 
    my $line;
    my @dim_labels;
    my ($d_cur,$d_pre)=(-1,-1);
    open(DATA_IN,$self->{input_filename})|| die("Cannot open input file $!");
    if($self->{dimension_labels_first_row}){
        $line=<DATA_IN>;
        @dim_labels=split(/\t/,$line);
        shift @dim_labels;#item 0,0 is going to be junk so throw it out
        $self->{dim_labels}=\@dim_labels;
    }
    while($line=<DATA_IN>){
        $n++;
        chomp($line);  
        my @fields=split(/\t/,$line); 
        if($n==0){
            $d_cur=$#fields;
            $d_pre=$d_cur;
        }
        else{
            $d_pre=$d_cur;
            $d_cur=$#fields;
        }
        foreach my $j (0..$d_cur){
            if(defined $fields[$j]){
                $u[$n][$j]=$fields[$j];
            }
        }
    } 
    $self->{data}=\@u;
    $self->{dimension}=$d_cur+1;#$d_cur is the last index in fields so we need to add 1
    close(DATA_IN);
}

=over 8

At the end of C< read_data() > we will have:

=item *

Populated C< $self-E<gt>{data}> with the raw data. This is a 2d data structure. d1 represents a row of the
data. d2 are the columns.

=item *

C<$self-E<gt>{dimension}> contains the number of dimensions (columns) of data.

=back 8

=cut

=head3 C<find_local_minimums_maximums()>

Finds the minimum and maximum value for each dimension.

=cut

sub find_local_minimums_maximums{
    my ($self)=@_;
    
    my $n=0;    
    my @minimums;
    my @maximums;
    foreach (0..$self->{dimension}-1){
        $minimums[$_]=MAXINT;
        $maximums[$_]=MININT;
    }
    my $data_count =()= @{$self->{data}};#goatse operator!
    while($n <= $data_count-1){   
        foreach my $i (0..($self->{dimension}-1)){  
            foreach my $row ($self->{data}[$n]){
                my $val = @{$row}[$i];  
                if($val < $minimums[$i]){
                    $minimums[$i]=$val;  
                }
                if($val > $maximums[$i]){
                    $maximums[$i]=$val;  
                }
            }    
        } 
        $n++;   
    }   
    $self->{minimums}=\@minimums;  
    $self->{maximums}=\@maximums;
}     

=over 8

At the end of C< find_local_minimums_maximums() > we will have:

=item *

Populated C<$self-E<gt>{minimums}> with the minimums for each dimension.

=item *

Populated C<$self-E<gt>{maximums}> with the maximums for each dimension.

=back 8

=cut

=head3 C<scale_dimensional_vectors()>

Perform the scaling transformation on the dimensional vectors.

=cut

sub scale_dimensional_vectors{
    my($self)=@_;
    my %scaled_vectors=();
    foreach my $d (1..$self->{dimension}){
        my $t=$self->{anchors}->{$d};
        my $u_x=$t->[0]/($self->{maximums}->[$d-1] - $self->{minimums}->[$d-1]);
        my $u_y=$t->[1]/($self->{maximums}->[$d-1] - $self->{minimums}->[$d-1]);
        $scaled_vectors{$d}=[$u_x,$u_y];
    }
    $self->{scaled_vectors}=\%scaled_vectors;   
} 

=head3 C<transform_data()>

Perform the Star Coordinates transformation on the data. 

=cut

sub transform_data{
    my($self)=@_;
       
    my @scaled_values;
    my $row_count =()= @{$self->{data}};
    foreach my $row (0..$row_count-1){
        my $sum_x=0;
        my $sum_y=0;
        foreach my $d (1..$self->{dimension}){
            my $u_x=$self->{scaled_vectors}->{$d}->[0];
            my $u_y=$self->{scaled_vectors}->{$d}->[1];      
            $sum_x=$sum_x+($u_x * ($self->{data}->[$row]->[$d-1] - $self->{minimums}->[$d-1]));
            $sum_y=$sum_y+($u_y * ($self->{data}->[$row]->[$d-1] - $self->{minimums}->[$d-1]));
        }
        $scaled_values[$row][0]=$sum_x;
        $scaled_values[$row][1]=$sum_y;
    }
    $self->{scaled}=\@scaled_values;
}    

sub place_dimensional_anchors_equidistant_on_unit_circle{
    #returns the position of the dimensional anchors on the unit circle
    #in cartesian x=r cos(q), y=r sin(q) co-ordinates
    #These values are stored in a hash where (key,value)=(label,[x,y])
    my($self)=@_;
    
    my %anchors=();
    my $theta=(2*PI)/$self->{dimension};#angle in radians
    foreach my $d (1..$self->{dimension}){
        $theta=$theta-deg2rad(.5);#-deg2rad(rand(15));
        my $r=1;#rand(11)+0;
        $anchors{"$d"}=[$r*cos($theta*$d),$r*sin($theta*$d)];
    }
    $self->{anchors}=\%anchors;
}

sub plot_starcoordinates{
    my($self)=@_;
    
    my $starviz=Chart::Gnuplot->new(title    => undef,
                                   border   => undef,
                                   legend   => undef,
                                   xtics    => undef,
                                   ytics    => undef,
                                   xlabel   => undef,
                                   ylabel   => undef,
                                   tmargin  => 0,
                                   bmargin  => 0,
                                   xrange   => [-1.5,1.5],
                                   yrange   => [-1.5,1.5],
                                   size     => "square",
                                   output   => $self->{output_filename});
    my %circle;
    $circle{x}="sin(t)";
    $circle{y}="cos(t)";         
    my $circle = Chart::Gnuplot::DataSet->new(func     => \%circle, 
                                              color    => CIRCLE_COLOR, 
                                              linetype => LINE_TYPE);
    
    my @xdata=map{$_->[0]} @{$self->{scaled}};
    my @ydata=map{$_->[1]} @{$self->{scaled}};
    my $dataSet0=Chart::Gnuplot::DataSet->new(pointtype => POINT_TYPE,
                                              pointsize => .25,
                                              color     => DATA_COLOR,
                                              xdata     => \@xdata,
                                              ydata     => \@ydata);
    #in order to get the labels just right we need to fiddle around a bit
    #with the label justification, rotation, and offset...
    my %palette=();
    my $text_color;
    my $offset="0,0"; 
    my $color_index=0;                                         
    my $rotation_angle=0;
    my $label_justification;                                   
    
	$offset="1.5,1"; 
	my $x;
	my $y;
	my $x_first;
	my $y_first;
	my $x_prev=MININT;
	my $y_prev=MININT;
	foreach my $label (sort {$a <=> $b} keys %{$self->{anchors}}){
	    #First draw the coordinate vectors
	    $starviz->arrow(from     => "0,0",
				   to       => "$self->{anchors}->{$label}->[0],$self->{anchors}->{$label}->[1]",
				   linetype => LINE_TYPE,
				   head     => "off",
				   color    => CIRCLE_COLOR);
	    #Now fiddle with the labels
		if(!$x && !$y){
			$x_first=$self->{anchors}->{$label}->[0];
			$y_first=$self->{anchors}->{$label}->[1];
			$x=$x_first;
			$y=$y_first;
		}
		else{
			$x=$self->{anchors}->{$label}->[0];
			$y=$self->{anchors}->{$label}->[1];
		}
		$label_justification="center";
		if($y<0 && $x<0){#offset differently for labels based on position (by quadrant).
		   $offset="-1.5,-1";
		}
		if($y>0 && $x<0){
		   $offset="-1.25,1";
		}
		if($y<0 && $x>0){
		   $offset="1.75,-.15";
		}
		if($y>0 && $x>0){
		   $offset="1.25,1";
		}
		#temp
		$label--;
		#temp
		$starviz->label(pointtype  => LABEL_POINTTYPE,
					   position   => "$x, $y");            
		$starviz->label(text => "D$label",
				 position   => "$x, $y $label_justification",
				 offset     => $offset);
		if($self->{draw_cv} && $x_prev > MININT){
			$starviz->arrow(from     => "$x,$y",
						   to       => "$x_prev,$y_prev",
						   linetype => LINE_TYPE,
						   head     => "off",
						   color    => CIRCLE_COLOR);
		}
		$x_prev=$x;
		$y_prev=$y;
	}
    $starviz->plot2d($dataSet0);#,$circle);
}

1;

=end lip

=cut

__END__
=pod

=head1 NAME

Chart::StarCoordinates - Perl implementation of the Star Coordinates data visualization algorithm

=head1 SYNOPSIS

  use Chart::StarCoordinates;
  Chart::StarCoordinates->new(%OPTIONS);

=head1 DESCRIPTION

Perl implementation of the Star Coordinates data visualization algorithm

=head2 EXPORT

C<new()>

=head1 SEE ALSO

For more on Star Coordinates, see this paper L<http://dl.acm.org/citation.cfm?id=502530> is a good place to start.

The code for this module is available at L<http://www.cs.uml.edu/~arussell/starcoordinates_code.html>.

The following reference is recommended for anyone interested in learning more about Gnuplot (in particular, the options which
are exposed via the Chart::Gnuplot module used here).
Philipp K. Janert. 2009. Gnuplot in Action: Understanding Data with Graphs. Manning Publications Co., Greenwich, CT, USA.

=head1 TODO

=over

=item Expand on tests

The module tests should be more encompassing.

=item Write cookbook

Show a number of examples of this module in use.

=back

=head1 AUTHOR

Adam Russell, E<lt>ac.russell@live.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Adam Russell

This work may be distributed and/or modified under the conditions of the 
LaTeX Project Public License, either version 1.3 of this license or (at your option) any later 
version. The latest version of this license is in L<http://www.latex-project.org/lppl.txt>
and version 1.3 or later is part of all distributions of LaTeX version 2005/12/01 or later.
This work has the LPPL maintenance status `maintained'. The Current Maintainer of this 
work is Adam Russell. This work consists of the files listed in MANIFEST.

=cut
