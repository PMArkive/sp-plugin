#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_timer>
#include <fuckTimer_zones>

enum struct Variables
{
    ConVar DisableCZZones;

    GlobalForward OnEnteringZone;
    GlobalForward OnTouchZone;
    GlobalForward OnLeavingZone;
}
Variables Core;

ZoneDetails Zone[MAX_ENTITIES];

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Zones",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    Core.OnEnteringZone = new GlobalForward("fuckTimer_OnEnteringZone", ET_Ignore, Param_Cell, Param_Cell, Param_String);
    Core.OnTouchZone = new GlobalForward("fuckTimer_OnTouchZone", ET_Ignore, Param_Cell, Param_Cell, Param_String);
    Core.OnLeavingZone = new GlobalForward("fuckTimer_OnLeavingZone", ET_Ignore, Param_Cell, Param_Cell, Param_String);

    CreateNative("fuckTimer_GetStartZone", Native_GetStartZone);
    CreateNative("fuckTimer_GetEndZone", Native_GetEndZone);

    CreateNative("fuckTimer_IsStartZone", Native_IsStartZone);
    CreateNative("fuckTimer_IsEndZone", Native_IsEndZone);
    CreateNative("fuckTimer_IsMiscZone", Native_IsMiscZone);
    CreateNative("fuckTimer_IsValidatorZone", Native_IsValidatorZone);
    CreateNative("fuckTimer_IsTeleToStartZone", Native_IsTeleToStartZone);
    CreateNative("fuckTimer_IsStopZone", Native_IsStopZone);
    CreateNative("fuckTimer_IsAntiJumpZone", Native_IsAntiJumpZone);
    CreateNative("fuckTimer_IsCheckerZone", Native_IsCheckerZone);

    CreateNative("fuckTimer_GetZoneBonus", Native_GetZoneBonus);

    CreateNative("fuckTimer_GetCheckpointZone", Native_GetCheckpointZone);
    CreateNative("fuckTimer_GetStageZone", Native_GetStageZone);

    CreateNative("fuckTimer_GetCheckpointByIndex", Native_GetCheckpointByIndex);
    CreateNative("fuckTimer_GetStageByIndex", Native_GetStageByIndex);

    RegPluginLibrary("fuckTimer_zones");

    return APLRes_Success;
}

public void OnConfigsExecuted()
{
    Core.DisableCZZones = FindConVar("fuckZones_disable_circle_polygon_zones");
    Core.DisableCZZones.SetBool(true);
    Core.DisableCZZones.AddChangeHook(OnChangeHook);
}

public void OnChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == Core.DisableCZZones)
    {
        bool bDisable = view_as<bool>(StringToInt(newValue));

        if (!bDisable)
        {
            Core.DisableCZZones.SetBool(true);
        }
    }
}

public void OnMapStart()
{
    for (int i = MaxClients; i < MAX_ENTITIES; i++)
    {
        Zone[i].Reset();
    }
}

public void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type)
{
    StringMap smEffects = fuckZones_GetZoneEffects(entity);

    char sValue[12];

    GetfuckTimerZoneValue(smEffects, "Start", sValue, sizeof(sValue));
    Zone[entity].Start = view_as<bool>(StringToInt(sValue));

    GetfuckTimerZoneValue(smEffects, "End", sValue, sizeof(sValue));
    Zone[entity].End = view_as<bool>(StringToInt(sValue));

    GetfuckTimerZoneValue(smEffects, "Bonus", sValue, sizeof(sValue));
    Zone[entity].Bonus = StringToInt(sValue);

    if (Zone[entity].Start)
    {
        Zone[entity].Stage = 1;
    }

    GetfuckTimerZoneValue(smEffects, "Checkpoint", sValue, sizeof(sValue));
    int iCheckpoint = StringToInt(sValue);

    GetfuckTimerZoneValue(smEffects, "Stage", sValue, sizeof(sValue));
    int iStage = StringToInt(sValue);

    if (iCheckpoint > 0)
    {
        Zone[entity].Checkpoint = iCheckpoint;
    }
    
    if (iStage > 0)
    {
        Zone[entity].Stage = iStage;
    }

    if (GetfuckTimerZoneValue(smEffects, "Misc", sValue, sizeof(sValue)))
    {
        Zone[entity].Misc = view_as<bool>(StringToInt(sValue));

        if (GetfuckTimerZoneValue(smEffects, "Validator", sValue, sizeof(sValue)))
        {
            Zone[entity].Validator = view_as<bool>(StringToInt(sValue));
        }

        if (GetfuckTimerZoneValue(smEffects, "TeleToStart", sValue, sizeof(sValue)))
        {
            Zone[entity].TeleToStart = view_as<bool>(StringToInt(sValue));
        }

        if (GetfuckTimerZoneValue(smEffects, "Stop", sValue, sizeof(sValue)))
        {
            Zone[entity].Stop = view_as<bool>(StringToInt(sValue));
        }

        if (GetfuckTimerZoneValue(smEffects, "AntiJump", sValue, sizeof(sValue)))
        {
            Zone[entity].AntiJump = view_as<bool>(StringToInt(sValue));
        }

        if (GetfuckTimerZoneValue(smEffects, "Checker", sValue, sizeof(sValue)))
        {
            Zone[entity].Checker = view_as<bool>(StringToInt(sValue));
            
            if (GetfuckTimerZoneValue(smEffects, "Validator", sValue, sizeof(sValue)))
            {
                Zone[entity].Validators = StringToInt(sValue);
            }
        }
    }
}

public void fuckZones_OnEffectsReady()
{
    fuckZones_RegisterEffect(FUCKTIMER_EFFECT_NAME, OneZoneStartTouch, OnZoneTouch, OnZoneEndTouch);

    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Tier", "0");

    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Start", "0");
    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "End", "0");
    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Misc", "0");
    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Stop", "0");

    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Stage", "0");
    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Checkpoint", "0");

    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Bonus", "0");

    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "TeleToStart", "0");
    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Checker", "0");
    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "Validator", "0");
    fuckZones_RegisterEffectKey(FUCKTIMER_EFFECT_NAME, "AntiJump", "0");
}

public void OneZoneStartTouch(int client, int entity, StringMap values)
{
    char sName[MAX_ZONE_NAME_LENGTH];
    fuckZones_GetZoneName(entity, sName, sizeof(sName));

    Call_StartForward(Core.OnEnteringZone);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_PushString(sName);
    Call_Finish();
}

public void OnZoneTouch(int client, int entity, StringMap values)
{
    char sName[MAX_ZONE_NAME_LENGTH];
    fuckZones_GetZoneName(entity, sName, sizeof(sName));

    Call_StartForward(Core.OnTouchZone);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_PushString(sName);
    Call_Finish();
}

public void OnZoneEndTouch(int client, int entity, StringMap values)
{
    char sName[MAX_ZONE_NAME_LENGTH];
    fuckZones_GetZoneName(entity, sName, sizeof(sName));

    Call_StartForward(Core.OnLeavingZone);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_PushString(sName);
    Call_Finish();
}

public int Native_GetStartZone(Handle plugin, int numParams)
{
    for (int i = MaxClients; i < MAX_ENTITIES; i++)
    {
        if (Zone[i].Start && Zone[i].Bonus == GetNativeCell(1))
        {
            return i;
        }
    }

    return -1;
}

public int Native_GetEndZone(Handle plugin, int numParams)
{
    for (int i = MaxClients; i < MAX_ENTITIES; i++)
    {
        if (Zone[i].End && Zone[i].Bonus == GetNativeCell(1))
        {
            return i;
        }
    }

    return -1;
}

public int Native_IsStartZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].Start)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        return true;
    }

    return false;
}

public int Native_IsEndZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].End)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        return true;
    }

    return false;
}

public int Native_IsMiscZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].Misc)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        return true;
    }

    return false;
}

public int Native_IsValidatorZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].Validator)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        return true;
    }

    return false;
}

public int Native_IsTeleToStartZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].TeleToStart)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        return true;
    }

    return false;
}

public int Native_IsStopZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].Stop)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        return true;
    }

    return false;
}

public int Native_IsAntiJumpZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].AntiJump)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        return true;
    }

    return false;
}

public int Native_IsCheckerZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    if (Zone[iEntity].Checker)
    {
        SetNativeCellRef(2, Zone[iEntity].Bonus);
        SetNativeCellRef(3, Zone[iEntity].Validators);
        return true;
    }

    return false;
}

public int Native_GetCheckpointZone(Handle plugin, int numParams)
{
    int bonus = GetNativeCell(1);
    int checkpoint = GetNativeCell(2);

    for (int i = MaxClients; i < MAX_ENTITIES; i++)
    {
        if (Zone[i].Bonus == bonus && Zone[i].Checkpoint == checkpoint)
        {
            return i;
        }
    }

    return -1;
}

public int Native_GetStageZone(Handle plugin, int numParams)
{
    int bonus = GetNativeCell(1);
    int stage = GetNativeCell(2);

    for (int i = MaxClients; i < MAX_ENTITIES; i++)
    {
        if (Zone[i].Bonus == bonus && Zone[i].Stage == stage)
        {
            return i;
        }
    }

    return -1;
}

public int Native_GetZoneBonus(Handle plugin, int numParams)
{
    return Zone[GetNativeCell(1)].Bonus;
}

public int Native_GetCheckpointByIndex(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    SetNativeCellRef(2, Zone[iEntity].Bonus);
    return Zone[iEntity].Checkpoint;
}
public int Native_GetStageByIndex(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);

    SetNativeCellRef(2, Zone[iEntity].Bonus);
    return Zone[iEntity].Stage;
}
