#!/bin/sh

. $(dirname $0)/functions.sh

n_tests=0

warn() {
    echo "$@" 1>&2
}

assertEqual() {
    fn=$1
    shift
    if [ x"$1" = x"=" ]; then
        args="$fn"
        actual=$($fn)
        expected=$2
    elif [ x"$2" = x"=" ]; then
        args="$fn $1"
        actual=$($fn $1)
        expected=$3
    elif [ x"$3" = x"=" ]; then
        args="$fn $1 $2"
        actual=$($fn $1 $2)
        expected=$4
    else
        warn "expected one of these forms:"
        warn "  assertEqual fn = value"
        warn "  assertEqual fn arg = value"
        warn "  assertEqual fn arg1 arg2 = value"
        warn "got"
        warn "  assertEqual $fn $@"
        exit 1
    fi
    if ! [ x"$actual" = x"$expected" ]; then
        warn "assertion failure: $args == $actual (expected $expected)"
        exit 1
    fi
    n_tests=$(($n_tests + 1))
}

assertEqual slugify /etc = etc
assertEqual slugify /etc/ = etc
assertEqual slugify /var/lib/dpkg/info = var-lib-dpkg-info
assertEqual slugify "" = root

echo "all $n_tests tests passed"
