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
#       back_up /opt/myapp --exclude opt/myapp/var/zdaemonsock
#
#    would create var-cache-debconf-config.dat.tar.gz and opt-myapp.tar.gz
#
#    Note: when using tar's ``--exclude``, be sure to omit both the leading and
#    the trailing slash!  Otherwise it will be ignored.
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

# copy_backup_to [<user>@]<server>:<path> [<ssh options>]
#   Copy today's backups to a remote server over SSH
#
#   Alias for ``rsync_backup_to``.
#
#   Example::
#
#       copy_backup_to backups@example.com:/backup/myhostname/ -i key.rsa
#
#   See also: rsync_backup_to, scp_backup_to
copy_backup_to() {
    rsync_backup_to "$@"
}

# rsync_to <pathname> [<user>@]<server>:<path> [<ssh options>]
#   Mirror a file or directory to a remote server over SSH, using rsync
#
#   It means a lot to rsync whether or not you have a trailing slash at the end
#   of <pathname>, when it's a directory.  No trailing slash: it will create a
#   new directory with the same basename on the server side, under <path>.
#   Trailing slash: it will make the contents of <path> on the server the same
#   as contents of <pathname> here.
#
#   Example::
#
#       rsync_to /var/www/uploads backups@example.com:/backup/myhostname/uploads -i key.rsa
#
rsync_to() {
    what=$1
    where=$2
    info "Copying $what to $where"
    shift 2
    [ $dry_run -ne 0 ] && return
    rsync -az -e "ssh -q -o BatchMode=yes $@" "$what" "${where}"
}

# rsync_backup_to [<user>@]<server>:<path> [<ssh options>]
#   Copy today's backups to a remote server over SSH, using rsync
#
#   Example::
#
#       rsync_backup_to backups@example.com:/backup/myhostname/ -i key.rsa
#
#   See also: scp_backup_to, copy_backup_to
rsync_backup_to() {
    rsync_to "$(backupdir)" "$@"
}

# scp_backup_to [<user>@]<server>:<path> [<scp options>]
#   Copy today's backups to a remote server over SSH, using scp
#
#   Destination directory must exist on the remote host.
#
#   Example::
#
#       copy_backup_to backups@example.com:/backup/myhostname/ -i key.rsa
#
#   Bugs:
#
#   - if the remote directory already exists, creates a second copy, as a
#     subdirectory (e.g. /backup/myhostname/2013-08-29/2013-08-29)
#
#   See also: rsync_backup_to, copy_backup_to
scp_backup_to() {
    where=$1
    info "Copying backup to $where"
    shift
    [ $dry_run -ne 0 ] && return
    scp -q -o BatchMode=yes -r "$(backupdir)" "${where%/}/$DATE" "$@"
}
