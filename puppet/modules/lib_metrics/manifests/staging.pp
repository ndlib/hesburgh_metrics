class lib_metrics::staging( $mysql_user = 'metrics', $mysql_db_name = 'metrics_staging', $mysql_passwd  = 'allthew0rld')  {
	
        $mysql_root_password = hiera('mysql_root_password')

	# create application subdirectories
	lib_app_home::mk_application_dir{ 'metrics': }

	# If we ever use this to build a developement machine,
	# add logic here to install fedora and mysql if needed
        # In our staging env, these are already present

	class { 'mysql::server':
  		root_password => $mysql_root_password
	}


	mysql::db { "${mysql_db_name}":
		user => "$mysql_user",
		password => "$mysql_passwd",	
		host => 'localhost',
		grant => ['all'],
	}
}
