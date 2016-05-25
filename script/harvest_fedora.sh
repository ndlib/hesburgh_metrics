#!/bin/bash

# Try to get a lock, and exit if someone else already has it.
# This keeps a lot of harvest processes from spawning
# should a paricular harvest take a long time.
# The lock is released when this shell exits.

cd /home/app/metrics/current

exec 200> "/tmp/harvest-fedora"
flock -e --nonblock 200 || exit 0

# source our ruby env
source /etc/profile.d/ruby.sh

# source our app environment.

source /home/app/metrics/shared/system/metrics-env.sh

# source our app environment. 

/opt/ruby/current/bin/bundle exec rake metrics:harvest_fedora 2>/home/app/metrics/shared/log/harvest_fedora.log
