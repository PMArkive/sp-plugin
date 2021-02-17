#if defined _fuckTimer_zones_included
    #endinput
#endif
#define _fuckTimer_zones_included

forward void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus);
forward void fuckTimer_OnTouchZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus);
forward void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus);

native int fuckTimer_GetStartZone();
native int fuckTimer_GetEndZone();
native int fuckTimer_GetCheckpointZone(int level);
native int fuckTimer_GetStageZone(int level);
native int fuckTimer_GetBonusZone(int level);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_zones_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetStartZone");
    MarkNativeAsOptional("fuckTimer_GetEndZone");
    MarkNativeAsOptional("fuckTimer_GetCheckpointZone");
    MarkNativeAsOptional("fuckTimer_GetStageZone");
    MarkNativeAsOptional("fuckTimer_GetBonusZone");
}
#endif

public SharedPlugin __pl_fuckTimer_zones = 
{
    name = "fuckTimer_zones",
    file = "zones.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
