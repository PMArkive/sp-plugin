#if defined _fuckTimer_timer_included
    #endinput
#endif
#define _fuckTimer_timer_included

enum TimeType
{
    TimeMain = 0,
    TimeCheckpoint,
    TimeStage,
    TimeBonus
};

native float fuckTimer_GetClientTime(int client, TimeType type, int level = 0);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_timer_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetClientTime");
}
#endif

public SharedPlugin __pl_fuckTimer_timer = 
{
    name = "fuckTimer_timer",
    file = "timer.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
