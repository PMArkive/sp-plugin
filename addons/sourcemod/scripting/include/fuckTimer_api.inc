#if defined _fuckTimer_api_included
    #endinput
#endif
#define _fuckTimer_api_included

#include <ripext>

#define MAX_URL_LENGTH 2048
#define FUCKTIMER_BASE_CLOUD_URL "https://raw.githubusercontent.com/fuckTimer"

/**
 * @return        SP_ERROR_NONE on success, any other integer on failure.
 */
native int fuckTimer_GetAPIUrl(char[] url);
native HTTPRequest fuckTimer_NewHTTPRequest(const char[] url, int length = MAX_URL_LENGTH);

stock HTTPRequest fuckTimer_NewCloudHTTPRequest(const char[] endpoint)
{
    char sUrl[MAX_URL_LENGTH];
    FormatEx(sUrl, sizeof(sUrl), "%s/%s", FUCKTIMER_BASE_CLOUD_URL, endpoint);

    HTTPRequest request = new HTTPRequest(sUrl);

    return request;
}

stock HTTPRequest fuckTimer_NewAPIHTTPRequest(const char[] endpoint)
{
    char sBase[1024];
    fuckTimer_GetAPIUrl(sBase);

    char sUrl[MAX_URL_LENGTH];
    FormatEx(sUrl, sizeof(sUrl), "%s/%s", sBase, endpoint);

    HTTPRequest request = fuckTimer_NewHTTPRequest(sUrl);

    return request;
}


#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_api_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetAPIUrl");
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
