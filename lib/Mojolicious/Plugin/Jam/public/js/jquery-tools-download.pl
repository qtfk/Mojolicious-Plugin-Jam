#!/usr/bin/env perl

use File::Spec;

my $v = '1.2.7';
my $b = "http://cdn.jquerytools.org/$v";
my $f = 'jquery.tools.min.js';
my @d = qw/full tiny form all full/;
my $d = "jquery-tools-$v";
my %u;

sub run {
  for (@_) {
    print ":: $_\n";
    system $_;
    print "\n";
  }
}

sub md {
  for (@_) {
    next if $_ eq '';
    next if -d;
    if (-e) {
      print STDERR "WARNING: File \"$_\" exists. Skipping!\n";
      next;
    }
    print ":: mkdir $_\n";
    mkdir $_;
  }
}

sub dl {
  my ($p, $d) = @_;
  md($d);
  run("lwp-download $b/$p $d") unless -e "$d/$f";
}

sub d { File::Spec->catdir(@_) }

my $dir = d($ARGV[0] || '.', $d);

dl($f, $dir);
dl("$_/$f", d($dir, $_)) for @d;

exit 0;

