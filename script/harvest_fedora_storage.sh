#!/bin/bash

# This script parse the fedora-storage-details.csv file created in fedoraprod overnight and
# update metrics-database with curate-fedora storage information
# Modify input file and database details from secrets and manually deploy this script
# Need to configure cron to run this script everyday after fedora-summary job completed in FedoraProd
# Need to manually copy this file to fedora server to run script after fedora-summary script complete

INPUT_PATH="/home/app/metrics/stats"
DBHOST= "DB_HOST"
DBUSERNAME= "DB_USERNAME"
DBPWD= "DB_PASSWORD"
DBNAME= "DB_NAME"

cd $INPUT_PATH
input_file=$(ls -Ft | grep "[^/]$" | tail -n 1)
echo "file_to_process: $INPUT_PATH/$input_file"
[ ! -f "$INPUT_PATH/$input_file" ] && { echo "$input_file not found in $INPUT_PATH"; exit 99; }

cat "$INPUT_PATH/$input_file" |  while IFS=',' read -r namespace obj_count ds_count total_count obj_size obj_size_human ds_size ds_size_human total_size total_size_human; do
  if [ "$namespace" == "und" ];
  then
    echo "---------------------------------------"
    echo "Namespace: $namespace"
    echo "Curate Namespace: $total_count"
    echo "Curate Size: $total_size"
    echo "Insert curate size and object count into metrics database"
    mysql -u$DBUSER -p$DBPWD -h$DBHOST -e "USE $DBNAME; INSERT INTO curate_storage_details (storage_type, object_count,object_bytes, harvest_date, created_at, updated_at) VALUES ('Fedora', $total_count, $total_size, NOW(), NOW(), NOW());";
    echo "Completed database insert"
    echo "---------------------------------------"
  fi
done
