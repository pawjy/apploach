all:

WGET = wget
CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl
	$(CURL) -s -S -L -f https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules t_deps/modules
	perl local/bin/pmbp.pl --update-pmbp-pl
	perl local/bin/pmbp.pl --update
	$(GIT) add config
	$(CURL) -sSLf https://raw.githubusercontent.com/wakaba/ciconfig/master/ciconfig | RUN_GIT=1 REMOVE_UNUSED=1 perl

## ------ Setup ------

deps: always
	true # dummy for make -q
ifdef PMBP_HEROKU_BUILDPACK
else
	$(MAKE) git-submodules
ifdef GAA
else
	$(MAKE) deps-local
endif
	$(GIT) rev-parse HEAD > rev
endif
	$(MAKE) pmbp-install

deps-docker: pmbp-install

deps-circleci: git-submodules deps-local-circleci
	$(GIT) rev-parse HEAD > rev

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L -f https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
            --create-perl-command-shortcut @perl \
            --create-perl-command-shortcut @prove

deps-local: pmbp-install
	./perl local/bin/pmbp.pl $(PMBP_OPTIONS) \
            --install-commands "make git docker wget curl" \
            --create-perl-command-shortcut @prove \
            --create-perl-command-shortcut @local/run-local-server=perl\ bin/local-server.pl \
            --create-bootstrap-script "src/lserver.in lserver"
	chmod u+x ./lserver

deps-local-circleci: pmbp-install
	./perl local/bin/pmbp.pl $(PMBP_OPTIONS) \
	    --install-commands "make git docker mysqld wget curl" \
            --create-perl-command-shortcut @prove

lserver: deps-local

create-commit-for-heroku-circleci: deps-circleci create-commit-for-heroku
create-commit-for-heroku:
	git config --global url."https://_:$$HEROKU_KEY@git.heroku.com/".insteadOf git@heroku.com:
	git add -f rev
	git remote rm origin
	rm -fr deps/pmtar/.git deps/pmpp/.git modules/*/.git
	git add -f deps/pmtar/* #deps/pmpp/*
	rm -fr ./t_deps/modules/*/.git
	git rm -r .gitmodules
	git rm modules/* t_deps/modules/* --cached
	git add -f modules/*/* t_deps/modules/*/*
	git commit -m "for heroku"

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps local/bin/tesica
test-deps-circleci: deps-circleci local/bin/tesica

local/bin/tesica:
	$(CURL) -sSLf https://raw.githubusercontent.com/pawjy/tesica/master/tesica > $@
	chmod u+x $@

test-main:
	$(PROVE) t/http/*.t

test-main-circleci:
	local/bin/tesica t/http

always:

## License: Public Domain.
