/* argc.c -- external procedures to let Algol W programs to access argc and argv. */

#include "awe.h"
#include <string.h>
#include <assert.h>
#include <stdlib.h>


#define STRING_LENGTH 100 /* This MUST match the string length in the Algol W declarations. */


/* Note: '_awe_argc' and '_awe_argc' are global copies of the 'main' function's arguments. */


int
get_argc (void) 
{
    return _awe_argc;
}


int
get_argv_length (int index) 
{
    assert(_awe_argv != NULL);
    if (index < 0 || index > _awe_argc)
        _awe_error(_awe_HERE, "attempted to access argv[%i], argc is %i\n", index, _awe_argc);
    assert(_awe_argv[index] != NULL);
    return strlen(_awe_argv[index]);
}


_awe_str
get_argv (int index) 
{
    int len;

    assert(_awe_argv != NULL);
    if (index < 0 || index > _awe_argc)
        _awe_error(_awe_HERE, "attempted to access argv[%i], argc is %i\n", index, _awe_argc);
    assert(_awe_argv[index] != NULL);
    len = strlen(_awe_argv[index]);
    if (len > STRING_LENGTH)
        _awe_error(_awe_HERE, "strlen(argv[%i] == %i: greater than target string's length of %i", index, len, STRING_LENGTH);
    return _awe_str_cast(_awe_argv[index], len, STRING_LENGTH);
}

/* end */
