#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <intmap>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>
#include <fuckTimer_timer>

enum struct PlayerTimes
{
    float MainTime;
    float BonusTime;

    IntMap Stage;
    IntMap Checkpoint;

    float Cooldown;

    void Reset()
    {
        this.MainTime = 0.0;
        this.BonusTime = 0.0;

        delete this.Stage;
        delete this.Checkpoint;
    }
}

PlayerTimes Times[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Timer",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("fuckTimer_GetClientTime", Native_GetClientTime);

    RegPluginLibrary("fuckTimer_timer");

    return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
    Times[client].Reset();
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    PrintToChat(client, "fuckTimer_OnEnteringZone, Zone: %s (%d), Start: %d, End: %d, Stage: %d, Checkpoint: %d", name, zone, start, end, stage, checkpoint);

    if (start)
    {
        Times[client].Reset();
    }
    
    if (end && bonus == 0 && Times[client].MainTime > 0.0)
    {
        PrintToChatAll("%N's time: %.3f", client, GetGameTime() - Times[client].MainTime); // TODO: for testing
        Times[client].Reset();
    }
    else if (end && bonus > 0 && Times[client].BonusTime > 0.0)
    {
        PrintToChatAll("%N's bonus time: %.3f", client, GetGameTime() - Times[client].BonusTime); // TODO: for testing
        Times[client].Reset();
    }
    else if (stage > 0)
    {
        int iPrevStage = stage - 1;

        if (iPrevStage < 1)
        {
            iPrevStage = 1;
        }

        float fStart;
        Times[client].Stage.GetValue(iPrevStage, fStart);
        
        float fTime = GetGameTime() - fStart;
        Times[client].Stage.SetValue(iPrevStage, fTime);
        PrintToChatAll("%N's time for Stage %d: %.3f", client, iPrevStage, fTime);
        Times[client].Stage.SetValue(stage, GetGameTime());
    }
    else if (checkpoint > 0)
    {
        int iPrevCheckpoint = checkpoint - 1;

        if (iPrevCheckpoint < 1)
        {
            iPrevCheckpoint = 1;
        }

        float fStart;
        Times[client].Checkpoint.GetValue(iPrevCheckpoint, fStart);
        
        float fTime = GetGameTime() - fStart;
        Times[client].Checkpoint.SetValue(iPrevCheckpoint, fTime);
        PrintToChatAll("%N's time for Checkpoint %d: %.3f", client, iPrevCheckpoint, fTime);
        Times[client].Checkpoint.SetValue(checkpoint, GetGameTime());
    }
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    if (Times[client].Cooldown < 1.0 || GetGameTime() - Times[client].Cooldown > 1.0)
    {
        PrintToChat(client, "fuckTimer_OnTouchZone, Zone: %s (%d), Start: %d, End: %d, Stage: %d, Checkpoint: %d", name, zone, start, end, stage, checkpoint);

        Times[client].Cooldown = GetGameTime();
    }

    if (start)
    {
        Times[client].Reset();
    }
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    PrintToChat(client, "fuckTimer_OnLeavingZone, Zone: %s (%d), Start: %d, End: %d, Stage: %d, Checkpoint: %d", name, zone, start, end, stage, checkpoint);

    if (start)
    {
        Times[client].Reset();

        if (bonus < 1)
        {
            Times[client].Stage = new IntMap();
            Times[client].Checkpoint = new IntMap();

            Times[client].MainTime = GetGameTime();
            Times[client].Stage.SetValue(1, GetGameTime());
            Times[client].Checkpoint.SetValue(1, GetGameTime());
        }
        else
        {
            Times[client].BonusTime = GetGameTime();
        }
    }
}

public any Native_GetClientTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    TimeType type = GetNativeCell(2);

    if (type == TimeMain)
    {
        return Times[client].MainTime;
    }
    else if (type == TimeBonus)
    {
        return Times[client].BonusTime;
    }

    return 0.0;
}
