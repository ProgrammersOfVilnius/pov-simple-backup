#
# Functions for pov-simple-backup
#

#
# Helpers
#

test -n "$verbose" || verbose=0

exec 3>&1

DATE_GLOB="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"

info() {
    if [ $verbose -ne 0 ]; then
        echo "$@"
    fi
}

error() {
    echo "$@" 1>&2
}

backupdir() {
    local dir=$BACKUP_ROOT/$DATE$BACKUP_SUFFIX
    echo "$dir"
}

# keep this in sync with the slugify() from functions.sh
slugify() {
    printf "%s\n" "$1" | sed -e 's,^/\+,,' -e 's,/\+$,,' -e 's,/\+,-,g' -e 's,^$,root,'
}

size_of() {
    local pathname=$1
    test -e "$pathname" || return
    du -s "$pathname" | awk '{print $1}'
}

size_of_last_backup() {
    local where=$1
    local suffix=$2
    test -d "$where" || return
    local last_backup
    # shellcheck disable=SC2086,SC2012
    last_backup=$(ls -d "${where%/}"/$DATE_GLOB"$suffix" 2>/dev/null | tail -n 1)
    test -n "$last_backup" || return
    size_of "$last_backup"
}

pretty_size() {
    local size=$1
    if [ "$size" -lt 10240 ]; then
        echo "${size}K"
        return
    fi
    size=$((size / 1024))
    if [ $size -lt 10240 ]; then
        echo "${size}M"
        return
    fi
    size=$((size / 1024))
    echo "${size}G"
}

estimate() {
    local filename=$1
    if [ $verbose -ne 0 ]; then
        local size
        size=$(size_of "$filename")
        test -n "$size" || return
        local pretty_size
        pretty_size=$(pretty_size "$size")
        echo "$filename is $pretty_size"
    fi
}

grand_total=0
backup_root_included=0
sizes_reported=0

estimate_summary() {
    if [ $backup_root_included -eq 0 ]; then
        local dir
        dir=$(backupdir)
        local size
        size=$(size_of "$dir")
        test -n "$size" || size=$(size_of_last_backup "$BACKUP_ROOT")
        test -n "$size" || {
            error "Backup was not created yet ($dir missing)"
            exit 1
        }
        local pretty_size
        pretty_size=$(pretty_size "$size")
        echo "$dir is $pretty_size"
        grand_total=$((grand_total + size))
        sizes_reported=$((sizes_reported + 1))
    fi
    if [ $sizes_reported -ge 2 ]; then
        local pretty_size
        pretty_size=$(pretty_size $grand_total)
        echo "Total: $pretty_size"
    fi
}

#
# Overridden back up functions
#

back_up() {
    local pathname=$1
    local outfile
    outfile=$(backupdir)/$(slugify "$pathname").tar.gz
    estimate "$outfile"
}

back_up_to() {
    local name=$1
    local outfile
    outfile=$(backupdir)/$name.tar.gz
    estimate "$outfile"
}

back_up_uncompressed() {
    local pathname=$1
    local outfile
    outfile=$(backupdir)/$(slugify "$pathname").tar
    estimate "$outfile"
}

back_up_uncompressed_to() {
    local name=$1
    local outfile
    outfile=$(backupdir)/$name.tar
    estimate "$outfile"
}

back_up_dpkg_selections() {
    local outfile
    outfile=$(backupdir)/dpkg--get-selections.gz
    estimate "$outfile"
    # XXX: there's another file
}

back_up_postgresql() {
    local outfile
    outfile=$(backupdir)/postgresql-dump.sql.gz
    estimate "$outfile"
}

back_up_mysql() {
    local outfile
    outfile=$(backupdir)/mysql-dump.sql.gz
    estimate "$outfile"
}

back_up_svn() {
    local pathname=$1
    local outfile
    outfile=$(backupdir)/$(slugify "$pathname").svndump.gz
    estimate "$outfile"
}

clean_up_old_backups() {
    local keep=$1
    local where=${2:-$BACKUP_ROOT}
    local suffix=${3:-$BACKUP_SUFFIX}
    local size
    size=$(size_of_last_backup "$where" "$suffix")
    test -n "$size" || return
    local pretty_size
    pretty_size=$(pretty_size "$size")
    local total
    total=$((size * keep))
    local pretty_total
    pretty_total=$(pretty_size $total)
    echo "$keep copies of ${where%/}/YYYY-MM-DD$suffix ($pretty_size) is $pretty_total"
    grand_total=$((grand_total + total))
    sizes_reported=$((sizes_reported + 1))
    if [ x"$where" = x"$BACKUP_ROOT" ]; then
        backup_root_included=1
    fi
}

copy_backup_to() {
    :
}

rsync_to() {
    :
}

rsync_backup_to() {
    :
}

scp_backup_to() {
    :
}
