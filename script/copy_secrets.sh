#!/bin/bash
#
# Copy the relevant secrets from the build server to the app server.
#
# usage:
#   ./copy_secrets.sh <secret directory> <target host>

secret_dir=$1
app_host=$2

if [ -d "$secret_dir" ];
then
	  ssh app@$app_host 'rm -rf /home/app/metrics/shared/secret'
	  scp -pr "${secret_dir}" "app@$app_host:/home/app/metrics/shared/secret"
else
          echo "Fatal Error: Source directory $secret_dir does not exist"
	  exit 1
fi

if [ $? -ne 0 ];
then
  echo "Fatal Error: scp ${secret_dir} app@${app_host}:/home/app/metrics/shared/secret failed"
  exit 1
fi
