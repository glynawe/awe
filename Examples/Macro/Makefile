PROGRAM        = macro
ALGOLW_SOURCES = stip_begin.alw macro.alw stip_end.alw
OTHER_FILES    = test.input test.expected man.py macro.1.src

BINDIR = /usr/local/bin
MANDIR = /usr/local/share/man/man1

.PHONY: build test install uninstall

build: macro macro.1 test

test: macro
	./macro < test.input > test.output
	diff test.expected test.output

install:
	install -m 755 -d $(BINDIR) $(MANDIR)
	install -m 755 -t $(BINDIR) macro
	install -m 644 -t $(MANDIR) macro.1

uninstall:
	rm -f $(BINDIR)/macro
	rm -f $(MANDIR)/macro.1

macro.1:
	python3 man.py macro.1.md macro.1

clean::
	rm -f test.output macro.1

include awe.mk
