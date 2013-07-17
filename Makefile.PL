use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::Jam',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Jam.pm',
  AUTHOR       => 'qtfk <mojolicious-plugin-jam@qtfk.net>',
  PREREQ_PM    => {
                    'Mojolicious' => '4.16',
                    'IO::Socket::SSL' => '1.94',
                  },
  test         => {TESTS => 't/*.t'}
);
