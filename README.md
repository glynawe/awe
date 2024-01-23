# Awe
ALGOL W is a successor to Algol 60 closely based on A Contribution to the Development of ALGOL by Niklaus Wirth and C. A. R. Hoare. It includes dynamically allocated records, string handling, complex numbers and a standard I/O system.

Awe is a new compiler for the ALGOL W language. It is a complete implementation of the language described in the [ALGOL W Language Description, June 1972](algolw.pdf). Awe should be able to compile code intended for the OS/360 ALGOL W compilers with little or no modification. For details read the [Awe manual](awe.md), [awe](awe.1.md)(1) and [awe.mk](awe.mk.7.md)(7).

The main requirements for compiling Awe are a Unix-like environment, GCC, Python3, OCaml and Boehm GC. For details read [INSTALL](INSTALL.md) and awe(1).

## Thank You

Thank you to: Hendrick Boom, Tony Marsland, Carey Bloodworth, John Boutland and Nicolas Brouard for a great deal of expert advice, encouragement and testing; and the authors of the *Algol W Language Description* for creating such an unambiguous work.

## By the Way

If you have found this software useful or enlightening, please consider buying one of the late Frank Key's [books](https://www.lulu.com/search/?contributor=Frank+Key). Frank kept me sane, somehow.