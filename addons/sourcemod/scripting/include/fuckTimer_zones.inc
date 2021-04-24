#if defined _fuckTimer_zones_included
    #endinput
#endif
#define _fuckTimer_zones_included

enum struct ZoneDetails
{
    bool Start;
    bool Misc;
    bool End;

    int Bonus;

    IntMap Checkpoints;
    IntMap Stages;
    IntMap Validators;

    void Init()
    {
        this.Checkpoints = new IntMap();
        this.Stages = new IntMap();
        this.Validators = new IntMap();
    }

    void Reset()
    {
        delete this.Checkpoints;
        delete this.Stages;
        delete this.Validators;
    }
}

forward void fuckTimer_OnEnteringZone(int client, int zone, const char[] name);
forward void fuckTimer_OnTouchZone(int client, int zone, const char[] name);
forward void fuckTimer_OnLeavingZone(int client, int zone, const char[] name);

/**
 * Level starts from 0 as main path, level 1 and higher is the bonus level
 *
 * @return     Entity Index or -1 for invalid index
 */
native int fuckTimer_GetStartZone(int bonus);

/**
 * Level starts from 0 as main path, level 1 and higher is the bonus level
 *
 * @return     Entity Index or -1 for invalid index
 */
native int fuckTimer_GetEndZone(int bonus);

/**
 * Bonus will be set, if return is true
 */

native bool fuckTimer_IsStartZone(int zone, int bonus);

/**
 * Bonus will be set, if return is true
 */

native bool fuckTimer_IsEndZone(int zone, int bonus);

/**
 * Returns the bonus level of the specific zone.
 *
 * @return     0 as return is the main path, otherwise it's the bonus level
 */
native int fuckTimer_GetZoneBonus(int zone);

native int fuckTimer_GetCheckpointZone(int bonus, int checkpoint);
native int fuckTimer_GetStageZone(int bonus, int stage);

/**
 * Paramter bonus and checkpoint will be set.
 *
 * @return     Return description
 */
native bool fuckTimer_GetCheckpointByIndex(int zone, int bonus, int checkpoint);

/**
 * Paramter bonus and stage will be set.
 *
 * @return     Return description
 */
native bool fuckTimer_GetStageByIndex(int zone, int bonus, int stage);

native int fuckTimer_GetValidatorCount(int bonus, int stage = 0);


#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_zones_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetStartZone");
    MarkNativeAsOptional("fuckTimer_GetEndZone");

    MarkNativeAsOptional("fuckTimer_IsStartZone");
    MarkNativeAsOptional("fuckTimer_IsEndZone");

    MarkNativeAsOptional("fuckTimer_GetZoneBonus");

    MarkNativeAsOptional("fuckTimer_GetCheckpointZone");
    MarkNativeAsOptional("fuckTimer_GetStageZone");

    MarkNativeAsOptional("fuckTimer_GetCheckpointByIndex");
    MarkNativeAsOptional("fuckTimer_GetStageByIndex");

    MarkNativeAsOptional("fuckTimer_GetValidatorCount");
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
