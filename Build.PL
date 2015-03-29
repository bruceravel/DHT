#!/usr/bin/perl

use strict;
use warnings;
use Module::Build;

my $build = Module::Build ->
  new(
      module_name        => 'MyDHT',
      create_readme      => 0,
      ##create_makefile_pl => 'traditional',
      license            => 'artistic',
      dist_author        => 'Bruce Ravel <http://bruceravel.github.io/home>',
      requires           => {
			     'Moose'    => '2.09',
			     'DateTime' => '0',
			     'File::Slurp' => '0',
			     'Graphics::GnuplotIF' => '0',
			     'JSON::Tiny' => '0',
			     'Text::Template' => '0',
			     'DBI' => '0',
			    }
     );

$build->create_build_script;
