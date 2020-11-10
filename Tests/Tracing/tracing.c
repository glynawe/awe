#include <awe.h>

int nesting = 0;

void _awe_trace_procedure_called (_awe_loc call_loc, const char *procedure_name)
{
    _awe_warning(call_loc, "%*s--> %s", nesting, "", procedure_name);
    nesting += 4;
}

void _awe_trace_procedure_entered (_awe_loc procedure_loc, const char *procedure_name)
{
    _awe_warning(procedure_loc, "%*s%s", nesting, "", procedure_name);
}

void _awe_trace_procedure_exited (_awe_loc call_loc, const char *procedure_name)
{
    nesting -= 4;
    _awe_warning(call_loc, "%*s<-- %s", nesting, "", procedure_name);
}
