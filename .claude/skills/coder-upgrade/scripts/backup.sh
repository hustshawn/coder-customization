#!/usr/bin/env bash
# Back up the Coder Postgres database before an upgrade, two independent ways:
#   1. pg_dump (custom format) to ~/coder-backups/, verified with pg_restore --list
#   2. EBS snapshot of the Postgres PVC's underlying volume
# Also records schema_migrations so there's a known-good pre-upgrade marker.
#
# Coder does not support rollback and a Helm rollback does NOT revert migrations,
# so this is the only real undo path.
#
# Usage: backup.sh <target-version-label> [--no-snapshot]
#   e.g. backup.sh 2.35.6
set -euo pipefail

NS="${CODER_NS:-coder}"
RELEASE="${CODER_RELEASE:-coder}"
REGION="${AWS_EBS_REGION:-ap-east-1}"   # the aws CLI default here is us-west-2 — wrong region
PGPOD="${PGPOD:-postgresql-0}"
PVC="${PGPVC:-data-postgresql-0}"

LABEL="${1:?usage: backup.sh <target-version-label> [--no-snapshot]}"
SNAPSHOT=true
[ "${2:-}" = "--no-snapshot" ] && SNAPSHOT=false

DIR="$HOME/coder-backups"
STAMP=$(date +%Y%m%d-%H%M)
DUMP="$DIR/coder-db-$STAMP.dump"
mkdir -p "$DIR"

# Credentials stay inside the pod: it already exposes POSTGRES_PASSWORD_FILE,
# POSTGRES_USER and POSTGRES_DATABASE, so nothing secret crosses the host boundary.
in_pg() {
  kubectl exec -n "$NS" "$PGPOD" -- bash -c "$1"
}
psql_q() {
  in_pg "PGPASSWORD=\$(cat \$POSTGRES_PASSWORD_FILE) psql -U \"\$POSTGRES_USER\" \
    -h 127.0.0.1 -d \"\$POSTGRES_DATABASE\" -tAc \"$1\""
}

echo "=== pre-upgrade state ==="
# Query version and dirty separately. Concatenating them in SQL renders the boolean as
# "false" rather than psql's usual "f", which makes the guard below ambiguous.
MIG_VER=$(psql_q "SELECT version FROM schema_migrations" | tr -d '[:space:]')
MIG_DIRTY=$(psql_q "SELECT dirty FROM schema_migrations" | tr -d '[:space:]')
TABLES=$(psql_q "SELECT count(*) FROM pg_tables WHERE schemaname = current_schema()" | tr -d '[:space:]')
WS=$(psql_q "SELECT count(*) FROM workspaces WHERE deleted = false" | tr -d '[:space:]')
USERS=$(psql_q "SELECT count(*) FROM users WHERE deleted = false" | tr -d '[:space:]')
MIG="$MIG_VER (dirty=$MIG_DIRTY)"
echo "schema_migrations: $MIG"
echo "public tables: $TABLES   workspaces: $WS   users: $USERS"

case "$MIG_DIRTY" in
  f|false) ;;
  *) echo "!! schema_migrations.dirty=$MIG_DIRTY — an earlier migration failed partway."
     echo "!! Resolve that before upgrading (docs/install/upgrade-best-practices.md)."
     exit 1 ;;
esac

echo
echo "=== pg_dump -> $DUMP ==="
in_pg 'PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE) pg_dump -U "$POSTGRES_USER" \
  -h 127.0.0.1 -Fc "$POSTGRES_DATABASE"' > "$DUMP"

[ -s "$DUMP" ] || { echo "!! dump is empty"; exit 1; }
[ "$(head -c 5 "$DUMP")" = "PGDMP" ] || { echo "!! dump lacks PGDMP header"; exit 1; }
ls -la "$DUMP"

echo
echo "=== verifying dump ==="
# `kubectl exec -i ... -- pg_restore --list < dump` hangs on stdin, so copy the file in
# and list it from a path instead.
kubectl cp "$DUMP" "$NS/$PGPOD:/tmp/verify.dump" >/dev/null 2>&1
ENTRIES=$(kubectl exec -n "$NS" "$PGPOD" -- pg_restore --list /tmp/verify.dump 2>/dev/null \
  | grep -c "TABLE DATA" || true)
kubectl exec -n "$NS" "$PGPOD" -- rm -f /tmp/verify.dump
echo "TABLE DATA entries in dump: $ENTRIES   (live public tables: $TABLES)"
[ "$ENTRIES" -gt 0 ] || { echo "!! dump not readable by pg_restore"; exit 1; }
[ "$ENTRIES" = "$TABLES" ] || echo "note: count differs from live tables — check before relying on this dump"

echo
echo "=== helm values -> $DIR/coder-values-$LABEL.yaml ==="
# -o yaml matters: bare `helm get values` prepends "USER-SUPPLIED VALUES:", which is not
# valid YAML and makes the file unusable as `-f` input.
helm get values "$RELEASE" -n "$NS" -o yaml > "$DIR/coder-values-$LABEL.yaml"
wc -l "$DIR/coder-values-$LABEL.yaml"

if $SNAPSHOT; then
  echo
  echo "=== EBS snapshot (region $REGION) ==="
  VOL=$(kubectl get pv "$(kubectl get pvc "$PVC" -n "$NS" -o jsonpath='{.spec.volumeName}')" \
    -o jsonpath='{.spec.csi.volumeHandle}')
  echo "volume: $VOL"
  SNAP=$(aws ec2 create-snapshot --region "$REGION" --volume-id "$VOL" \
    --description "coder postgres pre-upgrade -> $LABEL" \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=coder-pg-pre-$LABEL}]" \
    --query 'Snapshots[0].SnapshotId' --output text 2>/dev/null \
    || aws ec2 create-snapshot --region "$REGION" --volume-id "$VOL" \
       --description "coder postgres pre-upgrade -> $LABEL" \
       --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=coder-pg-pre-$LABEL}]" \
       --query 'SnapshotId' --output text)
  echo "snapshot: $SNAP"
  echo "poll: aws ec2 describe-snapshots --region $REGION --snapshot-ids $SNAP \\"
  echo "        --query 'Snapshots[0].[State,Progress]' --output text"
fi

cat <<EOF

=== BACKUP COMPLETE — record these ===
dump:              $DUMP
values:            $DIR/coder-values-$LABEL.yaml
schema_migrations: $MIG
tables/workspaces/users: $TABLES / $WS / $USERS
EOF
if $SNAPSHOT; then
  echo "snapshot:          ${SNAP:-n/a} (region $REGION)"
else
  echo "snapshot:          skipped (--no-snapshot)"
fi
