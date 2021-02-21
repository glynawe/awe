/* awe.c -- Awe Algol W runtime library 

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

#include "awe.h"

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <limits.h>
#include <fenv.h>

#include <complex.h>

#ifdef NO_GC
#include <malloc.h>
#else
#include <gc/gc.h>
#endif


int _awe_argc;
char **_awe_argv;


void
_awe_init (_awe_loc loc)
{
    _awe_record_counter = 0;
    _awe_init_awestd();
    _awe_init_exceptions(loc);
    _awe_init_aweio(loc);
}


/* Shut down all parts of the Awe runtime. */
void
_awe_finalize (_awe_loc loc)
{
    _awe_exit_aweio(loc);  /* Currently this all there is to it. */
}


void
_awe_error (_awe_loc l, const char *format, ...)
{
  va_list args;

  /* Flush the standard output first, so that the error message appears in a sensible place. */
  _awe_finalize(l);

  va_start(args, format);
  if (l)
      fprintf(stderr, "%s:%d:%d: ", l->file, l->line, l->column + 1);
  else
      fprintf(stderr, "<unknown location>: ");
  vfprintf(stderr, format, args);
  va_end(args);
  fputc('\n', stderr);
  exit(EXIT_FAILURE);
}


void
_awe_warning (_awe_loc l, const char *format, ...)
{
  va_list args;
  va_start(args, format);
  if (l)
      fprintf(stderr, "%s:%d:%d: ", l->file, l->line, l->column + 1);
  else
      fprintf(stderr, "<unknown location>: ");
  vfprintf(stderr, format, args);
  fprintf(stderr, "\n");
  va_end(args);
}


int
_awe_env_int(_awe_loc l, const char *name, int default_, int min, int max)
{
  char *var, *tail;
  int val;

  var = getenv(name);
  if (!var) 
    return default_;

  val = strtol (var, &tail, 10);
  if (tail == var || val > max || val < min)
    _awe_error(l, "Expected an integer between %d and %d in system variable %s.", min, max, name);

  return val;
}


int
_awe_env_bool (_awe_loc l, const char *name, int default_)
{
  char *var;

  var = getenv(name);
  if (!var) 
    return default_;

  if(strcasecmp(var, "on") == 0) return 1;
  if(strcasecmp(var, "true") == 0) return 1;
  if(strcasecmp(var, "t") == 0) return 1;
  if(strcasecmp(var, "1") == 0) return 1;
  if(strcasecmp(var, "yes") == 0) return 1;
  if(strcasecmp(var, "y") == 0) return 1;
  
  if(strcasecmp(var, "off") == 0) return 0;
  if(strcasecmp(var, "0") == 0) return 0;
  if(strcasecmp(var, "false") == 0) return 0;
  if(strcasecmp(var, "f") == 0) return 0;
  if(strcasecmp(var, "no") == 0) return 0;
  if(strcasecmp(var, "n") == 0) return 0;

  /* You've had enough chances. */
  _awe_error(l, "Expected a true or false value in system variable %s.", name);
}



/* Records and references ------------------------------------------------------------ */


int _awe_record_counter;


void *
_awe_allocate_record(_awe_loc l, int size)
{
  void *record;

#ifdef NO_GC
  record = malloc((size_t)size);
#else
  record = GC_MALLOC((size_t)size);
#endif

  if (record)
    return record;
  else
    _awe_error(l, "Could not allocate record %i: Out of memory!", _awe_record_counter + 1);
}


int
_awe_is (void *ref, const char *class) 
{
  return ref && _awe_class(ref) == class;  /* i.e. pointer is not NULL and points to record of right class */
}


int _awe_you_should_not_pointing_here;


void 
_awe_ref_field_check (_awe_loc loc, void *ref, const char *class, const char *field_name)
{
  if (!ref)
    _awe_error(loc, "reference error: tried to find field %s of a NULL reference", field_name);
  if (ref == _awe_uninitialized_reference)
    _awe_error(loc, "reference error: tried to find field %s of an uninitialized reference", field_name);
  if (!_awe_is(ref, class))
    _awe_error( loc, "reference error: tried to find field %s of a REFERENCE(%s)",
               field_name, 
               _awe_class(ref) );
}


/* Converts a zero-terminated array of record class numbers into the Algol W name for a reference type.  */
/* This only gets used by the function below. */
static
char *
_awe_string_of_ref (const char **classes)
{
  static char s[512];
  const char **pclass;
  
  assert(*classes != 0);
  strcpy(s, "a REFERENCE(");
  strcat(s, *classes);
  for (pclass = classes + 1; *pclass != 0; ++pclass) {
    strcat(s, ", ");
    strcat(s, *pclass);
  }
  strcat(s, ")");
  return s;
}


void *
_awe_ref_cast_check (_awe_loc loc, void *ref, const char **classes)
{
  const char **pclass;

  if (ref == NULL)
      return NULL;
  for (pclass = classes; *pclass != 0; ++pclass)
    if (_awe_class(ref) == *pclass) 
      return ref;
  _awe_error( loc, "reference error: %s cannot be made to refer to a '%s' record.",
             _awe_string_of_ref(classes),
             _awe_class(ref) );
}


/* Arrays -------------------------------------------------------------------------------- */


void
_awe_array_range_error(_awe_loc l, const char *array, int subscript, int lwb, int upb, int sub)
{
    if (upb - lwb < 1)
        _awe_error(l, "array subscript error: subscript %d of '%s' = %d, of empty array range (%d::%d)",
                  subscript, array, sub, lwb, upb);
    else
        _awe_error(l, "array subscript error: subscript %d of '%s' = %d, outside the range (%d::%d)",
                  subscript, array, sub, lwb, upb);
}


void
_awe_array_bounds_error(_awe_loc l, const char *array, int subscript, int lwb, int upb)
{
    _awe_error(l, "array bounds error: bound %d of '%s' is (%d::%d) here",
	    subscript, array, lwb, upb);
}


/* Statements -------------------------------------------------------------------------------- */


void
_awe_assert(_awe_loc l, int condition)
{
    if(! condition) {
        _awe_error(l, "assertion failure");
    }
}


void
_awe_check_for_step(_awe_loc l, int for_step)
{
  if (for_step == 0)  _awe_error(l, "FOR step of 0");
}


void
_awe_case_range_error(_awe_loc l, int selector)
{
  _awe_error(l, "CASE range error: selector is %d", selector);
}


/* Maths -------------------------------------------------------------------------------- */


int
_awe_div(_awe_loc loc, int dividend, int  divisor)
{
  if (divisor != 0)
    return dividend / divisor;
  else if (intdivzero == NULL)
    return dividend;
  else {
    _awe_process_exception(loc, intdivzero);
    return dividend;
  }
}


int
_awe_rem(_awe_loc loc, int dividend, int  divisor)
{
  if (divisor != 0)
    return dividend % divisor;
  else if (intdivzero == NULL)
    return dividend;
  else {
    _awe_process_exception(loc, intdivzero);
    return dividend;
  }
}


double
_awe_rdiv(_awe_loc loc, double dividend, double divisor)
{
  double quotient;

  feclearexcept(FE_DIVBYZERO);
  quotient = dividend / divisor;
  if (fetestexcept(FE_DIVBYZERO)) {
    feclearexcept(FE_DIVBYZERO);
    _awe_process_exception (loc, divzero);
    if (divzero) 
      switch (*xcpaction(loc, divzero)) {
      case 1: return maxreal;
      case 2: return 0.0;
      default: return dividend;
      }
    else
      return dividend;
  }
  else
    return quotient;
}


_Complex double
_awe_cdiv (_awe_loc loc, _Complex double dividend, _Complex double divisor)
{
  _Complex double quotient;

  feclearexcept(FE_DIVBYZERO);
  quotient = dividend / divisor;
  if (fetestexcept(FE_DIVBYZERO)) {
    feclearexcept(FE_DIVBYZERO);
    _awe_process_exception (loc, divzero);
    if (divzero) 
      switch (*xcpaction(loc, divzero)) {
      case 1: return maxreal;
      case 2: return 0.0;
      default: return dividend;
      }
    else
      return dividend;
  }
  else
    return quotient;
}


double 
_awe_fabs(double r)
{
  return fabs(r);
}

_Complex double _awe_cabs(_Complex double x)
{
  return cabs(x);
}


static
double 
rpwr_loop (double x, int n)
{
  double result = 1.0;
  while (n) {
    if (n & 1) {
      result *= x;
      n -= 1;
    }
    x *= x;
    n /= 2;
  }
  return result;
}


double
_awe_rpwr (_awe_loc l, double x, int n)
{
  if (x == 0.0 && n < 0)
      _awe_error(l, "Exponent operator division by zero: 0 ** %d", n);
  else if (n == 0)
      return 1.0;
  else if (n >= 0)
    return rpwr_loop(x, n);
  else
    return 1.0 / rpwr_loop(x, -n);
}
  

static
_Complex double 
cpwr_loop (_Complex double x, int n)
{
  _Complex double result = 1.0;
  while (n) {
    if (n & 1) {
      result *= x;
      n -= 1;
    }
    x *= x;
    n /= 2;
  }
  return result;
}


 _Complex double
_awe_cpwr (_awe_loc l, _Complex double x, int n)
{
  if (x == 0.0 && n < 0)
      _awe_error(l, "Exponent operator division by zero: 0 ** %d", n);
  else if (n == 0)
      return 1.0;
  else if (n >= 0)
    return cpwr_loop(x, n);
  else
    return 1.0 / cpwr_loop(x, -n);
}
  

/* end */
