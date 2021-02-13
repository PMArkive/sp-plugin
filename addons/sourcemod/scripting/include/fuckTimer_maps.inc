#if defined _fuckTimer_maps_included
    #endinput
#endif
#define _fuckTimer_maps_included

native int fuckTimer_GetMapTier();

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_maps_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetMapTier");
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
