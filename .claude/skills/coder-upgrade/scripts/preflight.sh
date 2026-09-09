#!/usr/bin/env bash
# Read-only survey of the Coder deployment and available upstream versions.
# With a target tag (e.g. v2.35.6) it also sizes up the jump: migration count,
# chart values diff, and the breaking-change notes of every intermediate minor.
#
# Usage: preflight.sh [target-tag]
set -uo pipefail

NS="${CODER_NS:-coder}"
RELEASE="${CODER_RELEASE:-coder}"
TARGET="${1:-}"

hr() { printf '\n=== %s ===\n' "$1"; }

hr "kube context"
kubectl config current-context

hr "running version"
CUR_IMAGE=$(kubectl get deploy "$RELEASE" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
CUR_TAG="${CUR_IMAGE##*:}"
echo "image:   $CUR_IMAGE"
kubectl get deploy,pods -n "$NS" -l app.kubernetes.io/name=coder 2>&1

hr "helm release"
helm list -n "$NS" 2>&1
echo "-- recent history --"
helm history "$RELEASE" -n "$NS" 2>&1 | tail -5

hr "user-supplied values"
helm get values "$RELEASE" -n "$NS" -o yaml 2>&1

hr "database"
kubectl get sts,pvc -n "$NS" 2>&1 | grep -iE 'postgres|NAME' || echo "no in-cluster postgres found"
echo "-- schema_migrations (version|dirty) --"
kubectl exec -n "$NS" postgresql-0 -- bash -c 'PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE) \
  psql -U "$POSTGRES_USER" -h 127.0.0.1 -d "$POSTGRES_DATABASE" \
  -tAc "SELECT version, dirty FROM schema_migrations"' 2>&1 | tail -2

hr "upstream releases (row marked Latest == STABLE channel; highest number == mainline)"
gh release list --repo coder/coder --limit 12 2>&1

hr "chart versions"
if helm repo list 2>/dev/null | grep -q coder-v2; then
  helm search repo coder-v2/coder --versions 2>/dev/null | head -8
else
  echo "coder-v2 repo not added yet:"
  echo "  helm repo add coder-v2 https://helm.coder.com/v2 && helm repo update coder-v2"
fi

hr "local CLI (AGPL means no ESR channel; brew formula often lags upstream)"
coder version 2>&1 | head -1
brew list --versions coder 2>/dev/null || true

# ---------------------------------------------------------------- jump assessment
[ -z "$TARGET" ] && {
  printf '\nPass a target tag (e.g. %s v2.35.6) to size up the jump.\n' "$(basename "$0")"
  exit 0
}

# Migration count via the git tree API. The contents API truncates at 1000 entries,
# which silently undercounts.
count_migrations() {
  gh api "repos/coder/coder/git/trees/$1?recursive=1" \
    -q '[.tree[]|select(.path|test("coderd/database/migrations/.*\\.up\\.sql$"))]|length' 2>/dev/null
}

hr "migrations to apply ($CUR_TAG -> $TARGET)"
A=$(count_migrations "$CUR_TAG"); B=$(count_migrations "$TARGET")
if [ -n "$A" ] && [ -n "$B" ]; then
  echo "$CUR_TAG: $A    $TARGET: $B    delta: $((B - A))"
  echo "Official guidance: 4-7 min for a large jump; >15 min means investigate."
else
  echo "could not count (check gh auth / tag names)"
fi

hr "chart values.yaml diff ($CUR_TAG -> $TARGET)"
TMP=$(mktemp -d)
for t in "$CUR_TAG" "$TARGET"; do
  gh api "repos/coder/coder/contents/helm/coder/values.yaml?ref=$t" -q .content 2>/dev/null \
    | base64 -d > "$TMP/$t.yaml"
done
if diff -u "$TMP/$CUR_TAG.yaml" "$TMP/$TARGET.yaml"; then
  echo "(identical)"
fi
echo
echo ">> Additive-only (new optional keys) => existing values file carries over unchanged."
echo ">> Renamed/removed keys => edit the values file BEFORE upgrading."
rm -rf "$TMP"

hr "breaking changes / deprecations in intermediate minors"
cur_minor=$(echo "$CUR_TAG" | sed -E 's/^v([0-9]+)\.([0-9]+).*/\2/')
tgt_minor=$(echo "$TARGET"  | sed -E 's/^v([0-9]+)\.([0-9]+).*/\2/')
major=$(echo "$TARGET" | sed -E 's/^v([0-9]+)\..*/\1/')
for m in $(seq $((cur_minor + 1)) "$tgt_minor"); do
  printf '\n---------- v%s.%s.0 ----------\n' "$major" "$m"
  # Enable on a BREAKING/DEPRECATION heading, disable on any other heading, print while on.
  gh release view "v$major.$m.0" --repo coder/coder --json body -q .body 2>/dev/null \
    | awk '/^#+ /{ f = ($0 ~ /BREAKING|DEPRECATION/) } f' \
    | head -50
done

cat <<'EOF'

>> Filter hard. Most entries are dashboard refactors that mean nothing here.
>> What matters: keys in `helm get values`, the auth flow, coder_agent/coder_env/module
>> usage in templates/, and the Postgres schema.
>> The ESR upgrade guides are the best cross-minor summary:
>>   gh api repos/coder/coder/contents/docs/install/releases/ -q '.[].name'
EOF
