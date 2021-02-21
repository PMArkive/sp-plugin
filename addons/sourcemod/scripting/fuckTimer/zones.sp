#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <intmap>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>

GlobalForward g_fwOnEnteringZone = null;
GlobalForward g_fwOnTouchZone = null;
GlobalForward g_fwOnLeavingZone = null;

int g_iStartZone = -1;
int g_iEndZone = -1;

IntMap g_imCheckpoint = null;
IntMap g_imStage = null;
IntMap g_imBonus = null;

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
    g_fwOnEnteringZone = new GlobalForward("fuckTimer_OnEnteringZone", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnTouchZone = new GlobalForward("fuckTimer_OnTouchZone", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_fwOnLeavingZone = new GlobalForward("fuckTimer_OnLeavingZone", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

    CreateNative("fuckTimer_GetStartZone", Native_GetStartZone);
    CreateNative("fuckTimer_GetEndZone", Native_GetEndZone);
    CreateNative("fuckTimer_GetCheckpointZone", Native_GetCheckpointZone);
    CreateNative("fuckTimer_GetStageZone", Native_GetStageZone);
    CreateNative("fuckTimer_GetBonusZone", Native_GetBonusZone);

    RegPluginLibrary("fuckTimer_zones");

    return APLRes_Success;
}

public void OnMapStart()
{
    g_iStartZone = -1;
    g_iEndZone = -1;

    delete g_imCheckpoint;
    g_imCheckpoint = new IntMap();

    delete g_imStage;
    g_imStage = new IntMap();

    delete g_imBonus;
    g_imBonus = new IntMap();
}

public void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type)
{
    StringMap smEffects = fuckZones_GetZoneEffects(entity);

    char sBuffer[12];

    if (StrContains(zone_name, "main0_start", false) != -1)
    {
        g_iStartZone = entity;

        g_imStage.SetValue(1, entity);
    }
    else if (StrContains(zone_name, "main0_end", false) != -1)
    {
        g_iEndZone = entity;
    }
    else if (StrContains(zone_name, "Stage", false) != -1 && GetfuckTimerZoneValue(smEffects, "Stage", sBuffer, sizeof(sBuffer)))
    {
        int iStage = StringToInt(sBuffer);

        if (iStage > 0)
        {
            g_imStage.SetValue(iStage, entity);
        }
    }
    else if (StrContains(zone_name, "Checkpoint", false) != -1 && GetfuckTimerZoneValue(smEffects, "Checkpoint", sBuffer, sizeof(sBuffer)))
    {
        int iCheckpoint = StringToInt(sBuffer);

        if (iCheckpoint > 0)
        {
            g_imCheckpoint.SetValue(iCheckpoint, entity);
        }
    }
    else if (StrContains(zone_name, "Bonus", false) != -1 && GetfuckTimerZoneValue(smEffects, "Bonus", sBuffer, sizeof(sBuffer)))
    {
        int iBonus = StringToInt(sBuffer);

        if (iBonus > 0)
        {
            g_imBonus.SetValue(iBonus, entity);
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
}

public void OneZoneStartTouch(int client, int entity, StringMap values)
{
    char sName[MAX_ZONE_NAME_LENGTH];
    fuckZones_GetZoneName(entity, sName, sizeof(sName));

    Call_StartForward(g_fwOnEnteringZone);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_PushString(sName);
    Call_PushCell(IsStartZone(values));
    Call_PushCell(IsMiscZone(values));
    Call_PushCell(IsEndZone(values));
    Call_PushCell(GetStageNumber(values));
    Call_PushCell(GetCheckpointNumber(values));
    Call_PushCell(GetBonusNumber(values));
    Call_Finish();
}

public void OnZoneTouch(int client, int entity, StringMap values)
{
    char sName[MAX_ZONE_NAME_LENGTH];
    fuckZones_GetZoneName(entity, sName, sizeof(sName));

    Call_StartForward(g_fwOnTouchZone);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_PushString(sName);
    Call_PushCell(IsStartZone(values));
    Call_PushCell(IsMiscZone(values));
    Call_PushCell(IsEndZone(values));
    Call_PushCell(GetStageNumber(values));
    Call_PushCell(GetCheckpointNumber(values));
    Call_PushCell(GetBonusNumber(values));
    Call_Finish();
}

public void OnZoneEndTouch(int client, int entity, StringMap values)
{
    char sName[MAX_ZONE_NAME_LENGTH];
    fuckZones_GetZoneName(entity, sName, sizeof(sName));

    Call_StartForward(g_fwOnLeavingZone);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_PushString(sName);
    Call_PushCell(IsStartZone(values));
    Call_PushCell(IsMiscZone(values));
    Call_PushCell(IsEndZone(values));
    Call_PushCell(GetStageNumber(values));
    Call_PushCell(GetCheckpointNumber(values));
    Call_PushCell(GetBonusNumber(values));
    Call_Finish();
}

bool IsStartZone(StringMap values)
{
    char sValue[MAX_KEY_VALUE_LENGTH];
    if (GetZoneValue(values, "Start", sValue, sizeof(sValue)))
    {
        return view_as<bool>(StringToInt(sValue));
    }
    return false;
}

bool IsMiscZone(StringMap values)
{
    char sValue[MAX_KEY_VALUE_LENGTH];
    if (GetZoneValue(values, "Misc", sValue, sizeof(sValue)))
    {
        return view_as<bool>(StringToInt(sValue));
    }
    return false;
}

bool IsEndZone(StringMap values)
{
    char sValue[MAX_KEY_VALUE_LENGTH];
    if (GetZoneValue(values, "End", sValue, sizeof(sValue)))
    {
        return view_as<bool>(StringToInt(sValue));
    }
    return false;
}

int GetStageNumber(StringMap values)
{
    char sValue[MAX_KEY_VALUE_LENGTH];
    if (GetZoneValue(values, "Stage", sValue, sizeof(sValue)))
    {
        return StringToInt(sValue);
    }
    return 0;
}

int GetCheckpointNumber(StringMap values)
{
    char sValue[MAX_KEY_VALUE_LENGTH];
    if (GetZoneValue(values, "Checkpoint", sValue, sizeof(sValue)))
    {
        return StringToInt(sValue);
    }
    return 0;
}

int GetBonusNumber(StringMap values)
{
    char sValue[MAX_KEY_VALUE_LENGTH];
    if (GetZoneValue(values, "Bonus", sValue, sizeof(sValue)))
    {
        return StringToInt(sValue);
    }
    return 0;
}

public int Native_GetStartZone(Handle plugin, int numParams)
{
    return g_iStartZone;
}

public int Native_GetEndZone(Handle plugin, int numParams)
{
    return g_iEndZone;
}

public int Native_GetCheckpointZone(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    int iLevel;
    bool success = g_imCheckpoint.GetValue(level, iLevel);

    if (success)
    {
        return iLevel;
    }
    else
    {
        return 0;
    }
}

public int Native_GetStageZone(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    int iLevel;
    bool success = g_imStage.GetValue(level, iLevel);

    if (success)
    {
        return iLevel;
    }
    else
    {
        return 0;
    }
}

public int Native_GetBonusZone(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    int iLevel;
    bool success = g_imBonus.GetValue(level, iLevel);

    if (success)
    {
        return iLevel;
    }
    else
    {
        return 0;
    }
}
