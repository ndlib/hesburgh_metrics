#!/bin/bash
home=/home/app/metrics
$home/fedora-summary.py > "$home/stats/$(date '+%Y%m%d').csv"
