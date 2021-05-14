#if defined _fuckTimer_timer_included
    #endinput
#endif
#define _fuckTimer_timer_included

enum TimeType
{
    TimeMain = 0,
    TimeCheckpoint,
    TimeStage
};

/**
 * We use TimeType here to keep forward parameters amount lower and we don't really need another enum here.
 */
forward void fuckTimer_OnClientTimerStart(int client, int bonus, TimeType type);
forward void fuckTimer_OnClientZoneTouchStart(int client, bool stop, TimeType type, int level, float time);
forward void fuckTimer_OnClientZoneTouchEnd(int client, TimeType type, int level);
forward void fuckTimer_OnClientTimerEnd(int client, int bonus, float time, TimeType type, IntMap times);

/**
 * For TimeMain is the level parameter useless, it just return the current running time.
 *
 */
native float fuckTimer_GetClientTime(int client, TimeType type, int level = 0);
native bool fuckTimer_IsClientTimeRunning(int client);

native int fuckTimer_GetClientCheckpoint(int client);
native int fuckTimer_GetClientStage(int client);
native int fuckTimer_GetClientBonus(int client);

native int fuckTimer_GetClientValidator(int client);

/*
 * Bonus 0 is the normal path, all above 0 is the bonus level
 */
native int fuckTimer_GetAmountOfCheckpoints(int bonus = 0);

/*
 * Bonus 0 is the normal path, all above 0 is the bonus level
 */
native int fuckTimer_GetAmountOfStages(int bonus = 0);
native int fuckTimer_GetAmountOfBonus();

native int fuckTimer_ResetClientTimer(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_timer_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetClientTime");
    MarkNativeAsOptional("fuckTimer_IsClientTimeRunning");

    MarkNativeAsOptional("fuckTimer_GetClientCheckpoint");
    MarkNativeAsOptional("fuckTimer_GetClientStage");
    MarkNativeAsOptional("fuckTimer_GetClientBonus");

    MarkNativeAsOptional("fuckTimer_GetClientValidator");

    MarkNativeAsOptional("fuckTimer_GetAmountOfCheckpoints");
    MarkNativeAsOptional("fuckTimer_GetAmountOfStages");
    MarkNativeAsOptional("fuckTimer_GetAmountOfBonus");

    MarkNativeAsOptional("fuckTimer_ResetClientTimer");
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
