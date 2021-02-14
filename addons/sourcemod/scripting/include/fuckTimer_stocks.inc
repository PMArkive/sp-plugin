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
