# Makefile -- build, test and install Awe

# To install Awe, run:
#     make
#     sudo make install

# Where the Awe files will be installed. Edit these to suit your system:

BASEDIR = /usr/local

BINDIR = $(BASEDIR)/bin
INCDIR = $(BASEDIR)/include
LIBDIR = $(BASEDIR)/lib
DOCDIR = $(BASEDIR)/share/doc/awe
MANDIR1 = $(BASEDIR)/share/man/man1
MANDIR7 = $(BASEDIR)/share/man/man7

export BINDIR LIBDIR DOCDIR INCDIR MANDIR1 MANDIR7

# The default Makefile action is to do a re-build and perform all the tests

.PHONY: default
default: build

# Useful targets:

.PHONY: build
.PHONY: install uninstall
.PHONY: test
.PHONY: doc
.PHONY: clean
.PHONY: zip

# ------------------------------------------------------------------------------

install:
	install -m 755 -d $(BINDIR) $(LIBDIR) $(INCDIR) $(DOCDIR) $(MANDIR1) $(MANDIR7)
	install -m 755 awe      $(BINDIR)
	install -m 644 libawe/awe.h    $(INCDIR)
	install -m 644 libawe/aweio.h  $(INCDIR)
	install -m 644 libawe/libawe.a $(LIBDIR)
	install -m 644 doc/awe.mk   $(INCDIR)
	install -m 644 doc/awe.html $(DOCDIR)
	install -m 644 doc/awe.1    $(MANDIR1)
	install -m 644 doc/awe.mk.7 $(MANDIR7)
	install -m 644 github-markdown.css $(DOCDIR)

uninstall:
	rm -f $(BINDIR)/awe 
	rm -f $(LIBDIR)/libawe.a 
	rm -f $(INCDIR)/awe.h 
	rm -f $(INCDIR)/aweio.h 
	rm -f $(INCDIR)/awe.mk
	rm -f $(MANDIR1)/awe.1
	rm -f $(MANDIR7)/awe.mk.7
	rm -f $(DOCDIR)/awe.txt


# ------------------------------------------------------------------------------
# Build everything

build : libawe awe doc

libawe:
	make -C libawe build 

awe:
	dune build

doc:
	make -C doc 

# ------------------------------------------------------------------------------
# test everything

test: clean build test-parsing test-suite test-programs test-examples webpages
	@echo "ALL TESTS PASSED"

TESTS = Tests/Separate \
	Tests/SeparateC \
	Tests/OldParse \
	Tests/Multifile-Error \
	Tests/Argv \
	Tests/Argv-Multisource \
	Tests/ExternalRecords \
	Tests/Strings-as-bytes \
	Tests/Tracing \
	Tests/Stderr-redirection

EXAMPLES = Examples/*

.PHONY: test-parsing test-suite test-programs test-examples

test-parsing:
	dune test

test-suite:
	ocaml -I +str ./testprograms.ml -h Tests/*.alw
	rm -f testme testme-*

test-programs:
	for d in $(TESTS) ; do \
		make test -C $$d -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1 ; \
	done

# Do the example Algol W projects compile?
test-examples:
	make test -C Examples/Roman  -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1
	make test -C Examples/List   -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1
	make test -C Examples/Wumpus -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1
	make test -C Examples/Macro -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1
	make test -C Examples/Logic -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1
ifndef NO_GC
	make test -C Examples/test-cords -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1
endif


# ------------------------------------------------------------------------------

clean:
	make -C libawe clean
	make -C doc clean
	make -f Makefile.testparsing clean
	make -f Makefile.awe clean
	for d in $(TESTS) ; do make clean -I $(shell pwd) -C $$d ; done
	for d in $(EXAMPLES) ; do make clean -I $(shell pwd) -C $$d ; done
	make -C Tools clean
	rm -f Tests/*.awe.c 
	rm -f testme testme-*
	rm -f awe.zip

# ------------------------------------------------------------------------------

zip:
	git archive --format=zip --prefix=awe/ -o awe.zip HEAD

