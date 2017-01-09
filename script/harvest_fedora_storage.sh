#!/bin/bash

INPUT="/path/to/input/csv/file"
DBHOST= "dbhost"
DBUSERNAME= "dbusername"
DBPWD= "dbpassword"
DBNAME= "database name"

[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }

cat $INPUT |  while IFS=',' read -r namespace obj_count ds_count total_count obj_size obj_size_human ds_size ds_size_human total_size total_size_human; do
  if [ $namespace == "und" ];
  then
    echo "---------------------------------------"
    echo "Namespace: $namespace"
    echo "Curate Namespace: $total_count"
    echo "Curate Size: $total_size"
    echo "INSERT INTO curate_storage_details (storage_type, object_count,object_bytes, harvest_date) VALUES ('Fedora', $total_count, $total_size, NOW());" | mysql -h$DBHOST -u$DBUSERNAME -p$DBPWD DBNAME;
    echo "---------------------------------------"
  fi
done