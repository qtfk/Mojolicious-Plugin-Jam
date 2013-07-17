#!/bin/sh

# Documentation
./scripts/doc.sh

# Update the date
dtg=$(date +%Y%m%d)
sed -i '' "s/[0-9]\{8\}/$dtg/" \
  scripts/dist.sh \
  scripts/install.sh \
  lib/Mojolicious/Plugin/Jam.pm

