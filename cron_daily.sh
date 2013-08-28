#!/bin/sh

set -e

[ -x /usr/sbin/pov-simple-backup ] || exit 0
[ -f /etc/pov/backup ] || exit 0

/usr/sbin/pov-simple-backup
