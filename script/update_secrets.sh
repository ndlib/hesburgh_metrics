#!/bin/bash
#
# Copy the secrets to the correct place for deployment
#
# usage:
#   ./update_secrets.sh


# copy .bundle/config from secrets
if [ ! -d .bundle ]; then
	mkdir .bundle
fi

cp -f  config/templates/bundle_config .bundle/config
cp -f config/templates/metrics-env.sh /home/app/metrics/shared/system
