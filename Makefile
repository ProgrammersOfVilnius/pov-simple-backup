source := $(shell dpkg-parsechangelog | awk '$$1 == "Source:" { print $$2 }')
version := $(shell dpkg-parsechangelog | awk '$$1 == "Version:" { print $$2 }')
date := $(shell dpkg-parsechangelog | grep ^Date: | cut -d: -f 2- | date --date="$$(cat)" +%Y-%m-%d)
target_distribution := $(shell dpkg-parsechangelog | awk '$$1 == "Distribution:" { print $$2 }')

manpage = pov-simple-backup.rst
#
# change this to the lowest supported Ubuntu LTS
TARGET_DISTRO := xenial

# for testing in vagrant:
#   mkdir -p ~/tmp/vagrantbox && cd ~/tmp/vagrantbox
#   vagrant init ubuntu/xenial64
#   vagrant ssh-config --host vagrantbox >> ~/.ssh/config
# now you can 'make vagrant-test-install', then 'ssh vagrantbox' and play
# with the package
VAGRANT_DIR = ~/tmp/vagrantbox
VAGRANT_SSH_ALIAS = vagrantbox


.PHONY: all
all: pov-simple-backup pov-simple-backup.8

%: %.sh
	sed -e 's,^libdir=\.$$,libdir=/usr/share/pov-simple-backup,' $< > $@

%.8: %.rst
	rst2man $< > $@

.PHONY: test check
test check: check-version check-docs shellcheck
	./tests.sh

.PHONY: shellcheck
shellcheck:
	case $$(shellcheck -V) in \
	    *"version: 0.3.7"*) \
	        echo "Your shellcheck is too old, skipping tests" 2>&1 ;; \
	    *) \
	        shellcheck -s bash *.sh example.conf ;; \
	esac

.PHONY: checkversion
check-version:
	@grep -q ":Version: $(version)" $(manpage) || { \
	    echo "Version number in $(manpage) doesn't match debian/changelog ($(version))" 2>&1; \
	    echo "Run make update-version" 2>&1; \
	    exit 1; \
	}
	@grep -q ":Date: $(date)" $(manpage) || { \
	    echo "Date in $(manpage) doesn't match debian/changelog ($(date))" 2>&1; \
	    echo "Run make update-version" 2>&1; \
	    exit 1; \
	}

.PHONY: update-version
update-version:
	sed -i -e 's/^:Version: .*/:Version: $(version)/' $(manpage)
	sed -i -e 's/^:Date: .*/:Date: $(date)/' $(manpage)

.PHONY: check-target
check-target:
	@test "$(target_distribution)" = "$(TARGET_DISTRO)" || { \
	    echo "Distribution in debian/changelog should be '$(TARGET_DISTRO)'" 2>&1; \
	    echo "Run make update-target" 2>&1; \
	    exit 1; \
	}

.PHONY: update-target
update-target:
	dch -r -D $(TARGET_DISTRO) ""

.PHONY: check-docs
check-docs:
	@./extract-documentation.py -c README.rst -c $(manpage) || echo "Run make update-docs please"

.PHONY: update-docs
update-docs:
	./extract-documentation.py -u README.rst -u $(manpage)
	$(MAKE)

.PHONY: install
install: pov-simple-backup
	install -D -m 644 functions.sh $(DESTDIR)/usr/share/pov-simple-backup/functions.sh
	install -D -m 644 estimate.sh $(DESTDIR)/usr/share/pov-simple-backup/estimate.sh
	install -D -m 644 generate.sh $(DESTDIR)/usr/share/pov-simple-backup/generate.sh
	install -D encryptdir.py $(DESTDIR)/usr/share/pov-simple-backup/encryptdir.py
	install -D -m 644 example.conf $(DESTDIR)/usr/share/doc/pov-simple-backup/backup.example
	install -D pov-simple-backup $(DESTDIR)/usr/sbin/pov-simple-backup
	install -D cron_daily.sh $(DESTDIR)/etc/cron.daily/pov-simple-backup


VCS_STATUS = git status --porcelain

.PHONY: clean-build-tree
clean-build-tree:
	@./extract-documentation.py -c README.rst -c $(manpage) || { echo "Run make update-docs please" 1>&2; exit 1; }
	@test -z "`$(VCS_STATUS) 2>&1`" || { \
	    echo; \
	    echo "Your working tree is not clean; please commit and try again" 1>&2; \
	    $(VCS_STATUS); \
	    echo 'E.g. run git commit -am "Release $(version)"' 1>&2; \
	    exit 1; }
	rm -rf pkgbuild/$(source)
	git archive --format=tar --prefix=pkgbuild/$(source)/ HEAD | tar -xf -

.PHONY: source-package
source-package: clean-build-tree
	cd pkgbuild/$(source) && debuild -S -i -k$(GPGKEY)

.PHONY: upload-to-ppa release
release upload-to-ppa: check-target check source-package
	dput ssh-ppa:pov/ppa pkgbuild/$(source)_$(version)_source.changes
	git tag $(version)
	git push
	git push --tags

.PHONY: binary-package
binary-package: clean-build-tree
	cd pkgbuild/$(source) && debuild -i -k$(GPGKEY)
	@echo
	@echo "Built pkgbuild/$(source)_$(version)_all.deb"

.PHONY: vagrant-test-install
vagrant-test-install: binary-package
	cp pkgbuild/$(source)_$(version)_all.deb $(VAGRANT_DIR)/
	cd $(VAGRANT_DIR) && vagrant up
	ssh $(VAGRANT_SSH_ALIAS) 'sudo DEBIAN_FRONTEND=noninteractive dpkg -i /vagrant/$(source)_$(version)_all.deb && sudo apt-get install -f'

.PHONY: pbuilder-test-build
pbuilder-test-build: source-package
	# NB: 1st time run pbuilder-dist $(TARGET_DISTRO) create
	# NB: you need to periodically run pbuilder-dist $(TARGET_DISTRO) update
	pbuilder-dist $(TARGET_DISTRO) build pkgbuild/$(source)_$(version).dsc
	@echo
	@echo "Look for the package in ~/pbuilder/$(TARGET_DISTRO)_result/"
