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

my @all = @App::makebeamerinfo::Transitions::All;
is keys %{ $trans->{frame} }, @all, 'right number of frame transitions';
is keys %{ $trans->{increment} }, @all, 'right number of increment transitions';

is_deeply [ $trans->get_selected('frame') ], $frame, 'frame transitions selected';
is_deeply [ $trans->get_selected('increment') ], $increment, 'increment transitions selected';

ok ! $trans->all_frame, 'Does not use all frames';
ok ! $trans->all_increment, 'Does not use all increment';

is $trans->get_random_element('increment'), 'WipeUp', 'Get the right transition when only one selected';
is $trans->get_random_element('increment'), 'WipeUp', 'Get the right transition when only one selected (again)';

$trans->{last_transition} = 'Crossfade';
is $trans->get_random_element, 'SlideDown', 'Get other transition';
is $trans->get_random_element, 'Crossfade', 'Get other transition (again)';

my $all = App::makebeamerinfo::Transitions->new('all');

ok $all->all_frame, 'Uses all frames';
ok $all->all_increment, 'Uses all increment';

$all->{frame}{Crossfade} = 0;
ok ! $all->all_frame, 'Now, does not use all frames';
ok $all->all_increment, 'But still uses all increment';


done_testing;

