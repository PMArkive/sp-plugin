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

native int fuckTimer_GetClientCheckpoint(int client);
native int fuckTimer_GetClientStage(int client);
native int fuckTimer_GetClientBonus(int client);

native int fuckTimer_GetAmountOfCheckpoints();
native int fuckTimer_GetAmountOfStages();
native int fuckTimer_GetAmountOfBonus();

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_timer_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetClientTime");

    MarkNativeAsOptional("fuckTimer_GetClientCheckpoint");
    MarkNativeAsOptional("fuckTimer_GetClientStage");
    MarkNativeAsOptional("fuckTimer_GetClientBonus");

    MarkNativeAsOptional("fuckTimer_GetAmountOfCheckpoints");
    MarkNativeAsOptional("fuckTimer_GetAmountOfStages");
    MarkNativeAsOptional("fuckTimer_GetAmountOfBonus");
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
