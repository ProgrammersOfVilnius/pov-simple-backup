#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

usage="\
Usage: pov-simple-backup [-v] [-n] [-o|-s] [-f configfile]
       pov-simple-backup -S [-v] [-f configfile]
       pov-simple-backup -g > configfile
       pov-simple-backup -h"

verbose=0
overwrite=0
skip=0
dry_run=0
estimate_size=0
generate=0
configfile=/etc/pov/backup

libdir=.

while getopts hvf:gosnS OPT; do
    case "$OPT" in
        v)
            verbose=1
            ;;
        h)
            echo "$usage"
            exit 0
            ;;
        g)
            generate=1
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
        S)
            estimate_size=1
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

if [ $generate -ne 0 ]; then
    . "$libdir/generate.sh"
    generate
    exit 0
fi

if ! [ -f "$configfile" ]; then
    echo "$0: $configfile doesn't exist" 1>&2
    exit 1
fi

if [ $estimate_size -ne 0 ]; then
    . "$libdir/estimate.sh"
else
    . "$libdir/functions.sh"
fi

cd / || exit 1

BACKUP_ROOT=/backup
DATE=$(date +%Y-%m-%d)

umask 077

. "$configfile"

if [ $estimate_size -ne 0 ]; then
    estimate_summary
fi

exit 0
