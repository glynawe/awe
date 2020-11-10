# Makefile -- build, test and install Awe tools

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


# Where the file will be installed. Edit these to suit your system:

PREFIX = $(DESTDIR)/usr/local
BINDIR = $(PREFIX)/bin
TOOLDIR = $(PREFIX)/share/awe
MANDIR = $(PREFIX)/share/man/man1

.phony:: build test install clean

default: test

install: build 
	install -m 755 -d $(BINDIR) $(TOOLDIR) $(MANDIR)
	install -m 755 -t $(BINDIR) awnest
	install -m 644 -t $(MANDIR) awnest.1
	install -m 644 -t $(TOOLDIR) algolw.ssh

build:
	ocamllex awnest.mll && ocamlc awnest.ml -o awnest

test : clean build
	./awnest < awnest-test-file.alw > actual.output
	diff expected.output actual.output
	rm actual.output
	echo "Success!"

clean:
	rm -f awnest awnest.cmi awnest.cmo awnest.ml actual.output
