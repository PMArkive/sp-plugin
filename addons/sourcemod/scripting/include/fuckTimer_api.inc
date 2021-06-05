#if defined _fuckTimer_api_included
    #endinput
#endif
#define _fuckTimer_api_included

#include <ripext>

#define MAX_URL_LENGTH 2048
#define FUCKTIMER_BASE_CLOUD_URL "https://fucktimer.cloud/file"

native bool fuckTimer_GetAPIUrl(char[] url);
native HTTPClient fuckTimer_NewHTTPRequest(const char[] url, int length = MAX_URL_LENGTH);

stock HTTPRequest fuckTimer_NewCloudHTTPRequest(const char[] endpoint)
{
    char sUrl[MAX_URL_LENGTH];
    FormatEx(sUrl, sizeof(sUrl), "%s/%s", FUCKTIMER_BASE_CLOUD_URL, endpoint);

    HTTPRequest request = new HTTPRequest(sUrl);

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
