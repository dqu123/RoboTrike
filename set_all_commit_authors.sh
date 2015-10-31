#!/usr/bin/env bash
git filter-branch -f --env-filter "
    GIT_AUTHOR_NAME='David Qu'
    GIT_AUTHOR_EMAIL='davidqu12345@gmail.com'
    GIT_COMMITTER_NAME='David Qu'
    GIT_COMMITTER_EMAIL='davidqu12345@gmail.com'
  " HEAD
