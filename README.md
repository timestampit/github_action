# TimestampIt! GitHub Action

This is a GitHub Action that creates signed Trusted Timestamps for the code in your repository using the [TimestampIt! API](https://timestampit.com/).

Trusted Timestamps prove when your code was merged or pushed into your GitHub repository, while also maintaining the privacy of your code.

Trusted Timestamps prove a time that your code or data inventions existed at. You can use these Trusted Timestamps
to prove your original code or data predates any copies that may exist.

See our [example repo trusted_timestamps branch](https://github.com/timestampit/action_test/tree/trusted_timestamps) for an example of the files created by this action.

## Usage

All inputs are optional. You can use it simply with
```
- uses: timestampit/github_action@v1.0
```

Several inputs are defined to customize behavior:
```
- uses: timestampit/github_action@v1.0
  with:
    # Name of the branch where trusted timestamps will be stored.
    # If this branch does not already exist it will be created
    # as an orphan, empty branch.
    timestamps_branch: trusted_timestamps

    # Username for the TimestampIt! account to use.
    # If not defined, then a default public user for GitHub actions is used
    timestampit_username: your_timestampit_username

    # Password for the TimestampIt! account to use
    timestampit_password: your_timestampit_password
```

## Trusted Timestamps overview

When this action runs it creates and commits a Trusted Timestamp file in your repo on a special branch. These files are plain text files that contain a timestamp and other data that is needed to verify the Trusted Timestamps.

Trusted Timestamp files look like this:
```
1.0|u8xe5a3i54lc|2024-08-12T20:26:51Z|sha256|556125fd7b4e6ea9a40557ee621930654e21627d72f01ab43f7d872a121e006c|https://timestampit.com/key/kleybzu2afwz|{"repo": "https://github.com/timestampit/testing", "sha": "284951a56c288cc719cee3ca9b093033cc2135fc"}
m02WEes/RuEB/uKIldiaYCjIR1tDI/2JcIgs/BxQui0+lK8R3ackco3OZ8T9/xsV8evBZijoRbup7O20sNYDDg==
```

For more information of the fields within a trusted timestamp, see https://timestampit.com/docs/design.

### How is a Trusted Timestamp different from the timestamp on a git commit?

Trusted Timestamps are made using a trusted clock and then cryptographically signed to prevent them being altered.

Timestamps on regular git commits are made using the local clock of the machine making the git commit. It is possible to set the local clock to a date in the past to make it appear as though the git commits happened at an earlier date than they did.

Trusted Timestamps are a higher standard of proof for when code was actually added to a git repo since the timestamp can not be forged or altered.

### Verifying Trusted Timestamps

By verifying a Trusted Timestamp file, you are proving that the git commit sha in the Trusted Timestamp existed in your git repo at the timestamped time. You are also proving that all files committed to the repo at that commit sha were present at the timestamped time. This is done by comparing the actual repo digest to the one in the Trusted Timestamp, and also by checking the signature on the Trusted Timestamp to ensure it is an authentic TimestampIt! created Trusted Timestamp.

When the action first runs, it commits a script `verify_repo_timestamp.sh` that can be used to verify these Trusted Timestamp files. This happens on the configured `timestamps_branch` (trusted_timestamps by default).

To verify a trusted timestamp file, you simply checkout the trusted_timestamps branch run a command like:
```
./verify_repo_timestamp.sh 284951a56c288cc719cee3ca9b093033cc2135fc.trusted_timestamp
```
The output of the script will inform you if the timestamp verifies, or why it fails verification. A successful verification has output like this:
```
All files in this repo at commit 284951a56c288cc719cee3ca9b093033cc2135fc were created no later than 2024-08-12T20:26:51Z
```

## Full Workflow Examples

### Recommended usage

The following workflow will create a Trusted Timestamp on every push into the `main` branch:
```
name: Create Signed Timestamp

on:
  push:
    branches:
      - main

permissions:
  contents: write

jobs:
  timestampit:
    runs-on: ubuntu-latest
    name: "Create a trusted timestamp for this repo"
    steps:
      - uses: timestampit/github_action@v0.8
```

## Repository privacy

This action sends the following information to TimestampIt! to create the Trusted Timestamp:
- The name of repo.
- The commit sha that is being timestamped.
- A calculated hash digest for the repo at a given commit.

**This action does not send any repo files/code/data to TimestampIt! or any other service.** The privacy of your code is preserved in all cases.

By default this action uses a public TimestampIt! user. This means that it is possible for other actors to see the above information about your repo/timestamps for a short period of time (24 hours). When using this action on private repos we do recommend that you sign up for your own TimestampIt! account to avoid leaking the existence of your repo and commit shas.
