#!/bin/bash

set -e

LC_ALL=POSIX

# Parse the command line
if [ "$#" -ne 1 ]; then
  echo "usage: $0 <repo timestamp file>"
  exit 1
fi
repo_timestamp_file=$1
if ! test -f "$repo_timestamp_file"; then
  echo "Error: No such file: $repo_timestamp_file"
  exit 1
fi

timestamp=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "3")
hash_algo=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "4")
expected_repo_digest=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "5")
key_url=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "6")
git_repo=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "7" | jq -r .repo)
sha=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "7" | jq -r .sha)

local_clone=$(mktemp -d)
git clone $git_repo $local_clone

pushd $local_clone
git checkout -q $sha
repo_digest=$(find -s . -type f -not -path "*/.git/*" -print0 | xargs -0 sha256sum | sha256sum | cut -f1 -d ' ')
popd
rm -rf $local_clone

if [[ "$expected_repo_digest" == "$repo_digest" ]]; then
  echo "Repo digests match"
else
  echo "Repo digests do not match"
  exit 1
fi

tmp_dir=$(mktemp -d)
message_file="$tmp_dir/message"
signature_file="$tmp_dir/sig"
key_file="$tmp_dir/key"

head -1 "$repo_timestamp_file" | tr -d "\n" > "$message_file"
head -2 "$repo_timestamp_file" | tail -1 | tr -d "\n" | base64 -D > "$signature_file"
curl -s -o "$key_file" "$key_url"

# Perform the openssl verification
openssl pkeyutl \
  -verify -pubin \
  -inkey "$key_file" \
  -rawin -in "$message_file" \
  -sigfile "$signature_file"

echo "All verifications successful"
echo "All files in $git_repo was created no later than $timestamp"
