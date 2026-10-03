#!/bin/bash
# Run on your Mac (shown on the workspace page):
#   coder ssh <workspace> -- cat /home/coder/.local/share/coder-dcv/mac-setup.sh | tr -d '\r' | bash
# (coder ssh allocates a pty, so output arrives with CRLF line endings; tr strips the CR.)
#
# Installs a launchd agent that keeps `coder port-forward` to your running ec2-dcv workspace up:
#   localhost:18443 -> DCV 8443, localhost:19222 -> Chrome CDP 9222
# It finds the workspace by template at every (re)connect, so replacing the workspace needs no re-setup.
# Agents: Playwright MCP with --cdp-endpoint http://localhost:19222
set -euo pipefail

[ "$(uname)" = Darwin ] || { echo "Run this on your Mac, not in the workspace." >&2; exit 1; }
CODER_BIN=$(command -v coder) || { echo "coder CLI not found on PATH" >&2; exit 1; }

LABEL=com.coder.dcv-agent-tunnel
PLIST=~/Library/LaunchAgents/$LABEL.plist
SCRIPT=~/.local/bin/dcv-agent-tunnel.sh
LOG=~/Library/Logs/dcv-agent-tunnel.log

mkdir -p ~/.local/bin ~/Library/LaunchAgents
cat > "$SCRIPT" <<'TUNNEL'
#!/bin/bash
TEMPLATE=ec2-dcv

log() { echo "$(date '+%F %T') $*"; }
trap 'log "stopping"; kill $(jobs -p) 2>/dev/null; exit 0' TERM INT

log "starting"
while true; do
  WS=$(coder list --search "owner:me template:$TEMPLATE status:running" -c workspace 2>/dev/null | awk 'NR>1 {print $1; exit}')
  if [ -z "$WS" ]; then sleep 30; continue; fi
  # --disable-autostart: a stopped workspace stays stopped (no surprise bill from reconnect attempts).
  coder port-forward "$WS" --disable-autostart \
    --tcp 127.0.0.1:18443:8443 --tcp 127.0.0.1:19222:9222 >/dev/null 2>&1 &
  pid=$!
  log "port-forward to $WS started pid $pid"
  fails=0
  while kill -0 $pid 2>/dev/null; do
    sleep 10
    if curl -sf -m 5 http://localhost:19222/json/version >/dev/null; then fails=0; else fails=$((fails + 1)); fi
    # ~1 min of failures (laptop sleep, workspace stopped or replaced): reconnect, re-picking the workspace.
    if [ $fails -ge 6 ]; then
      log "unhealthy, restarting"
      kill $pid
    fi
  done
  log "port-forward exited"
  sleep 10
done
TUNNEL
chmod +x "$SCRIPT"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$SCRIPT</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$(dirname "$CODER_BIN"):/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST

launchctl bootout gui/$(id -u)/$LABEL 2>/dev/null || true
# bootout is async; bootstrap fails with "5: Input/output error" if the old job is still unloading.
while launchctl print gui/$(id -u)/$LABEL >/dev/null 2>&1; do sleep 1; done
launchctl bootstrap gui/$(id -u) "$PLIST"

echo "Installed launchd agent $LABEL (log: $LOG)"
echo "  DCV:  https://localhost:18443"
echo "  CDP:  http://localhost:19222   (Playwright MCP: --cdp-endpoint http://localhost:19222)"
echo "Uninstall: launchctl bootout gui/\$(id -u)/$LABEL && rm $PLIST $SCRIPT"
