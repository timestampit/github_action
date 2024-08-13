#!/bin/bash

# This script verifies Trusted Timestamps created by TimestampIt! GitHub Actions in git repositories
# This script will exit with a 0 status if all verifications succeed.
# This script will exit with a non-zero status if any verification step fails.

set -e

# make sure the needed external programs are available
for util in "jq" "shasum" "openssl"; do
  command -v "$util" >/dev/null 2>&1 || { echo >&2 "Error: The $util command line program must be installed."; exit 1; }
done

# Parse the command line
if [ "$#" -ne 1 ]; then
  echo "usage: $0 <repo trusted timestamp file>"
  exit 1
fi
repo_timestamp_file=$1
if ! test -f "$repo_timestamp_file"; then
  echo "Error: No such file: $repo_timestamp_file"
  exit 1
fi

# ensure the trusted timestamp is inside a git repo
repo_dir=$(dirname "$repo_timestamp_file")
pushd "$repo_dir" > /dev/null
if ! git rev-parse &> /dev/null; then
  echo "Error: $repo_timestamp_file is not within a git repository"
  exit 1
fi
popd > /dev/null

# All data for the trusted timestamp is on the first line. The second line is the signature
# Split off the first line for further parsing
trusted_timestamp_data=$(head -1 "$repo_timestamp_file" | tr -d "\n")

# ensure the trusted timestamp file starts with 1.0|
if [[ "$trusted_timestamp_data" != 1.0\|* ]]; then
  echo "Error: $repo_timestamp_file does not appear to be a TimestampIt! Trusted Timestamp version 1.0 file"
  exit 1
fi

# ensure the timestamp data line has 6 | characters (7 fields)
if [[ 6 -ne $(echo "$trusted_timestamp_data" | tr -cd '|' | wc -c) ]]; then
  echo "Error: $repo_timestamp_file does not have exactly 6 | characters on the first line, indicating this is not a valid TimestampIt! Trusted Timestamp version 1.0 file"
  exit 1
fi

# extract the needed fields
timestamp=$(echo "$trusted_timestamp_data" | cut -d "|" -f "3")
hash_algo=$(echo "$trusted_timestamp_data" | cut -d "|" -f "4")
expected_repo_digest=$(echo "$trusted_timestamp_data" | cut -d "|" -f "5")
key_url=$(echo "$trusted_timestamp_data" | cut -d "|" -f "6")
sha=$(echo "$trusted_timestamp_data" | cut -d "|" -f "7" | jq -r .sha)

if [[ "$hash_algo" != "sha256" ]]; then
  echo "Error: This script only supports timestamps made with sha256 hashes"
  exit 1
fi

# Before attempting to check out the commit sha, test if it exists at all
if ! git cat-file -e "$sha"; then
  echo "Error: $sha is not a commit in this repo"
  exit 1
fi

echo "Calculating the repo digest..."
# Clone this repo into a temp dir
local_clone=$(mktemp --directory)
git clone --quiet "$repo_dir" "$local_clone"
# hash the cloned repo at the same sha as the trusted timestamp
pushd "$local_clone" > /dev/null
git checkout --quiet "$sha"
repo_digest=$(git ls-tree --full-tree -r --name-only HEAD | sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $1}')
popd > /dev/null
rm -rf "$local_clone"

if [[ "$expected_repo_digest" == "$repo_digest" ]]; then
  echo "Repo digests match"
else
  echo "Fail: Repo digests do not match"
  exit 1
fi

# write the message, signature, and verification key to tmp files
tmp_dir=$(mktemp -d)
message_file="$tmp_dir/message"
signature_file="$tmp_dir/sig"
key_file="$tmp_dir/key"
echo -n "$trusted_timestamp_data" > "$message_file"
head -2 "$repo_timestamp_file" | tail -1 | tr -d "\n" | base64 -D > "$signature_file"

# Attempt to get the key from the key url within the Trusted Timestamp.
# If that fails, get it from the GitHub replica repo
if ! curl --fail --silent --output "$key_file" "$key_url"; then
  # get the key id from the key url
  # key id is kleybzu2afwz for https://timestampit.com/key/kleybzu2afwz
  key_id=$(echo "$key_url" | rev | cut -d '/' -f 1 | rev)
  github_backup_key_url="https://raw.githubusercontent.com/timestampit/keychain/main/keys/pem/$key_id.pem"
  echo "Failed to get verification key at $key_url. Attempting to get it from backup repo: $github_backup_key_url"
  if ! curl --fail --silent --output "$key_file" "$github_backup_key_url"; then
    echo "ERROR: Failed to acquire verification key from either $key_url or $github_backup_key_url"
    exit 1
  fi
fi

# Perform ED25519 signature verification using openssl
# If this fails it prints "Signature Verification Failure"
openssl pkeyutl \
  -verify -pubin \
  -inkey "$key_file" \
  -rawin -in "$message_file" \
  -sigfile "$signature_file"

rm -rf "$tmp_dir"
echo "All verifications successful"
echo "All files in this repo at commit $sha were created no later than $timestamp"
