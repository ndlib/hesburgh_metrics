#!/bin/bash
#
# Copy the secrets to the correct place for deployment
#
# usage:
#   ./update_secrets.sh <name of secret repo>

secret_repo=$1

if [ -d $secret_repo ]; then
        echo "=-=-=-=-=-=-=-= delete $secret_repo"
        rm -rf $secret_repo
fi
echo "=-=-=-=-=-=-=-= git clone $secret_repo"
git clone "git@git.library.nd.edu:$secret_repo"

files_to_copy="
    database.yml
    application.yml
    "

for f in $files_to_copy; do
    echo "=-=-=-=-=-=-=-= copy $f"
    if [ -f ${secret_repo}/hesburgh_metrics/$f ];
    then
        cp ${secret_repo}/hesburgh_metrics/$f config/$f
    else
        echo "Fatal Error: File $f does not exist in ${secret_repo}/hesburgh_metrics"
        exit 1
    fi
done

# copy .bundle/config from secrets
if [ ! -d .bundle ]; then
	mkdir .bundle
fi

cp -f  $secret_repo/hesburgh_metrics/bundle_config .bundle/config

cp -f $secret_repo/hesburgh_metrics/metrics-env.sh /home/app/metrics/shared/system
