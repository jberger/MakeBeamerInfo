package App::makebeamerinfo;

use strict;
use warnings;

use Cwd 'abs_path';
use File::Basename;
use File::Find;

use Text::Balanced qw/extract_bracketed extract_multiple/;

our $VERSION = "2.002";
$VERSION = eval $VERSION;

use App::makebeamerinfo::Transitions;

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
    transitions => {}, #holder for all available transition sets

    options => {
      # set option to collapse AtBeginSection 
      #  and AtBeginSubsection elements (default true)
      collapse => 1,
      transition_set => undef,
    },
  };

  # pull files from arguments if present
  $self->{files}{pdf} = abs_path($args->{pdf}) if $args->{pdf};
  $self->{files}{nav} = abs_path($args->{nav}) if $args->{nav};

  bless $self, $class;

  $self->_setup_standard_transition_sets;

  $self->transition_set( $args->{transition_set} || 'default' );

  $self->_hunt_for_files;

  return $self;
  
}

sub _setup_standard_transition_sets {
  my $self = shift;
  $self->add_transition_set('all', ':all');
  $self->add_transition_set('default', ':default');
  $self->add_transition_set('none', ':none');
  $self->add_transition_set(
    'turn', 
    increment => ["WipeRight"],
    frame => ["PageTurn"],
  );

  # the "most" transition set sorts the available transitions 
  #  into the two uses as appropriate for a beamer presentation
  $self->add_transition_set(
    'most', 
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
    / ],
  );
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

#=========================
# Transition set helpers

sub add_transition_set {
  my $self = shift;
  my $name = $_[0];
  return $self->{transitions}{$name} = App::makebeamerinfo::Transitions->new( @_ );
}

sub transition_set {
  my $self = shift;
  if ( my $name = shift ) {
    my $trans = $self->{transitions}{$name} || die "Unknown transition set $name\n";
    $self->{options}{transition_set} = $trans;
  }
  return $self->{options}{transition_set}->name
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
  my $trans = $self->{options}{transition_set};

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
      && ! $trans->default_frame
    ) {
      print $info "\t  \'transition\': " . $trans->get_random_element . ",\n";
    }
    print $info "\t},\n";
  }
  print $info "}\n";
  unless ( $trans->default_increment ) {
    print $info "AvailableTransitions = [";
    print $info join( ", ", $trans->get_selected('increment') );
    print $info "]";
  }
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

The test suite is improving, but still not excellent coverage. Continuing this is important.

=back

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/MakeBeamerInfo>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


