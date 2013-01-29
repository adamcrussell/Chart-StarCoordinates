use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Chart::StarCoordinates',
    VERSION_FROM      => 'lib/Chart/StarCoordinates.pm', # finds $VERSION
    PREREQ_PM         => {Chart::Gnuplot => .16 ,PDL=>0, PDL::Stats=>0,FileHandle=>0,List::Util=>0}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Chart/StarCoordinates.pm', # retrieve abstract from module
       AUTHOR         => 'Adam Russell <ac.russell@live.com>') : ()),
);
