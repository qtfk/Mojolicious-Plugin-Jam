#!/bin/sh

v="20130716"

./scripts/dist.sh
cpanm Mojolicious-Plugin-Jam-$v.tgz 

