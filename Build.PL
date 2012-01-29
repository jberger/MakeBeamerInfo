use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'App::makebeamerinfo',
  dist_abstract => 'Creates .info file for use with Impressive and LaTeX Beamer',
  dist_author => 'Joel A. Berger <joel.a.berger@gmail.com>',
  license  => 'perl',
  requires => {
    'perl' => '5.8.1',
  },
  configure_requires => {
    'Module::Build' => 0.38,
  },
  recommends => {
    'Tk' => 0,
  },
  meta_merge => {
    resources  => {
      repository => "http://github.com/jberger/MakeBeamerInfo",
    },
  },
);

$builder->create_build_script;
