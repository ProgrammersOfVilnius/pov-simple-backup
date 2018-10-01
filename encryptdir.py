#!/usr/bin/env python
"""Create an encrypted copy of a directory.

Usage:

    encryptdir.py [-n] [-v] -r <recipients> <directory> <encrypted-directory>

"""

import os
import subprocess
import argparse
import sys


__author__ = 'Marius Gedminas <marius@pov.lt>'
__version__ = '1.0.1'


def encrypt(filename, outfilename, recipients):
    """Encrypt a file with GPG."""
    command = [
        'gpg',
        '-e',
        '--batch',
        '--trust-model=always',
        '--no-default-recipient',
        '--no-encrypt-to',
    ]
    for recipient in recipients:
        command += ['-r', recipient]
    with open(filename, 'rb') as fi:
        with open(outfilename, 'wb') as fo:
            rc = subprocess.call(command, stdin=fi, stdout=fo)
    if rc != 0:
        sys.exit("gpg exited with status code %s" % rc)


def sync(source, dest, recipients, verbose=False, dry_run=False):
    """Make sure ``dest`` contains encrypted copies of all files in ``source``.

    Leaves existing files alone.  Checks modification times and re-encrypts
    files in the destination directory if the corresponding file in the
    source directory is newer.
    """
    if dry_run and not os.path.exists(source):
        return
    for filename in sorted(os.listdir(source)):
        spath = os.path.join(source, filename)
        dpath = os.path.join(dest, filename) + '.gpg'
        try:
            dtime = os.stat(dpath).st_mtime
        except OSError:
            dtime = -1
        stime = os.stat(spath).st_mtime
        if stime >= dtime or os.stat(dpath).st_size == 0:
            if verbose:
                print("  encrypting %s" % spath)
            if not dry_run:
                encrypt(spath, dpath + '.tmp', recipients)
                os.rename(dpath + '.tmp', dpath)


def normalize_recipients(recipients):
    """Normalize list of recipient arguments into list of recipients.

    Each argument can be a comma- or space- separated list of recipients.
    """
    result = []
    for r in recipients:
        result.extend(r.replace(',', ' ').split())
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Encrypt a directory with GPG")
    parser.add_argument('--version', action='version',
                        version="%(prog)s version " + __version__)
    parser.add_argument('-v', '--verbose', action='store_true')
    parser.add_argument('-n', '--dry-run', action='store_true')
    parser.add_argument('-r', '--recipient', action='append',
                        help='list of user IDs who should be'
                             ' able to decrypt (can be repeated)')
    parser.add_argument('indir', help='Input directory')
    parser.add_argument('outdir', help='Output directory')
    args = parser.parse_args()
    recipients = normalize_recipients(args.recipient)
    if not recipients:
        parser.error("specify one or more recipients")
    if args.verbose:
        print("  encrypting to %s" % ", ".join(recipients))
    sync(args.indir, args.outdir, recipients=recipients,
         verbose=args.verbose, dry_run=args.dry_run)


if __name__ == '__main__':
    main()
