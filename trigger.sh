#!/usr/bin/env bash
# Triggers a daily-swipe workflow run NOW via the GitHub workflow_dispatch API,
# using the PAT in .token. Dispatch runs start within seconds, unlike the
# best-effort `schedule:` trigger. Usage: ./trigger.sh signin | signout
#
# Security: the token is written to a temp curl --config file (mktemp is 0600)
# and removed on exit. It never appears in argv / the process list.
set -euo pipefail

cd "$(dirname "$0")"

ACTION="${1:-}"
case "$ACTION" in
  signin)  WF="signin.yml" ;;
  signout) WF="signout.yml" ;;
  *) echo "Usage: $0 {signin|signout}" >&2; exit 2 ;;
esac

if [[ ! -s .token ]]; then
  echo "ERROR: .token is empty. Paste your GitHub PAT (repo + workflow scope) into it." >&2
  exit 1
fi
TOKEN="$(tr -d ' \t\r\n' < .token)"

CFG="$(mktemp)"
trap 'rm -f "$CFG"' EXIT
printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > "$CFG"

HTTP="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  --config "$CFG" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/AyushHarshit/daily-swipe/actions/workflows/${WF}/dispatches" \
  -d '{"ref":"main"}')"

if [[ "$HTTP" == "204" ]]; then
  echo "Triggered '$ACTION' ($WF). Check the Actions tab — the run should appear within seconds."
else
  echo "ERROR: GitHub API returned HTTP $HTTP (expected 204). Check the token scope and workflow name." >&2
  exit 1
fi
