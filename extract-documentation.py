#!/usr/bin/env python
import re
import sys
import optparse

code_marker = '\n#\n# Back up functions\n#\n\n'
update_marker_1 = '\n.. documentation generated by running ./extract-documentation.py\n\n'
update_marker_2 = '\n.. end of generated chunk\n'

doc_rx = re.compile('^\n(# [a-zA-Z_0-9]+.*\n(?:#.*\n)+)', re.MULTILINE)


def extract_docs(filename='functions.sh'):
    with open(filename) as f:
        code = f.read()
    code = '\n' + code.partition(code_marker)[-1]
    docs = doc_rx.findall(code)
    return docs


def format_rst(docs):
    rst = []
    for doc in docs:
        doc = (doc.lstrip('# ')
                  .replace('\n# ', '\n')
                  .replace('\n#', '\n')
                  .replace('\n  Example:', '\n\n  Example:'))
        doc = re.sub('Example: (.*)', r'Example: ``\1``', doc)
        rst.append(doc)
    return '\n\n'.join(rst)


class ReplaceError(Exception):
    pass


def replace_generated(text, replacement):
    before, m1, after = text.partition(update_marker_1)
    if not m1:
        raise ReplaceError('marker not found in text: \n%s' %
                           update_marker_1.replace('\n', '\n  '))
    old, m2, after = after.partition(update_marker_2)
    if not m2:
        return before + update_marker_1 + replacement + '\n'
    else:
        return before + update_marker_1 + replacement + update_marker_2 + after


def main():
    parser = optparse.OptionParser('usage: %prog [options]',
       description="extract documentation from functions.sh and format as ReStructured Text")
    parser.add_option('-u', '--update', metavar='filename', action='append',
       help='update a file in place (can be used more than once)')
    parser.add_option('-c', '--check', metavar='filename', action='append',
       help='check whether a file needs to be updated (can be used more than once)')
    opts, args = parser.parse_args()
    if args:
        parser.error('no arguments expected')

    docs = format_rst(extract_docs())

    if opts.check and opts.update:
        parser.error("cannot use -c and -u at the same time")

    if opts.check:
        failures = 0
        for filename in opts.check:
            with open(filename, 'r') as f:
                old = f.read()
                try:
                    new = replace_generated(old, docs)
                except ReplaceError, e:
                    sys.stderr.write("extract-documentation: %s: %s\n" % (filename, e))
                    sys.stderr.flush()
                    failures += 1
                else:
                    if new != old:
                        sys.stderr.write("%s is outdated\n" % filename)
                        sys.stderr.flush()
                        failures += 1
        if failures:
            sys.exit(1)
        else:
            sys.exit(0)

    if opts.update:
        for filename in opts.update:
            with open(filename, 'r+') as f:
                old = f.read()
                try:
                    new = replace_generated(old, docs)
                except ReplaceError, e:
                    sys.stderr.write("extract-documentation: %s: %s\n" % (filename, e))
                    sys.stderr.flush()
                else:
                    if new != old:
                        f.seek(0)
                        f.write(new)
                        f.truncate()
    else:
        print(docs)

if __name__ == '__main__':
    main()
