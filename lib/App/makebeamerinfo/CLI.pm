package App::makebeamerinfo::CLI;

use strict;
use warnings;

use App::makebeamerinfo;
our @ISA = qw/App::makebeamerinfo/;

sub userMessage {
  my ($title, $message) = @_;
  print "$title:\n$message\n";
}

sub run {
  my $self = shift;
  $self->createInfo;
}

1;

