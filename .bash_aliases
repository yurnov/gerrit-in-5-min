#!/bin/bash

alias gamend='git commit --amend --no-edit'
alias gdev='git reset --hard origin/development && git clean -df && git checkout development && git fetch && git reset --hard origin/development'
alias gmaster='git reset --hard origin/master && git clean -df && git checkout master && git fetch && git reset --hard origin/master'
alias gbranch='git reset --hard origin/$(git branch --show-current) && git clean -df && git checkout $(git branch --show-current) && git fetch && git reset --hard origin/$(git branch --show-current)'
alias gpush='git push origin HEAD:refs/for/$( git rev-parse --abbrev-ref HEAD )'
alias gpushm='git push origin HEAD:refs/for/master'
