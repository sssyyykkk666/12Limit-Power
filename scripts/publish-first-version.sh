#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
GH="${FYQMAC_GH:-$HOME/.local/bin/gh}"
OWNER=sssyyykkk666
REPO="$OWNER/FYQMac"
KEY="$HOME/.ssh/id_ed25519_fyqmac_github"
"$GH" auth status --hostname github.com
ACTUAL=$("$GH" api user --jq .login)
[ "$ACTUAL" = "$OWNER" ] || { echo "GitHub account mismatch: $ACTUAL"; exit 1; }
git diff --quiet
git diff --cached --quiet
[ -z "$(git ls-files --others --exclude-standard)" ] || { echo 'Uncommitted files exist'; exit 1; }
PUBLIC_KEY=$(awk '{print $1 " " $2}' "$KEY.pub")
EXISTING_KEYS=$("$GH" api user/keys --paginate --jq '.[].key')
if ! printf '%s\n' "$EXISTING_KEYS" | grep -Fxq "$PUBLIC_KEY"; then
  "$GH" ssh-key add "$KEY.pub" --title 'FYQMac Intel Mac'
fi
git config core.sshCommand "ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"
SSH_STATUS=0
SSH_RESULT=$(ssh -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -T git@github.com 2>&1) || SSH_STATUS=$?
[ "$SSH_STATUS" -eq 1 ] && [[ "$SSH_RESULT" == *"Hi $OWNER!"* ]] || { echo "$SSH_RESULT"; exit 1; }
if ! "$GH" repo view "$REPO" --json name >/dev/null 2>&1; then
  "$GH" repo create "$REPO" --private --description '为 Intel MacBook 定制的轻量中文功耗菜单栏，基于 VoltageShift 与 Swift AppKit'
fi
[ "$("$GH" repo view "$REPO" --json visibility --jq .visibility)" = PRIVATE ] || { echo 'Repository is not private; stopping'; exit 1; }
URL="git@github.com:$REPO.git"
if git remote get-url origin >/dev/null 2>&1; then
  [ "$(git remote get-url origin)" = "$URL" ] || { echo 'Remote mismatch'; exit 1; }
else
  git remote add origin "$URL"
fi
git push --atomic -u origin main refs/tags/v1.0.0
LOCAL=$(git rev-parse main)
REMOTE=$(git ls-remote origin refs/heads/main | awk '{print $1}')
[ "$LOCAL" = "$REMOTE" ]
git ls-remote origin refs/tags/v1.0.0
"$GH" repo view "$REPO" --json url,visibility,defaultBranchRef
