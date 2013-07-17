#!/bin/sh

v="20130717"

./scripts/dist.sh
cpanm Mojolicious-Plugin-Jam-$v.tgz 

