use strict;
use warnings;

use Test::More;
use File::Temp ();

use App::makebeamerinfo;

#================
# Create some temporary files

my $nav = File::Temp->new( SUFFIX => '.nav' );
print $nav <<'NAV';
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
seek($nav, 0, 0);

my $good_info = File::Temp->new( SUFFIX => '.pdf.info' );
print $good_info <<'INFO';
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
seek($good_info, 0, 0);

#========================
# Tests

my $app = App::makebeamerinfo->new( nav => "$nav" );
isa_ok( $app, 'App::makebeamerinfo' );

$app->readNav;

ok( values %{ $app->{pages} }, "Found pages" );
ok( values %{ $app->{sections} }, "Found sections" );

my $info = File::Temp->new();
$app->writeInfo($info);
seek($info, 0, 0);

my $i = 0;
while(my $good_line = <$good_info>) {
  chomp $good_line;

  my $test_line = <$info>;
  chomp $test_line;

  is( $test_line, $good_line, "Files equal line: " . ++$i );
}

done_testing;


