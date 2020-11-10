# awe.mk -- General purpose Makefile for Algol W programs.

# See man page awe.mk(7)

#Cygwin's libgc library (cygwin 1.7.16-1, libgc-devel 7.1-1) does not
#currently work with Awe, it issues warnings and corrupts memory, so
#'libawe.a' is not linked to 'libgc' on Cygwin.
#
ifeq ($(shell uname -o),Cygwin)
$(warning "This is Cygwin, so not linking your program to 'libgc'.")
LDLIBS += -lawe -lm
else
LDLIBS += -lawe -lm -lgc
endif


ifdef COMPILER_PATH
CFLAGS += -I$(COMPILER_PATH) -L$(COMPILER_PATH)
AWE=$(COMPILER_PATH)/awe
else
AWE=awe
endif

ifndef DISTNAME
DISTNAME = $(shell basename `pwd`)
endif

.PHONY: default build clean test dist 

# default rule:
build: Makefile $(PROGRAM) 

$(PROGRAM) : $(PROGRAM).awe.c $(PROGRAM).awe.h $(C_SOURCES) $(C_INCLUDES)
	gcc $(CFLAGS) $(C_SOURCES) $(PROGRAM).awe.c $(LDLIBS) -o $(PROGRAM)

$(PROGRAM).awe.c $(PROGRAM).awe.h : $(ALGOLW_SOURCES)
	$(AWE) $(AWE_FLAGS) $(ALGOLW_SOURCES) -c $(PROGRAM).awe.c > $(PROGRAM).awe.h

clean::
	rm -f $(PROGRAM) $(PROGRAM).awe.c $(PROGRAM).awe.h $(DISTNAME).tar.gz

# Tar the files with the program's name as a directory prefix.
#
# 	/$(sort ...)' = sort and remove duplicate file names (the latter is important)
#
# 	'--transform=...' = edit the path names going into 'tar' using 'sed'
#
ALL_FILES = $(sort $(wildcard Makefile $(ALGOLW_SOURCES) $(C_SOURCES) $(C_INCLUDES) $(EXTRA_FILES)))
dist:
	rm -f $(DISTNAME).tar.gz
	tar --create --gzip \
	    --no-recursion \
	    --transform "s|^|$(DISTNAME)/|" \
	    --file $(DISTNAME).tar.gz $(ALL_FILES)
#end
