# MACRO 1 / macro / Simple macro preprocessor

## NAME

macro \- expand string definitions, with arguments

## SYNOPSIS

macro < *input* > *output*

## DESCRIPTION

*macro* reads its input, looking for macro definitions of the form

```
define(ident,string)
```

and writes its output with each subsequent instance of the identifier
`ident` replaced by the arbitrary sequence of characters `string`.

Within a replacement string, any dollar sign `$` followed by a digit
is replaced by an argument corresponding to that digit.  Arguments are
written as a parenthesized list of strings following an instance of
the identifier, e.g.

```
ident(arg1,arg2,...)
```

So `$1` is replaced in the replacement string by `arg1`, `$2`
by `arg2`, and so on; `$0` is replaced by `ident`. Missing
arguments are taken as null strings; extra arguments are ignored.

The replacement string in a definition is expanded before the
definition occurs, except that any sequence of characters between a
backtick ` and a balancing apostrophe ' is taken literally, with
the backtick and apostrophe removed.  Thus, it is possible to make an
alias for define by writing

```
define(def,`define($1,$2)')
```

Additional predefined built-ins are:

`ifelse(a,b,c,b)` is replaced by the
string `c` if the string `a` exactly matches the string `b`;
otherwise it is replaced by the string `d`.

`expr(expression)` is replaced by the decimal string
representation of the numeric value of the `expression`. For correct
operation, the expression must consist of parentheses, integer
operands written as decimal digit strings, and the operators `+`,
`-`, `*`, `/` (integer division), and `%` (remainder).
Multiplication and division bind tighter than addition and
subtraction, but parentheses may be used to alter this order.

`substr(s,m,n)` is replaced by the substring
of `s` starting at location `m` (counting from one) and continuing
at most `n` characters.  If `n` is omitted, it is taken as a very
large number; if `m` is outside the string, the replacement string
is null.  `m` and `n` may be expressions suitable for `expr`.

`len(s)` is replaced by the string representing the length of its
argument in characters.

`changeq(xy)` changes the quote characters to `x` and `y`.
`changeq()` changes them back to ` and '.

Each replacement string is rescanned for further possible
replacements, permitting multi-level definitions to be expanded to
final form.


## EXAMPLE

The macro `len` could be written in terms of the other built-ins as:

```
define(`len',`ifelse($1,,0,`expr(1+len(substr($1,2)))')')
```

## BUGS

A recursive definition of the form `define(x,x)` will cause an
infinite loop. Expression evaluation is fragile.  There is no
unary minus. It is unwise to use parentheses as quote characters.

The error messages are not very descriptive and do not show the 
location of the error.

## COPYRIGHT

`macro`, and this man file, were adapted to Algol W from example
source code provided with the book *Software Tools in Pascal*, by
Brian W. Kernighan and P. J. Plauger. Copyright (C) 1981 by Bell
Laboratories, Inc.  and Whitesmiths Ltd.
