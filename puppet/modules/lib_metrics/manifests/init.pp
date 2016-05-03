# default lib_metrics class-
# will call appropriate subclass based on environment

class lib_metrics( $env = "staging" ) {

	include lib_app_home

	class { "lib_metrics::$env": }
}

