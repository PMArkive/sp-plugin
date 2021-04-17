#if defined _fuckTimer_zones_included
    #endinput
#endif
#define _fuckTimer_zones_included

enum eZone
{
    ZoneNone,
    ZoneStart = 0,
    ZoneEnd,
    ZoneCheckpoint,
    ZoneStage,
    ZoneBonus
}

forward void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus);
forward void fuckTimer_OnTouchZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus);
forward void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus);

native int fuckTimer_GetStartZone();
native int fuckTimer_GetEndZone();
native int fuckTimer_GetCheckpointZone(int level);
native int fuckTimer_GetStageZone(int level);
native int fuckTimer_GetBonusZone(int level);
native int fuckTimer_GetValidatorCount(int level);
native bool fuckTimer_IsNormalCheckpointZone(int zone);
native bool fuckTimer_IsNormalStageZone(int zone);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_zones_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetStartZone");
    MarkNativeAsOptional("fuckTimer_GetEndZone");
    MarkNativeAsOptional("fuckTimer_GetCheckpointZone");
    MarkNativeAsOptional("fuckTimer_GetStageZone");
    MarkNativeAsOptional("fuckTimer_GetBonusZone");
    MarkNativeAsOptional("fuckTimer_GetValidatorCount");
    MarkNativeAsOptional("fuckTimer_IsNormalCheckpointZone");
    MarkNativeAsOptional("fuckTimer_IsNormalStageZone");
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
