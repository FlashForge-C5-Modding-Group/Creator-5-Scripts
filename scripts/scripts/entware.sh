#!/bin/sh
mount --bind /usr/data/bin/opt /opt
[ -x /opt/etc/init.d/rc.unslung ] && /opt/etc/init.d/rc.unslung start
return 1
