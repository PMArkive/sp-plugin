#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <intmap>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>
#include <fuckTimer_timer>

enum struct PlayerData
{
    int Checkpoint;
    int Stage;
    int Bonus;

    int Validator;

    bool MainRunning;
    bool CheckpointRunning;
    bool StageRunning;
    bool BonusRunning;

    bool SetSpeed;
    bool BlockJump;

    float MainTime;

    IntMap StageTimes;
    IntMap CheckpointTimes;
    IntMap BonusTimes;

    void Reset()
    {
        this.Checkpoint = 0;
        this.Stage = 0;
        this.Bonus = 0;

        this.Validator = 0;

        this.MainRunning = false;
        this.CheckpointRunning = false;
        this.StageRunning = false;
        this.BonusRunning = false;
        
        this.SetSpeed = false;
        this.BlockJump = false;

        this.MainTime = 0.0;

        delete this.StageTimes;
        delete this.CheckpointTimes;
        delete this.BonusTimes;
    }
}

PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    int Stages;
    int Checkpoints;
    int Bonus;
}
PluginData Core;

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
    CreateNative("fuckTimer_IsClientTimeRunning", Native_IsClientTimeRunning);

    CreateNative("fuckTimer_GetClientCheckpoint", Native_GetClientCheckpoint);
    CreateNative("fuckTimer_GetClientStage", Native_GetClientStage);
    CreateNative("fuckTimer_GetClientBonus", Native_GetClientBonus);
    CreateNative("fuckTimer_GetClientValidator", Native_GetClientValidator);

    CreateNative("fuckTimer_GetAmountOfCheckpoints", Native_GetAmountOfCheckpoints);
    CreateNative("fuckTimer_GetAmountOfStages", Native_GetAmountOfStages);
    CreateNative("fuckTimer_GetAmountOfBonus", Native_GetAmountOfBonus);

    CreateNative("fuckTimer_ResetClientTimer", Native_ResetClientTimer);

    RegPluginLibrary("fuckTimer_timer");

    return APLRes_Success;
}

public void OnPluginStart()
{
    fuckTimer_LoopClients(client, false, false)
    {
        OnClientPutInServer(client);
    }
}

public void OnMapStart()
{
    Core.Stages = 0;
    Core.Checkpoints = 0;
    Core.Bonus = 0;
}

public void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type)
{
    StringMap smEffects = fuckZones_GetZoneEffects(entity);

    StringMap smValues;
    smEffects.GetValue(FUCKTIMER_EFFECT_NAME, smValues);

    StringMapSnapshot snap = smValues.Snapshot();

    char sKey[MAX_KEY_NAME_LENGTH];
    char sValue[MAX_KEY_VALUE_LENGTH];
    int iStage = 0;
    int iCheckpoint = 0;
    int iBonus = 0;

    if (snap != null)
    {
        for (int i = 0; i < snap.Length; i++)
        {
            snap.GetKey(i, sKey, sizeof(sKey));

            if (StrEqual(sKey, "Stage", false))
            {
                smValues.GetString(sKey, sValue, sizeof(sValue));

                iStage = StringToInt(sValue);

                if (iStage > 0 && iStage > Core.Stages)
                {
                    Core.Stages = iStage;
                }

                iStage = 0;
            }

            if (StrEqual(sKey, "Checkpoint", false))
            {
                smValues.GetString(sKey, sValue, sizeof(sValue));

                iCheckpoint = StringToInt(sValue);

                if (iCheckpoint > 0 && iCheckpoint > Core.Checkpoints)
                {
                    Core.Checkpoints = iCheckpoint;
                }

                iCheckpoint = 0;
            }

            if (StrEqual(sKey, "Bonus", false))
            {
                smValues.GetString(sKey, sValue, sizeof(sValue));

                iBonus = StringToInt(sValue);

                if (iBonus > 0 && iBonus > Core.Bonus)
                {
                    Core.Bonus = iBonus;
                }

                iBonus = 0;
            }
        }
    }

    delete snap;
}

public void OnClientPutInServer(int client)
{
    Player[client].Reset();

    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (IsPlayerAlive(client))
    {
        if (Player[client].SetSpeed)
        {
            SetClientSpeed(client);
        }

        if (Player[client].BlockJump && buttons & IN_JUMP)
        {
            buttons &= ~IN_JUMP;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }

    if (start)
    {
        SetClientStartValues(client, bonus);

        return;
    }

    if (misc)
    {
        StringMap smEffects = fuckZones_GetZoneEffects(zone);

        char sValue[4];
        if (GetfuckTimerZoneValue(smEffects, "Stop", sValue, sizeof(sValue)))
        {
            if (view_as<bool>(StringToInt(sValue)))
            {
                Player[client].Reset();

                return;
            }
        }
        
        if (GetfuckTimerZoneValue(smEffects, "TeleToStart", sValue, sizeof(sValue)))
        {
            if (view_as<bool>(StringToInt(sValue)))
            {
                Player[client].Reset();

                int iZone = fuckTimer_GetStartZone();

                if (iZone > 0)
                {
                    fuckZones_TeleportClientToZoneIndex(client, iZone);
                }

                return;
            }
        }

        if (GetfuckTimerZoneValue(smEffects, "AntiJump", sValue, sizeof(sValue)))
        {
            if (view_as<bool>(StringToInt(sValue)))
            {
                Player[client].BlockJump = true;
            }
        }

        if (GetfuckTimerZoneValue(smEffects, "Validator", sValue, sizeof(sValue)))
        {
            if (view_as<bool>(StringToInt(sValue)))
            {
                Player[client].Validator++;
            }
        }

        if (GetfuckTimerZoneValue(smEffects, "Checker", sValue, sizeof(sValue)))
        {
            if (view_as<bool>(StringToInt(sValue)))
            {
                int iValidator = 0;

                if (Player[client].Checkpoint > 0)
                {
                    iValidator = fuckTimer_GetValidatorCount(Player[client].Checkpoint);
                }
                else if (Player[client].Stage > 0)
                {
                    iValidator = fuckTimer_GetValidatorCount(Player[client].Stage);
                }

                if (iValidator > 0 && Player[client].Validator >= iValidator)
                {
                    return;
                }

                int iZone = 0;

                if (Player[client].Stage > 1)
                {
                    iZone = fuckTimer_GetStageZone(Player[client].Stage);

                    if (iZone > 0)
                    {
                        fuckZones_TeleportClientToZoneIndex(client, iZone);
                        return;
                    }
                }
                else if (Player[client].Bonus > 0)
                {
                    iZone = fuckTimer_GetStageZone(Player[client].Bonus);

                    if (iZone > 0)
                    {
                        fuckZones_TeleportClientToZoneIndex(client, iZone);
                        return;
                    }
                }

                iZone = fuckTimer_GetStartZone();

                if (iZone > 0)
                {
                    fuckZones_TeleportClientToZoneIndex(client, iZone);
                    return;
                }
            }
        }

        return;
    }

    // Fix for missing checkpoint entry in end zone
    if (checkpoint == 0 && Player[client].Checkpoint > 0)
    {
        Player[client].Checkpoint++;
        checkpoint = Player[client].Checkpoint;
    }
    
    if (stage > 0)
    {
        Player[client].Validator = 0;
        Player[client].SetSpeed = true;

        Player[client].Stage = stage;
        Player[client].Bonus = 0;

        // That isn't really an workaround or dirty fix but... 
        // with this check we're able to start the stage timer
        // and just count the stage times. So you don't need to
        // restart the whole timer from the first stage to your
        // selected or current stage.
        if (Player[client].StageTimes == null)
        {
            Player[client].StageTimes = new IntMap();
            return;
        }

        float fBuffer = 0.0;
        Player[client].StageTimes.GetValue(stage, fBuffer);

        if (fBuffer > 0.0)
        {
            Player[client].StageTimes.SetValue(stage, 0.0);
            return;
        }

        int iPrevStage = stage - 1;

        if (iPrevStage < 1)
        {
            iPrevStage = 1;
        }

        float fStart;
        Player[client].StageTimes.GetValue(iPrevStage, fStart);
        
        float fTime = GetGameTime() - fStart;
        Player[client].StageTimes.SetValue(iPrevStage, fTime);
        PrintToChatAll("%N's time for Stage %d: %.3f", client, iPrevStage, fTime);
        Player[client].StageRunning = false;
    }
    
    if (checkpoint > 0)
    {
        Player[client].Stage = 0;
        Player[client].Bonus = 0;

        float fBuffer = 0.0;
        Player[client].CheckpointTimes.GetValue(checkpoint, fBuffer);

        if (fBuffer > 0.0)
        {
            Player[client].CheckpointTimes.SetValue(checkpoint, 0.0);
            return;
        }

        int iPrevCheckpoint = checkpoint - 1;

        if (iPrevCheckpoint < 1)
        {
            iPrevCheckpoint = 1;
        }

        float fStart;
        Player[client].CheckpointTimes.GetValue(iPrevCheckpoint, fStart);
        
        float fTime = GetGameTime() - fStart;
        Player[client].CheckpointTimes.SetValue(iPrevCheckpoint, fTime);
        PrintToChatAll("%N's time for Checkpoint %d: %.3f", client, iPrevCheckpoint, fTime);
        Player[client].CheckpointRunning = false;
    }
    
    if (end && bonus == 0 && Player[client].MainTime > 0.0)
    {
        PrintToChatAll("%N's time: %.3f", client, GetGameTime() - Player[client].MainTime);
        Player[client].MainRunning = false;

        Player[client].Reset();
    }
    
    if (end && bonus > 0)
    {
        float fBuffer = 0.0;
        Player[client].BonusTimes.GetValue(bonus, fBuffer);

        if (fBuffer > 0.0)
        {
            Player[client].BonusTimes.SetValue(bonus, 0.0);
            return;
        }

        int iPrevBonus = bonus - 1;

        if (iPrevBonus < 1)
        {
            iPrevBonus = 1;
        }

        float fStart;
        Player[client].BonusTimes.GetValue(iPrevBonus, fStart);
        
        float fTime = GetGameTime() - fStart;
        Player[client].BonusTimes.SetValue(iPrevBonus, fTime);
        PrintToChatAll("%N's time for Bonus %d: %.3f", client, iPrevBonus, fTime);
        Player[client].BonusRunning = false;

        Player[client].Reset();
    }
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    if (start)
    {
        SetClientStartValues(client, bonus);
    }
    
    if (!misc && stage > 0)
    {
        Player[client].SetSpeed = true;
    }
}

public void fuckTimer_OnClientTeleport(int client, eZone type, int level)
{
    Player[client].Reset();
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    Player[client].SetSpeed = false;
    Player[client].BlockJump = false;

    if (start)
    {
        Player[client].Reset();

        if (bonus < 1)
        {
            Player[client].MainRunning = true;
            Player[client].MainTime = 0.0;

            if (Core.Stages > 0)
            {
                Player[client].StageTimes = new IntMap();
                Player[client].Stage = 1;

                Player[client].StageRunning = true;
                Player[client].StageTimes.SetValue(Player[client].Stage, 0.0);
            }

            if (Core.Checkpoints > 0)
            {
                Player[client].CheckpointTimes = new IntMap();
                Player[client].Checkpoint = 1;

                Player[client].CheckpointRunning = true;
                Player[client].CheckpointTimes.SetValue(Player[client].Checkpoint, 0.0);
            }
        }
        else
        {
            if (Player[client].BonusTimes == null)
            {
                Player[client].BonusTimes = new IntMap();
            }
            
            Player[client].Checkpoint = 0;
            Player[client].Stage = 0;
            Player[client].Bonus = bonus;

            Player[client].BonusRunning = true;
            Player[client].BonusTimes.SetValue(Player[client].Bonus, 0.0);
        }
    }

    if (stage > 1 && Player[client].StageTimes != null)
    {
        Player[client].Stage = stage;
        Player[client].Bonus = 0;

        Player[client].StageRunning = true;
        Player[client].StageTimes.SetValue(Player[client].Stage, 0.0);
    }

    if (checkpoint > 1 && Player[client].CheckpointTimes != null)
    {
        Player[client].Checkpoint = checkpoint;
        Player[client].Bonus = 0;

        Player[client].CheckpointRunning = true;
        Player[client].CheckpointTimes.SetValue(Player[client].Checkpoint, 0.0);
    }
}

public Action OnPostThinkPost(int client)
{
    if (client < 1 || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return Plugin_Continue;
    }

    float fTime = 0.0;

    if (Player[client].MainRunning)
    {
        Player[client].MainTime += GetTickInterval();
    }

    if (Player[client].CheckpointRunning)
    {   
        Player[client].CheckpointTimes.GetValue(Player[client].Checkpoint, fTime);
        fTime += GetTickInterval();
        Player[client].CheckpointTimes.SetValue(Player[client].Checkpoint, fTime);
    }

    if (Player[client].StageRunning)
    {   
        Player[client].StageTimes.GetValue(Player[client].Stage, fTime);
        fTime += GetTickInterval();
        Player[client].StageTimes.SetValue(Player[client].Stage, fTime);
    }

    if (Player[client].BonusRunning)
    {   
        Player[client].BonusTimes.GetValue(Player[client].Bonus, fTime);
        fTime += GetTickInterval();
        Player[client].BonusTimes.SetValue(Player[client].Bonus, fTime);
    }
    
    return Plugin_Continue;
}

void SetClientStartValues(int client, int bonus)
{
    Player[client].Reset();

    Player[client].SetSpeed = true;

    if (bonus > 0)
    {
        Player[client].Bonus = bonus;
    }
    else if (Core.Stages > 0)
    {
        Player[client].Stage = 1;
    }
    else if (Core.Checkpoints > 0)
    {
        Player[client].Checkpoint = 1;
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
        if (Player[client].BonusTimes != null)
        {
            Player[client].BonusTimes.GetValue(level, fTime);
        }
        
        return fTime;
    }
    else if (type == TimeCheckpoint)
    {
        if (Player[client].CheckpointTimes != null)
        {
            Player[client].CheckpointTimes.GetValue(level, fTime);
        }
        
        return fTime;
    }
    else if (type == TimeStage)
    {
        if (Player[client].StageTimes != null)
        {
            Player[client].StageTimes.GetValue(level, fTime);
        }
        
        return fTime;
    }

    return 0.0;
}

public int Native_IsClientTimeRunning(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (Player[client].MainTime > 0.0)
    {
        return true;
    }
    else if (Player[client].CheckpointTimes != null)
    {
        return true;
    }
    else if (Player[client].StageTimes != null)
    {
        return true;
    }
    else if (Player[client].BonusTimes != null)
    {
        return true;
    }

    return false;
}

public int Native_GetClientCheckpoint(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Checkpoint;
}

public int Native_GetClientStage(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Stage;
}

public int Native_GetClientBonus(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Bonus;
}

public int Native_GetClientValidator(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Validator;
}

public int Native_GetAmountOfCheckpoints(Handle plugin, int numParams)
{
    return Core.Checkpoints;
}

public int Native_GetAmountOfStages(Handle plugin, int numParams)
{
    return Core.Stages;
}

public int Native_GetAmountOfBonus(Handle plugin, int numParams)
{
    return Core.Bonus;
}

public int Native_ResetClientTimer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    Player[client].Reset();
}
