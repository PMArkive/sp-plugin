#if defined _fuckTimer_api_included
    #endinput
#endif
#define _fuckTimer_api_included

#include <ripext>

native HTTPClient fuckTimer_NewHTTPRequest();
#define MAX_URL_LENGTH 2048


#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_api_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_NewHTTPRequest");
}
#endif

public SharedPlugin __pl_fuckTimer_api = 
{
    name = "fuckTimer_api",
    file = "api.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
