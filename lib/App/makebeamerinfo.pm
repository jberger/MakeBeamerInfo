package App::makebeamerinfo;

use strict;
use warnings;

use Cwd 'abs_path';
use File::Spec;
use File::Find;

our $VERSION = v2.0;
$VERSION = eval $VERSION;

#list of the available transitions
my @available_transitions = ( qw/
  Crossfade
  None
  PagePeel PageTurn
  SlideDown SlideLeft SlideRight SlideUp
  SpinOutIn SpiralOutIn
  SqueezeDown SqueezeLeft SqueezeRight SqueezeUp
  WipeBlobs
  WipeCenterIn WipeCenterOut
  WipeUp WipeDown WipeLeft WipeRight
  WipeDownRight WipeUpLeft
  ZoomOutIn
/ );

# the "clean" transition set is a basic set useful in all circumstances
my %clean = (
  increment => ["WipeRight"],
  frame => "PageTurn"
);

# the "sane" transition set sorts the available transitions 
#  into the two uses as appropriate for a beamer presentation
my %sane = (
  increment => [ qw/
    WipeCenterIn WipeCenterOut
    WipeUp WipeDown WipeLeft WipeRight
    WipeDownRight WipeUpLeft
  / ],
  frame => [ qw/
    Crossfade
    PagePeel PageTurn
    SlideDown SlideLeft SlideRight SlideUp
    SpinOutIn SpiralOutIn
    SqueezeDown SqueezeLeft SqueezeRight SqueezeUp
    WipeBlobs
    ZoomOutIn
  / ]
);

#==========================
# Builder methods

sub new {
  my $class = shift;
  my $args = ref $_[0] ? shift() : { @_ };

  my $self = {
    files    => {}, #holder for file name etc.
    pages    => {}, #holder for page information from nav file
    sections => {}, #holder for section information
    transitions => undef,  #initialized later

    # holder for making sure that the next random transition
    #  is not the same as the last
    last_transition => '',

    options => {
      # set option to collapse AtBeginSection 
      #  and AtBeginSubsection elements (default true)
      collapse => 1,
      # set_transition default to clean
      transition_set => 'clean',
    },
  };

  # pull files from arguments if present
  $self->{files}{pdf} = abs_path($args->{pdf}) if $args->{pdf};
  $self->{files}{nav} = abs_path($args->{nav}) if $args->{nav};

  bless $self, $class;

  $self->_init_transitions;
  $self->_hunt_for_files;

  return $self;
  
}

sub _init_transitions {
  my $self = shift;

  # Initialize Hash of the custom transitions set 
  #  from array of available transitions
  my %transitions;
  foreach my $trans (@available_transitions) {
    $transitions{'increment'}{$trans} = 0;
    $transitions{'frame'}{$trans} = 0;
  }

  # set some base selections for the 'custom' set
  foreach my $trans (@{ $clean{'increment'} }) {
    $transitions{'increment'}{$trans} = 1;
  }
  foreach my $trans (@{ $sane{'frame'} }) {
    $transitions{'frame'}{$trans} = 1;
  }

  $self->{transitions} = \%transitions;
}

sub _hunt_for_files {
  my $self = shift;
  my $files = $self->{files};

  if (! $files->{pdf} and $files->{nav}) {
    $files->{pdf} = $self->findFile( $files->{nav} );
  }

  if (! $files->{nav} and $files->{pdf}) {
    $files->{nav} = $self->findFile( $files->{pdf} );
  }
}

#==========================
# common message methods

# Sub that displays "about" information
# Possibly to be deprecated and replaced with a version sub and a usage sub
sub aboutMBI {
  my $self = shift;
  $self->userMessage(
    "About MakeBeamerInfo",
    "Version: $VERSION"
  );
}

# Sub (mostly for GUI) to display an exit message and quit before attempting to create an info file
sub exitProgramEarly {
  my $self = shift;
  $self->userMessage(
    "Goodbye",
    "No .info file has been created!"
  );
  exit(1);
}

# Sub that after creation of an info file files, says goodbye and quits
sub exitProgramFinished {
  my $self = shift;
  $self->userMessage(
    "Goodbye",
    "Your .info file has been created."
  );
  exit();
}

#============================
# Methods for finding and opening files

# method that takes the full path of a specified file 
#  and returns the other file if possible
sub findFile {
  my $self = shift;

  # burst the full file path into pieces
  my $full_path = shift;
  my ($vol,$path,$file) = File::Spec->splitpath( $full_path );

  my $file_to_find = $file;
  if ($file =~ /\.nav$/) {
    $file_to_find =~ s/\.nav$/\.pdf/;
  } elsif ($file =~ /\.pdf$/) {
    $file_to_find =~ s/\.pdf$/\.nav/;
  } 

  my $found = '';
  my $wanted = sub { 
    return if $found;
    if ($_ eq $file_to_find) {
      $found = $File::Find::name;
    }
  };
  find( $wanted , File::Spec->catpath($vol,$path) );

  return $found;
}

sub openFile {
  my $self = shift;
  my ($filename, $type, $mode) = @_;

  unless ($filename) {
    $self->userMessage(
      "Error",
      "Please specify a .$type file."
    );
    $self->exitProgramEarly();
  } 

  my $handle;
  unless ( open($handle, $mode, $filename) ) {
    $self->userMessage(
      "Error",
      "Could not open $filename: $!"
    );
    $self->exitProgramEarly();
  }

  return $handle;
}

#============================
# Subs that perform the "meat" of the work

# super-sub that controls all the actions to generate info file
sub createInfo {
  my $self = shift;
  $self->readNav();
  $self->writeInfo();
  $self->exitProgramFinished();
}

# sub to read the nav file. The information is fed into %pages and %sections.
# by reading twice we are able to use the collapse relate frames (declared after sections) and sections
sub readNav {
  my $self = shift;

  # if a handle is given as an arg use it. This is for testing.
  my $nav = @_ ? shift :
    $self->openFile($self->{files}{'nav'}, 'nav', '<');

  my $pages = $self->{pages};
  my $sections = $self->{sections};
  my $collapse = $self->{options}{collapse};

  # first read through the nav file for framepages
  while (<$nav>) {
    if( /framepages {(\d+)}{(\d+)}/ ) {
      for ( my $i = $1; $i < $2; $i++) {
        $pages->{$i} = { page => $i, type => 'increment' };
      }
      $pages->{$2} = { page => $2, type => 'frame' };
    }
  }
  # go back to the top of the .nav file
  seek($nav,0,0); 
  # then read the file again to determine other information
  while (<$nav>) {
    if( /\\sectionentry {(\d+)}{([^\}]+)}{(\d+)}/ ) {
      $sections->{$1}{'page'} = $3;
      $sections->{$1}{'title'} = $2;
      $pages->{$3}{'is_section'} = $1;
    }
    if( /\@subsectionentry {\d+}{(\d+)}{(\d+)}{(\d+)}{([^\}]+)}/ ) {
      $pages->{$3}{'is_subsection'} = $2;
      $pages->{$3}{'of_section'} = $1;
      $sections->{$1}{$2}{'page'} = $3;
      $sections->{$1}{$2}{'title'} = $4;
      if ($collapse and $sections->{$1}{'page'} == ($3 - 1)) {
        $pages->{ $sections->{$1}{'page'} }{'to_collapse'} = 1;
      }
    }
  }
}

sub writeInfo {
  my $self = shift;

  # if a handle is given as an arg use it. This is for testing.
  my $info = @_ ? shift : 
    $self->openFile($self->{files}{'pdf'} . '.info', 'info', '>');

  my $pages = $self->{pages};
  my $sections = $self->{sections};
  my $options = $self->{options};

  print $info "PageProps = {\n";
  foreach my $page (sort { $a <=> $b } keys %$pages) {
    print $info "  " . $pages->{$page}{page} . ":\t{\n";
    if ($pages->{$page}{'type'} eq 'increment' || $pages->{$page}{'to_collapse'}) {
      print $info "\t  \'overview\': False,\n";
    }
    if ($pages->{$page}{'is_section'}) {
      print $info "\t  \'title\': \"" . $sections->{ $pages->{$page}{'is_section'} }{'title'} . "\",\n";
    } elsif ($page == 1) {
      print $info "\t  \'title\': \"Title\",\n";
    }
    if ($pages->{$page}{'is_subsection'}) {
      print $info "\t  \'title\': \"" . $sections->{ $pages->{$page}{'of_section'} }{'title'} . ": " . $sections->{ $pages->{$page}{'of_section'} }{ $pages->{$page}{'is_subsection'} }{'title'} . "\",\n";
    }
    if (
      $pages->{$page}{'type'} eq 'frame' 
      && ! $pages->{$page}{'to_collapse'} 
      && $options->{'transition_set'} ne 'default'
    ) {
      print $info "\t  \'transition\': " . $self->getFrameTransition() . ",\n";
    }
    print $info "\t},\n";
  }
  print $info "}\n";
  unless ($options->{'transition_set'} eq 'default') {
    print $info "AvailableTransitions = [";
    print $info join(", ", $self->getOverallTransitions());
    print $info "]";
  }
}

#============================
# Subs that select certain transitions in certain cases

sub getFrameTransition {
  my $self = shift;

  my $options = $self->{options};

  my $result;
  if ($options->{'transition_set'} eq 'custom') { 
    $result = $self->getRandomElement(
      $self->get_selected( $self->{transitions}{'frame'} )
    );
  } elsif ($options->{'transition_set'} eq 'clean') {
    $result = $clean{'frame'};
  } elsif ($options->{'transition_set'} eq 'sane') {
    $result = $self->getRandomElement( @{ $sane{'frame'} } );
  }
  return $result;
}

sub getOverallTransitions {
  my $self = shift;

  my $options = $self->{options};

  my @result;
  if ($options->{'transition_set'} eq 'custom') {
    @result = $self->get_selected( $self->{transitions}{'increment'} );
  } elsif ($options->{'transition_set'} eq 'clean') {
    @result = @{ $clean{'increment'} };
  } elsif ($options->{'transition_set'} eq 'sane') {
    @result = @{ $sane{'increment'} };
  }
  return @result;
}

#============================
# Simple methods to perform actions with data structures

# return the contents of a random element of an array
sub getRandomElement {
  my $self = shift;
  my @input = @_;
  my $length = @input;

  my $rand = int(rand($length));
  my $return = $input[$rand];

  # prevent repeated transitions
  while ($length > 1 && $return eq $self->{last_transition}) {
    $rand = int(rand($length));
    $return = $input[$rand];
  }

  $self->{last_transition} = $return;
  return $return;
}

# get the hash keys whose values are true
sub get_selected {
  my ($self, $input) = @_;
  return grep { $input->{$_} } keys %$input;
}


1;

