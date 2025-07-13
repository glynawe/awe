# ------------------------------------------------------------------------------
# Build libawe.a

.PHONY : build clean 

build : libawe.a

# Awe programs require an executable stack for call-by-name
# "-z execstack" suppresses a warning from the GCC linker
# See: https://www.redhat.com/en/blog/linkers-warnings-about-executable-stacks-and-segments

CFLAGS=-std=gnu11 -z execstack -Wall -Wextra -Werror -Wno-format-truncation
LDFLAGS += -z execstack

# In Cygwin GC_ALLOC crashes when used inside nested GCC auto functions.
# This is a very obscure bug that the Cygwin maintainers WONTFIX.
ifeq ($(shell uname -o),Cygwin)
$(warning "Compiling a runtime library that does not use libgc.")
NO_GC=1
CFLAGS += -DNO_GC
endif

HEADERS = awe.h aweio.h
SOURCES = aweexcept.c  aweio.c awe.c awestd.c  awestr.c

OBJECTS = $(patsubst %.c,%.o,$(SOURCES))

$(OBJECTS) : $(HEADERS)

aweio.o: aweio.c scanner.inc

scanner.inc: scanner.py
	python3 scanner.py

libawe.a: $(OBJECTS)
	rm -f libawe.a
	ar -cr libawe.a $(OBJECTS)

clean:
	rm -f scanner.inc scanner.dot
	rm -f *.o *.a
