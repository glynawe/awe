#include <stdio.h>
#include <awe.h>

#include "program.awe.h"

void Test (int v, int *r, int *vr, int *(*n)(void), int *a(_awe_loc, int))
{
    int j;

    printf("v = %d\n", v);
    printf("vr = %d\n", *vr);
    printf("n = %d\n", *n());  /* fetch Name parameter */
    for (j = 1; j <= 3; ++j) printf("a(%d) = %d\n", j, *a(_awe_HERE,j));

    v++;
    ++(*vr);
    ++(*n());  /* increment Name parameter */
    *r = 41;
    for (j = 1; j <= 3; ++j) ++(*a(_awe_HERE,j));

    printf("v = %d\n", v);
    printf("vr = %d\n", *vr);
    printf("n = %d\n", *n());  /* fetch Name parameter again */
    for (j = 1; j <= 3; ++j) printf("a(%d) = %d\n", j, *a(_awe_HERE,j));
}
