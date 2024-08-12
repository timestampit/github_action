# Signed Timestamps Branch

This is a special branch that contains signed timestamps of commits in this repository known as Trusted Timestamps.

These Trusted Timestamps prove the existence of the named commit sha at the timestamped time.

These Trusted Timestamps are created by a GitHub Action, see your Actions tab for it's configuration.

The `verify_repo_timestamp.sh` command can be used to verify the authenticity of these timestamps.

These timestamps are created by a Trusted Third Party called TimestampIt!.

See https://timestampit.com/docs/timestamp_a_git_repo for more information.


## Structure

In this branch, there is a set of files with names like `<git commit sha>.trusted_timestamp`. These files are plain text. The contents will look something like this:

```
1.0|ybtclcfugbfi|2024-08-12T03:37:13Z|sha256|e954a812a4802ded405080e0d178deb5713fbe3b72f763241e6ade7eaaebd22d|https://timestampit.com/key/kleybzu2afwz|{"repo": "https://github.com/user_or_org/repo", "sha": "9cd3ec55c91960c6de07472f7708f98ee8cbfeb1"}
KgLdXJnIueVvI2C6a0JgULd2i7yukC4BFYl9jXiLtMsGHXmsoELz3jh1XBm0Mki20YPw96i62HATD6XhWLuzCA==
```

The first line is the timestamp data. See https://timestampit.com/docs/design for a description of each field.
The second line is the cryptographic signature of the first line. If anything in this file is changed in any way, the Trusted Timestamp will fail to verify.


## Verifying these Trusted Timestamps.

By running the verification script, you are verifying that this file is completely unchanged from what was created by TimestampIt!. In doing so you are proving that given commit sha existed in this repo at the timestamp in the Trusted Timestamp (the third field on line one).

To verify a given Trusted Timestamp, run the included verification script like so:
`./verify_repo_timestamp.sh <trusted timestamp filename>`.

If the Trusted Timestamp verifies successfully, you will see output like:
```
All verifications successful
All files in this repo at commit a2a611052c4f689ae30bb9eb8c86f59c6653466d were created no later than 2024-08-12T04:04:21Z
```

If it fails to verify, you will see output like:
`Repo digests do not match`
or
`Signature Verification Failure`.

