/* aweexcept.c -- the "Exceptional Condition" variables 
                     and their predefined record class 'EXCEPTION', See section 8.5.

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


void *divzero;
void *intdivzero;
void *sqrterr;
void *experr;
void *lnlogerr;
void *sincoserr;
void *endfile;


struct exception {     /* This is a RECORD structure. */
  const char *_class;
  int _number;
  int xcpnoted;
  int xcplimit;
  int xcpaction;
  int xcpmark;
  unsigned char xcpmsg[64];
};


const char * const _awe_class_0_exception = "exception";

void *
exception ( _awe_loc loc, 
            int xcpnoted,
            int xcplimit,
            int xcpaction,
            int xcpmark,
            _awe_str xcpmsg )
{
  struct exception *ref = (struct exception *)_awe_allocate_record(loc, sizeof(struct exception));
  ref->_class = _awe_class_0_exception;
  ref->_number = _awe_record_counter++;
  ref->xcpnoted = xcpnoted;
  ref->xcplimit = xcplimit;
  ref->xcpaction = xcpaction;
  ref->xcpmark = xcpmark;
  _awe_str_cpy(ref->xcpmsg, 64, xcpmsg, 64);
  return (void *)ref;
}

int *
xcpnoted (_awe_loc loc, void *ref) 
{
  _awe_ref_field_check(loc, ref, _awe_class_0_exception, "xcpnoted");
  return &((struct exception *)ref)->xcpnoted;
}


int *
xcplimit (_awe_loc loc, void *ref)
{
  _awe_ref_field_check(loc, ref, _awe_class_0_exception, "xcplimit");
  return &((struct exception *)ref)->xcplimit;
}


int *
xcpaction (_awe_loc loc, void *ref) 
{
  _awe_ref_field_check(loc, ref, _awe_class_0_exception, "xcpaction");
  return &((struct exception *)ref)->xcpaction;
}


int *
xcpmark (_awe_loc loc, void *ref) 
{
  _awe_ref_field_check(loc, ref, _awe_class_0_exception, "xcpmark");
  return &((struct exception *)ref)->xcpmark;
}


_awe_str
xcpmsg (_awe_loc loc, void *ref) 
{
  _awe_ref_field_check(loc, ref, _awe_class_0_exception, "xcpmsg");
  return ((struct exception *)ref)->xcpmsg;
}


void
_awe_process_exception (_awe_loc loc, void *condition)
{
  if (condition) {
    *xcpnoted(loc, condition) = 1;
    (*xcplimit(loc, condition))--;
    if (*xcplimit(loc, condition) < 0 || *xcpmark(loc, condition)) {
      unsigned char msg[65];
      _awe_str_cpy(msg, 64, xcpmsg(loc, condition), 64); msg[64] = '\0';
      _awe_warning(loc, msg);
    }
    if (*xcplimit(loc, condition) < 0) {
      _awe_finalize(loc);
      exit(EXIT_FAILURE);
    }
  }
}


void
_awe_init_exceptions (_awe_loc loc)
{
  _awe_record_counter = -8; /* Predeclared records will have negative record numbers. */
  divzero    = exception(loc, 0, 0, 0, 1, "Floating-point division by zero.                                ");
  intdivzero = exception(loc, 0, 0, 0, 1, "Integer division by zero.                                       ");
  sqrterr    = exception(loc, 0, 0, 0, 1, "Negative argument for SQRT or LONGSQRT.                         ");
  experr     = exception(loc, 0, 0, 0, 1, "Argument of EXP or LONGEXP out of domain.                       ");
  lnlogerr   = exception(loc, 0, 0, 0, 1, "Argument of LN, LOG, LONGLN or LONGLOG out of domain.           ");
  sincoserr  = exception(loc, 0, 0, 0, 1, "Argument of SIN, COS, LONGSIN or LONGCOS out of domain.         ");
  endfile    = exception(loc, 0, 0, 0, 1, "Unexpected end of input.                                        ");
  _awe_record_counter = 0;
}


/* end */
