#!/usr/bin/env bash

echo "Running buildpack tests"
FAILED="false"

if [[ "$GIT_BRANCH" == "master" ]]; then
  echo "🟢  Git branch set"
else
  echo "🔴 Git branch set incorrectly GIT_BRANCH = $GIT_BRANCH"
  FAILED="true"
fi

if [ -n "$GIT_COMMIT" ]; then
  echo "🟢  Git commit set"
else
  echo "🔴 Git commit set incorrectly GIT_COMMIT = $GIT_COMMIT"
  FAILED="true"
fi

if [[ "$GIT_TAG" == "undefined" ]]; then
  echo "🟢  Git tag set"
else
  echo "🔴 Git tag set incorrectly GIT_TAG = $GIT_TAG"
  FAILED="true"
fi

if [[ "$FAILED" == "true" ]]; then
  echo "🔴 Test suite failed"
  exit 1
else
  echo "Test suite finished"
fi
