#if defined _fuckTimer_core_included
    #endinput
#endif
#define _fuckTimer_core_included

native bool fuckTimer_GetBaseURL(char[] url, int length);
native bool fuckTimer_GetAPIKey(char[] key, int length);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_core_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetBaseURL");
    MarkNativeAsOptional("fuckTimer_GetAPIKey");
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
