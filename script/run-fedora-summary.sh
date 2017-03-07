#!/bin/bash
home=/global/home/dbrower
$home/fedora-summary.py > "$home/stats/$(date '+%Y%m%d').csv"
