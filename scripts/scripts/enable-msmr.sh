#!/bin/sh
export LD_LIBRARY_PATH="/usr/prog/Python-3.8.2/lib:${LD_LIBRARY_PATH:-}"

(
    # Poll until available (60s should be more than long enough)
    i=0
    while ! pgrep -f "klippy" > /dev/null 2>&1 && [ "$i" -lt 60 ]; do
        sleep 1
        i=$((i+1))
    done

    if pgrep -f "klippy" > /dev/null 2>&1; then
        /usr/prog/nginx/sbin/nginx -p /usr/prog/nginx -c /usr/prog/nginx/conf/nginx.conf &
        /usr/prog/klipper/moonrakerDaemon start
    fi
) &
