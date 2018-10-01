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

set -o pipefail

exec 3>&1

DATE_GLOB="[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]"

info() {
    if [ $verbose -ne 0 ] || [ $dry_run -ne 0 ]; then
        echo "$@"
    fi
}

error() {
    echo "$@" 1>&2
}

backupdir() {
    local suffix=${1:-$BACKUP_SUFFIX}
    local dir=$BACKUP_ROOT/$DATE$suffix
    if [ $dry_run -eq 0 ] && ! [ -d "$dir" ]; then
        info "Creating $dir" 1>&3
        mkdir -p "$dir"
    fi
    echo "$dir"
}

# slugify <pathname>
#   Convert a pathname into a "slug" suitable for a filename
#
#   Strips leading and trailing slashes and converts internal slashes to
#   dashes.
#
#   Special-cases / as "root".
slugify() {
    printf "%s\n" "$1" | sed -e 's,^/\+,,' -e 's,/\+$,,' -e 's,/\+,-,g' -e 's,^$,root,'
}

# backup_name <slug> <maybe-pathname>
#   Comes up with a pretty name for a backup
#
#   Internal helper for back_up_to
#
#   Usually we want to say "Backing up /folder", but sometimes a tar option
#   must come first before the filename, and "Backing up --no-recursive" looks
#   silly.
backup_name() {
    local slug=$1
    local pathname=$2
    case "$pathname" in
        /*) printf "%s\n" "$pathname";;
        *)  printf "%s\n" "$slug";;
    esac
}

check_overwrite() {
    local filename=$1
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
    local pathname=$1
    local name
    name=$(slugify "$pathname")
    back_up_to "$name" "$@"
}

# back_up_to <name> <pathname> [<tar options>]
#   Back up a directory or a file.
#
#   Creates <name>.tar.gz.
#
#   Examples::
#
#       back_up_to backup-skeleton --no-recursive backups/host1 backups/host2
#
#    Note: when using tar's ``--no-recursive``, be sure to specify it *before*
#    the directory you don't want to recurse into.  Otherwise it may be
#    ignored, depending on the version of tar.
#
#    Note: when using tar's ``--exclude``, be sure to omit both the leading and
#    the trailing slash!  Otherwise it will be ignored.
#
#    Note: you can back up multiple files/directories, but you'll have
#    to omit leading slashes to avoid warnings from tar.
back_up_to() {
    local name=$1
    local pathname=$2
    local what
    what=$(backup_name "$name" "$pathname")
    local outfile
    outfile=$(backupdir)/$name.tar.gz
    info "Backing up $what"
    check_overwrite "$outfile" || return
    shift 2
    [ $dry_run -ne 0 ] && return
    # shellcheck disable=SC2015
    tar -czf "$outfile.tmp" "${pathname#/}" "$@" \
        && mv "$outfile.tmp" "$outfile" \
        || error "failed to back up $what"
}

# back_up_uncompressed <pathname> [<tar options>]
#   Back up a directory or a single file
#
#   Creates <filename>.tar, where the <filename> is constructed
#   from the <pathname> by stripping leading slashes and replacing
#   all other slashes with hyphens.
#
#   Examples::
#
#       back_up_uncompressed /git/myrepo.git
#
#    would create git-myrepo.git.tar
#
#    Note: when using tar's ``--exclude``, be sure to omit both the leading and
#    the trailing slash!  Otherwise it will be ignored.
back_up_uncompressed() {
    local pathname=$1
    local name
    name=$(slugify "$pathname")
    back_up_uncompressed_to "$name" "$@"
}

# back_up_uncompressed_to <name> <pathname> [<tar options>]
#   Back up a directory or a file.
#
#   Creates <name>.tar.
#
#   Examples::
#
#       back_up_uncompressed_to backup-skeleton --no-recursive /backups/host1 backups/host2
#
#    Note: when using tar's ``--no-recursive``, be sure to specify it *before*
#    the directory you don't want to recurse into.  Otherwise it may be
#    ignored, depending on the version of tar.
#
#    Note: when using tar's ``--exclude``, be sure to omit both the leading and
#    the trailing slash!  Otherwise it will be ignored.
#
#    Note: you can back up multiple files/directories, but you'll have
#    to omit leading slashes to avoid warnings from tar.
back_up_uncompressed_to() {
    local name=$1
    local pathname=$2
    local what
    what=$(backup_name "$name" "$pathname")
    local outfile
    outfile=$(backupdir)/$name.tar
    info "Backing up $what"
    check_overwrite "$outfile" || return
    shift 2
    [ $dry_run -ne 0 ] && return
    # shellcheck disable=SC2015
    tar -czf "$outfile.tmp" "${pathname#/}" "$@" \
        && mv "$outfile.tmp" "$outfile" \
        || error "failed to back up $what"
}

# back_up_dpkg_selections
#   Back up dpkg selections (i.e. list of installed packages)
#
#   Creates dpkg--get-selections.gz and var-lib-apt-extended_states.gz
back_up_dpkg_selections() {
    local outfile
    outfile=$(backupdir)/dpkg--get-selections.gz
    info "Backing up dpkg selections"
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    # shellcheck disable=SC2015
    dpkg --get-selections | gzip > "$outfile.tmp" \
        && mv "$outfile.tmp" "$outfile" \
        || error "failed to back up dpkg selections"
    local infile=/var/lib/apt/extended_states
    outfile=$(backupdir)/var-lib-apt-extended_states.gz
    check_overwrite "$outfile" || return
    # shellcheck disable=SC2015
    gzip < "$infile" > "$outfile.tmp" \
        && mv "$outfile.tmp" "$outfile" \
        || error "failed to back up apt extended_states"
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
    local outfile
    outfile=$(backupdir)/postgresql-dump.sql.gz
    info "Backing up PostgreSQL"
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    # shellcheck disable=SC2015
    sudo -u postgres pg_dumpall | gzip > "$outfile.tmp" \
        && mv "$outfile.tmp" "$outfile" \
        || error "failed to back up PostgreSQL"
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
    local outfile
    outfile=$(backupdir)/mysql-dump.sql.gz
    info "Backing up MySQL"
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    # shellcheck disable=SC2015
    mysqldump --defaults-file=/etc/mysql/debian.cnf --all-databases --events \
        | gzip > "$outfile.tmp" \
        && mv "$outfile.tmp" "$outfile" \
        || error "failed to back up MySQL"
}

# back_up_svn <pathname>
#   Back up a single SVN repository
#
#   Creates <filename>.svndump.gz, where the <filename> is constructed
#   from the <pathname> by stripping leading slashes and replacing
#   all other slashes with hyphens.
#
#   Bugs:
#
#   - does not back up hooks/ and conf/ subdirectories
#
#   Example::
#
#       back_up_svn /var/lib/svn/myrepo
#       back_up /var/lib/svn/myrepo/conf
#       back_up /var/lib/svn/myrepo/hooks
#
back_up_svn() {
    local pathname=$1
    local name
    name=$(slugify "$pathname")
    local outfile
    outfile=$(backupdir)/$name.svndump.gz
    info "Backing up $pathname"
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    # shellcheck disable=SC2015
    (svnadmin dump "$pathname" | gzip > "$outfile.tmp") 2>&1 \
        | (grep -v '^\* Dumped revision' || true) \
        && mv "$outfile.tmp" "$outfile" \
        || error "back_up_svn: failed to back up $pathname"
}

# generate_checksums [<suffix>]
#   Generate a SHA256SUMS file in the backup directory
#
#   Do this after all the backup commands, and before all the rsync/scp
#   commands.
#
#   Example::
#
#       generate_checksums
#       generate_checksums -git
#
generate_checksums() {
    local suffix=${1:-$BACKUP_SUFFIX}
    local where
    where=$(backupdir "$suffix")
    info "Generating checkums in $where"
    local outfile=$where/SHA256SUMS
    check_overwrite "$outfile" || return
    [ $dry_run -ne 0 ] && return
    # shellcheck disable=SC2015
    (cd "$where" && sha256sum -b ./* > "$outfile.tmp") \
        && mv "$outfile.tmp" "$outfile" \
        || error "failed to generate checksums in $where"
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
    local keep=$1
    local where=${2:-$BACKUP_ROOT}
    local suffix=${3:-$BACKUP_SUFFIX}
    if [ -n "$suffix" ]; then
        info "Cleaning up old backups in $where ($suffix)"
    else
        info "Cleaning up old backups in $where"
    fi
    local to_remove
    # shellcheck disable=SC2086,SC2012
    to_remove=$(ls -rd "${where%/}"/$DATE_GLOB"$suffix" 2>/dev/null | tail -n +$((keep+1)))
    if [ -n "$to_remove" ]; then
        echo "$to_remove" | while read -r fn; do
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
    local what=$1
    local where=$2
    info "Copying $what to $where"
    shift 2
    [ $dry_run -ne 0 ] && return
    rsync -az -e "ssh -q -o BatchMode=yes $*" "$what" "$where" \
        || error "rsync -az $what $where failed (see error above)"
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
    local where=$1
    info "Copying backup to $where"
    shift
    [ $dry_run -ne 0 ] && return
    scp -q -o BatchMode=yes -r "$(backupdir)" "${where%/}/$DATE" "$@"
}
