#!/usr/bin/env bash

# Determine the next build number with the format: "v2013.12"

current_year=$(date "+%Y")

# For the beginning with the current year, figure out the maximum build number.
# Then print a tag for the current year with the maximum build number
# incremented by one. If there is no build number for the current year, use a
# build number of "1". This is ugly because we need to shell expand current_year,
# but not the awk argument $2.
git tag | awk -F '.' "/^v$current_year/ {if (max < \$2) {max = \$2}} END {print \"v$current_year.\"max+1}"
exit 0
