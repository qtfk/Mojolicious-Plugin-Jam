#!/bin/sh

v="20130717"
n="Mojolicious-Plugin-Jam-$v"

./scripts/doc.sh
rm $n.tgz
git archive --prefix $n/ -o $n.tgz HEAD .
rm -rf $n
tar xzf $n.tgz
rm $n/README.pod
rm $n.tgz
tar czf $n.tgz $n
rm -rf $n

