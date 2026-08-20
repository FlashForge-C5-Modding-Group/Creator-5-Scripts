#!/bin/sh
#
# Scans TARGET_DIR for .sh scripts and executes each one in the
# background, logging its output individually to /tmp.
#
set -e
set -u

TARGET_DIR="/usr/prog/scripts/scripts"
LAUNCHER_LOG="/tmp/launcher.sh.log"

# --------------------------------------------------------------
# All of this launcher's own messages (as opposed to the output
# of the scripts it launches) go to LAUNCHER_LOG instead of
# stdout/stderr, so they don't get mixed into whatever is
# capturing the caller's output, and so there's a single place
# to check "what did the launcher itself do on this boot".
# --------------------------------------------------------------
log_launcher() {
    echo "$1" >> "$LAUNCHER_LOG"
}

# --------------------------------------------------------------
# No lock file here on purpose.
#
# This launcher is only ever invoked once per boot, by a single
# caller that guarantees it won't be run twice. A lock file would
# add a failure mode (a stale lock blocking every future run)
# without protecting against anything that can actually happen
# in this setup, so we skip it entirely.
# --------------------------------------------------------------

# --------------------------------------------------------------
# Verify the target directory exists before doing anything else.
# --------------------------------------------------------------
if [ ! -d "$TARGET_DIR" ]; then
    log_launcher "Error: Directory $TARGET_DIR does not exist."
    exit 1
fi

# --------------------------------------------------------------
# Scan and execute each .sh script found in TARGET_DIR.
#
# Each script gets:
#   - its own log file in /tmp, named after the script
#   - a header line noting whether the +x bit was set
#     (informational only: we run every script through "sh",
#     so a missing +x bit does not prevent execution)
# --------------------------------------------------------------
for script in "$TARGET_DIR"/*.sh; do

    # Guards against the literal glob string when TARGET_DIR is
    # empty (POSIX sh has no nullglob, so "*.sh" would otherwise
    # be treated as a real, non-existent filename).
    if [ -f "$script" ]; then

        script_name=$(basename "$script")
        log_file="/tmp/${script_name}.log"

        if [ -x "$script" ]; then
            EXEC_TYPE="has +x"
        else
            EXEC_TYPE="missing +x"
        fi

        log_launcher "Launched: $script_name ($EXEC_TYPE)"

        ( echo "=== Executed via sh ($EXEC_TYPE) ==="; sh "$script" ) > "$log_file" 2>&1 &
    fi
done

# --------------------------------------------------------------
# Intentionally NOT waiting for background scripts here.
#
# The caller (e.g. the main boot script) must continue immediately
# after launching everything; it should not block on how long the
# individual scripts take to finish. Each script's own log file is
# the way to check on its progress/completion after the fact.
# --------------------------------------------------------------
