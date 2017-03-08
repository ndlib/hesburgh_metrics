#!/bin/bash
#
# Copy the secrets to the correct place for deployment
#
# usage:
#   ./update_secrets.sh <directory of secrets>

secret_dir=$1

files_to_copy="
    database.yml
    application.yml
    "

for f in $files_to_copy; do
    echo "=-=-=-=-=-=-=-= copy $f"
    if [ -f ${secret_dir}/$f ];
    then
        cp ${secret_dir}/$f config/$f
    else
        echo "Fatal Error: File $f does not exist in $secret_dir"
        exit 1
    fi
done

# copy .bundle/config from secrets
if [ ! -d .bundle ]; then
	mkdir .bundle
fi

cp -f  $secret_dir/bundle_config .bundle/config

cp -f $secret_dir/metrics-env.sh /home/app/metrics/shared/system
