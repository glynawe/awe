/* awestd.c -- Algol W standard procedure library 

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

/* Some of these functions look like they would be happier as macros,
   but they must be passable as procedure actual parameters. */

#include <math.h>
#include <complex.h>
#include <stdio.h>
#include <float.h>
#include <sys/time.h>
#include <time.h>
#include <limits.h>
#include <errno.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <ctype.h>

#include "awe.h"

int maxinteger = INT_MAX;
double pi = M_PI;
double epsilon = DBL_EPSILON;
double longepsilon = DBL_EPSILON;
double maxreal = DBL_MAX;


/* real procedure Roundtoreal(long real value X);
 Returns the properly rounded real (short precision) value of the
 long precision value X.
 Source:
 https://webdocs.cs.ualberta.ca/~tony/Public/Awit-Wita-ComputerChess/AlgolwSupport/vol16%20(ALGOL%20W).pdf
 page 438.
*/
double roundtoreal(double r)
{
  return (double)((float) r);
}

int truncate(double r)  { return (int)r; }
int entier(double r)    { return (int)floor(r); }

int round_(double r)
{
    if (r < 0)
        return (int)(-(floor(-r + 0.5)));
    else
        return (int)floor(r + 0.5);
}


int odd_ (int i) { return abs(i) % 2 == 1; }


unsigned int bitstring(int i) { return (unsigned long int)i; }
int number(unsigned int bits)  { return (int)bits; }


_Complex double imag(double r)     { return r * I; }
_Complex double longimag(double r) { return r * I; }

double imagpart    (_Complex double x) { return cimag(x); }
double realpart    (_Complex double x) { return creal(x); }
double longimagpart(_Complex double x) { return cimag(x); }
double longrealpart(_Complex double x) { return creal(x); }


static
double
analysis_exception (_awe_loc loc, void *condition, double action_1_default)
{
  _awe_process_exception (loc, condition);
  if (condition && *xcpaction(loc, condition) == 1)
    return action_1_default;
  else
    return 0.0;
}


double 
_awe_sin (_awe_loc loc, double arg)
{
  double result;

  errno = 0;
  result = sin(arg);
  if (errno == ERANGE) return analysis_exception(loc, sincoserr, 0.0);
  return result;
}


double 
_awe_cos (_awe_loc loc, double arg)
{
  double result;

  errno = 0;
  result = cos(arg);
  if (errno == ERANGE) return analysis_exception(loc, sincoserr, 0.0);
  return result;
}


double 
_awe_arctan (_awe_loc loc, double arg)
{
  double result;

  errno = 0;
  result = atan(arg);
  if (errno == ERANGE) return analysis_exception(loc, sincoserr, 0.0);
  return result;
}


double 
_awe_exp (_awe_loc loc, double arg)
{
  double result;

  errno = 0;
  result = exp(arg);
  if (errno == ERANGE) return analysis_exception(loc, experr, maxreal);
  return result;
}


double 
_awe_ln (_awe_loc loc, double arg)
{
  double result;

  errno = 0;
  result = log(arg);
  if (errno == ERANGE) return analysis_exception(loc, lnlogerr, -maxreal);
  return result;
}


double 
_awe_log (_awe_loc loc, double arg)
{
  double result;

  errno = 0;
  result = log10 (arg);
  if (errno == ERANGE) return analysis_exception(loc, lnlogerr, -maxreal);
  return result;
}


double 
_awe_sqrt (_awe_loc loc, double arg)
{
  double result;

  if ( (arg < -0.0)) return analysis_exception(loc, sqrterr, sqrt(fabs(arg)));  /* do not alter */
  errno = 0;
  result = sqrt(arg);
  if (errno == ERANGE) return analysis_exception(loc, sqrterr, sqrt(fabs(arg)));
  return result;
}


double
_awe_gamma (_awe_loc loc, double arg)
{
  double result;

  if ( (arg < -0.0)) return analysis_exception(loc, lnlogerr, fabs(arg));   /* do not alter */
  errno = 0;
  result = tgamma(arg);
  if (errno == ERANGE) return analysis_exception(loc, lnlogerr, fabs(arg));
  return result;
}


/* Note the rules for using _awe_return_string. */

_awe_str intbase10(int i)
{
    sprintf((char*)_awe_return_string, " %c%010d", (i < 0 ? '-' : '+'), abs(i));
    assert(strlen((char*)_awe_return_string) == 12);
    return _awe_return_string;
}


_awe_str intbase16(int i)
{
    sprintf((char*)_awe_return_string, "    %08X", i);
    assert(strlen((char*)_awe_return_string) == 12);
    return _awe_return_string;
}


_awe_str 
base10 (double x)
{
    char _awe_repr[13], c_repr[14], sign, first_digit, *following_digits, *tailptr;
    int exponent;

    sprintf(c_repr, "%#+.6e", x);
    assert(strlen(c_repr) <= 14);

    assert(c_repr[0] == '+' || c_repr[0] == '-');
    sign = c_repr[0];

    assert(isdigit(c_repr[1]));
    first_digit = c_repr[1];

    assert(c_repr[2] == '.');
    assert(c_repr[9] == 'e');
    c_repr[9] = '\0';
    following_digits = c_repr + 3;

    assert(c_repr[10] == '+' || c_repr[10] == '-');
    exponent = strtol (c_repr + 10, &tailptr, 10);

    if (exponent <= -100) 
        sprintf(_awe_repr, "-%03d%c%c%s",  -exponent, sign, first_digit, following_digits);
    else if (exponent < 0) 
        sprintf(_awe_repr, " -%02d%c%c%s", -exponent, sign, first_digit, following_digits);
    else if (exponent < 100) 
        sprintf(_awe_repr, " +%02d%c%c%s", +exponent, sign, first_digit, following_digits);
    else
        sprintf(_awe_repr, "+%03d%c%c%s",  +exponent, sign, first_digit, following_digits);

    assert(strlen(_awe_repr) == 12);
    return _awe_string((_awe_str)_awe_repr, 12);
}


_awe_str 
longbase10 (double x)
{
    char _awe_repr[21], c_repr[22], sign, first_digit, *following_digits, *tailptr;
    int exponent;

    sprintf(c_repr, "%#+.14e", x);
    assert(strlen(c_repr) <= 22);

    assert(c_repr[0] == '+' || c_repr[0] == '-');
    sign = c_repr[0];

    assert(isdigit(c_repr[1]));
    first_digit = c_repr[1];

    assert(c_repr[2] == '.');
    assert(c_repr[17] == 'e');
    c_repr[17] = '\0';
    following_digits = c_repr + 3;

    assert(c_repr[18] == '+' || c_repr[18] == '-');
    exponent = strtol (c_repr + 18, &tailptr, 10);

    if (exponent <= -100) 
        sprintf(_awe_repr, "-%03d%c%c%s",  -exponent, sign, first_digit, following_digits);
    else if (exponent < 0) 
        sprintf(_awe_repr, " -%02d%c%c%s", -exponent, sign, first_digit, following_digits);
    else if (exponent < 100) 
        sprintf(_awe_repr, " +%02d%c%c%s", +exponent, sign, first_digit, following_digits);
    else
        sprintf(_awe_repr, "+%03d%c%c%s",  +exponent, sign, first_digit, following_digits);

    assert(strlen(_awe_repr) == 20);
    return _awe_string((_awe_str)_awe_repr, 21);
}


static clock_t start;


int 
time_ (int n)
{
  struct timeval tv;
  struct tm *tm;
  int seconds;

  switch (n) {
  case -1: 
    gettimeofday(&tv, NULL);
    tm = localtime(&tv.tv_sec);
    seconds = tm->tm_hour * 3600 + tm->tm_min * 60 + tm->tm_sec;
    return seconds * 60 + tv.tv_usec * 60 / 1000000;
  case 0:  
    return (int)((double)(clock() - start) * 60 / 100 / CLOCKS_PER_SEC);
  case 1:  
    return (int)((double)(clock() - start) * 60 / CLOCKS_PER_SEC);
  case 2:  
    return (int)((double)(clock() - start) * 38400 / CLOCKS_PER_SEC);

    /* These are non-standard: */
  case 10000:  
    return (int)((double)clock() - start);
  case 10001:  
    return CLOCKS_PER_SEC;
  default:
    return 0;
  }
}


void _awe_init_awestd (void)
{
  start = clock();
}


/* end */
