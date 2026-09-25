#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gh >/dev/null || { echo 'Install GitHub CLI from https://cli.github.com, then run gh auth login.'; exit 1; }
gh auth status
repo_owner="$(gh api user --jq '.login')"
repo_name='Clearspace-iOS'
if gh repo view "$repo_owner/$repo_name" >/dev/null 2>&1; then
  echo "Repository $repo_owner/$repo_name already exists. No changes made; confirm the destination manually."
  exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init -b main
fi
if git remote get-url origin >/dev/null 2>&1; then
  echo 'This project already has an origin. No remote changes made.'
  exit 1
fi
if ! git config user.name >/dev/null; then git config user.name "$repo_owner"; fi
if ! git config user.email >/dev/null; then
  github_id="$(gh api user --jq '.id')"
  git config user.email "$github_id+$repo_owner@users.noreply.github.com"
fi
git add .
if ! git diff --cached --quiet; then git commit -m 'feat: implement initial storage cleaner core loop'; fi
gh repo create "$repo_owner/$repo_name" --private --description 'Clearspace: on-device iPhone storage cleaner with safe review and deletion' --source . --remote origin --push
echo "Created https://github.com/$repo_owner/$repo_name"
