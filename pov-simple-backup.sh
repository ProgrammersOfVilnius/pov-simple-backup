#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

usage="\
Usage: pov-simple-backup [-v] [-n] [-o|-s] [-f configfile]
       pov-simple-backup -h"

verbose=0
overwrite=0
skip=0
dry_run=0
configfile=/etc/pov/backup

libdir=.

while getopts hvf:osn OPT; do
    case "$OPT" in
        v)
            verbose=1
            ;;
        h)
            echo "$usage"
            exit 0
            ;;
        f)
            configfile=$(readlink -f "$OPTARG")
            ;;
        o)
            overwrite=1
            ;;
        s)
            skip=1
            ;;
        n)
            dry_run=1
            ;;
        *)
            echo "$usage" 1>&2
            exit 1
            ;;
    esac
done

shift $(($OPTIND - 1))

if [ $# -ne 0 ]; then
    echo "$usage" 1>&2
    exit 1
fi

if ! [ -f "$configfile" ]; then
    echo "$0: $configfile doesn't exist" 1>&2
    exit 1
fi

. "$libdir/functions.sh"

cd / || exit 1

BACKUP_ROOT=/backup
DATE=$(date +%Y-%m-%d)

umask 077

. "$configfile"

exit 0
