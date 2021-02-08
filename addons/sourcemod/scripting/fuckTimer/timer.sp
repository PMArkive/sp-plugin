#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <intmap>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>

enum struct PlayerTimes
{
    float Main;
    IntMap Stage;
    IntMap Checkpoint;

    void Reset()
    {
        this.Main = -1.0;

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

public void OnClientPutInServer(int client)
{
    Times[client].Reset();
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint)
{
    PrintToChat(client, "fuckTimer_OnEnteringZone, Zone: %s (%d), Start: %d, End: %d, Stage: %d, Checkpoint: %d", name, zone, start, end, stage, checkpoint);

    if (start)
    {
        Times[client].Reset();
    }
    else if (end && Times[client].Main > 0)
    {
        PrintToChatAll("%N's time: %.4f", client, GetGameTime() - Times[client].Main); // TODO: for testing
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
        PrintToChatAll("%N's time for Stage %d: %.4f", client, iPrevStage, fTime);
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
        PrintToChatAll("%N's time for Checkpoint %d: %.4f", client, iPrevCheckpoint, fTime);
        Times[client].Checkpoint.SetValue(checkpoint, GetGameTime());
    }
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint)
{
    PrintToChat(client, "fuckTimer_OnLeavingZone, Zone: %s (%d), Start: %d, End: %d, Stage: %d, Checkpoint: %d", name, zone, start, end, stage, checkpoint);

    if (start)
    {
        Times[client].Reset();

        Times[client].Stage = new IntMap();
        Times[client].Checkpoint = new IntMap();

        Times[client].Main = GetGameTime();
        Times[client].Stage.SetValue(1, GetGameTime());
        Times[client].Checkpoint.SetValue(1, GetGameTime());
    }
}
