#!/bin/bash
#
# Copy the metrics scripts from the build server to the application's fedora server.
#
# usage:
#   ./set_fedora_metrics.sh <secret directory> <scripts_dir>  <target host>

secret_dir=$1
scripts_dir=$2
fedora_host=$3

fedora_metric_files="
  run-fedora-summary.sh
  harvest_fedora_storage.sh
  fedora-summary.py
"

# $1 is file, $2 is field name. Returns value
function var_from_yml() {
  echo $(head -n 10 $1 | grep $2 | cut -d: -f2 | sed 's/ //')
}

# $1 is temp_dir, $2 is secrets_dir
function inject_secrets() {
  db_host=$(var_from_yml "$2/database.yml" 'host')
  username=$(var_from_yml "$2/database.yml" 'username')
  db_password=$(var_from_yml "$2/database.yml" 'password')
  database=$(var_from_yml "$2/database.yml" 'database')
  ds_store=$(var_from_yml "$2/application.yml" 'fedora_ds_store')
  object_store=$(var_from_yml "$2/application.yml" 'fedora_object_store')

  sed -e "s/DB_HOST/$db_host/" -i -f ${temp_dir}/harvest_fedora_storage.sh
  sed -e "s/DB_USERNAME/$username/" -i -f ${temp_dir}/harvest_fedora_storage.sh
  sed -e "s/DB_PASSWORD/$db_password/" -i -f ${temp_dir}/harvest_fedora_storage.sh
  sed -e "s/DB_NAME/$database/" -i -f ${temp_dir}/harvest_fedora_storage.sh
  sed -e "s?fedora_object_store?$object_store?" -i -f ${temp_dir}/fedora-summary.py
  sed -e "s?fedora_ds_store?$ds_store?" -i  -f ${temp_dir}/fedora-summary.py
}

if [ ! -d "$secret_dir" ]; then
          echo "Fatal Error: Source directory $secret_dir does not exist"
	  exit 1
elif [ ! -d "$scripts_dir" ]; then
         echo "Fatal Error: Scripts directory $scripts_dir does not exist"
	  exit 1
else
	  temp_dir=$(mktemp -d)
	  echo $temp_dir

	  cp -R "${scripts_dir}/" "${temp_dir}"
	  inject_secrets $temp_dir $secret_dir
	  
	  for file in $fedora_metric_files; do
	  	scp  "${temp_dir}/$file" "app@$fedora_host:/home/app/metrics/"
	  done
fi

if [ $? -ne 0 ];
then
  echo "Fatal Error: scp ${tmp_dir} app@${fedora_host}:/home/app/metrics/ failed"
  exit 1
fi

rm -rf $temp_dir
