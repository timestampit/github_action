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

# split the trusted timestamp into first and second lines (message and signature)
trusted_timestamp_data=$(head -1 "$repo_timestamp_file" | tr -d "\n")

# ensure the trusted timestamp file starts with 1.0|
if [[ $trusted_timestamp_data != 1.0\|*  ]]; then
  echo "Error: $repo_timestamp_file does not appear to be a TimestampIt! Trusted Timestamp version 1.0 file"
  exit 1
fi

# ensure the trusted timestamp file first line has 6 | characters (7 fields)
if [[ 6 -ne $(echo $trusted_timestamp_data | tr -cd '|' | wc -c) ]]; then
  echo "Error: $repo_timestamp_file does not have exactly 6 | characters on the first line, indicating this is not a valid TimestampIt! Trusted Timestamp version 1.0 file"
  exit 1
fi

# extract the needed fields
timestamp=$(echo $trusted_timestamp_data | cut -d "|" -f "3")
hash_algo=$(echo $trusted_timestamp_data | cut -d "|" -f "4")
expected_repo_digest=$(echo $trusted_timestamp_data | cut -d "|" -f "5")
key_url=$(echo $trusted_timestamp_data | cut -d "|" -f "6")
sha=$(echo $trusted_timestamp_data | cut -d "|" -f "7" | jq -r .sha)

if [[ "$hash_algo" != "sha256" ]]; then
  echo "This script only supports timestamps made with sha256 hashes"
  exit 1
fi

# Clonse this repo into a temp dir
local_clone=$(mktemp -d)
git clone  --quiet . $local_clone

# hash the cloned repo at the same sha as the trusted timestamp
pushd $local_clone > /dev/null
git checkout --quiet $sha
repo_digest=$(git ls-tree --full-tree -r --name-only HEAD | sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $1}')
popd  > /dev/null
rm -rf $local_clone

if [[ "$expected_repo_digest" == "$repo_digest" ]]; then
  echo "Repo digests match"
else
  echo "Fail: Repo digests do not match"
  exit 1
fi

# write the message, signature, and verification key to tmp files
tmp_dir=$(mktemp -d)
echo $tmp_dir
message_file="$tmp_dir/message"
signature_file="$tmp_dir/sig"
key_file="$tmp_dir/key"
echo -n "$trusted_timestamp_data" > "$message_file"
signature=$(head -2 "$repo_timestamp_file" | tail -1 | tr -d "\n" | base64 -D)
echo -n "$signature" > "$signature_file"
curl -s -o "$key_file" "$key_url"

# Perform the verification using openssl
openssl pkeyutl \
  -verify -pubin \
  -inkey "$key_file" \
  -rawin -in "$message_file" \
  -sigfile "$signature_file"

echo "All verifications successful"
echo "All files in this repo at commit $sha were created no later than $timestamp"
