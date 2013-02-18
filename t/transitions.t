use strict;
use warnings;

use Test::More;
use App::makebeamerinfo::Transitions;

my $frame = [qw/Crossfade SlideDown/];
my $increment = [qw/WipeUp/];

my $trans = App::makebeamerinfo::Transitions->new(
  'myname',
  frame => $frame,
  increment => $increment,
);

is $trans->name, 'myname', 'Name gets added correctly';

my @all = sort @App::makebeamerinfo::Transitions::All;
is_deeply [ sort keys %{ $trans->{frame} } ],     \@all, 'right frame transitions';
is_deeply [ sort keys %{ $trans->{increment} } ], \@all, 'right increment transitions';

is_deeply [ $trans->get_selected('frame') ],     $frame,     'frame transitions selected';
is_deeply [ $trans->get_selected('increment') ], $increment, 'increment transitions selected';

is $trans->get_random_element('increment'), 'WipeUp', 'Get the right transition when only one selected';
is $trans->get_random_element('increment'), 'WipeUp', 'Get the right transition when only one selected (again)';

$trans->{last_transition} = 'Crossfade';
is $trans->get_random_element, 'SlideDown', 'Get other transition';
is $trans->get_random_element, 'Crossfade', 'Get other transition (again)';

ok ! $trans->default_frame, 'Not using default set for frame';
ok ! $trans->default_increment, 'Not using default set for increment';

done_testing;

