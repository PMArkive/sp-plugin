#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_core>
#include <fuckTimer_maps>
#include <fuckTimer_timer>
#include <fuckTimer_zones>
#include <fuckTimer_styles>
#include <fuckTimer_players>

enum struct PlayerData
{
    char Zone[MAX_ZONE_NAME_LENGTH];

    void Reset(bool zoneOnly)
    {
        this.Zone[0] = '\0';
    }
}

PlayerData Player[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "HUD",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void OnClientPutInServer(int client)
{
    Player[client].Reset(false);
}

public void OnGameFrame()
{
    float fTime = 0.0;

    fuckTimer_LoopClients(client, false, false)
    {
        fTime = fuckTimer_GetClientTime(client, TimeMain);

        if (fTime > 0.0)
        {
            fTime = GetGameTime() - fTime;
        }

        if (fTime  == 0.0)
        {
            fTime = fuckTimer_GetClientTime(client, TimeBonus, fuckTimer_GetClientBonus(client));

            if (fTime > 0.0)
            {
                fTime = GetGameTime() - fTime;
            }
        }

        float fCPStageTime = 0.0;
        char sTime[16], sCPStageTime[16], sZone[MAX_ZONE_NAME_LENGTH + 6], sCPStage[32];
        GetTimeBySeconds(fTime, sTime, sizeof(sTime));

        if (strlen(Player[client].Zone) > 1)
        {
            FormatEx(sZone, sizeof(sZone), " | Zone: %s", Player[client].Zone);
        }

        int iCheckpoint = fuckTimer_GetClientCheckpoint(client);
        int iStage = fuckTimer_GetClientStage(client);

        int iStages = fuckTimer_GetAmountOfStages();
        int iCheckpoints = fuckTimer_GetAmountOfCheckpoints();

        int iValidator = 0;

        if (iStages > 0)
        {
            fCPStageTime = fuckTimer_GetClientTime(client, TimeStage, iStage);

            if (fCPStageTime > 0.0)
            {
                fCPStageTime = GetGameTime() - fCPStageTime;
            }

            if (strlen(Player[client].Zone) < 1)
            {
                GetTimeBySeconds(fCPStageTime, sCPStageTime, sizeof(sCPStageTime));
            }
            else
            {
                FormatEx(sCPStageTime, sizeof(sCPStageTime), "0.000");
            }

            FormatEx(sCPStage, sizeof(sCPStage), "Stage: %d/%d | Time: %s", iStage, iStages, sCPStageTime);

            iValidator = fuckTimer_GetValidatorCount(iStage);
        }
        else if (iCheckpoints > 0)
        {
            fCPStageTime = fuckTimer_GetClientTime(client, TimeCheckpoint, iCheckpoint);

            if (fCPStageTime > 0.0)
            {
                fCPStageTime = GetGameTime() - fCPStageTime;
            }

            GetTimeBySeconds(fCPStageTime, sCPStageTime, sizeof(sCPStageTime));
            FormatEx(sCPStage, sizeof(sCPStage), "CP: %d/%d | Time: %s", iCheckpoint, iCheckpoints, sCPStageTime);

            iValidator = fuckTimer_GetValidatorCount(iCheckpoint);
        }
        else
        {
            FormatEx(sCPStage, sizeof(sCPStage), "Linear");
        }

        int iBonus = fuckTimer_GetClientBonus(client);
        int iMaxBonus = fuckTimer_GetAmountOfBonus();

        if (iMaxBonus > 0 && iBonus > 0)
        {
            FormatEx(sCPStage, sizeof(sCPStage), "Bonus: %d/%d", iBonus, iMaxBonus);
        }

        char sValidator[24];

        if (iValidator > 0)
        {
            FormatEx(sValidator, sizeof(sValidator), "| Validator: %d/%d", fuckTimer_GetClientValidator(client), iValidator);
        }

        Styles style = fuckTimer_GetClientStyle(client);

        char sStyle[MAX_STYLE_NAME_LENGTH];
        fuckTimer_GetStyleName(style, sStyle, sizeof(sStyle));
        
        PrintCSGOHUDText(client, " Speed: %.0f | %s\n %s\n Tier: %d%s\n Style: %s %s", GetClientSpeed(client), sTime, sCPStage, fuckTimer_GetMapTier(), sZone, sStyle, sValidator);
    }
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus)
{
    Player[client].Reset(false);

    if (start)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Start");
    }
    else if (end)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "End");
    }
    
    if (stage > 0)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Stage %d", stage);
    }
    
    if (bonus > 0)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Bonus %d", bonus);
    }
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus)
{
    Player[client].Reset(true);
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
