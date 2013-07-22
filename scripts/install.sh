#!/bin/sh

v="20130719"

./scripts/dist.sh
cpanm Mojolicious-Plugin-Jam-$v.tgz 

