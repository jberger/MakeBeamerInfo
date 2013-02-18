use strict;
use warnings;

use Test::More tests => 3;

use_ok('App::makebeamerinfo');
use_ok('App::makebeamerinfo::CLI');

my $have_tk = eval { require 'Tk'; 1 };

SKIP: {
  skip "Tk not found", 1 unless $have_tk;
  use_ok('App::makebeamerinfo::GUI');
}

