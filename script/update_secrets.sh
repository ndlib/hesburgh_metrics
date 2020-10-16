#!/bin/bash
#
# Copy the secrets to the correct place for deployment
#
# usage:
#   ./update_secrets.sh 

# A prior build step for this environment should have built the config files for this env,
# and copied them to /home/app/curatend/shared/secrets on the target machine

shared_config_dir=/home/app/metrics/shared/secrets

files_to_copy="
    database.yml
    application.yml
    "

for f in $files_to_copy; do
    echo "=-=-=-=-=-=-=-= copy $f"
    if [ -f $shared_config_dir/$f ];
    then
        cp $shared_config_dir/$f config/$f
    else
        echo "Fatal Error: File $f does not exist in ${secret_repo}/hesburgh_metrics"
        exit 1
    fi
done

# copy .bundle/config from secrets
if [ ! -d .bundle ]; then
	mkdir .bundle
fi

cp -f  $shared_config_dir/bundle_config .bundle/config
cp -f  $shared_config_dir/env-vars env-vars

cp -f $shared_config_dir/hesburgh_metrics/metrics-env.sh /home/app/metrics/shared/system
