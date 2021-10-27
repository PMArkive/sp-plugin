#if defined _fuckTimer_zones_included
    #endinput
#endif
#define _fuckTimer_zones_included

#include <intmap>

enum struct ZoneDetails
{
    bool Start;
    bool End;
    bool Misc;
    bool Validator;
    bool TeleToStart;
    bool Stop;
    bool AntiJump;
    bool Checker;

    int Bonus;
    int Validators;

    int Checkpoint;
    int Stage;

    int PreSpeed;

    char MapAuthor[MAX_NAME_LENGTH];
    char ZoneAuthor[MAX_NAME_LENGTH];

    float TeleportOrigin[3];
    float TeleportAngles[3];

    void Reset()
    {
        this.Start = false;
        this.End = false;
        this.Misc = false;
        this.Validator = false;
        this.TeleToStart = false;
        this.Stop = false;
        this.AntiJump = false;
        this.Checker = false;

        this.Bonus = 0;
        this.Validators = 0;
        this.Checkpoint = 0;
        this.Stage = 0;

        this.PreSpeed = 0;

        this.MapAuthor[0] = '\0';
        this.ZoneAuthor[0] = '\0';

        this.TeleportOrigin = {0.0, 0.0, 0.0};
        this.TeleportAngles = {0.0, 0.0, 0.0};
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
native bool fuckTimer_IsStartZone(int zone, int &bonus);

/**
 * Bonus will be set, if return is true
 */
native bool fuckTimer_IsEndZone(int zone, int &bonus);

/**
 * Bonus will be set, if return is true
 */
native bool fuckTimer_IsMiscZone(int zone, int &bonus);

/**
 * Bonus will be set, if return is true
 */
native bool fuckTimer_IsValidatorZone(int zone, int &bonus);

/**
 * Bonus will be set, if return is true
 */
native bool fuckTimer_IsTeleToStartZone(int zone, int &bonus);

/**
 * Bonus will be set, if return is true
 */
native bool fuckTimer_IsStopZone(int zone, int &bonus);

/**
 * Bonus will be set, if return is true
 */
native bool fuckTimer_IsAntiJumpZone(int zone, int &bonus);

/**
 * Bonus and validators will be set, if return is true
 */
native bool fuckTimer_IsCheckerZone(int zone, int &bonus, int &validators);

/**
 * Returns the bonus level of the specific zone.
 *
 * @return     0 as return is the main path, otherwise it's the bonus level
 */
native int fuckTimer_GetZoneBonus(int zone);

native int fuckTimer_GetCheckpointZone(int bonus, int checkpoint);
native int fuckTimer_GetZoneCheckpoint(int entity, int bonus);
native int fuckTimer_GetStageZone(int bonus, int stage);
native int fuckTimer_GetZoneStage(int entity, int bonus);

/**
 * Paramter bonus will be set.
 */
native int fuckTimer_GetCheckpointByIndex(int zone, int &bonus);

/**
 * Paramter bonus will be set.
 */
native int fuckTimer_GetStageByIndex(int zone, int &bonus);
native int fuckTimer_GetZonePreSpeed(int zone);
native int fuckTimer_GetMaxVelocity(int zone);
native void fuckTimer_GetZoneMapAuthor(int zone, char[] author, int maxlen);
native void fuckTimer_GetZoneZoneAuthor(int zone, char[] author, int maxlen);
native bool fuckTimer_GetZoneTeleportCoords(int zone, float origin[3], float angles[3]);
native void fuckTimer_TeleportEntityToZone(int client, int zone);

stock bool GetfuckTimerZoneValue(StringMap effects, const char[] key, char[] value, int length)
{
    StringMap smValues;
    effects.GetValue(FUCKTIMER_EFFECT_NAME, smValues);

    char sKey[MAX_KEY_NAME_LENGTH];
    StringMapSnapshot keys = smValues.Snapshot();

    for (int x = 0; x < keys.Length; x++)
    {
        keys.GetKey(x, sKey, sizeof(sKey));

        if (StrEqual(sKey, key, false))
        {
            smValues.GetString(sKey, value, length);

            delete keys;
            return true;
        }
    }

    delete keys;
    return false;
}

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_zones_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetStartZone");
    MarkNativeAsOptional("fuckTimer_GetEndZone");

    MarkNativeAsOptional("fuckTimer_IsStartZone");
    MarkNativeAsOptional("fuckTimer_IsEndZone");
    MarkNativeAsOptional("fuckTimer_IsMiscZone");
    MarkNativeAsOptional("fuckTimer_IsValidatorZone");
    MarkNativeAsOptional("fuckTimer_IsTeleToStartZone");
    MarkNativeAsOptional("fuckTimer_IsStopZone");
    MarkNativeAsOptional("fuckTimer_IsAntiJumpZone");

    MarkNativeAsOptional("fuckTimer_GetZoneBonus");

    MarkNativeAsOptional("fuckTimer_GetCheckpointZone");
    MarkNativeAsOptional("fuckTimer_GetZoneCheckpoint");
    MarkNativeAsOptional("fuckTimer_GetStageZone");
    MarkNativeAsOptional("fuckTimer_GetZoneStage");

    MarkNativeAsOptional("fuckTimer_GetCheckpointByIndex");
    MarkNativeAsOptional("fuckTimer_GetStageByIndex");

    MarkNativeAsOptional("fuckTimer_GetZonePreSpeed");
    MarkNativeAsOptional("fuckTimer_GetMaxVelocity");

    MarkNativeAsOptional("fuckTimer_GetZoneMapAuthor");
    MarkNativeAsOptional("fuckTimer_GetZoneZoneAuthor");

    MarkNativeAsOptional("fuckTimer_GetZoneTeleportCoords");
    MarkNativeAsOptional("fuckTimer_TeleportEntityToZone");
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
