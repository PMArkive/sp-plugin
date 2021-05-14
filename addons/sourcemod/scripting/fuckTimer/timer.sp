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

    bool SetSpeed;
    bool BlockJump;
    bool BlockTeleport;

    float Time;
    IntMap StageTimes;
    IntMap CheckpointTimes;

    void Reset(bool noCheckpoint = false)
    {
        if (!noCheckpoint)
        {
            this.Checkpoint = 0;
        }

        this.Stage = 0;
        this.Bonus = 0;

        this.Validator = 0;

        this.MainRunning = false;
        this.CheckpointRunning = false;
        this.StageRunning = false;

        this.SetSpeed = false;
        this.BlockJump = false;

        this.Time = 0.0;
        delete this.CheckpointTimes;
        delete this.StageTimes;
    }
}

PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    IntMap Stages;
    IntMap Checkpoints;

    int Bonus;

    GlobalForward OnClientTimerStart;
    GlobalForward OnClientZoneTouchStart;
    GlobalForward OnClientZoneTouchEnd;
    GlobalForward OnClientTimerEnd;
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
    Core.OnClientTimerStart = new GlobalForward("fuckTimer_OnClientTimerStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    Core.OnClientZoneTouchStart = new GlobalForward("fuckTimer_OnClientZoneTouchStart", ET_Ignore); // TODO
    Core.OnClientZoneTouchEnd = new GlobalForward("fuckTimer_OnClientZoneTouchEnd", ET_Ignore); // TODO
    Core.OnClientTimerEnd = new GlobalForward("fuckTimer_OnClientTimerEnd", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell, Param_Cell);

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
        LoadPlayer(client);
    }

    HookEvent("player_activate", Event_PlayerActivate);
}

public void OnMapStart()
{
    delete Core.Stages;
    Core.Stages = new IntMap();
    
    delete Core.Checkpoints;
    Core.Checkpoints = new IntMap();
    
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

            if (StrEqual(sKey, "Bonus", false))
            {
                smValues.GetString(sKey, sValue, sizeof(sValue));

                iBonus = StringToInt(sValue);

                if (iBonus > 0 && iBonus > Core.Bonus)
                {
                    Core.Bonus = iBonus;
                }
            }

            if (StrEqual(sKey, "Stage", false))
            {
                if (GetfuckTimerZoneValue(smEffects, "Bonus", sValue, sizeof(sValue)))
                {
                    iBonus = StringToInt(sValue);
                }

                smValues.GetString(sKey, sValue, sizeof(sValue));

                iStage = StringToInt(sValue);

                if (iStage > 0 && iStage > Core.Stages.GetInt(iBonus))
                {
                    Core.Stages.SetValue(iBonus, iStage);
                }
            }

            if (StrEqual(sKey, "Checkpoint", false))
            {
                if (GetfuckTimerZoneValue(smEffects, "Bonus", sValue, sizeof(sValue)))
                {
                    iBonus = StringToInt(sValue);
                }

                if (Core.Checkpoints.GetInt(iBonus) == -1)
                {
                    Core.Checkpoints.SetValue(iBonus, 0);
                }
                
                if (Core.Checkpoints.GetInt(iBonus) == 1)
                {
                    Core.Checkpoints.SetValue(iBonus, 2); // If we've a checkpoint map here, add one additional checkpoint more for the end zone as workaround without adding/changing each map zone config.
                }

                smValues.GetString(sKey, sValue, sizeof(sValue));

                iCheckpoint = StringToInt(sValue);

                if (iCheckpoint > 0 && iCheckpoint > Core.Checkpoints.GetInt(iBonus))
                {
                    Core.Checkpoints.SetValue(iBonus, Core.Checkpoints.GetInt(iBonus) + 1);
                }
            }

            iCheckpoint = 0;
            iStage = 0;
            iBonus = 0;
        }
    }

    delete snap;
}

public Action Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    LoadPlayer(client);
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

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }

    int iBonus = 0;

    if (fuckTimer_IsStartZone(zone, iBonus) && !fuckTimer_IsMiscZone(zone, iBonus))
    {
        SetClientStartValues(client, iBonus);

        return;
    }

    if (fuckTimer_IsMiscZone(zone, iBonus))
    {
        if (fuckTimer_IsStopZone(zone, iBonus))
        {
            Player[client].Reset();
            return;
        }

        if (fuckTimer_IsTeleToStartZone(zone, iBonus) && !Player[client].BlockTeleport)
        {
            bool bStart = fuckTimer_IsStartZone(zone, iBonus);

            int iZone = bStart ? fuckTimer_GetStartZone(iBonus) : fuckTimer_GetStageZone(Player[client].Bonus, Player[client].Stage);

            if (bStart)
            {
                Player[client].Reset();
            }

            if (iZone > 0)
            {
                fuckZones_TeleportClientToZoneIndex(client, iZone);

                Player[client].BlockTeleport = true;
            }

            return;
        }

        if (fuckTimer_IsAntiJumpZone(zone, iBonus))
        {
            Player[client].BlockJump = true;
        }

        int iValidators;
        if (fuckTimer_IsCheckerZone(zone, iBonus, iValidators) && !Player[client].BlockTeleport)
        {
            if (iBonus == Player[client].Bonus && iValidators > 0 && Player[client].Validator >= iValidators)
            {
                return;
            }

            int iZone = fuckTimer_GetStageZone(Player[client].Bonus, Player[client].Stage);

            if (iZone > 0)
            {
                fuckZones_TeleportClientToZoneIndex(client, iZone);

                Player[client].BlockTeleport = true;
            }
            
            return;
        }

        if (fuckTimer_IsValidatorZone(zone, Player[client].Bonus))
        {
            Player[client].Validator++;
        }

        return;
    }

    int iStage = fuckTimer_GetStageByIndex(zone, iBonus);
    if (fuckTimer_IsEndZone(zone, Player[client].Bonus) && iStage < 1 && Player[client].Stage > 0)
    {
        Player[client].Stage++;
        iStage = Player[client].Stage;
    }
    
    if (iStage > 0)
    {
        Player[client].Validator = 0;
        Player[client].SetSpeed = true;

        Player[client].Stage = iStage;

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
        Player[client].StageTimes.GetValue(iStage, fBuffer);

        if (fBuffer > 0.0)
        {
            Player[client].StageTimes.SetValue(iStage, 0.0);
            return;
        }

        int iPrevStage = iStage - 1;

        if (iPrevStage < 1)
        {
            iPrevStage = 1;
        }

        float fStart;
        Player[client].StageTimes.GetValue(iPrevStage, fStart);
        PrintToChatAll("%N's time for%s Stage %d: %.3f", client, iBonus ? " Bonus" : "", iPrevStage, fStart);
        Player[client].StageRunning = false;
    }

    // Fix for missing checkpoint entry in end zone
    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, iBonus);
    if (fuckTimer_IsEndZone(zone, Player[client].Bonus) && iCheckpoint < 1 && Player[client].Checkpoint > 0)
    {
        // Player[client].Checkpoint++;
        iCheckpoint = Player[client].Checkpoint;
    }
    
    if (iCheckpoint > 0)
    {
        if (Player[client].CheckpointTimes == null)
        {
            return;
        }
        
        iCheckpoint = Player[client].Checkpoint + 1;
        Player[client].Stage = 0;

        float fBuffer = 0.0;
        Player[client].CheckpointTimes.GetValue(iCheckpoint, fBuffer);

        if (fBuffer > 0.0)
        {
            Player[client].CheckpointTimes.SetValue(iCheckpoint, 0.0);
        }

        int iPrevCheckpoint = iCheckpoint - 1;

        if (iPrevCheckpoint < 0)
        {
            iPrevCheckpoint = 0;
        }

        float fStart;
        Player[client].CheckpointTimes.GetValue(iPrevCheckpoint, fStart);

        // We increase this here, to show the correct Checkpoint Number in players chat
        iPrevCheckpoint++;

        if (iPrevCheckpoint > Core.Checkpoints.GetInt(iBonus))
        {
            iPrevCheckpoint = Core.Checkpoints.GetInt(iBonus);
        }

        PrintToChatAll("%N's time for%s Checkpoint %d: %.3f", client, iBonus ? " Bonus" : "", iPrevCheckpoint, fStart);
        Player[client].CheckpointRunning = false;

        if (fuckTimer_IsEndZone(zone, Player[client].Bonus))
        {
            Player[client].Checkpoint++;
        }
    }
    
    int bonus = fuckTimer_GetZoneBonus(zone);
    
    if (fuckTimer_IsEndZone(zone, Player[client].Bonus) && Player[client].Time > 0.0)
    {
        if (Player[client].Bonus == 0)
        {
            PrintToChat(client, "End Time: %.3f", Player[client].Time);
        }
        else
        {
            int iPrevBonus = bonus/* - 1*/; // TODO: Requires some tests, whether we don't need it anymore

            if (iPrevBonus < 1)
            {
                iPrevBonus = 1;
            }

            PrintToChatAll("%N's time for Bonus %d: %.3f", client, iPrevBonus, Player[client].Time);
        }

        Call_StartForward(Core.OnClientTimerEnd);
        Call_PushCell(client);
        Call_PushCell(Player[client].Bonus);
        Call_PushFloat(Player[client].Time);

        if (Player[client].CheckpointTimes != null)
        {
            Call_PushCell(TimeCheckpoint);
            Call_PushCell(view_as<int>(Player[client].CheckpointTimes));
        }
        else if (Player[client].StageTimes != null)
        {
            Call_PushCell(TimeStage);
            Call_PushCell(view_as<int>(Player[client].StageTimes));
        }
        else
        {
            Call_PushCell(TimeType);
            Call_PushCell(0);
        }

        Call_Finish();
        
        Player[client].MainRunning = false;

        Player[client].Reset(true);
        Player[client].Bonus = bonus;
    }
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client) || Player[client].Time == 0.0)
    {
        return;
    }
    
    int iBonus = 0;
    if (fuckTimer_IsStartZone(zone, iBonus))
    {
        SetClientStartValues(client, iBonus);
    }

    int iStage = fuckTimer_GetStageByIndex(zone, iBonus);
    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, iBonus);
    
    if (!fuckTimer_IsMiscZone(zone, iBonus) && iStage > 0)
    {
        Player[client].SetSpeed = true;
        Player[client].StageRunning = false;
        Player[client].StageTimes.SetValue(iStage, 0.0);
    }

    if (!fuckTimer_IsMiscZone(zone, iBonus) && iCheckpoint > 0)
    {
        Player[client].CheckpointRunning = false;
        Player[client].CheckpointTimes.SetValue(iCheckpoint, 0.0);
    }

    if (fuckTimer_IsAntiJumpZone(zone, iBonus))
    {
        Player[client].BlockJump = true;
    }
}

public void fuckTimer_OnClientTeleport(int client, int level)
{
    Player[client].Reset();
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    Player[client].SetSpeed = false;
    Player[client].BlockJump = false;

    int bonus = fuckTimer_GetZoneBonus(zone);

    if (fuckTimer_IsStartZone(zone, bonus) && !fuckTimer_IsMiscZone(zone, bonus))
    {
        Player[client].Reset();

        Player[client].Bonus = bonus;
        Player[client].MainRunning = true;

        if (Core.Stages.GetInt(bonus) > 0)
        {
            if (Player[client].StageTimes == null)
            {
                Player[client].StageTimes = new IntMap();
            }

            Player[client].Stage = 1;
            Player[client].StageRunning = true;
            Player[client].StageTimes.SetValue(Player[client].Stage, 0.0);
        }

        if (Core.Checkpoints.GetInt(bonus) > 0)
        {
            if (Player[client].CheckpointTimes == null)
            {
                Player[client].CheckpointTimes = new IntMap();
            }

            Player[client].Checkpoint = 0;
            Player[client].CheckpointRunning = true;
            Player[client].CheckpointTimes.SetValue(Player[client].Checkpoint, 0.0);
        }

        Player[client].BlockTeleport = false;
    }

    int iStage = fuckTimer_GetStageByIndex(zone, Player[client].Bonus);
    if (iStage > 1 && Player[client].StageTimes != null)
    {
        Player[client].Stage = iStage;
        Player[client].StageRunning = true;
        Player[client].StageTimes.SetValue(Player[client].Stage, 0.0);

        Player[client].BlockTeleport = false;
    }

    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, Player[client].Bonus);
    if (iCheckpoint > 1 && Player[client].CheckpointTimes != null)
    {
        Player[client].Checkpoint++;
        Player[client].CheckpointRunning = true;
        Player[client].CheckpointTimes.SetValue(Player[client].Checkpoint, 0.0);

        Player[client].BlockTeleport = false;
    }

    if (Player[client].MainRunning)
    {
        Call_StartForward(Core.OnClientTimerStart);
        Call_PushCell(client);
        Call_PushCell(Player[client].Bonus);
        if (Player[client].Checkpoint > 0)
        {
            Call_PushCell(TimeCheckpoint);
            Call_PushCell(Player[client].Checkpoint);
        }
        else if (Player[client].Stage > 0)
        {
            Call_PushCell(TimeStage);
            Call_PushCell(Player[client].Stage);
        }
        else
        {
            Call_PushCell(TimeMain);
            Call_PushCell(0);
        }
        Call_Finish();
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
        Player[client].Time += GetTickInterval();
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
    else if (Core.Stages.GetInt(bonus) > 0)
    {
        Player[client].Stage = 1;
    }
    else if (Core.Checkpoints.GetInt(bonus) > 0)
    {
        Player[client].Checkpoint = 0;
    }
}

void LoadPlayer(int client)
{
    Player[client].Reset();

    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public any Native_GetClientTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    TimeType type = GetNativeCell(2);

    int level = GetNativeCell(3);

    if (type == TimeMain)
    {
        if (Player[client].Time > 0.0)
        {
            return Player[client].Time;
        }
    }
    else if (type == TimeCheckpoint)
    {
        if (Player[client].CheckpointTimes != null)
        {
            return Player[client].CheckpointTimes.GetFloat(level);
        }
    }
    else if (type == TimeStage)
    {
        if (Player[client].StageTimes != null)
        {
            return Player[client].StageTimes.GetFloat(level);
        }
    }

    return 0.0;
}

public int Native_IsClientTimeRunning(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (Player[client].Time > 0.0)
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
    int iBonus = GetNativeCell(1);
    return Core.Checkpoints.GetInt(iBonus);
}

public int Native_GetAmountOfStages(Handle plugin, int numParams)
{
    int iBonus = GetNativeCell(1);
    return Core.Stages.GetInt(iBonus);
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
