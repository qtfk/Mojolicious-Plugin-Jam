#!/usr/bin/env perl

my $s = shift;
my $c = "morbo -l \"http://*:3000\" " .
        "-l \"https://*:3001?key=\$HOME/.mojolicious/server.key&cert=" .
        "\$HOME/.mojolicious/server.crt\" $s";
print ":: $c\n";
exec $c;

