package App::makebeamerinfo::GUI;

use strict;
use warnings;

use Tk;
use Tk::LabFrame;
use Tk::LabEntry;
use Tk::NoteBook;

use App::makebeamerinfo;
our @ISA = qw/App::makebeamerinfo/;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  #rebless
  bless $self, $class;

  $self->{gui} = $self->create_window;

  return $self;
}

sub userMessage {
  my $self = shift;
  my ($title, $message) = @_;
  $self->{gui}{'mw'} -> messageBox(-title=> $title, -message=> $message);
}

sub run {
  MainLoop();
}

sub create_window {
  #creates Tk window

  my $self = shift;

  my %gui;

  $gui{'mw'} = MainWindow->new;
  $gui{'mw'} -> title( 'Makebeamerinfo' );

  # Create Tabs
  $gui{'nb'} = $gui{'mw'} -> NoteBook() -> pack;
  $gui{'tabs'}{'setup'} = $gui{'nb'} -> add(
    'setup',
    -label => "Setup"
  );
  $gui{'tabs'}{'transitions'} = $gui{'nb'} -> add(
    'transitions',
    -label => "Transitions",
    -state => "disabled" # start disabled if defaulting to use non-custom trans_set
  );

  # Create frame to hold action buttons
  $gui{'frame'}{'actions'} = $gui{'mw'} -> Frame(
    -relief => "raised",
    -borderwidth => 2
  ) -> pack(-fill => 'x');

  # Create action buttons
  $gui{'button'}{'create'} = $gui{'frame'}{'actions'} -> Button(
    -text => "Create .info",
    -command => sub{ $self->createInfo },
  ) -> grid(-row => 1, -column => 1);
  $gui{'button'}{'about'} = $gui{'frame'}{'actions'} -> Button(
    -text => "About MBI",
    -command => sub{ $self->aboutMBI },
  ) -> grid(-row => 1, -column => 2);
  $gui{'button'}{'quit'} = $gui{'frame'}{'actions'} -> Button(
    -text => "Quit",
    -command => sub{ $self->exitProgramEarly },
  ) -> grid(-row => 1, -column => 3);

  # Create Frames for "Setup" page
  $gui{'frame'}{'locations'} = $gui{'tabs'}{'setup'} -> LabFrame(
    -label => "File Locations",
    -labelside => "acrosstop"
  ) -> pack;
  $gui{'frame'}{'transition_set'} = $gui{'tabs'}{'setup'} -> LabFrame(
    -label => "Transition Set",
    -labelside => "acrosstop"
  ) -> pack(-fill => 'x');
  $gui{'frame'}{'other_options'} = $gui{'tabs'}{'setup'} -> LabFrame(
    -label => "Other Options",
    -labelside => "acrosstop"
  ) -> pack(-fill => 'x');

  # Create Frame for "Transitions" page
  $gui{'frame'}{'custom_transitions'} = $gui{'tabs'}{'transitions'} -> LabFrame(
    -label => "Custom Transitions",
    -labelside => "acrosstop"
  ) -> pack(-fill => 'x');

  # Inputs blocks for files
  $gui{'entry'}{'pdf'} = $gui{'frame'}{'locations'} -> LabEntry(
    -label => ".pdf file",
    -labelPack => [-side => "left"],
    -textvariable => \$self->{files}{pdf}
  ) -> grid(-row => 1, -column => 1);
  $gui{'button'}{'pdf'}{'get'} = $gui{'frame'}{'locations'} -> Button(
    -text => "Browse",
    -command => sub { $self->getFile('pdf'); }
  ) -> grid(-row => 1, -column => 2);
  $gui{'button'}{'pdf'}{'clear'} = $gui{'frame'}{'locations'} -> Button(
    -text => "Clear",
    -command => sub { $self->clearFile('pdf'); }
  ) -> grid(-row => 1, -column => 3);
  $gui{'entry'}{'nav'} = $gui{'frame'}{'locations'} -> LabEntry(
    -label => ".nav file",
    -labelPack => [-side => "left"],
    -textvariable => \$self->{files}{nav}
  ) -> grid(-row => 2, -column => 1);
  $gui{'button'}{'nav'}{'get'} = $gui{'frame'}{'locations'} -> Button(
    -text => "Browse",
    -command => sub { $self->getFile('nav'); }
  ) -> grid(-row => 2, -column => 2);
  $gui{'button'}{'nav'}{'clear'} = $gui{'frame'}{'locations'} -> Button(
    -text => "Clear",
    -command => sub { $self->clearFile('nav'); }
  ) -> grid(-row => 2, -column => 3);

  # "Transition Set" items
  my $custom = $self->add_transition_set('custom', ':all');

  my $trans_counter = 1;
  my $selected;
  foreach my $trans ( sort { $a->name cmp $b->name } values %{ $self->{transitions} } ) {
    my $name = $trans->name;
    my $state    = $name eq 'custom'  ? 'normal' : 'disabled';

    $selected = $trans + 0 if $name eq 'all';

    my $command = sub {
      $self->{options}{'transition_set'} = $trans;
      $gui{'nb'} -> pageconfigure('transitions', -state => $state);
    };
    
    $gui{'radio'}{$name} = $gui{'frame'}{'transition_set'} -> Radiobutton(
      -command => $command,
      -variable => \$selected,
      -value => $trans + 0,
    ) -> grid(-row => $trans_counter, -column => 1);
    $gui{'label'}{$name} = $gui{'frame'}{'transition_set'} -> Label(
      -text => ucfirst($name)
    ) -> grid(-row => $trans_counter++, -column => 2);

  }

  # "Other options" items
  $gui{'check'}{'collapse'} = $gui{'frame'}{'other_options'} -> Checkbutton(
    -variable => \$self->{options}{collapse},
    -onvalue => 1,
    -offvalue => 0
  ) -> grid(-row => 1, -column=> 1);
  $gui{'label'}{'collapse'} = $gui{'frame'}{'other_options'} -> Label(
    -text => "Collapse automatically generated\noutline pages at the simultaneous\nstart of a section and a subsection"
  ) -> grid(-row => 1, -column=> 2);

  # Populate custom transition tab
  my @all = @App::makebeamerinfo::Transitions::All;
  $gui{'label'}{'F1'} = $gui{'frame'}{'custom_transitions'} -> Label(
    -text => 'F'
  ) -> grid(-row => 0, -column => 1);
  $gui{'label'}{'I1'} = $gui{'frame'}{'custom_transitions'} -> Label(
    -text => 'I'
  ) -> grid(-row => 0, -column => 2);
  $gui{'label'}{'F2'} = $gui{'frame'}{'custom_transitions'} -> Label(
    -text => 'F'
  ) -> grid(-row => 0, -column => 4);
  $gui{'label'}{'I2'} = $gui{'frame'}{'custom_transitions'} -> Label(
    -text => 'I'
  ) -> grid(-row => 0, -column => 5);
  foreach my $trans (sort @all) {
    # Create each transition selection element
    $gui{'transitions'}{$trans}{'frame'} = $gui{'frame'}{'custom_transitions'} -> Checkbutton(
      -variable => \$custom->{'frame'}{$trans},
      -onvalue => 1,
      -offvalue => 0
    );
    $gui{'transitions'}{$trans}{'increment'} = $gui{'frame'}{'custom_transitions'} -> Checkbutton(
      -variable => \$custom->{'increment'}{$trans},
      -onvalue => 1,
      -offvalue => 0
    );
    $gui{'transitions'}{$trans}{'label'} = $gui{'frame'}{'custom_transitions'} -> Label(
      -text => $trans
    );
    # Put each transition selection element into one of two columns
    my $counter = keys %{ $gui{'transitions'} };
    my $col;
    my $row;
    my $num = @all;
    if ($counter <= $num / 2) {
      $col = 1;
      $row = $counter;
    } else {
      $col = 4;
      $row = $counter - $num / 2;
    }
    $gui{'transitions'}{$trans}{'frame'} -> grid(-row => $row, -column => $col);
    $gui{'transitions'}{$trans}{'increment'} -> grid(-row => $row, -column => $col + 1);
    $gui{'transitions'}{$trans}{'label'} -> grid(-row => $row, -column => $col + 2);
  }

  return \%gui;
}

## callbacks for Tk window

sub getFile {
  # read file type to get
  my ($self, $file_type) = @_;
  my $other_type = ($file_type eq 'pdf') ? 'nav' : 'pdf';

  # setup file dialog available filetypes
  my %types = (
    nav =>
    [
      ["Nav Files", '.nav', 'TEXT'],
      ["All Files", "*"]
    ],
    pdf => 
    [
      ["Pdf Files", '.pdf', 'PDF'],
      ["All Files", "*"]
    ]
  );

  # open file dialog and get full filename
  $self->{files}{$file_type} = $self->{gui}{'mw'} -> getOpenFile(-filetypes => \@{ $types{$file_type} });
  #if the other file isn't known, try to find it
  unless ( $self->{files}{$other_type} ) {
    $self->{files}{$other_type} = $self->findFile($self->{files}{$file_type});
  }
}

sub clearFile {
  my ($self, $file_type) = @_;
  $self->{files}{$file_type} = '';
}

1;

