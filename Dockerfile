# syntax = docker/dockerfile:1

FROM ubuntu:latest
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates curl git jq
RUN update-ca-certificates
COPY timestamp_repo.sh verify_repo_timestamp.sh ./
CMD ["ls"]
