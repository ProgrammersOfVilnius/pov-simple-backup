source := $(shell dpkg-parsechangelog | awk '$$1 == "Source:" { print $$2 }')
version := $(shell dpkg-parsechangelog | awk '$$1 == "Version:" { print $$2 }')
date := $(shell dpkg-parsechangelog | grep ^Date: | cut -d: -f 2- | date --date="$$(cat)" +%Y-%m-%d)

VCS_STATUS = git status --porcelain

.PHONY: all
all: pov-simple-backup pov-simple-backup.8

%: %.sh
	sed -e 's,^libdir=\.$$,libdir=/usr/share/pov-simple-backup,' $< > $@

%.8: %.rst
	rst2man $< > $@

.PHONY: test check
test check: check-docs
	./tests.sh

.PHONY: check-docs
check-docs:
	@./extract-documentation.py -c README.rst -c pov-simple-backup.rst || echo "Run make update-docs please"

.PHONY: update-docs
update-docs:
	./extract-documentation.py -u README.rst -u pov-simple-backup.rst
	$(MAKE)

.PHONY: install
install: pov-simple-backup
	install -D -m 644 functions.sh $(DESTDIR)/usr/share/pov-simple-backup/functions.sh
	install -D -m 644 estimate.sh $(DESTDIR)/usr/share/pov-simple-backup/estimate.sh
	install -D -m 644 example.conf $(DESTDIR)/usr/share/doc/pov-simple-backup/backup.example
	install -D pov-simple-backup $(DESTDIR)/usr/sbin/pov-simple-backup
	install -D cron_daily.sh $(DESTDIR)/etc/cron.daily/pov-simple-backup

.PHONY: clean-build-tree
clean-build-tree:
	@./extract-documentation.py -c README.rst -c pov-simple-backup.rst || { echo "Run make update-docs please" 1>&2; exit 1; }
	@test -z "`$(VCS_STATUS) 2>&1`" || { echo; echo "Your working tree is not clean; please commit and try again" 1>&2; $(VCS_STATUS); exit 1; }
	rm -rf pkgbuild/$(source)
	git archive --format=tar --prefix=pkgbuild/$(source)/ HEAD | tar -xf -

.PHONY: source-package
source-package: clean-build-tree
	cd pkgbuild/$(source) && debuild -S -i -k$(GPGKEY)

.PHONY: upload-to-ppa
upload-to-ppa: source-package
	dput ppa:pov/ppa pkgbuild/$(source)_$(version)_source.changes
	git tag $(version)
	git push
	git push --tags

.PHONY: binary-package
binary-package: clean-build-tree
	cd pkgbuild/$(source) && debuild -i -k$(GPGKEY)
