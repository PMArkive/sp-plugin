#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_core>
#include <fuckTimer_maps>
#include <fuckTimer_timer>
#include <fuckTimer_zones>

enum struct PlayerData
{
    char Zone[MAX_ZONE_NAME_LENGTH];

    int Stage;
    int Checkpoint;
    int Bonus;

    void Reset(bool zoneOnly)
    {
        this.Zone[0] = '\0';

        if (!zoneOnly)
        {
            this.Stage = 0;
            this.Checkpoint = 0;
            this.Bonus = 0;
        }
    }
}

PlayerData Player[MAXPLAYERS + 1];

int g_iStages = 0;
int g_iCheckpoints = 0;
int g_iBonus = 0;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "HUD",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void OnMapStart()
{
    g_iStages = 0;
    g_iCheckpoints = 0;
    g_iBonus = 0;
}

public void OnClientPutInServer(int client)
{
    Player[client].Reset(false);
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

                if (iStage > 0 && iStage > g_iStages)
                {
                    g_iStages = iStage;
                }

                iStage = 0;
            }

            if (StrEqual(sKey, "Checkpoint", false))
            {
                smValues.GetString(sKey, sValue, sizeof(sValue));

                iCheckpoint = StringToInt(sValue);

                if (iCheckpoint > 0 && iCheckpoint > g_iCheckpoints)
                {
                    g_iCheckpoints = iCheckpoint;
                }

                iCheckpoint = 0;
            }

            if (StrEqual(sKey, "Bonus", false))
            {
                smValues.GetString(sKey, sValue, sizeof(sValue));

                iBonus = StringToInt(sValue);

                if (iBonus > 0 && iBonus > g_iBonus)
                {
                    g_iBonus = iBonus;
                }

                iBonus = 0;
            }
        }
    }

    delete snap;
}

public void OnGameFrame()
{
    float fTime = 0.0;

    fuckTimer_LoopClients(client, false, false)
    {
        char sTime[16];
        FormatEx(sTime, sizeof(sTime), "Time: N/A");

        fTime = fuckTimer_GetClientTime(client, TimeMain);

        if (fTime > 0.0)
        {
            fTime = GetGameTime() - fTime;
            FormatEx(sTime, sizeof(sTime), "Time: %.3f", fTime);
        }

        if (fTime  == 0.0)
        {
            fTime = fuckTimer_GetClientTime(client, TimeBonus);

            if (fTime > 0.0)
            {
                fTime = GetGameTime() - fTime;
                FormatEx(sTime, sizeof(sTime), "Bonus: %.3f", fTime);
            }
        }

        char sZone[MAX_ZONE_NAME_LENGTH + 6], sCPStage[12];

        if (strlen(Player[client].Zone) > 1)
        {
            FormatEx(sZone, sizeof(sZone), " | Zone: %s", Player[client].Zone);
        }

        if (g_iStages > 0)
        {
            FormatEx(sCPStage, sizeof(sCPStage), "Stage: %d/%d", Player[client].Stage, g_iStages);
        }
        else if (g_iCheckpoints > 0)
        {
            FormatEx(sCPStage, sizeof(sCPStage), "CP: %d/%d", Player[client].Checkpoint, g_iCheckpoints);
        }
        else
        {
            FormatEx(sCPStage, sizeof(sCPStage), "Linear");
        }

        if (g_iBonus > 0 && Player[client].Bonus > 0)
        {
            FormatEx(sCPStage, sizeof(sCPStage), "Bonus: %d/%d", Player[client].Bonus, g_iBonus);
        }
        
        PrintCSGOHUDText(client, " Speed: %.0f | %s\n %s%s\n Tier: %d", GetClientSpeed(client), sTime, sCPStage, sZone, fuckTimer_GetMapTier());
    }
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    Player[client].Reset(false);

    if (start)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Start");
        
        if (g_iStages > 0)
        {
            Player[client].Stage = 1;
        }

        if (g_iCheckpoints > 0)
        {
            Player[client].Checkpoint = 1;
        }

        if (bonus > 0)
        {
            Player[client].Bonus = bonus;
        }
    }
    else if (end)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "End");
    }
    
    if (stage > 0)
    {
        Player[client].Stage = stage;
        Player[client].Bonus = 0;
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Stage %d", stage);
    }
    
    if (checkpoint > 0)
    {
        Player[client].Checkpoint = checkpoint;
        Player[client].Bonus = 0;
    }
    
    if (bonus > 0)
    {
        Player[client].Bonus = bonus;
        Player[client].Stage = 0;
        Player[client].Checkpoint = 0;
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Bonus %d", bonus);
    }
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint, int bonus)
{
    Player[client].Reset(true);

    if (Player[client].Bonus == 0)
    {
        if ((start && g_iStages > 0))
        {
            Player[client].Stage = 1;
        }
        else if (stage > 0)
        {
            Player[client].Stage = stage;
        }

        if ((start && g_iCheckpoints > 0))
        {
            Player[client].Checkpoint = 1;
        }
        else if (checkpoint > 0)
        {
            Player[client].Checkpoint = checkpoint;
        }
    }

    if (Player[client].Stage == 0 && Player[client].Checkpoint == 0)
    {
        if ((start && bonus > 0))
        {
            Player[client].Bonus = bonus;
        }
    }
}

void PrintCSGOHUDText(int client, const char[] format, any ...)
{
    char sMessage[225];
    VFormat(sMessage, sizeof(sMessage), format, 3);
    Format(sMessage, sizeof(sMessage), "</font>%s ", sMessage);
    
    for(int i = strlen(sMessage); i < sizeof(sMessage); i++)
    {
        sMessage[i] = '\n';
    }
    
    Protobuf pbBuf = view_as<Protobuf>(StartMessageOne("TextMsg", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS));
    pbBuf.SetInt("msg_dst", 4);
    pbBuf.AddString("params", "#SFUI_ContractKillStart");
    pbBuf.AddString("params", sMessage);
    pbBuf.AddString("params", NULL_STRING);
    pbBuf.AddString("params", NULL_STRING);
    pbBuf.AddString("params", NULL_STRING);
    pbBuf.AddString("params", NULL_STRING);
    
    EndMessage();
}
