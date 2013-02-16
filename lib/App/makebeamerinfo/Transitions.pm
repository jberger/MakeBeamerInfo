package App::makebeamerinfo::Transitions;

use strict;
use warnings;
use Carp;

#list of the available transitions
our @All = ( qw/
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

sub new {
  my $class = shift;
  my $self = {
    name => shift,
    last_transition => '', # prevent repeated transitions
  };
  bless $self, $class;

  $self->_initialize(@_);
  return $self;
}

sub _initialize {
  my $self = shift;

  # called without arguments, get all, otherwise null for later setting
  my $base = @_ ? 0 : 1;

  $self->{increment}{$_} = $base for @All;
  $self->{frame}{$_}     = $base for @All;

  return unless @_;

  my %init = @_;

  $self->{increment}{$_} = 1 for @{ $init{increment} };
  $self->{frame}{$_}     = 1 for @{ $init{frame} };
}

# get all selected

sub get_selected {
  my ($self, $type) = @_;
  my $hash = $self->{$type} || croak "Unknown transition type '$type'";
  return sort grep { $hash->{$_} } keys %$hash;
}

# return the contents of a random element of an array
sub get_random_element {
  my $self = shift;
  my $type = shift || 'frame';

  my @array = $self->get_selected($type);
  my $length = @array;

  return $array[0] if $length == 1;

  my $return = $self->{last_transition};

  # prevent repeated transitions
  while ($return eq $self->{last_transition}) {
    $return = $array[int rand $length];
  }

  $self->{last_transition} = $return;
  return $return;
}

# test if all X are selected

sub _all {
  my ($self, $type) = @_;
  my @array = $self->get_selected($type);
  return @All == @array;
}

sub all_frame     { shift->_all('frame')     }
sub all_increment { shift->_all('increment') }

# ro accessors
sub name { $_[0]->{name} }

1;

