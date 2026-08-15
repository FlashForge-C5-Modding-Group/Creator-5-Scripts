#!/bin/sh
set -e
set -u

TARGET_DIR="/usr/prog/scripts/scripts"

# Verify the target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory $TARGET_DIR does not exist." >&2
    exit 1
fi

# Scan and execute each .sh
for script in "$TARGET_DIR"/*.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            "$script" &
        else
            sh "$script" &
        fi
    fi
done
