#!/usr/bin/env bash

clean_repo=$(git status --porcelain)
if [ -n "$clean_repo" ]; then
  printf "Unable to tag current build; The git repository has changes. Please review:\n\n"
  printf "$clean_repo\n" 1>&2
  exit 1
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
next_build_identifier=$($DIR/next-build-identifier.sh)
echo "$next_build_identifier" > $( cd "$DIR/.." && pwd )/VERSION
git add VERSION
git commit -m "Bumping build identifier to \"$next_build_identifier\""
git tag $next_build_identifier
git push --tags
git push origin