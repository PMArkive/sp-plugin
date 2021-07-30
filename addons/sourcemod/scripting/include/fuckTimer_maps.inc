#if defined _fuckTimer_maps_included
    #endinput
#endif
#define _fuckTimer_maps_included

typedef fuckTimer_OnGetMapTier = function void (int client, StringMap maps);

forward void fuckTimer_OnZoneDownload(const char[] map, bool success);

native int fuckTimer_GetCurrentMapId();
native int fuckTimer_GetCurrentMapTier();

/*
 *   StringMap must be closed/freed with delete (or CloseHandle) in callback.
 */
native void fuckTimer_GetMapTiers(int client = 0, const char[] name, fuckTimer_OnGetMapTier callback);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_maps_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetCurrentMapId");
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
