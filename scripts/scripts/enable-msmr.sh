#!/bin/sh

if pgrep -f "klippy" > /dev/null 2>&1; then
    /usr/prog/nginx/sbin/nginx -p /usr/prog/nginx -c /usr/prog/nginx/conf/nginx.conf
    /usr/prog/klipper/moonrakerDaemon start
fi
