#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <intmap>
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

    int StartZone;
    int EndZone;

    IntMap Checkpoint;
    IntMap Stage;
    IntMap Bonus;

    IntMap Validator;

    void Reset()
    {
        this.StartZone = -1;
        this.EndZone = -1;

        delete this.Checkpoint;
        delete this.Stage;
        delete this.Bonus;

        if (this.Validator != null)
        {
            IntMapSnapshot imSnap = this.Validator.Snapshot();

            for (int i = 0; i < imSnap.Length; i++)
            {
                int iIndex = imSnap.GetKey(i);

                ArrayList alArray = null;

                if (this.Validator.GetValue(iIndex, alArray))
                {
                    delete alArray;
                }
            }

            delete imSnap;
        }

        delete this.Validator;
    }

    void Init()
    {
        this.StartZone = -1;
        this.EndZone = -1;

        this.Checkpoint = new IntMap();
        this.Stage = new IntMap();
        this.Bonus = new IntMap();

        this.Validator = new IntMap();
    }
}
Variables Core;

bool g_bBonusZone[2048] = { false, ... };

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
    Core.OnEnteringZone = new GlobalForward("fuckTimer_OnEnteringZone", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    Core.OnTouchZone = new GlobalForward("fuckTimer_OnTouchZone", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    Core.OnLeavingZone = new GlobalForward("fuckTimer_OnLeavingZone", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

    CreateNative("fuckTimer_GetStartZone", Native_GetStartZone);
    CreateNative("fuckTimer_GetEndZone", Native_GetEndZone);
    CreateNative("fuckTimer_GetCheckpointZone", Native_GetCheckpointZone);
    CreateNative("fuckTimer_GetStageZone", Native_GetStageZone);
    CreateNative("fuckTimer_GetBonusZone", Native_GetBonusZone);
    CreateNative("fuckTimer_GetValidatorCount", Native_GetValidatorCount);
    CreateNative("fuckTimer_IsNormalZone", Native_IsBonusZone);

    RegPluginLibrary("fuckTimer_zones");

    return APLRes_Success;
}

public void OnMapStart()
{
    Core.Reset();
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

public void OnEntityCreated(int entity, const char[] classname)
{
    g_bBonusZone[entity] = false;
}

public void OnEntityDestroyed(int entity)
{
    g_bBonusZone[entity] = false;
}

public void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type)
{
    if (Core.Stage == null)
    {
        Core.Init();
    }

    StringMap smEffects = fuckZones_GetZoneEffects(entity);

    char sValue[12];

    if (StrContains(zone_name, "main0_start", false) != -1)
    {
        Core.StartZone = entity;
        Core.Stage.SetValue(1, entity);

        return;
    }
    else if (StrContains(zone_name, "main0_end", false) != -1)
    {
        Core.EndZone = entity;
        return;
    }

    GetfuckTimerZoneValue(smEffects, "Checkpoint", sValue, sizeof(sValue));
    int iCheckpoint = StringToInt(sValue);

    GetfuckTimerZoneValue(smEffects, "Stage", sValue, sizeof(sValue));
    int iStage = StringToInt(sValue);

    GetfuckTimerZoneValue(smEffects, "Bonus", sValue, sizeof(sValue));
    int iBonus = StringToInt(sValue);

    if (iBonus > 0)
    {
        g_bBonusZone[entity] = true;
    }

    if (StrContains(zone_name, "checkpoint", false) != -1 && iCheckpoint > 0)
    {
        Core.Checkpoint.SetValue(iCheckpoint, entity);
        return;
    }
    else if (StrContains(zone_name, "stage", false) != -1 && iStage > 0)
    {
        Core.Stage.SetValue(iStage, entity);
        return;
    }
    else if (StrContains(zone_name, "bonus", false) != -1 && iBonus > 0)
    {
        Core.Bonus.SetValue(iBonus, entity);
        return;
    }

    if (StrContains(zone_name, "validator", false) != -1 && GetfuckTimerZoneValue(smEffects, "Validator", sValue, sizeof(sValue)) &&
            (
                iCheckpoint > 0 || iStage > 0
            )
        )
    {
        bool bValidator = view_as<bool>(StringToInt(sValue));

        if (bValidator)
        {
            int iLevel = 0;

            if (iCheckpoint > 0)
            {
                iLevel = iCheckpoint;
            }
            else if (iStage > 0)
            {
                iLevel = iStage;
            }
            else
            {
                LogError("Validator zone detected without valid checkpoint/stage value.");
                return;
            }

            ArrayList alArray = null;

            Core.Validator.GetValue(iLevel, alArray);

            if (alArray == null)
            {
                alArray = new ArrayList();
                Core.Validator.SetValue(iLevel, alArray);
            }

            alArray.Push(EntIndexToEntRef(entity));

            return;
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

    PrintToChat(client, "OneZoneStartTouch - Name: %s", sName);

    Call_StartForward(Core.OnEnteringZone);
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

    Call_StartForward(Core.OnTouchZone);
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

    PrintToChat(client, "OnZoneEndTouch - Name: %s", sName);

    Call_StartForward(Core.OnLeavingZone);
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
    return Core.StartZone;
}

public int Native_GetEndZone(Handle plugin, int numParams)
{
    return Core.EndZone;
}

public int Native_GetCheckpointZone(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    int iEntity;
    bool success = Core.Checkpoint.GetValue(level, iEntity);

    if (success)
    {
        return iEntity;
    }
    else
    {
        return 0;
    }
}

public int Native_GetStageZone(Handle plugin, int numParams)
{
    int level = GetNativeCell(1);

    int iEntity;
    bool success = Core.Stage.GetValue(level, iEntity);

    if (success)
    {
        return iEntity;
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
    bool success = Core.Bonus.GetValue(level, iLevel);

    if (success)
    {
        return iLevel;
    }
    else
    {
        return 0;
    }
}

public int Native_GetValidatorCount(Handle plugin, int numParams)
{
    if (fuckTimer_GetAmountOfStages() > 1)
    {
        ArrayList alArray = null;

        Core.Validator.GetValue(GetNativeCell(1), alArray);

        if (alArray != null)
        {
            return alArray.Length;
        }
    }
    else
    {
        ArrayList alArray = null;

        Core.Validator.GetValue(0, alArray);

        if (alArray != null)
        {
            return alArray.Length;
        }
    }

    return 0;
}

public int Native_IsBonusZone(Handle plugin, int numParams)
{
    int iEntity = GetNativeCell(1);
    
    return g_bBonusZone[iEntity];
}
