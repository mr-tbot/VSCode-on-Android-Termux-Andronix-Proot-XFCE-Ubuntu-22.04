#!/data/data/com.termux/files/usr/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  add-wakelock.sh — Inject termux-wake-lock into start-ubuntu22.sh
# ─────────────────────────────────────────────────────────────────────
#  Run this script ONCE from Termux (not inside proot).
#  It adds "termux-wake-lock" right after the shebang line in your
#  proot start script so the device stays awake for the entire session.
#
#  Usage:
#    chmod +x add-wakelock.sh
#    ./add-wakelock.sh                          # default: ~/start-ubuntu22.sh
#    ./add-wakelock.sh /path/to/my-start.sh     # custom path
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

TARGET="${1:-$HOME/start-ubuntu22.sh}"

# ── Sanity checks ───────────────────────────────────────────────────
if [[ ! -f "$TARGET" ]]; then
    echo "❌  File not found: $TARGET"
    echo "    Pass the path to your proot start script as the first argument."
    exit 1
fi

if ! command -v termux-wake-lock &>/dev/null; then
    echo "⚠️  termux-wake-lock not found."
    echo "    Install it with:  pkg install termux-api"
    echo "    Also install the Termux:API companion app from F-Droid."
    exit 1
fi

# ── Check if already patched ────────────────────────────────────────
if grep -q '^termux-wake-lock' "$TARGET"; then
    echo "✅  termux-wake-lock is already present in $TARGET — nothing to do."
    exit 0
fi

# ── Inject after the shebang line ───────────────────────────────────
# If the first line is a shebang (#!), insert on line 2.
# Otherwise insert at the very top.

if head -1 "$TARGET" | grep -q '^#!'; then
    sed -i '1a\termux-wake-lock' "$TARGET"
    echo "✅  Added termux-wake-lock after the shebang in $TARGET"
else
    sed -i '1i\termux-wake-lock' "$TARGET"
    echo "✅  Added termux-wake-lock at the top of $TARGET"
fi

echo "    The device will now stay awake whenever you run: $TARGET"
