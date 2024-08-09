#!/bin/sh

set -e

LC_ALL=POSIX

# Parse the command line
if [ "$#" -ne 1 ]; then
  echo "usage: $0 <git remote>"
  exit 1
fi
git_repo=$1

local_clone=$(mktemp -d)

git clone $git_repo $local_clone

pushd $local_clone
branch=$(git branch --show-current)
sha=$(git rev-parse HEAD)
repo_digest=$(find -s . -type f -not -path "*/.git/*" -print0 | xargs -0 sha256sum | sha256sum | cut -f1 -d ' ')
popd
rm -rf $local_clone

ext_json="{\"repo\": \"$git_repo\", \"sha\":\"$sha\", \"branch\": \"$branch\"}"

echo "Extended timestamp data:"
echo $ext_json | jq

echo "Performing timestamp create"
curl \
  --data-urlencode algorithm=sha256 \
  --data-urlencode digest=$repo_digest \
  --data-urlencode ext="$ext_json" \
  --user public:publicpublic \
  -o "$sha.tt" \
  https://timestampit.com/create
