#if defined _fT_core_included
    #endinput
#endif
#define _fT_core_included

native bool fT_GetBaseURL(char[] url, int length);
native bool fT_GetAPIKey(char[] key, int length);

#if !defined REQUIRE_PLUGIN
public void __pl_fT_core_SetNTVOptional()
{
    MarkNativeAsOptional("fT_GetBaseURL");
    MarkNativeAsOptional("fT_GetAPIKey");
}
#endif

public SharedPlugin __pl_fT_core = 
{
    name = "fT_core",
    file = "core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
