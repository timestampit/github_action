#!/bin/sh

set -e

# Parse the command line
if [ "$#" -ne 1 ]; then
  echo "usage: $0 <git remote>"
  exit 1
fi
git_repo=$1

local_clone=$(mktemp -d -t $(basename $0))
echo $local_clone

git clone $git_repo $local_clone

bundle_file=$(mktemp -t $(basename $0))
pushd $local_clone
branch=$(git branch --show-current)
sha=$(git rev-parse HEAD)
git bundle create $bundle_file $branch
popd

echo "---"
echo $bundle_file
echo "---"

digest=$(shasum -a 256 $bundle_file  | cut -f 1 -d ' ')

rm -rf $local_clone
# rm $bundle_file

git_version=$(git --version)

ext_json="{\"git_version\": \"$git_version\", \"repo\": \"$git_repo\", \"sha\":\"$sha\"}"

echo "Extended timestamp data:"
echo $ext_json | jq

echo "Performing timestamp create"
curl \
  --data-urlencode algorithm=sha256 \
  --data-urlencode digest=$digest \
  --data-urlencode ext="$ext_json" \
  --user public:publicpublic \
  -o "$sha.tt" \
  https://timestampit.com/create