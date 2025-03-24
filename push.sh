#!/bin/bash
set -e

CONTENT=`cat debian/changelog`
REGEX='\(([0-9]+)\.([0-9]+)\.([0-9]+)\)';

[[ $CONTENT =~ $REGEX ]]

major=${BASH_REMATCH[1]};
minor=${BASH_REMATCH[2]};
patch=${BASH_REMATCH[3]};


docker login
docker buildx build --push --platform linux/amd64,linux/arm64 \
  -t intermesh/groupoffice-mailserver:latest \
  -t intermesh/groupoffice-mailserver:$major.$minor \
  -t intermesh/groupoffice-mailserver:$major.$minor.$patch \
  .

#docker push intermesh/groupoffice-mailserver:latest
