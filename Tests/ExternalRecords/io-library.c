/* io.c --very simple I/O library for Algol W programs, to demonstrate external records. */

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <stdlib.h>
#include "awe.h"


#define LINE_LENGTH 256  /* This MUST match the result string length in the Algol W declarations. */
#define PATH_LENGTH 256  /* This MUST match the path string length in the Algol W declarations. */


void * 
algolw_open (_awe_str path, _awe_str mode)
{
    FILE *f;

    char c_path [PATH_LENGTH + 1];
    char c_mode [3];

    _awe_str_unpadded_copy(c_path, path, PATH_LENGTH);
    _awe_str_unpadded_copy(c_mode, mode, 2);

    f = fopen(c_path, c_mode);
    if (f == NULL)
        /* _awe_error(_awe_HERE, "algolw_open: '%s': %s", c_path, strerror(errno)); */
        /* We want to demonstrate returning a NULL pointer as a reference here, so: */
        return NULL;
    else
        return (void*)f;
}


void 
algolw_readline (void *f, _awe_str line, int *success)
{
    char *s;
    size_t size;
    int len;

    size = LINE_LENGTH + 2; /* allow for "\n\0" at end of line */
    s = (char *)malloc(size);  
    assert(s);
    
    len = getline(&s, &size, (FILE*)f);  /* Note: this a GNU C function. */
    if (ferror((FILE*)f))
        _awe_error(_awe_HERE, "algolw_readline: %s", strerror(errno));
    assert (len >= -1);

    if (len == -1) { /* at EOF */
        _awe_str_init(line, LINE_LENGTH); /* clear the string */
        *success = 0;
    }    
    else {
        if (len > 0 && s[len - 1] == '\n') --len;
        assert(len <= LINE_LENGTH);
        _awe_str_cpy(line, LINE_LENGTH, s, len);
        *success = 1;
    }
    free(s);
};


void 
algolw_writeline (void * f, _awe_str line)
{
    int i, len;

    assert(line);
    if (f == NULL) 
        _awe_error(_awe_HERE, "algolw_writeline: File handle is NULL");

    len = _awe_str_unpadded_length(line, LINE_LENGTH);
    for (i = 0; i < len; ++i) 
        if (fputc(line[i], (FILE*)f) == EOF)
            _awe_error(_awe_HERE, "algolw_writeline: %s", strerror(errno));
    if (fputc('\n', (FILE*)f) == EOF)
        _awe_error(_awe_HERE, "algolw_writeline: %s", strerror(errno));
}


void 
algolw_close (void * f)
{
    if (f == NULL) 
        _awe_error(_awe_HERE, "algolw_close: File handle is NULL");

    if (fclose((FILE*)f) != 0)
        _awe_error(_awe_HERE, "algolw_close: %s", strerror(errno));
}

/* end */
