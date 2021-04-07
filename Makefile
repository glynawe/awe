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

# The default Makefile action is to do a re-build and perform all the tests

.PHONY: default
default: test

# Useful targets:

.PHONY: build
.PHONY: install uninstall
.PHONY: test
.PHONY: manpages webpages
.PHONY: clean
.PHONY: zip

# ------------------------------------------------------------------------------

install:
	install -m 755 -d $(BINDIR) $(LIBDIR) $(INCDIR) $(DOCDIR) $(MANDIR1) $(MANDIR7)
	install -m 755 -t $(BINDIR) awe
	install -m 644 -t $(INCDIR) awe.h
	install -m 644 -t $(INCDIR) aweio.h
	install -m 644 -t $(LIBDIR) libawe.a 
	install -m 644 -t $(INCDIR) awe.mk
	install -m 644 -t $(DOCDIR) awe.html
	install -m 644 -t $(DOCDIR) github-markdown.css
	install -m 644 -t $(MANDIR1) awe.1
	install -m 644 -t $(MANDIR7) awe.mk.7

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

build: libawe.a awe manpages

awe:
	make -f Makefile.awe byte-code
	make test -C Tools


# ------------------------------------------------------------------------------
# Build libawe.a

CFLAGS=-std=gnu11 -Wall -Wextra -Werror

# In Cygwin GC_ALLOC crashes when used inside nested GCC auto functions.
# This is a very obscure bug that the Cygwin maintainers WONTFIX.
ifeq ($(shell uname -o),Cygwin)
$(warning "Compiling a runtime library that does not use libgc.")
NO_GC=1
CFLAGS += -DNO_GC
endif

HEADERS = awe.h aweio.h
SOURCES = aweexcept.c aweio.c awe.c awestd.c awestr.c awearray.c

OBJECTS = $(patsubst %.c,%.o,$(SOURCES))

$(OBJECTS) : $(HEADERS)

aweio.o: aweio.c scanner.inc

scanner.inc: scanner.py
	python3 scanner.py

libawe.a: $(OBJECTS)
	rm -f libawe.a
	ar -cr libawe.a $(OBJECTS)


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
	make -f Makefile.testparsing
	./testparsing --test expressions  Tests/parser-lexing*.dat 
	./testparsing --test expressions  Tests/parser-expressions*.dat 
	./testparsing --test expressions  Tests/parser-statements*.dat 
	./testparsing --test declarations Tests/parser-declarations*.dat 

test-suite:
	ocaml ./testprograms.ml -h Tests/*.alw
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
ifndef NO_GC
	make test -C Examples/test-cords -I $(shell pwd) COMPILER_PATH=$(shell pwd) || exit 1
endif


# ------------------------------------------------------------------------------
# Preprocess the documentation

manpages: awe.1 awe.mk.7 awe.html github-markdown.css

webpages: manpages awe.1.html awe.mk.7.html INSTALL.html

awe.1 : man.py awe.1.md VERSION
	python3 man.py awe.1.md awe.1 \
                      VERSION="$(shell cat VERSION)" \
                      BINDIR="$(BINDIR)" LIBDIR="$(LIBDIR)" DOCDIR="$(DOCDIR)" INCDIR="$(INCDIR)"

awe.mk.7 : man.py awe.mk.7.md VERSION
	python3 man.py awe.mk.7.md awe.mk.7 \
                      VERSION="$(shell cat VERSION)" \
                      BINDIR="$(BINDIR)" LIBDIR="$(LIBDIR)" DOCDIR="$(DOCDIR)" INCDIR="$(INCDIR)"

awe.1.html: awe.1 htmltext.py
	MANWIDTH=80 man ./awe.1 | python3 htmltext.py "awe(1): Awe ALGOL W compiler man page" > awe.1.html

awe.mk.7.html: awe.mk.7 htmltext.py
	MANWIDTH=80 man ./awe.mk.7 | python3 htmltext.py "awe.mk(7): Awe ALGOL W Makefile man page" > awe.mk.7.html

awe.html: awe.md markdown-to-html.py github-markdown.css
	python3 markdown-to-html.py awe.md awe.html

INSTALL.html: INSTALL.md markdown-to-html.py github-markdown.css
	python3 markdown-to-html.py INSTALL.md INSTALL.html


# ------------------------------------------------------------------------------

clean:
	make -f Makefile.testparsing clean
	make -f Makefile.awe clean
	for d in $(TESTS) ; do make clean -I $(shell pwd) -C $$d ; done
	for d in $(EXAMPLES) ; do make clean -I $(shell pwd) -C $$d ; done
	rm -f Tests/*.awe.c 
	rm -f scanner.inc scanner.dot
	rm -f *.o *.a
	rm -f awe
	rm -f awe.1 awe.mk.7 awe.html awe.1.html awe.mk.7.html INSTALL.html
	rm -f awe.tar.gz
	rm -f testme testme-*
	rm -f awe.zip awe.tar.gz

# ------------------------------------------------------------------------------

zip:
	git archive --format=zip --prefix=awe/ -o awe.zip HEAD

# ------------------------------------------------------------------------------


# This file is part of Awe. Copyright 2012 Glyn Webster.
# 
# Awe is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Awe is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public
# License along with Awe.  If not, see <http://www.gnu.org/licenses/>.

#end
