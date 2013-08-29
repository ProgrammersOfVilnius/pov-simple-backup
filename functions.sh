#
# Functions for pov-simple-backup
#

#
# Helpers
#

test -n "$verbose" || verbose=0
test -n "$dry_run" || dry_run=0
test -n "$overwrite" || overwrite=0
test -n "$skip" || skip=0

exec 3>&1

DATE_GLOB=[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]

info() {
    if [ $verbose -ne 0 ] || [ $dry_run -ne 0 ]; then
        echo "$@"
    fi
}

error() {
    echo "$@" 1>&2
}

backupdir() {
    dir=$BACKUP_ROOT/$DATE
    if [ $dry_run -eq 0 ] && ! [ -d "$dir" ]; then
        info "Creating $dir" 1>&3
        mkdir -p "$dir"
    fi
    echo "$dir"
}

slugify() {
    echo $1|sed -e 's,^/\+,,' -e 's,/\+$,,' -e 's,/\+,-,g' -e 's,^$,root,'
}

check_overwrite() {
    filename=$1
    if [ -e "$filename" ]; then
        if [ $overwrite -ne 0 ]; then
            info "  overwriting $filename"
        elif [ $skip -ne 0 ]; then
            info "  skipping $filename"
            return 1
        else
            error "Refusing to overwrite $filename"
            exit 1
        fi
    fi
}

#
# Back up functions
#

# back_up <pathname> [<tar options>]
#   Back up a directory or a single file
#
#   Creates <filename>.tar.gz, where the <filename> is constructed
#   from the <pathname> by stripping leading slashes and replacing
#   all other slashes with hyphens.
#
#   Examples::
#
#       back_up /var/cache/debconf/config.dat
#       back_up /opt/myapp --exclude 'opt/myapp/var/zdaemonsock'
#
#    would create var-cache-debconf-config.dat.tar.gz and opt-myapp.tar.gz
back_up() {
    pathname=$1
    outfile=$(backupdir)/$(slugify "$pathname").tar.gz
    info "Backing up $pathname"
    check_overwrite "$outfile" || return
    shift
    [ $dry_run -ne 0 ] && return
    tar czf "$outfile" "${pathname#/}" "$@"
}

# back_up_dpkg_selections
#   Back up dpkg selections (i.e. list of installed packages)
#
#   Creates dpkg--get-selections.gz
back_up_dpkg_selections() {
    outfile=$(backupdir)/dpkg--get-selections.gz
    info "Backing up dpkg selections"
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    dpkg --get-selections | gzip > "$outfile"
}

# back_up_postgresql
#   Back up all PostgreSQL databases in the main cluster
#
#   Creates postgresql-dump.sql.gz
#
#   Bugs:
#
#   - a single dump file for all databases is unwieldy
#   - a text dump file is inefficient
back_up_postgresql() {
    outfile=$(backupdir)/postgresql-dump.sql.gz
    info "Backing up PostgreSQL"
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    sudo -u postgres pg_dumpall | gzip > "$outfile"
}

# back_up_mysql
#   Back up all MySQL databases
#
#   Creates mysql-dump.sql.gz
#
#   Bugs:
#
#   - a single dump file for all databases is unwieldy
#   - a text dump file is inefficient
back_up_mysql() {
    outfile=$(backupdir)/mysql-dump.sql.gz
    info "Backing up MySQL"
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    mysqldump --defaults-file=/etc/mysql/debian.cnf --all-databases --events | gzip > "$outfile"
}

# clean_up_old_backups <number> [<directory> [<suffix>]]
#   Remove old backups, keep last <number>
#
#   Example::
#
#       clean_up_old_backups 14
#       clean_up_old_backups 14 /backup/otherhost/
#       clean_up_old_backups 14 /backup/ -git
#
#   to keep just two weeks' backups
clean_up_old_backups() {
    keep=$1
    where=${2:-$BACKUP_ROOT}
    suffix=$3
    if [ -n "$suffix" ]; then
        info "Cleaning up old backups in $where ($suffix)"
    else
        info "Cleaning up old backups in $where"
    fi
    to_remove=$(ls -rd "${where%/}"/$DATE_GLOB$suffix 2>/dev/null | tail -n +$(($keep+1)))
    if [ -n "$to_remove" ]; then
        echo "$to_remove" | while read fn; do
          info "  cleaning up $fn"
          [ $dry_run -eq 0 ] && rm -rf "$fn"
        done
    fi
}

# copy_backup_to [<user>@]<server>:<path> [<scp options>]
#   Copy today's backups to a remote server over SSH
#
#   Destination directory must exist on the remote host.
#
#   Example::
#
#       copy_backup_to backups@example.com:/backup/myhostname/ -i key.rsa
copy_backup_to() {
    where=$1
    info "Copying backup to $where"
    shift
    [ $dry_run -ne 0 ] && return
    scp -q -o BatchMode=yes -r "$(backupdir)" "${where%/}/$DATE" "$@"
}
