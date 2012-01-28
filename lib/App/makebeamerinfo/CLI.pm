package App::makebeamerinfo::CLI;

use strict;
use warnings;

use App::makebeamerinfo;
our @ISA = qw/App::makebeamerinfo/;

sub userMessage {
  my $self = shift;
  my ($title, $message) = @_;
  print "$title:\n$message\n";
}

1;

