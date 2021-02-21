/* awestr.c -- Awe Algol W runtime string library 

--

This file is part of Awe. Copyright 2012 Glyn Webster.

This file is free software: you can redistribute it and/or modify it
under the terms of the GNU Limited General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Awe is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU Limited General Public
License along with Awe.  If not, see <http://www.gnu.org/licenses/>.

*/

/* Run "gcc -lgc -D AWESTRING_TEST awestr.c && ./a.out" to test
   this file. You should see these runtime error messages pop up, 
   but you are not supposed to see any assertion failures:

   nnn: Tried to copy substring (2|4) of a string of length 5.
   nnn: Tried to copy substring (3|3) of a string of length 5.
   nnn: Tried to copy invalid substring (-3|3).
*/

#include <string.h>
#include <assert.h>

#ifndef AWESTRING_TEST
#include "awe.h"
#endif

#ifdef AWESTRING_TEST
#include <stdio.h>
#include <stdarg.h>
typedef int _awe_loc;
typedef unsigned char *_awe_str;
void
_awe_error (_awe_loc l, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    fprintf(stderr, "%d: ", l);
    vfprintf(stderr, format, args);
    va_end(args);
}
#endif


/* String manipulation -------------------------------------------------------------------- */


unsigned char _awe_return_string [256];


_awe_str
_awe_string (_awe_str src, int srclen)
{
    assert(srclen >= 0);
    if (src != _awe_return_string) memcpy(_awe_return_string, src, srclen);
    return _awe_return_string;
}


_awe_str
_awe_str_cast (_awe_str src, int srclen, int length)
{
    assert(length > 0);
    assert(srclen >= 0);
    assert(length >= srclen);
    if (src != _awe_return_string)
        memcpy(_awe_return_string, src, srclen);
    if (srclen < length) 
        memset(_awe_return_string + srclen, ' ', length - srclen);
    return _awe_return_string;
}


_awe_str
_awe_str_cast_c (unsigned char c, int length)
{
    assert(length > 0);
    _awe_return_string[0] = c;
    if (length > 1) 
        memset(_awe_return_string + 1, ' ', length - 1);
    return _awe_return_string;
}


int 
_awe_str_unpadded_length (const _awe_str src, int srclen)
{
    int i;
    for (i = srclen; i > 0; --i)
        if (src[i - 1] != ' ')
            break;
    return i;
}


void
_awe_str_unpadded_copy (char *s,  const _awe_str src, int srclen)
{
    int length;

    length = _awe_str_unpadded_length(src, srclen);
    strncpy(s, src, length);
    s[length] = '\0';
}


_awe_str 
_awe_str_sub (_awe_loc loc, const _awe_str src, int srclen, int index, int length)
{
    assert(src);
    assert(srclen >= 1);
    assert(length > 0);
    
    if (index < 0 || length <= 0)
        _awe_error( loc, "Invalid substring (%d|%d).", index, length);
    
    if (index + length > srclen)
        _awe_error( loc, "Substring (%d|%d) of a string of length %d.", index, length, srclen );
    
    return src + index;
}


_awe_str 
_awe_str_cpy (_awe_str dst, int dstlen, const _awe_str src, int srclen)
{
    assert(dst);
    assert(dstlen >= 2);
    assert(src);
    assert(srclen >= 0);
    assert(dstlen >= srclen);

    memcpy(dst, src, srclen);
    if (srclen < dstlen)
        memset(dst + srclen, ' ', dstlen - srclen);
    return src;
}


unsigned char
_awe_str_cpy_sc (_awe_str dst, int dstlen, unsigned char src)
{
    assert(dst);
    assert(dstlen >= 2);
    dst[0] = src;
    if (dstlen > 1)
        memset(dst + 1, ' ', dstlen - 1);
    return src;
}


void
_awe_str_init (_awe_str dst, int dstlen)
{
    assert(dst);
    assert(dstlen >= 2);
    memset(dst, ' ', dstlen);
}

/* Character transfer functions ----------------------------------------------------------------- */


/* IBM Code Page 01047: EBCDIC Latin-1 */

unsigned char _awe_ebcdic_of_latin1 [256] = {
    0x00, 0x01, 0x02, 0x03, 0x37, 0x2d, 0x2e, 0x2f, 0x16, 0x05, 0x25, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    0x10, 0x11, 0x12, 0x13, 0x3c, 0x3d, 0x32, 0x26, 0x18, 0x19, 0x3f, 0x27, 0x1c, 0x1d, 0x1e, 0x1f,
    0x40, 0x5a, 0x7f, 0x7b, 0x5b, 0x6c, 0x50, 0x7d, 0x4d, 0x5d, 0x5c, 0x4e, 0x6b, 0x60, 0x4b, 0x61,
    0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0x7a, 0x5e, 0x4c, 0x7e, 0x6e, 0x6f,
    0x7c, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6,
    0xd7, 0xd8, 0xd9, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xad, 0xe0, 0xbd, 0x5f, 0x6d,
    0x79, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96,
    0x97, 0x98, 0x99, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xc0, 0x4f, 0xd0, 0xa1, 0x07,
    0x20, 0x21, 0x22, 0x23, 0x24, 0x15, 0x06, 0x17, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x09, 0x0a, 0x1b,
    0x30, 0x31, 0x1a, 0x33, 0x34, 0x35, 0x36, 0x08, 0x38, 0x39, 0x3a, 0x3b, 0x04, 0x14, 0x3e, 0xff,
    0x41, 0xaa, 0x4a, 0xb1, 0x9f, 0xb2, 0x6a, 0xb5, 0xbb, 0xb4, 0x9a, 0x8a, 0xb0, 0xca, 0xaf, 0xbc,
    0x90, 0x8f, 0xea, 0xfa, 0xbe, 0xa0, 0xb6, 0xb3, 0x9d, 0xda, 0x9b, 0x8b, 0xb7, 0xb8, 0xb9, 0xab,
    0x64, 0x65, 0x62, 0x66, 0x63, 0x67, 0x9e, 0x68, 0x74, 0x71, 0x72, 0x73, 0x78, 0x75, 0x76, 0x77,
    0xac, 0x69, 0xed, 0xee, 0xeb, 0xef, 0xec, 0xbf, 0x80, 0xfd, 0xfe, 0xfb, 0xfc, 0xba, 0xae, 0x59,
    0x44, 0x45, 0x42, 0x46, 0x43, 0x47, 0x9c, 0x48, 0x54, 0x51, 0x52, 0x53, 0x58, 0x55, 0x56, 0x57,
    0x8c, 0x49, 0xcd, 0xce, 0xcb, 0xcf, 0xcc, 0xe1, 0x70, 0xdd, 0xde, 0xdb, 0xdc, 0x8d, 0x8e, 0xdf,
};

unsigned char _awe_latin1_of_ebcdic [256] = {
    0x00, 0x01, 0x02, 0x03, 0x9C, 0x09, 0x86, 0x7F, 0x97, 0x8D, 0x8E, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    0x10, 0x11, 0x12, 0x13, 0x9D, 0x85, 0x08, 0x87, 0x18, 0x19, 0x92, 0x8F, 0x1C, 0x1D, 0x1E, 0x1F,
    0x80, 0x81, 0x82, 0x83, 0x84, 0x0A, 0x17, 0x1B, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x05, 0x06, 0x07,
    0x90, 0x91, 0x16, 0x93, 0x94, 0x95, 0x96, 0x04, 0x98, 0x99, 0x9A, 0x9B, 0x14, 0x15, 0x9E, 0x1A,
    ' ',  0xA0, 0xE2, 0xE4, 0xE0, 0xE1, 0xE3, 0xE5, 0xE7, 0xF1, 0xA2, '.',  '<',  '(',  '+',  '|', 
    '&',  0xE9, 0xEA, 0xEB, 0xE8, 0xED, 0xEE, 0xEF, 0xEC, 0xDF, '!',  '$',  '*',  ')',  ';',  '^', 
    '-',  '/',  0xC2, 0xC4, 0xC0, 0xC1, 0xC3, 0xC5, 0xC7, 0xD1, 0xA6, ',',  '%',  '_',  '>',  '?', 
    0xF8, 0xC9, 0xCA, 0xCB, 0xC8, 0xCD, 0xCE, 0xCF, 0xCC, '`',  ':',  '#',  '@',  '\'', '=',  '"', 
    0xD8, 'a',  'b',  'c',  'd',  'e',  'f',  'g',  'h',  'i',  0xAB, 0xBB, 0xF0, 0xFD, 0xFE, 0xB1,
    0xB0, 'j',  'k',  'l',  'm',  'n',  'o',  'p',  'q',  'r',  0xAA, 0xBA, 0xE6, 0xB8, 0xC6, 0xA4,
    0xB5, '~',  's',  't',  'u',  'v',  'w',  'x',  'y',  'z',  0xA1, 0xBF, 0xD0, '[',  0xDE, 0xAE,
    0xAC, 0xA3, 0xA5, 0xB7, 0xA9, 0xA7, 0xB6, 0xBC, 0xBD, 0xBE, 0xDD, 0xA8, 0xAF, ']',  0xB4, 0xD7,
    '{',  'A',  'B',  'C',  'D',  'E',  'F',  'G',  'H',  'I',  0xAD, 0xF4, 0xF6, 0xF2, 0xF3, 0xF5,
    '}',  'J',  'K',  'L',  'M',  'N',  'O',  'P',  'Q',  'R',  0xB9, 0xFB, 0xFC, 0xF9, 0xFA, 0xFF,
    '\\', 0xF7, 'S',  'T',  'U',  'V',  'W',  'X',  'Y',  'Z',  0xB2, 0xD4, 0xD6, 0xD2, 0xD3, 0xD5,
    '0',  '1',  '2',  '3',  '4',  '5',  '6',  '7',  '8',  '9',  0xB3, 0xDB, 0xDC, 0xD9, 0xDA, 0x9F
};


int
decode (unsigned char c) 
{
    return _awe_ebcdic_of_latin1[c];
}


unsigned char
code (int i)
{
    return _awe_latin1_of_ebcdic[i % 256];
}


/* String comparision  -------------------------------------------------------------------- */


int 
_awe_str_cmp_cc (unsigned char c1, unsigned char c2)
{
    return _awe_ebcdic_of_latin1[c1] - _awe_ebcdic_of_latin1[c2];
}


/* Compare two equal length strings in EBCDIC order */

static
int
ebcdic_memcmp (const _awe_str a, const _awe_str b, int n)
{
    int i, cmp;
    for (i = 0; i < n; ++i) {
        cmp = _awe_str_cmp_cc(a[i], b[i]);
        if (cmp != 0)
            return cmp;
    }
    return 0;
}


/* Compare a longer string with a shorter one, using Algol W's padding rule. */

static
int
long_cmp ( const _awe_str str1, int str1len, 
           const _awe_str str2, int str2len )
{
    int i, n;

    assert(str1len >= str2len);

    n = ebcdic_memcmp(str1, str2, str2len);
    if (n != 0) return n;
    for (i = str2len; i < str1len; ++i)
        if (str1[i] != ' ')
            return 1;
    return 0;
}


int 
_awe_str_cmp ( const _awe_str str1, int str1len, 
              const _awe_str str2, int str2len )
{
    assert(str1);
    assert(str1len > 0);
    assert(str2);
    assert(str2len > 0);
    
    if (str1len > str2len)
        return long_cmp(str1, str1len, str2, str2len);
    else
        return -long_cmp(str2, str2len, str1, str1len);
}


int 
_awe_str_cmp_sc ( const _awe_str str1, int str1len, unsigned char c )
{
    unsigned char str2 = c;
    return _awe_str_cmp(str1, str1len, &str2, 1);
}


int 
_awe_str_cmp_cs ( unsigned char c, const _awe_str str2, int str2len )
{
    unsigned char str1 = c;
    return _awe_str_cmp(&str1, 1, str2, str2len);
}


#ifdef AWESTRING_TEST
void print (_awe_str s, int n)
{
    int i;
    putchar('"');
    for (i = 0; i < n; ++i) putchar(s[i]);
    putchar('"');
    putchar('\n');
}
int 
main (void)
{
    int i;
    for (i = 0; i < 256; ++i) {
        assert(_awe_latin1_of_ebcdic[_awe_ebcdic_of_latin1[i]] == i);
        assert(_awe_ebcdic_of_latin1[_awe_latin1_of_ebcdic[i]] == i);
    }

    unsigned char c;
    _awe_str s5 [5];
    _awe_str s3 [3];
    _awe_str s;

    /* XXX this not complete and methodical */

    assert(memcmp(s5, "     ", 5) == 0);
    assert(memcmp(s3, "   ", 3) == 0);

    _awe_str_cpy(s5, 5, "abc", 3);
    assert(memcmp(s5, "abc  ", 5) == 0);

    _awe_str_cpy(s3, 3, "AB", 2);
    s = _awe_str_cpy(s5, 5, s3, 3);
    assert(s == s3);
    assert(memcmp(s5, "AB   ", 5) == 0);

    _awe_str_cpy(s5, 5, "abc", 3);
    s = _awe_str_sub(__LINE__, s5, 5, 3, 2);
    assert(s == s5 + 3);
    assert(memcmp(s, "  ", 2) == 0);

    s = _awe_str_cpy(s5, 5, "abcx", 3);
    assert(memcmp(s5, "abc  ", 5) == 0);
    assert(memcmp(s, "abcx", 4) == 0);


    _awe_str_cpy(s5, 5, "abcde", 5);
    _awe_str_cpy(s3, 3, "12", 2);
    s = _awe_str_sub(__LINE__, s5, 5, 1, 3);
    assert(memcmp(s, "bcd", 3) == 0);
    _awe_str_cpy(_awe_str_sub(__LINE__, s5, 5, 1, 3), 3, s3, 3);
    assert(memcmp(s5, "a12 e", 5) == 0);

    c = _awe_str_cpy_sc(s5, 5, ' ');
    assert(c == ' ');
    assert(memcmp(s5, "     ", 5) == 0);


    /* Runtime errors: */
    _awe_str_sub(__LINE__, s5, 5, 2, 4);
    _awe_str_sub(__LINE__, s5, 5, 3, 3);
    _awe_str_sub(__LINE__, s5, 5, -3, 3);

    assert(_awe_str_cmp("abc", 3, "abc", 3) == 0);
    assert(_awe_str_cmp("abc", 3, "bcd", 3) < 0);
    assert(_awe_str_cmp("bcd", 3, "abc", 3) > 0);

    assert(_awe_str_cmp("abc ", 4, "abc", 3) == 0);
    assert(_awe_str_cmp("abc ", 4, "bcd", 3) < 0);
    assert(_awe_str_cmp("bcd ", 4, "abc", 3) > 0);

    assert(_awe_str_cmp("abc", 3, "abc  ", 5) == 0);
    assert(_awe_str_cmp("abc", 3, "bcd  ", 5) < 0);
    assert(_awe_str_cmp("bcd", 3, "abc  ", 5) > 0);

    assert(_awe_str_cmp("abc.", 4, "abc", 3) > 0);
    assert(_awe_str_cmp("abc.", 4, "bcd", 3) < 0);
    assert(_awe_str_cmp("bcd.", 4, "abc", 3) > 0);

    assert(_awe_str_cmp("abc", 3, "abc. ", 5) < 0);
    assert(_awe_str_cmp("abc", 3, "bcd. ", 5) < 0);
    assert(_awe_str_cmp("bcd", 3, "abc. ", 5) > 0);

    s = _awe_str_new("xyz", 3, 5);
    assert(memcmp(s, "xyz  ", 5) == 0);

    s = _awe_str_new_c('x', 5);
    assert(memcmp(s, "x    ", 5) == 0);

    c = _awe_str_cpy_sc(s, 3, 'w');
    assert(c == 'w');
    assert(memcmp(s, "w    ", 5) == 0);

    printf("*** 'awestr.c' looks okay.\n");
    return 0;
}
#endif


/* end */
