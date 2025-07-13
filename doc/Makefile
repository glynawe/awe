# imported variables: BINDIR LIBDIR DOCDIR INCDIR MANDIR1 MANDIR7

.PHONY: all manpages webpages clean

all: manpages webpages

manpages: awe.1 awe.mk.7 awe.html github-markdown.css

webpages: manpages awe.1.html awe.mk.7.html INSTALL.html

awe.1 : man.py awe.1.md ../VERSION
	python3 man.py awe.1.md awe.1 \
                      VERSION="$(shell cat ../VERSION)" \
                      BINDIR="$(BINDIR)" LIBDIR="$(LIBDIR)" DOCDIR="$(DOCDIR)" INCDIR="$(INCDIR)"

awe.mk.7 : man.py awe.mk.7.md ../VERSION
	python3 man.py awe.mk.7.md awe.mk.7 \
                      VERSION="$(shell cat ../VERSION)" \
                      BINDIR="$(BINDIR)" LIBDIR="$(LIBDIR)" DOCDIR="$(DOCDIR)" INCDIR="$(INCDIR)"

awe.1.html: awe.1 htmltext.py
	MANWIDTH=80 man ./awe.1 | python3 htmltext.py "awe(1): Awe ALGOL W compiler man page" > awe.1.html

awe.mk.7.html: awe.mk.7 htmltext.py
	MANWIDTH=80 man ./awe.mk.7 | python3 htmltext.py "awe.mk(7): Awe ALGOL W Makefile man page" > awe.mk.7.html

awe.html: awe.md markdown-to-html.py github-markdown.css
	python3 markdown-to-html.py awe.md awe.html

INSTALL.html: ../INSTALL.md markdown-to-html.py github-markdown.css
	python3 markdown-to-html.py ../INSTALL.md INSTALL.html

github-markdown.css:
	cp ../github-markdown.css .

clean:
	rm -f awe.1 awe.mk.7 awe.html awe.1.html awe.mk.7.html INSTALL.html
	rm -f github-markdown.css
