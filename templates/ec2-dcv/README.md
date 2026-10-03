---
display_name: AWS EC2 DCV Desktop (Linux)
description: Ubuntu desktop over Amazon DCV with a persistent Chrome that coding agents drive via CDP
icon: ../../../site/static/icon/dcv.svg
maintainer_github: coder
verified: false
tags: [vm, linux, aws, persistent-vm, desktop, dcv]
---

# Remote desktop browser for coding agents on AWS EC2

A GNOME desktop served by [Amazon DCV](https://docs.aws.amazon.com/dcv/latest/adminguide/what-is-dcv.html),
with a Chrome that agents (Claude Code / Codex / Kiro) control over the Chrome DevTools Protocol (CDP), while you
watch and take over in the browser.

```
browser ──Coder login──▶ Coder app "Desktop (DCV)" ──agent tunnel──▶ EC2: DCV :8443
                                                                     Chrome CDP 127.0.0.1:9222  ◀── Claude Code (in workspace)
Mac agent ──coder port-forward ──────────────────────────────────▶   Chrome CDP                 ◀── or from your laptop
```

## What you get

- **Desktop (DCV)** app on the workspace page — logs straight in (random per-workspace password, passed in the app URL)
- Chrome autostarted in the DCV session with CDP on `127.0.0.1:9222` and a persistent profile
  (`~/.config/agent-chrome`): log in to sites once in DCV, agents reuse the session; survives workspace stop/start
- Claude Code (Bedrock) with the `remote-browser` Playwright MCP preconfigured (`--cdp-endpoint http://localhost:9222`)

## Use from your laptop

```bash
coder port-forward <workspace> --tcp 19222:9222
# MCP: npx -y @playwright/mcp@latest --cdp-endpoint http://localhost:19222
```

## Design notes

- **No ingress** in the security group. DCV and CDP are only reachable through the Coder agent tunnel
- **Minimal IAM**: SSM core, DCV license bucket read, Bedrock invoke. Unlike `ec2-linux`, no AdministratorAccess,
  because this box holds a browser full of logged-in sessions
- **x86_64 only**: Google Chrome has no Linux arm64 build
- **Ubuntu 24.04**, DCV virtual session `desktop` owned by `coder`, kept alive by `dcv-virtual-session.service`
- First start installs the desktop, DCV and Chrome (~10 min, see the "DCV Desktop" script log); later starts only
  re-apply config
- Chrome runs with `--password-store=basic` (avoids the GNOME keyring dialog blocking startup); cookies are encrypted
  with a fixed key, so at-rest protection relies on the encrypted EBS root volume
- Screen lock is disabled in the session
- CDP has no auth — anything that can reach port 9222 controls the browser

## Caveats

- With `CODER_BLOCK_DIRECT=true` all traffic is relayed through coderd; put the workspace in the same region as
  Coder (default `ap-east-1`) to keep the DCV stream responsive
- Deleting the workspace deletes the Chrome profile (logins)
