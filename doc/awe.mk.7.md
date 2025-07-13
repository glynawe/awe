# AWE.MK 7 / awe.mk / Awe compiler universal Makefile


## NAME

awe.mk - all-purpose Makefile for Algol W programs


## DESCRIPTION

This **make** include file contains targets to build, clean and
distribute moderately complex Algol W programs, i.e. ones that contain
multiple Algol and C source files and might require linking to
external libraries.

An Algol W program Makefile need only contain a few variable definitions
naming the source files, followed by the line *include awe.mk*.

Note that include files are a GNU extension to Make, described in
section 3.3 of the GNU Make manual.


### The targets provided by awe.mk

build
: Build the program.

clean
: Clean away the temporary files. This only deletes files that **awe.mk**
creates.

dist
: Pack your source files into a tar file for distribution.


### Variables to set for awe.mk

PROGRAM
: the name of the executable (mandatory).

ALGOLW_SOURCES
: the Algol W source files, in order (mandatory).

C_SOURCES, C_INCLUDES
: C library files for external procedures, if any.

AWE_FLAGS, CFLAGS, LDLIBS
: flags to pass to the Awe and GCC compilers. Extra libraries to link to the
executable. (The libraries required by the Awe runtime will always be
linked.)

OTHER_FILES
: Additional files to include in the distribution tar file.
(The source files above and your Makefile are always included.)

DISTNAME
: A name for the project. The default name is the name of the current
working directory. The distribution file will have this as its
basename, with a *.tar.gz* extension added. The distribution file will
unpack to a directory with this name.

COMPILER_PATH
: A path to a directory containing Awe's compiler and runtime library
files.  Set this to Awe's build directory to test Awe before
installing it.  (This exists mainly for Awe's self testing.)


### C Interface Headers

If the Algol program contains procedures with external references
(c.f. section 5.3.2.4 of the *Algol W Language Description*) then
**awe.mk** will write prototypes for them to a temporary C include
file. It is a good idea to include that file into your C source files
to ensure you have all function interfaces right. The include file's
name is the program name, followed by *.awe.h*.

```C
#include <awe.h>
#include "program.awe.h"
```

The Awe manual explains the C interface in more detail.


### Multiple Algol W files

*Awe* concatenates the source files on its command line.
The first source file should be an ALGOL W file containing just 
the symbol `BEGIN` and the last file should contain the 
symbols `END.`, the files between them should not enclose
their contents in BEGIN and END. This places your sequence of source files 
inside a single ALGOL W block, which gives you a primitive module system.


## EXAMPLES

The minimal Makefile looks like this:

```Makefile
PROGRAM = mini
ALGOLW_SOURCES = mini.alw
include awe.mk
```

A typical multi-source Makefile might look like this:

```Makefile
PROGRAM        = bugzapper
ALGOLW_SOURCES = BEGIN.alw zap.alw bugzapper.alw END.alw
C_SOURCES      = zap.c highvoltage.c
C_INCLUDES     = zap.h
OTHER_FILES    = README safety.txt
include awe.mk
```

The following Makefile contains an additional target for testing its program, 
and a target to remove the test's temporary file. The *clean* target will be
run in addition the one defined by **awe.mk**. Note that it needs to be
followed by two colons for this to happen.

```Makefile
PROGRAM        = parse
ALGOLW_SOURCES = parse.alw
OTHER_FILES    = expected.output README GRAMMAR

default: build

test: build
        ./parse < GRAMMAR > actual.output
        diff --strip-trailing-cr expected.output actual.output

clean::
        rm -f actual.output

include awe.mk
```

## PREREQUISITES

Awe, GNU Make, tar, sed

## FILES

{{INCDIR}}/awe.mk

## SEE ALSO

**awe**(1), **make**(1), **tar**(1)

{{DOCDIR}}/awe.txt

## VERSION

{{VERSION}}

## AUTHOR

Copyright 2020 by Glyn Webster.

Awe is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License and Lesser GNU General 
Public License as published by the Free Software Foundation, either 
version 3 of the License, or (at your option) any later version.
