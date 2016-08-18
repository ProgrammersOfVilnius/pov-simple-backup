#!/bin/bash

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
        actual=$($fn "$1")
        expected=$3
    elif [ x"$3" = x"=" ]; then
        args="$fn $1 $2"
        actual=$($fn "$1" "$2")
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
    n_tests=$((n_tests + 1))
}

. "$(dirname "$0")"/functions.sh

assertEqual slugify /etc = etc
assertEqual slugify /etc/ = etc
assertEqual slugify /var/lib/dpkg/info = var-lib-dpkg-info
assertEqual slugify "" = root

. "$(dirname "$0")"/estimate.sh

assertEqual pretty_size 0 = 0K
assertEqual pretty_size 1 = 1K
assertEqual pretty_size 1024 = 1024K
assertEqual pretty_size 10240 = 10M
assertEqual pretty_size 1048576 = 1024M
assertEqual pretty_size 10485760 = 10G

back_up_functions=$(sed -ne '/^# Back up functions/,$p' functions.sh | sed -ne 's/^\([a-zA-Z0-9_]\+\)() {.*/\1/p')
estimate_functions=$(sed -ne '/^# Overridden back up functions/,$p' estimate.sh | sed -ne 's/^\([a-zA-Z0-9_]\+\)() {.*/\1/p')
diff=$(diff -u <(echo "$back_up_functions") <(echo "$estimate_functions"))
if [ -n "$diff" ]; then
    warn "functions.sh and estimate.sh do not define the same functions:"
    warn "$diff"
    exit 1
fi

echo "all $n_tests tests passed"
