#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <discordWebhookAPI>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_records>

enum struct PluginData
{
    ConVar Webhook;
    ConVar SteamKey;
    ConVar BotAvatar;
    ConVar BotName;
    ConVar FooterImage;
    ConVar PRColor;
    ConVar SRColor;
    ConVar MapImage;
    ConVar MapBase;
}
PluginData Core;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Discord",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void OnPluginStart()
{
    fuckTimer_StartConfig("discord");
    Core.Webhook = AutoExecConfig_CreateConVar("discord_webhook", "", "Webhook URL for all records to your specific discord channel", FCVAR_PROTECTED);
    Core.SteamKey = AutoExecConfig_CreateConVar("discord_steam_key", "", "Set your steam api key here", FCVAR_PROTECTED);
    Core.BotAvatar = AutoExecConfig_CreateConVar("discord_bot_avatar", "", "Avatar URL for your webhook bot/account");
    Core.BotName = AutoExecConfig_CreateConVar("discord_bot_name", "", "Name for your webhook bot/account");
    Core.FooterImage = AutoExecConfig_CreateConVar("discord_footer_image", "", "Footer Image URL for your webhook bot/account");
    Core.PRColor = AutoExecConfig_CreateConVar("discord_personal_color", "65427", "Decimal color code for personal records\nHex to Decimal - https://www.rapidtables.com/convert/number/hex-to-decimal.html");
    Core.SRColor = AutoExecConfig_CreateConVar("discord_server_color", "16758272", "Decimal color code for server records\nHex to Decimal - https://www.rapidtables.com/convert/number/hex-to-decimal.html");
    Core.MapImage = AutoExecConfig_CreateConVar("discord_map_image", "1", "Where the map image should be shown. (0 - Disabled, 1 - Thumbnail, 2 - Big Image)", _, true, 0.0, true, 2.0);
    Core.MapBase = AutoExecConfig_CreateConVar("discord_map_base", "https://image.gametracker.com/images/maps/160x120/csgo/<MAP>.jpg", "Base URL for map images.\nNote: <MAP> must be definied as map name\nExample: \"surf_easy1\" becomes <MAP>");
    fuckTimer_EndConfig();
}

public void fuckTimer_OnNewRecord(int client, bool serverRecord, StringMap temp, float oldTime)
{
    // Copy all handles, before it'll be deleted and we get some errors
    StringMap recordDetails = view_as<StringMap>(CloneHandle(temp));
    IntMap moreTemp;
    temp.GetValue("Details", moreTemp);
    if (moreTemp != null)
    {
        recordDetails.SetValue("Details", CloneHandle(moreTemp));
    }

    char sSteam[64];
    Core.SteamKey.GetString(sSteam, sizeof(sSteam));

    if (strlen(sSteam) < 1)
    {
        PrepareMessage(client, serverRecord, recordDetails, oldTime, "");
        return;
    }

    char sCommunityId[32];
    GetClientAuthId(client, AuthId_SteamID64, sCommunityId, sizeof(sCommunityId));

    char sEndpoint[256];
    FormatEx(sEndpoint, sizeof(sEndpoint), "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s", sSteam, sCommunityId);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(view_as<int>(serverRecord));
    pack.WriteCell(view_as<int>(recordDetails));
    pack.WriteFloat(oldTime);

    HTTPRequest request = new HTTPRequest(sEndpoint);
    request.Get(OnHTTPResponse, pack);
}

public void OnHTTPResponse(HTTPResponse response, DataPack pack)
{
    if (response.Status != HTTPStatus_OK) {
        LogMessage("[fuckTimer.Discord.OnHTTPResponse] Status Code: %d", response.Status);

        pack.Reset();
        pack.ReadCell(); // TODO: DataPack.Position?
        pack.ReadCell();
        StringMap recordDetails = view_as<StringMap>(pack.ReadCell());
        IntMap imDetails;
        recordDetails.GetValue("Details", imDetails);
        delete imDetails;
        delete recordDetails;
        delete pack;
        return;
    }

    JSONObject jObj = view_as<JSONObject>(view_as<JSONObject>(response.Data).Get("response"));
    JSONArray jArr = view_as<JSONArray>(jObj.Get("players"));

    JSONObject jPlayer = view_as<JSONObject>(jArr.Get(0));
    
    char sAvatar[256];
    jPlayer.GetString("avatarmedium", sAvatar, sizeof(sAvatar));
    
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    bool bServerRecord = view_as<bool>(pack.ReadCell());
    StringMap recordDetails = view_as<StringMap>(pack.ReadCell());
    float fOldTime = pack.ReadFloat();

    PrepareMessage(client, bServerRecord, recordDetails, fOldTime, sAvatar);

    delete jPlayer;
    delete jArr;
    delete jObj;
    delete pack;
}

void PrepareMessage(int client, bool serverRecord, StringMap recordDetails, float oldTime, char[] avatar)
{
    Webhook wWebhook = new Webhook();

    char sBuffer[512];
    Core.BotAvatar.GetString(sBuffer, sizeof(sBuffer));
    wWebhook.SetAvatarURL(sBuffer);
    Core.BotName.GetString(sBuffer, sizeof(sBuffer));
    wWebhook.SetUsername(sBuffer);


    Embed eEmbed = new Embed();

    char sName[MAX_NAME_LENGTH];
    GetClientName(client, sName, sizeof(sName));
    EmbedAuthor aAuthor = new EmbedAuthor(sName);
    aAuthor.SetIconURL(avatar);
    GetClientAuthId(client, AuthId_SteamID64, sBuffer, sizeof(sBuffer));
    Format(sBuffer, sizeof(sBuffer), "https://steamcommunity.com/profiles/%s", sBuffer);
    aAuthor.SetURL(sBuffer);
    eEmbed.SetAuthor(aAuthor);
    delete aAuthor;

    FormatTime(sBuffer, sizeof(sBuffer), "%FT%T.000%z");
    eEmbed.SetTimeStampNow();
    eEmbed.SetColor(serverRecord ? Core.SRColor.IntValue : Core.PRColor.IntValue);
    // eEmbed.SetURL("..."); - when we've a statistic page?


    char sMap[PLATFORM_MAX_PATH];
    fuckTimer_GetCurrentWorkshopMap(sMap, sizeof(sMap));
    Core.MapBase.GetString(sBuffer, sizeof(sBuffer));
    ReplaceString(sBuffer, sizeof(sBuffer), "<MAP>", sMap, false);

    if (Core.MapImage.IntValue == 1)
    {
        EmbedThumbnail eThumbnail = new EmbedThumbnail(sBuffer);
        eEmbed.SetThumbnail(eThumbnail);
        delete eThumbnail;
    }
    else if (Core.MapImage.IntValue == 2)
    {
        EmbedImage eImage = new EmbedImage(sBuffer);
        eEmbed.SetImage(eImage);
        delete eImage;
    }

    FormatEx(sBuffer, sizeof(sBuffer), "New %s Record on %s", serverRecord ? "Server" : "Player", sMap);
    eEmbed.SetTitle(sBuffer);

    float fTime;
    recordDetails.GetValue("Time", fTime);
    GetTimeBySeconds(fTime, sBuffer, sizeof(sBuffer));
    EmbedField eTime = new EmbedField("Time", sBuffer, true);
    eEmbed.AddField(eTime);

    if (oldTime > 0.0)
    {
        float fDifference = fTime - oldTime;
        GetTimeBySeconds(fDifference, sBuffer, sizeof(sBuffer));
        EmbedField eDifference = new EmbedField("Difference", sBuffer, true);
        eEmbed.AddField(eDifference);
    }

    int iBonus;
    recordDetails.GetValue("Level", iBonus);

    
    TimeType type;
    recordDetails.GetValue("Type", type);
    if (iBonus > 0)
    {
        FormatEx(sBuffer, sizeof(sBuffer), "Bonus");
    }
    else
    {
        FormatEx(sBuffer, sizeof(sBuffer), "Main");
    }

    EmbedField eType = new EmbedField("Type", sBuffer, true);
    eEmbed.AddField(eType);

    if (iBonus > 0)
    {
        FormatEx(sBuffer, sizeof(sBuffer), "%d", iBonus);
        EmbedField eBonus = new EmbedField("Bonus", sBuffer, true);
        eEmbed.AddField(eBonus);
    }

    Styles style;
    recordDetails.GetValue("StyleId", style);
    fuckTimer_GetStyleName(style, sBuffer, sizeof(sBuffer));
    EmbedField eStyle = new EmbedField("Style", sBuffer, true);
    eEmbed.AddField(eStyle);

    int iAttempts;
    recordDetails.GetValue("Attempts", iAttempts);
    FormatEx(sBuffer, sizeof(sBuffer), "%d", iAttempts);
    EmbedField eAttempts = new EmbedField("Attempts", sBuffer, true);
    eEmbed.AddField(eAttempts);

    FindConVar("hostname").GetString(sBuffer, sizeof(sBuffer));
    EmbedFooter eFooter = new EmbedFooter(sBuffer);
    Core.FooterImage.GetString(sBuffer, sizeof(sBuffer));
    eFooter.SetIconURL(sBuffer);
    eEmbed.SetFooter(eFooter);
    delete eFooter;

    wWebhook.AddEmbed(eEmbed);
    Core.Webhook.GetString(sBuffer, sizeof(sBuffer));
    if (strlen(sBuffer) > 1)
    {
        wWebhook.Execute(sBuffer, OnWebHookExecuted);
    }
    delete wWebhook;

    IntMap imDetails;
    recordDetails.GetValue("Details", imDetails);
    delete imDetails;
    delete recordDetails;
}

public void OnWebHookExecuted(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_NoContent)
    {
        LogError("[Discord.OnWebHookExecuted] An error has occured while sending the webhook. Status Code: %d", response.Status);
    }
}

void GetTimeBySeconds(float seconds, char[] time, int length, eHUDTime format = HTMinimal, bool show0Hours = false)
{
    int iBuffer = RoundToFloor(seconds);
    float fSeconds = (iBuffer % 60) + seconds - iBuffer;
    int iMinutes = (iBuffer / 60) % 60;
    int iHours = RoundToFloor(iBuffer / 3600.0);

    if (format == HTMinimal)
    {
        FormatEx(time, length, "%.3f", fSeconds);
        
        if (seconds > 59.999)
        {
            Format(time, length, "%d:%s", iMinutes, time);
        }

        if (seconds > 3599.999)
        {
            Format(time, length, "%d:%s", iHours, time);
        }
    }
    else if (format == HTFull)
    {
        if (seconds < 60.0)
        { 
            FormatEx(time, length, "%s00:%s%.3f", show0Hours ? "00:" : "", seconds < 10 ? "0" : "", fSeconds);
        }
        else if (seconds < 3600.0)
        {
            Format(time, length, "%s%s%d:%s%.3f", show0Hours ? "00:" : "", iMinutes < 10 ? "0" : "", iMinutes, fSeconds < 10.0 ? "0" : "", fSeconds);
        }   
        else
        {
            Format(time, length, "%s%d:%s%d:%s%.3f", (iHours < 10 && show0Hours) ? "0" : "", iHours, iMinutes < 10 ? "0" : "", iMinutes, fSeconds < 10.0 ? "0" : "", fSeconds);
        }
    }
}
