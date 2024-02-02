# INSTALLING AWE


## Requirements

A Unix-like operating system, Gnu C, Python 3, OCaml 4.05 or later,
make, ar, markdown and the Boehm GC.

Ubuntu or Debian Linux are ideal.  The Windows Subsystem for Linux should be
used on Windows; Awe has not been tested on Cygwin. Awe will successfully
compile and run its tests on macOS, but it should be considered experimental.

On Debian or Ubuntu install these packages:

     gcc ocaml-nox python3 python3-markdown binutils make libgc-dev


## Building Awe

These are commands to compile and install Awe, to be run from within
the `awe/` source code directory:

`make`

   This builds Awe, then performs a large number of automated tests on it.

`sudo make install`

   This installs Awe. 

   The default destination is the standard "/usr/local" directories.
   Edit `Makefile` if you do not want this.

`man awe`

   Learn how to run your new Algol W compiler.


That's it, it should be that simple.

Feel free to ask me any questions. 
My email address is in the distribution files.

---
Glyn Webster, 2024
