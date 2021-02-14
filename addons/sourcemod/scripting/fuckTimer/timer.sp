#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <intmap>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>
#include <fuckTimer_timer>

enum struct PlayerData
{
    bool SetSpeed;

    float MainTime;
    float BonusTime;

    IntMap Stage;
    IntMap Checkpoint;

    void Reset()
    {
        this.SetSpeed = false;

        this.MainTime = 0.0;
        this.BonusTime = 0.0;

        delete this.Stage;
        delete this.Checkpoint;
    }
}

PlayerData Player[MAXPLAYERS + 1];

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
    Player[client].Reset();
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (IsPlayerAlive(client) && Player[client].SetSpeed)
    {
        SetClientSpeed(client);
    }
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    if (start)
    {
        Player[client].Reset();


        Player[client].SetSpeed = true;
    }
    
    if (end && bonus == 0 && Player[client].MainTime > 0.0)
    {
        PrintToChatAll("%N's time: %.3f", client, GetGameTime() - Player[client].MainTime);
        Player[client].Reset();
    }
    else if (end && bonus > 0 && Player[client].BonusTime > 0.0)
    {
        PrintToChatAll("%N's bonus time: %.3f", client, GetGameTime() - Player[client].BonusTime);
        Player[client].Reset();
    }
    else if (stage > 0)
    {
        Player[client].SetSpeed = true;

        float fBuffer = 0.0;
        Player[client].Stage.GetValue(stage, fBuffer);

        if (fBuffer > 0.0)
        {
            Player[client].Stage.SetValue(stage, 0.0);
            return;
        }

        int iPrevStage = stage - 1;

        if (iPrevStage < 1)
        {
            iPrevStage = 1;
        }

        float fStart;
        Player[client].Stage.GetValue(iPrevStage, fStart);
        
        float fTime = GetGameTime() - fStart;
        Player[client].Stage.SetValue(iPrevStage, fTime);
        PrintToChatAll("%N's time for Stage %d: %.3f", client, iPrevStage, fTime);
    }
    else if (checkpoint > 0)
    {
        float fBuffer = 0.0;
        Player[client].Checkpoint.GetValue(stage, fBuffer);

        if (fBuffer > 0.0)
        {
            Player[client].Checkpoint.SetValue(checkpoint, 0.0);
            return;
        }

        int iPrevCheckpoint = checkpoint - 1;

        if (iPrevCheckpoint < 1)
        {
            iPrevCheckpoint = 1;
        }

        float fStart;
        Player[client].Checkpoint.GetValue(iPrevCheckpoint, fStart);
        
        float fTime = GetGameTime() - fStart;
        Player[client].Checkpoint.SetValue(iPrevCheckpoint, fTime);
        PrintToChatAll("%N's time for Checkpoint %d: %.3f", client, iPrevCheckpoint, fTime);
    }
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    if (start)
    {
        Player[client].Reset();

        Player[client].SetSpeed = true;
    }
    
    if (stage > 0)
    {
        Player[client].SetSpeed = true;
    }

}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    Player[client].SetSpeed = false;

    if (start)
    {
        Player[client].Reset();

        if (bonus < 1)
        {
            Player[client].Stage = new IntMap();
            Player[client].Checkpoint = new IntMap();

            Player[client].MainTime = GetGameTime();
            Player[client].Stage.SetValue(1, GetGameTime());
            Player[client].Checkpoint.SetValue(1, GetGameTime());
        }
        else
        {
            Player[client].BonusTime = GetGameTime();
        }
    }

    if (stage > 1)
    {
        Player[client].Stage.SetValue(stage, GetGameTime());
    }

    if (checkpoint > 1)
    {
        Player[client].Checkpoint.SetValue(checkpoint, GetGameTime());
    }
}

public any Native_GetClientTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    TimeType type = GetNativeCell(2);

    int level = GetNativeCell(3);
    float fTime = 0.0;

    if (type == TimeMain)
    {
        return Player[client].MainTime;
    }
    else if (type == TimeBonus)
    {
        return Player[client].BonusTime;
    }
    else if (type == TimeCheckpoint)
    {
        if (Player[client].Checkpoint != null)
        {
            Player[client].Checkpoint.GetValue(level, fTime);
        }
        
        return fTime;
    }
    else if (type == TimeStage)
    {
        if (Player[client].Stage != null)
        {
            Player[client].Stage.GetValue(level, fTime);
        }
        
        return fTime;
    }

    return 0.0;
}
