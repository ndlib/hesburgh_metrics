# Hesburgh Metrics

[![Build Status](https://travis-ci.org/ndlib/hesburgh_metrics.png?branch=master)](https://travis-ci.org/ndlib/hesburgh_metrics)
[![APACHE 2 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)

This repository provides code to harvest fedora and bendo usage details along with harvesting fedora objects
and access details for [CurateND].  Additionally, it provides code for generating periodic reports for [CurateND].
Fedora summary script is housed in script folder which runs overnite in fedora server.

This repository receives input from various source like fedora storage details, bendo storage details,
CurateND fedora objects information. Also harvest curateND access_log to store access events. Also these
details are reported weekly in Periodic Metrics Report.
[CurateND]: https://curate.nd.edu

# Format of this Repository

This repository is deployed using the rails deployment tool capistrano.
harvest_fedora.sh will harvest curate objects from fedora and store basic details
about them in the database. harvest_bendo will store the number and size of curate bendo objects in
the database. harvest_fedora_storage will store curate fedora objects and their size in database.
Crontab is used as the scheduler to run, on a weekly basis, weekly_metrics_report.sh, and to send the report via email.


# Running Tests

Looking at the `.travis.yml` file, use the `script` value (e.g. `bundle exec rake`). This
script is what Travis runs when we push builds. If you do not have mysql running, and
installed via homebrew, you may need to run `mysql.server start` to launch mysql

```console
$ bundle exec rake
```

# Usage

To run locally:

* `cd /path/to/this/repository`
* Modify fedora-summary.py to point to fedora datastore and objectstore path
* Modify run-fedora-summary.sh $HOME path to path where the csv file need to be created
* Move run-fedora-summary.sh and fedora-summary.py script to the fedora server to harvest fedora storage details
* run `./run-fedora-summary - Run the executable to csv file about fedora storage detils
* Modify harvest_fedora_storage.sh for INPUT, DBHOST, DBUSERNAME, DBPWD, DBNAME to store them in database
* `./harvest_fedora_storage` - Run the executable to store fedora storage details;
* `./harvest_fedora` - Run the executable to store curate object details;
* `./harvest_metrics` - Run the executable to store curate access details;
* `./harvest_bendo` - Run the executable to store bendo details;
* `./weekly_metrics_report` - Run the executable to generate weekly usage report;
