/* io.c --very simple I/O library for Algol W programs */

/* This provides the functions for the external procdure declarations in io.alw. */

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include "awe.h"


#define LINE_LENGTH 256  /* This MUST match the result string lengths in io.alw. */
#define PATH_LENGTH 256  /* This MUST match the path string lengths in file.alw. */


void * 
file_open (_awe_str path, _awe_str mode)
{
    FILE *f;

    char c_path [PATH_LENGTH + 1];
    char c_mode [3];

    _awe_str_unpadded_copy(c_path, path, PATH_LENGTH);
    _awe_str_unpadded_copy(c_mode, mode, 2);

    f = fopen(c_path, c_mode);
    if (f == NULL)
        _awe_error(_awe_HERE, "file_open: '%s': %s", c_path, strerror(errno));
    else
        return (void*)f;
}


void 
file_close (void * f)
{
    if (f == NULL) 
        _awe_error(_awe_HERE, "file_close: File handle is NULL");

    if (fclose((FILE*)f) != 0)
        _awe_error(_awe_HERE, "file_close: %s", strerror(errno));
}

/* end */
