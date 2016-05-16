# default lib_metrics class-
# will call appropriate subclass based on environment

class lib_metrics( $env = "staging" ) {

	include lib_app_home

	$rpm_files = [ 'sqlite-dev' ]

	# RPMs required by the Metrics software stack

	package { 'metrics_dependencies':
		name => $rpm_files,
		ensure => installed
	}

	class { "lib_metrics::$env":
		require => Package[ 'metrics_dependencies']
         }


	# Schedule Metrics Collection
	cron { 
		command => '/home/app/metrics/current/script/harvest_metrics.sh',
		user => 'root',
		hour => 2,
		minute => 0,
	}
} 


