#
# Functions for pov-simple-backup
#

#
# Helpers
#

test -n "$verbose" || verbose=0

exec 3>&1

DATE_GLOB=[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]

info() {
    if [ $verbose -ne 0 ]; then
        echo "$@"
    fi
}

error() {
    echo "$@" 1>&2
}

backupdir() {
    dir=$BACKUP_ROOT/$DATE$BACKUP_SUFFIX
    echo "$dir"
}

slugify() {
    echo $1|sed -e 's,^/\+,,' -e 's,/\+$,,' -e 's,/\+,-,g' -e 's,^$,root,'
}

size_of() {
    pathname=$1
    test -e "$pathname" || return
    du -s "$pathname" | awk '{print $1}'
}

size_of_last_backup() {
    where=$1
    suffix=$2
    test -d "$where" || return
    last_backup=$(ls -d "${where%/}"/$DATE_GLOB$suffix 2>/dev/null | tail -n 1)
    test -n "$last_backup" || return
    size_of "$last_backup"
}

pretty_size() {
    size=$1
    if [ $size -lt 10240 ]; then
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
    filename=$1
    if [ $verbose -ne 0 ]; then
        size=$(size_of "$filename")
        test -n "$size" || return
        pretty_size=$(pretty_size $size)
        echo "$filename is $pretty_size"
    fi
}

grand_total=0
backup_root_included=0
sizes_reported=0

estimate_summary() {
    if [ $backup_root_included -eq 0 ]; then
        dir=$(backupdir)
        size=$(size_of "$dir")
        test -n "$size" || size=$(size_of_last_backup "$BACKUP_ROOT")
        test -n "$size" || {
            error "Backup was not created yet ($dir missing)"
            exit 1
        }
        pretty_size=$(pretty_size $size)
        echo "$dir is $pretty_size"
        grand_total=$((grand_total + size))
        sizes_reported=$((sizes_reported + 1))
    fi
    if [ $sizes_reported -ge 2 ]; then
        pretty_size=$(pretty_size $grand_total)
        echo "Total: $pretty_size"
    fi
}

#
# Overridden back up functions
#

back_up() {
    pathname=$1
    outfile=$(backupdir)/$(slugify "$pathname").tar.gz
    estimate "$outfile"
}

back_up_to() {
    name=$1
    outfile=$(backupdir)/$name.tar.gz
    estimate "$outfile"
}

back_up_uncompressed() {
    pathname=$1
    outfile=$(backupdir)/$(slugify "$pathname").tar
    estimate "$outfile"
}

back_up_to_uncompressed() {
    name=$1
    outfile=$(backupdir)/$name.tar
    estimate "$outfile"
}

back_up_dpkg_selections() {
    outfile=$(backupdir)/dpkg--get-selections.gz
    estimate "$outfile"
}

back_up_postgresql() {
    outfile=$(backupdir)/postgresql-dump.sql.gz
    estimate "$outfile"
}

back_up_mysql() {
    outfile=$(backupdir)/mysql-dump.sql.gz
    estimate "$outfile"
}

back_up_svn() {
    pathname=$1
    outfile=$(backupdir)/$(slugify "$pathname").svndump.gz
    estimate "$outfile"
}

clean_up_old_backups() {
    keep=$1
    where=${2:-$BACKUP_ROOT}
    suffix=$3
    size=$(size_of_last_backup "$where" "$suffix")
    test -n "$size" || return
    pretty_size=$(pretty_size $size)
    total=$((size * keep))
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
