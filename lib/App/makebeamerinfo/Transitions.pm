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

  # handle shortcut
  if ( @_ == 1 ) {
    my $base = shift;
    if ( $base eq ':none' ) {
      push @_, frame => ':default', increment => ['None'];
    } else {
      push @_, frame => $base, increment => $base;
    }
  }

  $self->_initialize(@_);
  return $self;
}

sub _initialize {
  my $self = shift;

  my %init = @_;

  for my $type ( qw/ frame increment / ) {

    my $spec = $init{$type};

    $self->{$type} = {};
    next if $spec eq ':default';

    my $base = 0;
    if ( $spec eq ':all' ) {
      $base = 1;
    }

    $self->{$type}{$_} = $base for @All;

    if ( ref $spec ) {
      $self->{$type}{$_} = 1 for @$spec;
    }

  }
}

# get all selected

sub get_selected {
  my ($self, $type) = @_;
  my $hash = $self->get_type($type);
  my @keys = keys %$hash;
  croak "Type $type is default" unless @keys;
  return sort grep { $hash->{$_} } @keys;
}

sub get_type {
  my ($self, $type) = @_;
  my $hash = $self->{$type} || croak "Unknown transition type '$type'";
  return $hash;
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

# test if default X are selected

sub _default {
  my ($self, $type) = @_;
  return ! keys %{ $self->{$type} };
}

sub default_frame     { shift->_default('frame')     }
sub default_increment { shift->_default('increment') }

# ro accessors
sub name { $_[0]->{name} }

1;

