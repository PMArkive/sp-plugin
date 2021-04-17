#if defined _fuckTimer_maps_included
    #endinput
#endif
#define _fuckTimer_maps_included

typedef fuckTimer_OnGetMapTier = function void (int client, StringMap maps);


native int fuckTimer_GetCurrentMapTier();

/*
 *   StringMap must be closed/freed with delete (or CloseHandle) in callback.
 */
native void fuckTimer_GetMapTiers(int client = 0, const char[] name, fuckTimer_OnGetMapTier callback);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_maps_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetCurrentMapTier");
    MarkNativeAsOptional("fuckTimer_GetMapTiers");
}
#endif

public SharedPlugin __pl_fuckTimer_maps = 
{
    name = "fuckTimer_maps",
    file = "maps.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
