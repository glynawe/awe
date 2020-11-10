These files are copied from:

http://www.hpl.hp.com/personal/Hans_Boehm/gc/gc_source/bdwgc-7_2alpha5-20110107.tar.bz2

They require the libgc-dev package to be intalled.

To test:

gcc -lgc -I. -I/usr/include/gc cord*.c && ./a.out
