#!/bin/sh

pod="lib/Mojolicious/Plugin/Jam.pod"

cat $pod.master |perl -ne 'if (/^=include (.*)$/) { open IN, "<$1"; while (<IN>) { print " $_" } close IN } else { print }' >$pod

cp $pod README.pod

# Pages
pod2html --infile=$pod --outfile=pages/index.html 2>/dev/null
mkdir -p Form/Field
pod2html --infile=lib/Mojolicious/Plugin/Jam/Form.pm --outfile=pages/Form/index.html 2>/dev/null
pod2html --infile=lib/Mojolicious/Plugin/Jam/Form/Field.pod --outfile=pages/Form/Field/index.html 2>/dev/null
sed -i '' "s/mailto:[^\"]*/mailto:mojolicious-plugin-jam@qtfk.net/" pages/index.html pages/Form/index.html pages/Form/Field/index.html
rm pod2htmd.tmp

