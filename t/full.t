use strict;
use warnings;

use Test::More;

use App::makebeamerinfo;

#================
# Create some temporary files

my $nav = <<'NAV';
\beamer@endinputifotherversion {3.10pt}
\headcommand {\slideentry {0}{0}{1}{1/1}{}{0}}
\headcommand {\beamer@framepages {1}{1}}
\headcommand {\slideentry {0}{0}{2}{2/2}{}{0}}
\headcommand {\beamer@framepages {2}{2}}
\headcommand {\sectionentry {1}{section1}{3}{section1}{0}}
\headcommand {\beamer@sectionpages {1}{2}}
\headcommand {\beamer@subsectionpages {1}{2}}
\headcommand {\beamer@subsectionentry {0}{1}{1}{3}{subsection1a}}\headcommand {\beamer@subsectionpages {3}{2}}
\headcommand {\slideentry {1}{1}{1}{3/5}{subsection1a}{0}}
\headcommand {\beamer@framepages {3}{5}}
\headcommand {\beamer@partpages {1}{5}}
\headcommand {\beamer@subsectionpages {3}{5}}
\headcommand {\beamer@sectionpages {3}{5}}
\headcommand {\beamer@documentpages {5}}
\headcommand {\def \inserttotalframenumber {3}}
NAV

my $turn_info = <<'INFO';
PageProps = {
  1:	{
	  'title': "Title",
	  'transition': PageTurn,
	},
  2:	{
	  'transition': PageTurn,
	},
  3:	{
	  'overview': False,
	  'title': "section1",
	  'title': "section1: subsection1a",
	},
  4:	{
	  'overview': False,
	},
  5:	{
	  'transition': PageTurn,
	},
}
AvailableTransitions = [WipeRight]
INFO

#========================
# Tests

my $app = App::makebeamerinfo->new;
isa_ok( $app, 'App::makebeamerinfo' );

{
  # this should prevent cross platform newline problems when reading the test doc above
  local $/ = '
';

  open my $nav_handle, '<', \$nav or die "Cannot open scalar for reading: $!";
  $app->readNav($nav_handle);
}

ok( values %{ $app->{pages} }, "Found pages" );
ok( values %{ $app->{sections} }, "Found sections" );

#=====================
# Test default set

is $app->transition_set, 'default', 'Default to correct set (default)';

my $output = '';
{
  open my $output_handle, '>', \$output or die "Cannot open scalar for writing: $!";
  $app->writeInfo($output_handle);
}

unlike( $output, qr/transition/, 'Default set does not emit transition statments' );
unlike( $output, qr/AvailableTransitions/, 'Default set does not emit AvailableTransitions' );

#=====================
# Test 'none' set

$app->transition_set( 'none' );

$output = '';
{
  open my $output_handle, '>', \$output or die "Cannot open scalar for writing: $!";
  $app->writeInfo($output_handle);
}

unlike( $output, qr/transition/, q{'none' set does not emit transition statments} );
like( $output, qr/AvailableTransitions\s*=\s*[\s*None\s*]/, q{'none' AvailableTransitions is only 'None'} );

#=================
# Test turn set

$app->transition_set('turn');

$output = '';
{
  open my $output_handle, '>', \$output or die "Cannot open scalar for writing: $!";
  $app->writeInfo($output_handle);
}

# remove confusing vertical whitespace
$output    =~ s/[\r\n]//g;
$turn_info =~ s/[\r\n]//g;

is( $output, $turn_info, 'Output as expected' );

#===================
# Other tests

eval { $app->transition_set('does_not_exist') };
ok( $@, 'Selecting unknown transition set dies' );
like( $@, qr/Unknown transition set/, 'Error message' );

done_testing;


