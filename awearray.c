/* awearray.c -- Algol W runtime library: array descriptors.

--

This file is part of Awe. Copyright 2019 Glyn Webster.

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

#include "awe.h"  /* See the "Arrays." section for the documentation */

#include <assert.h>

void
_awe_array_initialize ( _awe_loc loc,
                        _awe_array_t *array,
                        int ndimensions,
                        _awe_array_bound_t *bounds,
                        long *multipliers,
                        long element_size )
{
    array->ndimensions  = ndimensions;
    array->bounds = bounds;
    array->multipliers = multipliers;
    array->element_size = element_size;

    /* check bounds, calculate number of elements in the array */
    array->nelements = 1; /* at least one */
    if (array->ndimensions < 1)
        _awe_error(loc, "array dimension error: %d dimensions", array->ndimensions);
    for (int i = 0; i < array->ndimensions; ++i) {
        const int lwb = array->bounds[i].lower, upb = array->bounds[i].upper;
        const int width = upb - lwb + 1;
        if (width < 0)  /* dimensions 0 elements wide are allowed ("empty arrays", see awe.txt) */
            _awe_error(loc, "array dimension error: dimension %d is (%d::%d)", i + 1, lwb, upb);
        else
            array->nelements *= width;
    }

    /* subscript multipliers for each dimension (in bytes) */
    array->multipliers[array->ndimensions - 1] = array->element_size;
    for (int i = array->ndimensions - 2; i >= 0; --i) {
        int width = array->bounds[i+1].upper - array->bounds[i+1].lower + 1;
        array->multipliers[i] = array->multipliers[i+1] * width;
    }

    /* sum of offsets for each dimension (in bytes) */
    long z = 0;
    for (int i = 0; i < array->ndimensions; ++i) {
        z += array->bounds[i].lower * array->multipliers[i];
    }
    array->total_offset = z;
}


void
_awe_subarray_initialize ( _awe_loc loc,
                           const _awe_array_t *array,
                           _awe_array_t *subarray,
                           int subarray_ndimensions,
                           const _awe_array_slicer_t *slicers,
                           _awe_array_bound_t *bounds,
                           long *multipliers )
{
    /* the subarray shares the array's data */
    subarray->element_data = array->element_data;
    subarray->element_size = array->element_size;
    subarray->bounds = bounds;
    subarray->multipliers = multipliers;

    /* make the subarray subscripts part of the total offset */
    subarray->total_offset = array->total_offset;
    for (int i = 0; i < array->ndimensions; ++i) {
        if (slicers[i].slice) {
            const int sub = slicers[i].subscript;
            if (sub < array->bounds[i].lower || sub > array->bounds[i].upper)
                _awe_error(loc, "array subarray subscript error: subscript %d = %d, outside the range (%d::%d)",
                           i + 1, sub, array->bounds[i].lower, array->bounds[i].upper);

            subarray->total_offset -= sub * array->multipliers[i];
        }
    }

    /* remove the sliced away dimensions */
    int n = 0;
    for (int i = 0; i < array->ndimensions; ++i) {
        if (!slicers[i].slice) {
            subarray->multipliers[n] = array->multipliers[i];
            subarray->bounds[n].lower = array->bounds[i].lower;
            subarray->bounds[n].upper = array->bounds[i].upper;
            ++n;
        }
    }
    subarray->ndimensions = n;
}


void *
_awe_array_element_pointer ( _awe_loc loc,
                             const _awe_array_t *array,
                             const int *subscripts )
{
    long offset = -array->total_offset;
    for (int i = 0; i < array->ndimensions; ++i) {

        if (subscripts[i] < array->bounds[i].lower || subscripts[i] > array->bounds[i].upper)
            _awe_error(loc, "array subscript error: subscript %d = %d, outside the range (%d::%d)",
                       i + 1, subscripts[i], array->bounds[i].lower, array->bounds[i].upper);

        offset += subscripts[i] * array->multipliers[i];
    }
    return (char*)(array->element_data) + offset;
}


/* end */
