#!/bin/sh
(
    n=0
    while [ $n -lt 30 ]; do
        if ping -c1 -W2 time.nist.gov >/dev/null 2>&1; then
            rdate -s time.nist.gov
            break
        fi
        n=$((n+1))
        sleep 2
    done
)
return 1
