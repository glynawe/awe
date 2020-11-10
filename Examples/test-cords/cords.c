/* cords_a.c -- adapts cords functions to the data types that Algol W uses */

/* Mostly size_t --> int */

#include <awe.h>
#include <stddef.h>
#include <string.h>
#include "cords/cord.h"

#define AWE_STRING_LEN 256


CORD
CORD_of_text (_awe_str src)
{
    int length;

    char s [AWE_STRING_LEN + 1];

    _awe_str_unpadded_copy(s, src, AWE_STRING_LEN);

    length = strlen(s);
    return CORD_from_char_star(s);
}


CORD
CORD_of_string (_awe_str src, int index, int length)
{
    char s [AWE_STRING_LEN + 1];
    if (index < 0 || length <= 0 || index + length > AWE_STRING_LEN)
        _awe_error( _awe_HERE, 
                   "Cannot take substring (%d|%d) of a STRING(%d).", 
                   index, length, AWE_STRING_LEN );
    strncpy(s, src + index, length);
    s[length] ='\0';
    return CORD_from_char_star(s);
}


CORD
CORD_of_chars (unsigned char c, int n)
{
    return CORD_chars(c, (size_t)n);
}


_awe_str
string_of_CORD (CORD src)
{
    int length;
    const char *s;

    length = CORD_len(src);
    if (length > AWE_STRING_LEN)
        _awe_error( _awe_HERE, 
                   "A CORD of length(%d) will not fit in a string(%d)", 
                   length, AWE_STRING_LEN );

    s = CORD_to_const_char_star(src);
    return _awe_str_cast((_awe_str)s, length, AWE_STRING_LEN);
}


int
ord (unsigned char c)
{
    return c;
}


unsigned char
chr (int i)
{
    if (i < 0 || i > 255) _awe_error(_awe_HERE, "chr: %d is not a Latin-1 code", i);
    return i;
}


int
text_len (_awe_str src)
{
    return _awe_str_unpadded_length(src, AWE_STRING_LEN);
}


/* end */
