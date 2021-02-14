#if defined _fuckTimer_zones_included
    #endinput
#endif
#define _fuckTimer_zones_included

#define FUCKTIMER_EFFECT_NAME "fuckTimer"

forward void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus);
forward void fuckTimer_OnTouchZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus);
forward void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_zones_SetNTVOptional()
{
    // MarkNativeAsOptional("<NativeName>");
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
