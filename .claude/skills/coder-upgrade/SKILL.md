---
name: coder-upgrade
description: >
  Upgrade the self-hosted Coder control plane running on EKS via Helm — pick a target
  version from the right release channel, assess the size of the version jump, back up
  Postgres, run the upgrade, and verify it. Use this skill whenever the user asks about
  Coder versions or upgrading Coder in any phrasing: "最新的 Coder 版本是多少", "升级/更新
  coder", "帮我更新到 stable 版", "coder 要升级需要做什么", "helm upgrade coder", "是不是
  该升级 coder 了", or asks what would break if they upgraded. Also use it when Coder is
  behaving oddly and the version might be the cause, or when the user wants to check
  whether their deployment is behind upstream — even if they haven't said the word
  "upgrade". Do NOT use it for upgrading the Coder CLI alone, for pushing workspace
  templates (that is ./push-templates.sh), or for upgrading the in-cluster Postgres chart.
---

# Upgrading Coder on EKS

Coder applies database migrations on startup and **does not support rollback**. A Helm
rollback reverts the container image but leaves the schema migrated forward, and the old
binary refuses to run against a newer schema. So the backup in step 3 is the only real
undo, and skipping it turns a routine upgrade into an unrecoverable one. Everything else
here is ordinary care; that one step is the load-bearing one.

## The deployment this targets

There is exactly **one** Coder deployment. If something suggests a second one, it's stale —
verify before believing it.

The concrete identifiers — cluster name, account IDs, hostnames, Route53 zone — live in
`CLAUDE.local.md` at the repo root, which is untracked because this repo is public. Every
`<PLACEHOLDER>` below is defined there; read it first if it isn't already in context.

| | |
|---|---|
| Cluster | `<EKS_CLUSTER>` (ap-east-1, account `<AWS_ACCOUNT>`) |
| Namespace / Helm release | `coder` / `coder` |
| Dashboard | `https://<CODER_HOST>` |
| Chart | `coder-v2/coder` from `https://helm.coder.com/v2` |
| Database | in-cluster Bitnami Postgres, `statefulset/postgresql`, pod `postgresql-0`, db+user `coder` |
| **AWS region for EBS work** | **`ap-east-1`** — the local `aws` CLI defaults to `us-west-2`, so every `aws ec2` call needs an explicit `--region ap-east-1` or it will silently look in the wrong region |
| **App wildcard** | `*.<APP_DOMAIN>` → CNAME to the HK ALB `<ALB_DNS>` |
| **Route53 zone** | `<ROUTE53_ZONE_ID>`, in account `<DNS_ACCOUNT>` — reachable via the **`main`** AWS CLI profile, *not* the default one |
| Local CLI | Homebrew (`/opt/homebrew/bin/coder`), and the formula lags upstream by several minors |

The DNS zone living in a different account than the cluster is the single most confusing
thing about this setup. `aws route53 ...` with the default profile returns an empty list of
hosted zones, which reads like "no DNS here" rather than "wrong account".

Scripts read `CODER_NS` / `CODER_RELEASE` if you ever point them elsewhere, defaulting to
`coder` for both.

## Step 0 — Pick a target version

Coder cuts a release from `main` on the first Tuesday of each month and runs four channels:

- **Mainline** — newest minor, bleeding edge
- **Stable** — N-1, promoted after mainline has been public for a month. **Default choice.**
- **Security Support** — N-2, security/CVE patches only
- **ESR** — biannual long-term version, patches only, **paying customers only**

This deployment is AGPL (`coder version` prints `Coder (AGPL)`), so ESR is out. Go to
**stable** unless the user asks otherwise.

Read the channel off `gh release list --repo coder/coder`: the row tagged `Latest` is
**stable**, and the highest version number is **mainline**. This is counterintuitive
enough that it's worth double-checking rather than assuming the top row is what you want.

> Fetching docs: `coder.com` and `api.github.com` are both blocked for WebFetch in this
> environment. Use `gh` instead. The docs are in the repo, so
> `gh api repos/coder/coder/contents/docs/install/upgrade-best-practices.md -q .content | base64 -d`
> reads any doc page. Useful ones live under `docs/install/`: `upgrade.md`,
> `upgrade-best-practices.md`, `kubernetes.md`, `releases/index.md`, and the
> `releases/esr-*-upgrade.md` guides — those ESR guides are by far the best source for
> "what actually changes across several minors", even when you aren't on an ESR version.

## Step 1 — Survey current state

```bash
.claude/skills/coder-upgrade/scripts/preflight.sh              # state + available versions
.claude/skills/coder-upgrade/scripts/preflight.sh v2.35.6      # ...plus assessment of that jump
```

With a target argument it also counts the migrations you're about to apply, diffs the
chart's `values.yaml` between the two tags, and dumps the BREAKING CHANGES / DEPRECATIONS
sections of every intermediate minor.

## Step 2 — Assess the jump

Read what preflight printed, and judge rather than skim. Three questions:

**Do any breaking changes touch this deployment?** Most entries in Coder's release notes
are dashboard refactors and internal cleanups that read alarming and mean nothing here.
What matters is anything touching the values in `helm get values`, the auth flow,
`coder_agent`/`coder_env`/module usage in `templates/`, or the Postgres schema. Report the
handful that apply and ignore the rest — listing forty irrelevant "BREAKING" lines buries
the two that matter.

**Did the chart's `values.yaml` change incompatibly?** Additive changes (new optional keys)
mean the existing values file carries over untouched. A renamed or removed key means you
must edit the values file before upgrading.

**Do the workspace templates still hold up?** Scan `templates/` for things the release
notes deprecate. Known-relevant checks, from the 2.30→2.35 upgrade:

```bash
grep -rnE 'coder_agent|coder_env|sidebar_app|^[[:space:]]+dir[[:space:]]*=' templates/
grep -rn '^module\|registry.coder.com' templates/
grep -rnA4 required_providers templates/*/main.tf
```

`coder_agent`'s `dir` attribute is deprecated and breaks Coder Desktop file sync unless
it's `$HOME`; the pre-2.28 `sidebar_app` Tasks format was dropped in 2.30. Since 2.34,
Terraform modules are **cached per template version**, so `registry.coder.com` module
updates only land when a new template version is pushed — which `./push-templates.sh`
does anyway. The `coder/coder` provider is unpinned in both templates, so the first
template push after an upgrade pulls a fresh provider; that's the strongest argument for
building one real workspace as a post-upgrade check.

Also decide **maintenance window**. Migration count is the driver: the official guidance
is 4–7 minutes for a large jump, with >15 minutes meaning something is wrong. In practice
this deployment is small (single replica, ~100 tables, a handful of workspaces) and the
2.30.4→2.35.6 jump with 123 migrations finished in well under a minute. Don't quote the
official worst case as if it were the expectation here, but do leave room for it.

## Step 3 — Back up

```bash
.claude/skills/coder-upgrade/scripts/backup.sh 2.35.6
```

This writes a verified `pg_dump` to `~/coder-backups/`, takes an EBS snapshot of the
Postgres volume, and records `schema_migrations` (version + `dirty` flag) so you have a
known-good pre-upgrade marker. Two independent backups is deliberate — the dump is fast to
inspect and partially restore, the snapshot recovers the volume wholesale.

Do not proceed until the script reports the dump verified and `dirty=false`. A pre-existing
`dirty=true` means an earlier migration failed halfway and needs sorting out first.

## Step 4 — Upgrade

```bash
NS=coder
helm repo add coder-v2 https://helm.coder.com/v2 2>/dev/null; helm repo update coder-v2

# Clean values file. Use -o yaml: bare `helm get values` prefixes its output with
# "USER-SUPPLIED VALUES:", which is not valid YAML and makes -f fail confusingly.
helm get values coder -n $NS -o yaml > ~/coder-backups/coder-values-<target>.yaml

# Render first — catches values/chart mismatches before anything is touched.
helm upgrade coder coder-v2/coder -n $NS --version <target> \
  -f ~/coder-backups/coder-values-<target>.yaml --dry-run=client > /tmp/render.yaml
grep -nE 'image:|livenessProbe|readinessProbe|replicas:|ingressClassName' /tmp/render.yaml
```

In the rendered output confirm the image tag is your target, `replicas: 1`,
`ingressClassName: "coder-alb"` survived, and that **`livenessProbe` is absent**. Coder
disabled liveness probes by default in 2.30+ precisely because they kill pods mid-migration;
if one shows up, migrations can be killed halfway and leave the schema `dirty`.

```bash
# Scale to zero so migrations acquire locks without competing with the old pod.
kubectl scale deployment coder -n $NS --replicas=0
kubectl wait --for=delete pod -l app.kubernetes.io/name=coder -n $NS --timeout=120s

# No --wait: Helm's default 5m timeout can be shorter than a long migration, and blocking
# here can also outrun the shell's own timeout. Apply, return, then poll.
helm upgrade coder coder-v2/coder -n $NS --version <target> \
  -f ~/coder-backups/coder-values-<target>.yaml
```

The chart sets `replicas` back to 1, so no manual scale-up is needed.

```bash
kubectl get pods -n $NS -l app.kubernetes.io/name=coder -w
kubectl logs -n $NS -l app.kubernetes.io/name=coder -f
```

Watch for `CrashLoopBackOff`. If it appears, read
`docs/install/upgrade-best-practices.md` (§ Recovering from failed database migrations)
before touching anything — the usual cause is lock contention, not a corrupt database, and
it's recoverable without restoring.

## Step 5 — Verify

Check all of these, and read the values rather than just confirming the commands ran:

```bash
curl -fsS https://<CODER_HOST>/api/v2/buildinfo   # version == target
curl -fsS -o /dev/null -w '%{http_code}\n' https://<CODER_HOST>/healthz
kubectl get pods -n coder -l app.kubernetes.io/name=coder            # 1/1, 0 restarts

# dirty must be false; note the version so you can compare against the pre-upgrade marker
kubectl exec -n coder postgresql-0 -- bash -c 'PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE) \
  psql -U "$POSTGRES_USER" -h 127.0.0.1 -d "$POSTGRES_DATABASE" \
  -tAc "SELECT version, dirty FROM schema_migrations"'

# data survived
kubectl exec -n coder postgresql-0 -- bash -c 'PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE) \
  psql -U "$POSTGRES_USER" -h 127.0.0.1 -d "$POSTGRES_DATABASE" \
  -tAc "SELECT count(*) FROM workspaces WHERE deleted = false"'

# triage new warnings — expect a small, explainable set, not silence
kubectl logs -n coder -l app.kubernetes.io/name=coder --tail=400 \
  | grep -E '\[error\]|\[fatal\]|\[warn\]' | sort | uniq -c | sort -rn
```

Any `[warn]` that is new since the upgrade deserves being traced to its source in the
Coder repo before being called benign — `gh api repos/coder/coder/contents/<path>?ref=<tag>`
plus a grep for the message text lands on the emitting code and shows what the server
actually does next. That's how the terraform warning below turned from "probably fine" into
a specific known answer.

Then hand back to the user, because these need a human:

1. `coder login` — the CLI session expires and login is interactive
2. Build one real workspace from `templates/ec2-linux` — the genuine end-to-end check,
   especially with unpinned providers and registry modules
3. The local CLI version, if Homebrew still lags (see below)

## Rollback reality

`helm rollback coder <rev>` restores the old image but **not** the schema. Once migrations
have run, the old binary won't start. Real recovery is:

1. `kubectl scale deployment coder -n coder --replicas=0`
2. Restore the dump (`pg_restore`) or the EBS snapshot from step 3
3. `helm rollback coder <pre-upgrade revision> -n coder`

Say this plainly when reporting a completed upgrade. It's easy for "we have backups and a
Helm history" to be heard as "we can roll back in one command," which isn't true.

## Gotchas already paid for

Each of these cost time during the 2.30.4→2.35.6 upgrade. They are environment quirks, not
things you can reason your way to.

- **`helm get values` without `-o yaml`** emits a `USER-SUPPLIED VALUES:` header that makes
  the file invalid as `-f` input.
- **`kubectl exec -i <pod> -- pg_restore --list < file.dump` hangs.** To verify a dump
  inside the pod, `kubectl cp` it in, run `pg_restore --list` on the path, then delete it.
- **Never pass the DB password from the host.** The Postgres pod exposes
  `$POSTGRES_PASSWORD_FILE`, `$POSTGRES_USER` and `$POSTGRES_DATABASE`, so
  `kubectl exec … -- bash -c 'PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE) psql -U "$POSTGRES_USER" …'`
  keeps the secret in the pod and dodges a layer of quoting.
- **`psql -tAc` with single-quoted SQL literals** gets mangled through nested shell quoting.
  Prefer `current_schema()` and other function calls over `'public'`-style literals.
- **`psql` renders booleans two different ways.** `SELECT version, dirty` prints `535|f`,
  but `SELECT version || '|' || dirty` prints `535|false` — the concatenation casts to text
  in full. Comparing against `f` alone silently reports a healthy database as corrupt.
  Query the flag on its own rather than building a composite string.
- **`aws ec2` needs `--region ap-east-1`.** The CLI default is `us-west-2`.
- **zsh needs URLs with `?` quoted** — `gh api "…/values.yaml?ref=$t"`, or you get
  `no matches found`.
- **The GitHub contents API truncates at 1000 entries**, which silently undercounts
  migrations. Use the git tree API (`git/trees/<tag>?recursive=1`), as `preflight.sh` does.
- **Homebrew's `coder` formula lags upstream** (2.33.6 while upstream was at 2.36.3), so
  `brew upgrade coder` won't reach a current version. Installing via `install.sh` would
  overwrite the Homebrew-managed binary — that's the user's call to make, not a step to
  perform silently. A CLI one or two minors behind the server works fine.

## Version-specific findings

Carry these forward and add to them; they're the things a fresh look wouldn't rediscover.

**AI Gateway is on by default since ~2.34.** `CODER_AIBRIDGE_ENABLED` (default `false`) was
renamed `CODER_AI_GATEWAY_ENABLED` and its default flipped to `true`, so an in-memory AI
Gateway starts on every deployment after upgrading past it. With no providers configured it
just idles (`provider_count=0` in the logs), which is harmless. Flag it to the user rather
than silently adding config to suppress it — they asked for an upgrade, not a config change:

```yaml
- name: CODER_AI_GATEWAY_ENABLED
  value: "false"
```

**The terraform version warning in 2.35.6 is an upstream packaging slip, not a
misconfiguration.**

```
[warn] provisionerd: installed terraform version newer than expected, you may experience bugs
       installed_version=1.15.5  max_version=1.14.9
```

The image bundles Terraform 1.15.5 while `provisioner/terraform/install.go` still declares
`maxTerraformVersion = 1.14.9` — the Dockerfile's own comment says to keep them in sync and
it wasn't. Per `serve.go`, Coder **warns and uses the newer binary anyway** (it stopped
downloading its own version to make testing newer Terraform easier), so builds run on
1.15.5. Harmless in itself, but it's a real reason to build one workspace before declaring
success.

**Secure auth cookies auto-enable when `CODER_ACCESS_URL` is HTTPS** (somewhere in
2.30–2.34). This deployment sits behind an ALB with `proxyTrustedOrigins: 10.0.0.0/8` and
was fine, but a login failure right after an upgrade points here first.

## When a workspace app won't open, check DNS before reading source

This one cost hours. A JupyterLab app returned `400 - Invalid Application URL: invalid
application url format "jupyterlab--jp-c8i-2--shawnzh"`, which reads exactly like a Coder
bug — and the investigation went deep into `appurl.go`, `db2sdk.go`, Go vs Python regex
semantics, and even grepping the regex literal out of the running binary. All of it was
wasted, because the request was never reaching this deployment at all.

**Check the routing first — it's one command and it eliminates the whole class:**

```bash
dig +short <app>--<workspace>--<owner>.<APP_DOMAIN>
dig +short <ALB_DNS>   # must match
```

If they differ, nothing about Coder's code matters yet. To confirm this deployment is
innocent, force the app hostname at the right ALB and watch the behaviour change:

```bash
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' \
  --resolve "$H:443:<HK-ALB-IP>" "https://$H/"
```

`303` to `/api/v2/applications/auth-redirect` means healthy. A `400` over real DNS plus a
`303` over `--resolve` is a DNS problem, full stop.

**Why the error message was so misleading:** since 2.30, `db2sdk.AppSubdomain` deliberately
*omits* the agent name for non-port app slugs, so this deployment generates 3-segment names
(`jupyterlab--<ws>--<owner>`). Coder ≥2.30 parses that fine — the regex has an optional agent
group. The old 2.25.2 deployment that the wildcard pointed at required 4 segments, so it
rejected a hostname that was perfectly valid for the deployment that generated it.

**Expected responses once routing is right**, so a healthy state isn't mistaken for a bug:

| Response | Meaning |
|---|---|
| `303` → `/api/v2/applications/auth-redirect` | working, just needs auth |
| `400 - Workspace Offline` | workspace is stopped — not a fault |
| `400 - Invalid Application URL` | genuinely malformed, or wrong deployment |

Also note `<OLD_CODER_HOST>` (the deleted deployment's old hostname) now falls
through to the wildcard and returns `400 - Invalid Application URL` on this deployment. That
is expected — it is not evidence of a surviving second deployment.

**Why subdomain apps fail while others don't:** `subdomain=false` apps (code-server here) are
served as a path under the dashboard host, so they bypass the wildcard entirely and keep
working. If exactly the subdomain apps are broken, suspect the wildcard, not Coder.

## Upgrade history

Append a row after each upgrade — the previous jump's size and duration is the best
predictor of the next one's.

| Date | From → To | Migrations | Downtime | Notes |
|---|---|---|---|---|
| 2026-08-30 | v2.30.4 → v2.35.6 (stable) | 123 (schema_migrations 412 → 535) | ~1.5 min | Helm rev 9 → 10. Chart values additive only, reused unchanged. AI Gateway self-enabled; terraform 1.15.5 warning appeared. 88 → 116 tables. 6 workspaces / 2 users intact. |

## Other changes worth knowing

**2026-08-31 — second Coder deployment removed.** A v2.25.2 deployment in cluster
`<OLD_CLUSTER>` (us-west-2, account `<DNS_ACCOUNT>`, dashboard `<OLD_CODER_HOST>`)
was deleted, and `*.<APP_DOMAIN>` was repointed to the HK ALB. That old deployment
owned the wildcard through external-dns, which is what broke subdomain apps here.

Two mechanics from that cleanup are worth remembering if anything similar comes up:

- **external-dns ran with `--policy=upsert-only`**, so it never deletes records. Removing a
  host from an ingress makes it stop *re-asserting* the record but leaves the old one in
  place, so the Route53 record still has to be fixed by hand. Conversely, leaving the host on
  the ingress means any manual DNS fix gets overwritten within a minute.
- **That release had annotation drift** — its values said `group.name: shared-alb` while the
  live ingress said `coder-dedicated`. A plain `helm upgrade` would have moved its ALB. When a
  release has been hand-edited, patch the live object instead of upgrading, or reconcile the
  values first. Worth checking here too before assuming `helm upgrade` is inert.
