/**
 * Merge Checkpoint stuff from OnLeavingZone into OnEnteringZone
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <fuckZones>
#include <fuckTimer_players>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>
#include <fuckTimer_timer>
#include <fuckTimer_maps>

enum struct PlayerData
{
    int Checkpoint;
    int Stage;
    int Bonus;
    int Attempts;
    int Validator;
    int Zone;

    bool MainRunning;
    bool CheckpointRunning;
    bool StageRunning;

    bool SetSpeed;
    bool BlockJump;
    bool BlockTeleport;

    // Prestrafe
    int LastButtons;
    bool Prestrafe;

    float Time;
    float TimeInZone;

    // Variables for Offset calculation
    float Fraction;
    float Offset[OFFSET_MAX]; // 0 - Start, 1 - End
    bool GetOffset;
    float Origin1[3];
    float Origin2[3];

    float StartPosition[3];
    float StartAngle[3];
    float StartVelocity[3];

    float EndPosition[3];
    float EndAngle[3];
    float EndVelocity[3];

    IntMap StageDetails;
    IntMap CheckpointDetails;

    void Reset(bool noCheckpoint = false, bool resetTimeInZone = true, bool resetAttempts = true)
    {
        if (!noCheckpoint)
        {
            this.Checkpoint = 0;
        }

        this.Stage = 0;
        this.Bonus = 0;
        
        if (resetAttempts)
        {
            this.Attempts = 0;
        }

        this.Validator = 0;
        this.Zone = 0;

        this.MainRunning = false;
        this.CheckpointRunning = false;
        this.StageRunning = false;

        this.SetSpeed = false;
        this.BlockJump = false;

        this.LastButtons = 0;
        this.Prestrafe = false;

        this.Time = 0.0;

        if (resetTimeInZone)
        {
            this.TimeInZone = 0.0;
        }

        this.Fraction = 0.0;
        this.Origin1 = {0.0, 0.0, 0.0};
        this.Origin2 = {0.0, 0.0, 0.0};
        this.Offset = { 0.0, 0.0 };
        this.GetOffset = false;

        this.StartPosition = {0.0, 0.0, 0.0};
        this.StartAngle = {0.0, 0.0, 0.0};
        this.StartVelocity = {0.0, 0.0, 0.0};

        this.EndPosition = {0.0, 0.0, 0.0};
        this.EndAngle = {0.0, 0.0, 0.0};
        this.EndVelocity = {0.0, 0.0, 0.0};

        delete this.CheckpointDetails;
        delete this.StageDetails;
    }

    void AllowPrestrafe(bool status)
    {
        this.Prestrafe = status;
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

#include "timer/native.sp"

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
    Core.OnClientZoneTouchStart = new GlobalForward("fuckTimer_OnClientZoneTouchStart", ET_Ignore, Param_Cell, Param_Cell,  Param_Cell, Param_Cell, Param_Cell, Param_Float);
    Core.OnClientZoneTouchEnd = new GlobalForward("fuckTimer_OnClientZoneTouchEnd", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    Core.OnClientTimerEnd = new GlobalForward("fuckTimer_OnClientTimerEnd", ET_Ignore, Param_Cell, Param_Any);

    CreateNative("fuckTimer_GetClientTime", Native_GetClientTime);
    CreateNative("fuckTimer_IsClientTimeRunning", Native_IsClientTimeRunning);

    CreateNative("fuckTimer_GetClientTimeInZone", Native_GetClientTimeInZone);
    CreateNative("fuckTimer_GetClientAttempts", Native_GetClientAttempts);

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
    if (GetExtensionFileStatus("accelerator.ext") != 1)
    {
        SetFailState("Extension \"Accelerator\" not found!");
        return;
    }

    fuckTimer_LoopClients(client, false, false)
    {
        LoadPlayer(client);
    }

    HookEvent("round_poststart", Event_RoundReset);
    HookEvent("round_end", Event_RoundReset);
    HookEvent("player_activate", Event_PlayerActivate);
}

public void OnAllPluginsLoaded()
{
    if (!LibraryExists("endtouchfix"))
    {
        SetFailState("Plugin \"End Touch Fix\" not found!");
        return;
    }
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

public Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
    fuckTimer_LoopClients(client, false, false)
    {
        Player[client].Reset();
    }
}

public Action Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    LoadPlayer(client);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    for (int i = 0; i < 25; i++)
    {
        int button = (1 << i);

        if ((buttons & button))
        {
            if (!(Player[client].LastButtons & button))
            {
                OnButtonPress(client, button);
            }
        }
    }

    Player[client].LastButtons = buttons;

    if (IsPlayerAlive(client))
    {
        if (Player[client].SetSpeed && !Player[client].Prestrafe)
        {
            int iMaxSpeed = fuckTimer_GetZonePreSpeed(Player[client].Zone);

            SetClientSpeed(client, iMaxSpeed);
        }

        if (Player[client].BlockJump && buttons & IN_JUMP)
        {
            buttons &= ~IN_JUMP;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

void OnButtonPress(int client, int button)
{
    if (button & IN_JUMP)
    {
        // Check if client is in a zone who we'll set the speed
        if (!Player[client].SetSpeed)
        {
            return;
        }

        Player[client].AllowPrestrafe(true);
    }
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }

    Player[client].Zone = zone;

    int iBonus = 0;

    if (fuckTimer_IsStartZone(zone, iBonus) && !fuckTimer_IsMiscZone(zone, iBonus))
    {
        SetClientStartValues(client, iBonus);
        Player[client].AllowPrestrafe(false);

        return;
    }

    if (fuckTimer_IsMiscZone(zone, iBonus))
    {
        if (fuckTimer_IsStopZone(zone, iBonus))
        {
            Player[client].Reset();

            Call_StartForward(Core.OnClientZoneTouchStart);
            Call_PushCell(client);
            Call_PushCell(view_as<int>(true));
            Call_PushCell(iBonus);
            Call_PushCell(0);
            Call_PushCell(0);
            Call_PushFloat(0.0);
            Call_Finish();
            
            return;
        }

        if (fuckTimer_IsTeleToStartZone(zone, iBonus) && !Player[client].BlockTeleport)
        {
            bool bStart = fuckTimer_IsStartZone(zone, iBonus);

            int iZone = bStart ? fuckTimer_GetStartZone(iBonus) : fuckTimer_GetStageZone(Player[client].Bonus, Player[client].Stage);

            if (bStart)
            {
                Player[client].Reset();

                Call_StartForward(Core.OnClientZoneTouchStart);
                Call_PushCell(client);
                Call_PushCell(view_as<int>(true));
                Call_PushCell(iBonus);
                Call_PushCell(0);
                Call_PushCell(0);
                Call_PushFloat(0.0);
                Call_Finish();
            }

            if (iZone > 0)
            {
                fuckTimer_TeleportEntityToZone(client, iZone);

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
                fuckTimer_TeleportEntityToZone(client, iZone);

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

    CSDetails details;
    
    if (Player[client].StageRunning && iStage > 0)
    {
        Player[client].Validator = 0;
        Player[client].SetSpeed = true;

        Player[client].Stage = iStage;
        Player[client].AllowPrestrafe(false);

        // That isn't really an workaround or dirty fix but... 
        // with this check we're able to start the stage timer
        // and just count the stage times. So you don't need to
        // restart the whole timer from the first stage to your
        // selected or current stage.
        if (Player[client].StageDetails == null)
        {
            Player[client].StageDetails = new IntMap();
            return;
        }

        Player[client].StageDetails.GetArray(iStage, details, sizeof(details));

        if (details.Time > 0.0)
        {
            SetIntMapTime(Player[client].StageDetails, iStage, 0.0);
            return;
        }

        int iPrevStage = iStage - 1;

        if (iPrevStage < 1)
        {
            iPrevStage = 1;
        }

        Player[client].StageDetails.GetArray(iPrevStage, details, sizeof(details));
        CalculateTickIntervalOffsetCS(client, Player[client].StageDetails, iPrevStage, true);
        details.Time += GetIntMapOffset(Player[client].StageDetails, iPrevStage, OFFSET_START);
        details.Time -= GetTickInterval();
        details.Time += GetIntMapOffset(Player[client].StageDetails, iPrevStage, OFFSET_END);
        Player[client].StageDetails.SetArray(iPrevStage, details, sizeof(details));

        PrintToChatAll("%N's time for%s Stage %d: %.3f. (Attempts: %d, Time in Zone: %.3f)", client, iBonus ? " Bonus" : "", iPrevStage, details.Time, Player[client].Attempts, Player[client].TimeInZone);
        Player[client].StageRunning = false;

        SetIntMapAttempts(Player[client].StageDetails, iPrevStage, Player[client].Attempts);
        SetIntMapTimeInZone(Player[client].StageDetails, iPrevStage, Player[client].TimeInZone);
        SetIntMapPositionAngleVelocity(client, Player[client].StageDetails, iPrevStage, false);

        Player[client].Attempts = 0;
        Player[client].TimeInZone = 0.0;

        Call_StartForward(Core.OnClientZoneTouchStart);
        Call_PushCell(client);
        Call_PushCell(view_as<int>(false));
        Call_PushCell(iBonus);
        Call_PushCell(TimeStage);
        Call_PushCell(iPrevStage);
        Call_PushFloat(details.Time);
        Call_Finish();
    }

    // Fix for missing checkpoint entry in end zone
    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, iBonus);
    if (fuckTimer_IsEndZone(zone, Player[client].Bonus) && iCheckpoint < 1 && Player[client].Checkpoint > 0)
    {
        // Player[client].Checkpoint++;
        iCheckpoint = Player[client].Checkpoint;
    }
    
    if (Player[client].CheckpointRunning && iCheckpoint > 0)
    {
        if (Player[client].CheckpointDetails == null)
        {
            return;
        }
        
        iCheckpoint = Player[client].Checkpoint + 1;
        Player[client].Stage = 0;

        Player[client].CheckpointDetails.GetArray(iCheckpoint, details, sizeof(details));

        if (details.Time > 0.0)
        {
            SetIntMapTime(Player[client].CheckpointDetails, iCheckpoint, 0.0);
        }

        int iPrevCheckpoint = iCheckpoint - 1;

        if (iPrevCheckpoint < 0)
        {
            iPrevCheckpoint = 0;
        }

        Player[client].CheckpointDetails.GetArray(iPrevCheckpoint, details, sizeof(details));

        if (iPrevCheckpoint > Core.Checkpoints.GetInt(iBonus))
        {
            iPrevCheckpoint = Core.Checkpoints.GetInt(iBonus);
        }

        CalculateTickIntervalOffsetCS(client, Player[client].CheckpointDetails, iPrevCheckpoint, true);
        details.Time += GetIntMapOffset(Player[client].CheckpointDetails, iPrevCheckpoint, OFFSET_START);
        details.Time -= GetTickInterval();
        details.Time += GetIntMapOffset(Player[client].CheckpointDetails, iPrevCheckpoint, OFFSET_END);
        Player[client].CheckpointDetails.SetArray(iPrevCheckpoint, details, sizeof(details));

        PrintToChatAll("%N's time for%s Checkpoint %d: %.3f", client, iBonus ? " Bonus" : "", iPrevCheckpoint, details.Time);
        SetIntMapTime(Player[client].CheckpointDetails, iPrevCheckpoint, details.Time, false);
        SetIntMapPositionAngleVelocity(client, Player[client].CheckpointDetails, iPrevCheckpoint, false);

        Player[client].CheckpointRunning = false;

        Call_StartForward(Core.OnClientZoneTouchStart);
        Call_PushCell(client);
        Call_PushCell(view_as<int>(false));
        Call_PushCell(iBonus);
        Call_PushCell(TimeCheckpoint);
        Call_PushCell(iPrevCheckpoint);
        Call_PushFloat(details.Time);
        Call_Finish();

        if (fuckTimer_IsEndZone(zone, Player[client].Bonus))
        {
            Player[client].Checkpoint++;
        }
    }
    
    int bonus = fuckTimer_GetZoneBonus(zone);
    
    if (Player[client].MainRunning && fuckTimer_IsEndZone(zone, Player[client].Bonus) && Player[client].Time > 0.0)
    {
        CalculateTickIntervalOffset(client, true);

        Player[client].Time += Player[client].Offset[OFFSET_START];
        Player[client].Time -= GetTickInterval();
        Player[client].Time += Player[client].Offset[OFFSET_END];

        if (Player[client].Bonus == 0)
        {
            PrintToChat(client, "End Time: %.3f", Player[client].Time);
        }
        else
        {
            int iPrevBonus = bonus;

            if (iPrevBonus < 1)
            {
                iPrevBonus = 1;
            }

            PrintToChatAll("%N's time for Bonus %d: %.3f", client, iPrevBonus, Player[client].Time);
        }

        GetClientPosition(client, Player[client].EndPosition);
        GetClientAngle(client, Player[client].EndAngle);
        GetClientVelocity(client, Player[client].EndVelocity);

        StringMap map = new StringMap();
        map.SetValue("MapId", fuckTimer_GetCurrentMapId());
        map.SetValue("PlayerId", GetSteamAccountID(client));

        char sBuffer[MAX_NAME_LENGTH];
        GetClientName(client, sBuffer, sizeof(sBuffer));
        map.SetString("PlayerName", sBuffer);

        fuckTimer_GetClientSetting(client, "Style", sBuffer);
        map.SetValue("StyleId", StringToInt(sBuffer));

        map.SetValue("Level", Player[client].Bonus);
        
        if (Player[client].CheckpointDetails != null)
        {
            map.SetValue("Type", TimeCheckpoint);
            map.SetValue("Details", view_as<any>(Player[client].CheckpointDetails));
        }
        else if (Player[client].StageDetails != null)
        {
            map.SetValue("Type", TimeStage);
            map.SetValue("Details", view_as<any>(Player[client].StageDetails));
        }
        else
        {
            map.SetValue("Type", TimeMain);
            map.SetValue("Details", 0);
        }

        map.SetValue("Tickrate", GetServerTickrate());
        map.SetValue("Time", Player[client].Time);
        map.SetValue("TimeInZone", Player[client].TimeInZone);
        map.SetValue("Attempts", Player[client].Attempts);
        map.SetArray("StartPosition", Player[client].StartPosition, 3);
        map.SetArray("StartAngle", Player[client].StartAngle, 3);
        map.SetArray("StartVelocity", Player[client].StartVelocity, 3);
        map.SetArray("EndPosition", Player[client].EndPosition, 3);
        map.SetArray("EndAngle", Player[client].EndAngle, 3);
        map.SetArray("EndVelocity", Player[client].EndVelocity, 3);

        Call_StartForward(Core.OnClientTimerEnd);
        Call_PushCell(client);
        Call_PushCell(view_as<int>(map));
        Call_Finish();

        RequestFrame(Frame_DeleteStringMap, map);
        
        Player[client].MainRunning = false;

        Player[client].Reset(true);
        Player[client].Bonus = bonus;
    }
}

public void Frame_DeleteStringMap(any map)
{
    delete view_as<StringMap>(map);
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }

    Player[client].Zone = zone;
    Player[client].Bonus = fuckTimer_GetZoneBonus(Player[client].Zone);

    int iBonus = 0;
    bool bStart = fuckTimer_IsStartZone(Player[client].Zone, iBonus);
    bool bEnd = fuckTimer_IsEndZone(Player[client].Zone, iBonus);
    int iStage = fuckTimer_GetStageByIndex(Player[client].Zone, iBonus);

    if (iStage > 0)
    {
        Player[client].Stage = iStage;
    }

    if (bEnd)
    {
        Player[client].Stage = Core.Stages.GetInt(iBonus);
    }

    if (Player[client].Time == 0.0)
    {
        Player[client].TimeInZone += GetTickInterval();

        // We need to check this here, otherwise set speed can be abused
        if (!fuckTimer_IsMiscZone(Player[client].Zone, iBonus) && iStage > 0)
        {
            Player[client].SetSpeed = true;
        }

        return;
    }
    
    if (bStart)
    {
        SetClientStartValues(client, iBonus);
    }

    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, iBonus);

    if (!fuckTimer_IsMiscZone(Player[client].Zone, iBonus) && iStage > 0)
    {
        Player[client].SetSpeed = true;
        Player[client].StageRunning = false;
        SetIntMapTime(Player[client].StageDetails, iStage, 0.0);
        Player[client].TimeInZone += GetTickInterval();
    }

    if (!fuckTimer_IsMiscZone(Player[client].Zone, iBonus) && iCheckpoint > 0)
    {
        Player[client].CheckpointRunning = false;
        SetIntMapTime(Player[client].CheckpointDetails, iCheckpoint, 0.0);
    }

    if (fuckTimer_IsAntiJumpZone(Player[client].Zone, iBonus))
    {
        Player[client].BlockJump = true;
    }
}

public void fuckTimer_OnClientCommand(int client, int level, bool start)
{
    Player[client].Reset();
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    int bonus = fuckTimer_GetZoneBonus(zone);
    if (Player[client].Zone != zone)
    {
        return;
    }
    
    Player[client].SetSpeed = false;
    Player[client].BlockJump = false;

    bool bSkipAttempts = false;

    if (fuckTimer_IsStartZone(zone, bonus) && !fuckTimer_IsMiscZone(zone, bonus))
    {
        Player[client].Reset(.resetTimeInZone = false, .resetAttempts = false);
        Player[client].AllowPrestrafe(false);

        Player[client].Bonus = bonus;
        Player[client].MainRunning = true;
        Player[client].GetOffset = true;

        GetClientPosition(client, Player[client].StartPosition);
        GetClientAngle(client, Player[client].StartAngle);
        GetClientVelocity(client, Player[client].StartVelocity);

        if (Core.Stages.GetInt(bonus) > 0)
        {
            if (Player[client].StageDetails == null)
            {
                Player[client].StageDetails = new IntMap();
            }

            Player[client].Stage = 1;
            Player[client].StageRunning = true;
            SetIntMapTime(Player[client].StageDetails, Player[client].Stage, 0.0);
            SetIntMapPositionAngleVelocity(client, Player[client].StageDetails, Player[client].Stage, true);
        }

        if (Core.Checkpoints.GetInt(bonus) > 0)
        {
            if (Player[client].CheckpointDetails == null)
            {
                Player[client].CheckpointDetails = new IntMap();
            }

            Player[client].Checkpoint = 1;
            Player[client].CheckpointRunning = true;
            SetIntMapTime(Player[client].CheckpointDetails, Player[client].Checkpoint, 0.0);
            SetIntMapPositionAngleVelocity(client, Player[client].CheckpointDetails, Player[client].Checkpoint + 1, true);
        }

        if (Player[client].Attempts < 0)
        {
            Player[client].Attempts = 0;
            bSkipAttempts = true;
        }

        Player[client].BlockTeleport = false;
    }

    int iStage = fuckTimer_GetStageByIndex(zone, Player[client].Bonus);
    if (iStage > 1 && Player[client].StageDetails != null)
    {
        if (Player[client].Stage < iStage)
        {
            Player[client].Attempts = 0;
        }

        Player[client].AllowPrestrafe(false);
        
        Player[client].Stage = iStage;
        Player[client].StageRunning = true;
        SetIntMapTime(Player[client].StageDetails, Player[client].Stage, 0.0);
        SetIntMapPositionAngleVelocity(client, Player[client].StageDetails, Player[client].Stage, true);
        SetIntMapGetOffset(Player[client].StageDetails, Player[client].Stage, true);

        Player[client].BlockTeleport = false;
    }

    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, Player[client].Bonus);
    if (iCheckpoint > 1 && Player[client].CheckpointDetails != null)
    {
        Player[client].Checkpoint++;
        Player[client].CheckpointRunning = true;
        SetIntMapTime(Player[client].CheckpointDetails, Player[client].Checkpoint, 0.0);
        SetIntMapPositionAngleVelocity(client, Player[client].CheckpointDetails, Player[client].Checkpoint, true);
        SetIntMapGetOffset(Player[client].CheckpointDetails, Player[client].Checkpoint, true);
        
        Player[client].BlockTeleport = false;
    }

    if (Player[client].MainRunning)
    {
        Call_StartForward(Core.OnClientTimerStart);
        Call_PushCell(client);
        Call_PushCell(Player[client].Bonus);

        if (!bSkipAttempts && iCheckpoint == 0)
        {
            Player[client].Attempts++;
        }

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

    Call_StartForward(Core.OnClientZoneTouchEnd);
    Call_PushCell(client);
    Call_PushCell(Player[client].Bonus);

    if (Player[client].CheckpointRunning)
    {
        Call_PushCell(TimeCheckpoint);
        Call_PushCell(Player[client].Checkpoint);
    }
    if (Player[client].StageRunning)
    {
        Call_PushCell(TimeStage);
        Call_PushCell(Player[client].Stage);
    }

    Call_Finish();

    Player[client].Zone = 0;
}

public Action OnPostThinkPost(int client)
{
    if (client < 1 || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return Plugin_Continue;
    }

    if (Player[client].Prestrafe && Player[client].SetSpeed)
    {
        if (GetEntityFlags(client) & FL_ONGROUND)
        {
            Player[client].AllowPrestrafe(false);
        }
    }

    Player[client].Origin2 = Player[client].Origin1;
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", Player[client].Origin1);

    if (Player[client].MainRunning)
    {
        if (Player[client].GetOffset)
        {
            Player[client].GetOffset = false;

            CalculateTickIntervalOffset(client, false);
        }

        Player[client].Time += GetTickInterval();
    }

    if (Player[client].CheckpointRunning)
    {
        if (GetIntMapGetOffset(Player[client].CheckpointDetails, Player[client].Checkpoint))
        {
            CalculateTickIntervalOffsetCS(client, Player[client].CheckpointDetails, Player[client].Checkpoint, false);
            SetIntMapGetOffset(Player[client].CheckpointDetails, Player[client].Checkpoint, false);
        }

        SetIntMapTime(Player[client].CheckpointDetails, Player[client].Checkpoint, GetTickInterval());
    }

    if (Player[client].StageRunning)
    {
        if (GetIntMapGetOffset(Player[client].StageDetails, Player[client].Stage))
        {
            CalculateTickIntervalOffsetCS(client, Player[client].StageDetails, Player[client].Stage, false);
            SetIntMapGetOffset(Player[client].StageDetails, Player[client].Stage, false);
        }

        SetIntMapTime(Player[client].StageDetails, Player[client].Stage, GetTickInterval());
    }
    
    return Plugin_Continue;
}

void SetClientStartValues(int client, int bonus)
{
    Player[client].Reset(.resetTimeInZone = false, .resetAttempts = false);

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

    if (Player[client].TimeInZone < 0.0)
    {
        Player[client].TimeInZone = 0.0;
    }

    if (Player[client].Attempts < 0)
    {
        Player[client].Attempts = 0;
    }

    Player[client].TimeInZone += GetTickInterval();
}

void LoadPlayer(int client)
{
    Player[client].Reset();

    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

void SetIntMapTime(IntMap map, int key, float value, bool add = true)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (value == 0.0 || !add)
    {
        details.Time = value;
    }
    else
    {
        details.Time += value;
    }

    map.SetArray(key, details, sizeof(details));
}

void SetIntMapTimeInZone(IntMap map, int key, float value)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    details.TimeInZone = value;

    map.SetArray(key, details, sizeof(details));
}

void SetIntMapPositionAngleVelocity(int client, IntMap map, int key, bool start)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (start)
    {
        GetClientPosition(client, details.StartPosition);
        GetClientAngle(client, details.StartAngle);
        GetClientVelocity(client, details.StartVelocity);
    }
    else
    {
        GetClientPosition(client, details.EndPosition);
        GetClientAngle(client, details.EndAngle);
        GetClientVelocity(client, details.EndVelocity);
    }

    map.SetArray(key, details, sizeof(details));
}

bool GetIntMapGetOffset(IntMap map, int key)
{
    if (map == null)
    {
        return false;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.GetOffset;
}

bool SetIntMapGetOffset(IntMap map, int key, bool status)
{
    if (map == null)
    {
        return false;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));
    details.GetOffset = status;
    map.SetArray(key, details, sizeof(details));

    return details.GetOffset;
}

float GetIntMapOffset(IntMap map, int key, int offset)
{
    if (map == null)
    {
        return 0.0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.Offset[offset];
}

float GetIntMapTimeInZone(IntMap map, int key)
{
    if (map == null)
    {
        return  0.0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.TimeInZone;
}

void SetIntMapAttempts(IntMap map, int key, int value)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    details.Attempts = value;

    map.SetArray(key, details, sizeof(details));
}

int GetIntMapAttempts(IntMap map, int key)
{
    if (map == null)
    {
        return 0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.Attempts;
}

// Thanks to bhoptimer for this code.
// Source: https://github.com/shavitush/bhoptimer/blob/e6de599808b5a8c1b2e74729da0820e73392cdce/addons/sourcemod/scripting/shavit-core.sp#L3487
// Reference: https://github.com/momentum-mod/game/blob/5e2d1995ca7c599907980ee5b5da04d7b5474c61/mp/src/game/server/momentum/mom_timer.cpp#L388
void CalculateTickIntervalOffset(int client, bool end)
{
    float fOrigin[3];
    float fMins[3];
    float fMaxs[3];

    GetEntPropVector(client, Prop_Data, "m_vecOrigin", fOrigin);
    GetEntPropVector(client, Prop_Data, "m_vecMins", fMins);
    GetEntPropVector(client, Prop_Data, "m_vecMaxs", fMaxs);

    if (!end)
    {
        TR_EnumerateEntitiesHull(fOrigin, Player[client].Origin2, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
    }
    else
    {
        TR_EnumerateEntitiesHull(Player[client].Origin1, fOrigin, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
    }

    Player[client].Offset[end ? OFFSET_END : OFFSET_START] = Player[client].Fraction * GetTickInterval();
}

bool TREnumTrigger(int entity, any client) {

    if (entity <= MaxClients) {
        return true;
    }

    char sClass[32];
    GetEntityClassname(entity, sClass, sizeof(sClass));

    if(StrContains(sClass, "trigger_multiple") > -1)
    {
        TR_ClipCurrentRayToEntity(MASK_ALL, entity);
        
        Player[client].Fraction = TR_GetFraction();

        return false;
    }
    return true;
}

void CalculateTickIntervalOffsetCS(int client, IntMap map, int key, bool end)
{
    float fFraction;
    float fOrigin[3];
    float fMins[3];
    float fMaxs[3];

    GetEntPropVector(client, Prop_Data, "m_vecOrigin", fOrigin);
    GetEntPropVector(client, Prop_Data, "m_vecMins", fMins);
    GetEntPropVector(client, Prop_Data, "m_vecMaxs", fMaxs);

    if (!end)
    {
        TR_EnumerateEntitiesHull(fOrigin, Player[client].Origin2, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTriggerCS, fFraction);
    }
    else
    {
        TR_EnumerateEntitiesHull(Player[client].Origin1, fOrigin, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTriggerCS, fFraction);
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));
    details.Fraction = fFraction;
    details.Offset[end ? OFFSET_END : OFFSET_START] = details.Fraction * GetTickInterval();
    map.SetArray(key, details, sizeof(details));
}

bool TREnumTriggerCS(int entity, any fraction) {

    if (entity <= MaxClients) {
        return true;
    }

    char sClass[32];
    GetEntityClassname(entity, sClass, sizeof(sClass));

    if(StrContains(sClass, "trigger_multiple") > -1)
    {
        TR_ClipCurrentRayToEntity(MASK_ALL, entity);
        
        fraction = TR_GetFraction();

        return false;
    }
    return true;
}
