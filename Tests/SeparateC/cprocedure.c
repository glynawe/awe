#include <stdio.h>
#include <awe.h>

#include "program.awe.h"

void Test (int v, int *r, int *vr, int *(*n)(void), _awe_array_t *a)
{
    #define N    *n()                                    /* Name parameter */
    #define A(j) *_awe_array_SUB(_awe_HERE, int, a, (j)) /* array parameter */

    int j;

    printf("v = %d\n", v);
    printf("vr = %d\n", *vr);
    printf("n = %d\n", N);
    for (j = 1; j <= 3; ++j) printf("a(%d) = %d\n", j, A(j));

    v++;
    ++(*vr);
    ++N;  /* increment Name parameter */
    *r = 41;
    for (j = 1; j <= 3; ++j) ++A(j);

    printf("v = %d\n", v);
    printf("vr = %d\n", *vr);
    printf("n = %d\n", N);  /* fetch Name parameter again */
    for (j = 1; j <= 3; ++j) printf("a(%d) = %d\n", j, A(j));

    #undef A
    #undef N
}
