#if defined _fuckTimer_stocks_included
    #endinput
#endif
#define _fuckTimer_stocks_included

#include <autoexecconfig>
#include <sdktools>

#define FUCKTIMER_PLUGIN_NAME "fuckTimer - "
#define FUCKTIMER_PLUGIN_AUTHOR "fuckTimer Contributors"
#define FUCKTIMER_PLUGIN_DESCRIPTION ""
#define FUCKTIMER_PLUGIN_VERSION "1.0.0-devvvvvvvvvvvvvvvv"
#define FUCKTIMER_PLUGIN_URL "github.com/fuckTimer"

#define FUCKTIMER_BASE_CLOUD_URL "https://fucktimer.cloud/file"

#define FUCKTIMER_EFFECT_NAME "fuckTimer"

#define MAX_URL_LENGTH 256
#define MIN_BASE_URL_LENGTH 4
#define MIN_API_KEY_LENGTH 12
#define PRESPEED_LIMIT 250

#define fuckTimer_LoopClients(%1,%2,%3) for(int %1 = 1; %1 <= MaxClients; %1++) if(fuckTimer_IsClientValid(%1, %2, %3))

stock void fuckTimer_StartConfig(char[] file, char[] directory = "fuckTimer")
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile(file, directory);
}

stock void fuckTimer_EndConfig()
{
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

stock void fuckTimer_GetCurrentWorkshopMap(char[] sMap, int iMapSize)
{
    GetCurrentMap(sMap, iMapSize);
    ReplaceString(sMap, iMapSize, "/", "-", false);
}

stock bool fuckTimer_IsClientValid(int client, bool bots = false, bool sourcetv = false)
{
    if (client > 0 && client <= MaxClients)
    {
        if (!IsClientInGame(client))
        {
            return false;
        }

        if (bots && IsFakeClient(client))
        {
            return false;
        }

        if (sourcetv && IsClientSourceTV(client))
        {
            return false;
        }

        return true;
    }
    return false;
}

stock float GetClientSpeed(int client)
{
    float fVelocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
    return SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
}

stock void SetClientSpeed(int client)
{
    float fVelocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);

    float fSpeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));

    if (fSpeed > PRESPEED_LIMIT)
    {
        // https://github.com/shavitush/bhoptimer/blob/master/addons/sourcemod/scripting/shavit-core.sp#L3426
        float fScale = PRESPEED_LIMIT / fSpeed;

        if (fScale < 1.0)
        {
            ScaleVector(fVelocity, fScale);
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
        }
    }
}

stock void GetTimeBySeconds(float seconds, char[] time, int length)
{
    if (seconds < 60.0)
    {
        FormatEx(time, length, "%.3f", seconds);
    }
    else if (seconds < 3600.0)
    {
        int iBuffer = RoundToFloor(seconds);
        int iMinutes = (iBuffer / 60) % 60;
        float fSeconds = (iBuffer % 60) + seconds - iBuffer;
        FormatEx(time, length, "%d:%.3f", iMinutes, fSeconds);
    }
    else
    {
        int iBuffer = RoundToFloor(seconds);

        int iHours = RoundToFloor(iBuffer / 3600.0);
        int iMinutes = (iBuffer / 60) % 60;
        float fSeconds = (iBuffer % 60) + seconds - iBuffer;

        FormatEx(time, length, "%d:%d:%.3f", iHours, iMinutes, fSeconds);
    }
}

stock bool GetZoneValue(StringMap values, const char[] key, char[] value, int length)
{
    char sKey[MAX_KEY_NAME_LENGTH];
    StringMapSnapshot keys = values.Snapshot();

    for (int x = 0; x < keys.Length; x++)
    {
        keys.GetKey(x, sKey, sizeof(sKey));

        if (StrEqual(sKey, key, false))
        {
            values.GetString(sKey, value, length);

            delete keys;
            return true;
        }
    }

    delete keys;
    return false;
}

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
