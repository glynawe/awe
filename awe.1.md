# AWE 1 / awe / ALGOL W compiler

## NAME

awe \- compiler for the ALGOL W language

## SYNOPSIS

**awe** *source.alw*... [**flags**] [**-o** *executable* | **-c** *object.c* | **-p** *object.c*]

## OPTIONS

**-o** *executable*  specifies a name for the executable.

**-c** *object.c* compiles the ALGOL W program into a C
intermediate-code file. Use this if you need to link your ALGOL W
program with external C functions.

**-p** *object.c* compiles a single ALGOL W procedure 
into a C function.

The following flags are meant for debugging purposes only:

**-n** leave out the code that pre-initializes numbers to zero and strings
to spaces.

**-t** adds tracing hooks to all procedure calls. (Experimental.)

## DESCRIPTION

Awe implements the language described in the 
*ALGOL W Language Description, June 1972* very closely.
*awe.txt* documents Awe's dialect of ALGOL W, the run-time
behaviour of Awe-compiled programs, and how to interface ALGOL with C.

The **awe** command line may consist of a list of ALGOL W source file
names and an optional output file flag.  The source files will be
concatenated into a single source program.

By default **awe** compiles an executable. The default name of the
executable is the name of the last ALGOL W source file with its
extension removed. 

If an ALGOL W program contains procedures with external references 
(cf. section 5.3.2.4 of the Language Description) then **awe** 
will write C prototypes for them to stdout. You will need to 
provide C functions for those, and link them into your program.

The syntax for a separately compiled procedure is an ALGOL W procedure
declaration followed by a fullstop.

The most convenient way to maintain moderately complex ALGOL W
programs is to write a Makefile that uses the ready-make targets 
in *awe.mk*.  See **awe.mk**(7).

### Error Messages and Warnings

Programs compiled by Awe should be able to produce ALGOL W specific
error messages for most runtime errors. Assertion errors always
indicate bugs in Awe. Segmentation faults should only occur in the
case of unbounded recursion. (However, if you link to C code you are
back on your own.)

"Call by Name" should used with great caution or great abandon.
**awe** notes the locations where Name formal parameters are defined,
and where expressions are used as Name actual parameters.

### Awe and GCC

Awe uses Gnu C, with its extensions, as an intermediate language. Awe
is responsible for all parsing, type checking and compile-time error
messages, it uses **gcc** to generate object code only. **gcc**
should stay completely invisible when you run **awe**, any messages
from **gcc** whatsoever should be considered to be bugs in Awe.
The C files **awe** generates are temporary and will not contain human
readable code: do not store them in a version control system or
distribute them; delete them when you delete object files.

## EXAMPLES

```sh
awe program.alw

awe zap.alw -c zap.c > externals.h
gcc zap.c externals.c -lm -lgc -lawe -o zap

awe procedure.alw -c procedure.c
```

## PREREQUISITES

The Gnu C compiler, the Boehm GC library.

## FILES

{{BINDIR}}/awe
: The Awe compiler.

{{DOCDIR}}/awe.txt
: The Awe ALGOL W documentation file.

{{INCDIR}}/awe.mk
: The Awe general-purpose Makefile.

{{INCDIR}}/awe.h
: The Awe runtime library header file. Include this in C files that define external procedures for ALGOL W programs.

{{LIBDIR}}/libawe.a
: The runtime library for Awe-compiled programs.

{{INCDIR}}/aweio.h
: The Awe Standard I/O System header file. (Experimental.)

## SEE ALSO

**awe.mk**(7),
**gcc**(1), 
**gc**(3), 
*ALGOL W Language Description, June 1972*

## VERSION

{{VERSION}}

## AUTHOR

Copyright 2017, 2020 by Glyn Webster.

Awe is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License and Lesser GNU General 
Public License as published by the Free Software Foundation, either 
version 3 of the License, or (at your option) any later version.
