#!/usr/bin/env bash

## ref: https://intoli.com/blog/exit-on-errors-in-bash-scripts/
# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

echo "Check out master branch:"
git checkout master

#echo "Delete current local public branch:"
#git branch -D public

echo "Check out to a temporary branch:"
git checkout --orphan TEMP_BRANCH

echo "Add all the files:"
git add -A

echo "Commit the changes:"
git commit -am "Initial commit"

echo "Delete the old branch:"
git branch -D master

echo "Rename the temporary branch to public:"
## ref: https://gist.github.com/heiswayi/350e2afda8cece810c0f6116dadbe651
git branch -m master

echo "Force public branch update to origin repository:"
#git push -f origin master
git push -f --set-upstream origin master
