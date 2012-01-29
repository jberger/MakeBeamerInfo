package App::makebeamerinfo;

use strict;
use warnings;

use Cwd 'abs_path';
use File::Basename;
use File::Find;

use Text::Balanced qw/extract_bracketed extract_multiple/;

our $VERSION = "2.001";
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
    files => { #holder for file names
      pdf => '',
      nav => '',
    },
    pages => {}, #holder for page information from nav file
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

  # set transition_set if specified and valid
  my @transition_sets = qw/default clean sane/;
  if( my $arg_trans = $args->{transition_set} ) {
    if (grep {$arg_trans eq $_} @transition_sets) {
      $self->{options}{transition_set} = $arg_trans;
    } 
  }

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
# Overloadable methods

sub userMessage {
  my $self = shift;
  my ($title, $message) = @_;

}

sub run {
  my $self = shift;
  $self->createInfo;
}

#============================
# Methods for finding and opening files

# method that takes the full path of a specified file 
#  and returns the other file if possible
sub findFile {
  my $self = shift;

  # burst the full file path into pieces
  my $full_path = shift or return '';
  my ($file, $dirs, $suffix) = fileparse( $full_path, '.pdf', '.nav' );

  $file .= ($suffix eq '.pdf') ? '.nav' : '.pdf';

  my $found = '';
  my $wanted = sub { 
    return if $found;
    if ($_ eq $file) {
      $found = $File::Find::name;
    }
  };
  find( $wanted , $dirs );

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
    if( /\\beamer\@framepages\s*/gc ) {
      my ($begin, $end) = tex_parser( $_, 2 );

      for ( my $i = $begin; $i < $end; $i++) {
        $pages->{$i} = { page => $i, type => 'increment' };
      }
      $pages->{$end} = { page => $end, type => 'frame' };
    }
  }
  # go back to the top of the .nav file
  seek($nav,0,0); 
  # then read the file again to determine other information
  while (<$nav>) {
    if( /\\sectionentry\s*/gc ) {
      my ($section, $title, $page) = tex_parser( $_, 3 );

      $sections->{$section}{'page'} = $page;
      $sections->{$section}{'title'} = $title;
      $pages->{$page}{'is_section'} = $section;
    }
    if( /\\beamer\@subsectionentry\s*/gc ) {
      my (undef, $section, $subsection, $page, $title)
        = tex_parser( $_, 5 );

      $pages->{$page}{'is_subsection'} = $subsection;
      $pages->{$page}{'of_section'} = $section;
      $sections->{$section}{$subsection}{'page'} = $page;
      $sections->{$section}{$subsection}{'title'} = $title;
      if ($collapse and $sections->{$section}{'page'} == ($page - 1)) {
        $pages->{ $sections->{$section}{'page'} }{'to_collapse'} = 1;
      }
    }
  }
}

sub tex_parser {
  # this function needs aliased arguments
  # args: ( string with pos at start position, number of matches (optional) )

  # match {} blocks, See Text::Balanced for explaination
  my @fields = extract_multiple( 
    $_[0], [sub { extract_bracketed( $_[0], '{}' ) }], $_[1], 1 
  );

  # strip surrounding {}
  return map { my $f = $_; $f =~ s/^\{//; $f =~ s/\}$//; $f } @fields;
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

__END__
__POD__

=head1 NAME

App::makebeamerinfo - Creates .info file for use with Impressive and LaTeX Beamer

=head1 SYNOPSIS

 use App::makebeamerinfo;
 my $app = App::makebeamerinfo->new();
 $app->run;

=head1 DESCRIPTION

This module and its subclasses serve as the backend for L<makebeamerinfo>. Most users should probably be using that script rather than investigating this module.

=head1 SEE ALSO

=over

=item *

L<makebeamerinfo>

=item *

L<Impressive|http://impressive.sourceforge.net/>

=item *

L<LaTeX Beamer|http://latex-beamer.sourceforge.net/>

=back

=head1 FUTURE PLANS

=over

=item *

Need more tests! Specifically, unit tests. This was my first published script, written before I was aware of such thing. The version 2.0 release was requested by user and as such is still lacking a roundly covering test suite. This should be corrected.

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/MakeBeamerInfo>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


