#!/bin/sh

pod="lib/Mojolicious/Plugin/Jam.pod"

cat $pod.master |perl -ne 'if (/^=include (.*)$/) { open IN, "<$1"; while (<IN>) { print " $_" } close IN } else { print }' >$pod

cp $pod README.pod

#pod2html --infile=$pod --outfile=README.html 2>/dev/null
#rm pod2htmd.tmp

