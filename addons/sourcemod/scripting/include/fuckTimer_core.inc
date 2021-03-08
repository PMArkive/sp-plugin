#if defined _fuckTimer_core_included
    #endinput
#endif
#define _fuckTimer_core_included

#include <ripext>

forward void fuckTimer_OnAPIReady();

native HTTPClient fuckTimer_GetHTTPClient();

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_core_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetHTTPClient");
}
#endif

public SharedPlugin __pl_fuckTimer_core = 
{
    name = "fuckTimer_core",
    file = "core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
