#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_downloader>

enum struct MapData {
    int Id;
    int Tier;
    bool IsActive;
}
MapData Map;

enum struct PluginData
{
    bool API;
    bool Zones;
}
PluginData Core;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Maps",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("fuckTimer_GetCurrentMapId", Native_GetCurrentMapId);
    CreateNative("fuckTimer_GetCurrentMapTier", Native_GetCurrentMapTier);

    CreateNative("fuckTimer_GetMapTiers", Native_GetMapTiers);

    RegPluginLibrary("fuckTimer_maps");

    return APLRes_Success;
}

public void fuckTimer_OnAPIReady()
{
    Core.API = true;

    char sMap[32];
    fuckTimer_GetCurrentWorkshopMap(sMap, sizeof(sMap));
    ArePluginsReady(sMap);
}

public void fuckTimer_OnZoneDownload(const char[] map, bool success)
{
    if (!success)
    {
        SetFailState("[Maps.fuckTimer_OnZoneDownload] Can not add/update map.");
        return;
    }

    Core.Zones = true;

    ArePluginsReady(map);
}

void ArePluginsReady(const char[] map)
{
    if (Core.API && Core.Zones)
    {
        LoadMapData(map);

        Core.API = false;
        Core.Zones = false;
    }
}

void LoadMapData(const char[] map)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map/Name/%s", map);
    
    DataPack pack = new DataPack();
    pack.WriteString(map);

    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);

    request.Get(GetMapData, pack);
}

public void GetMapData(HTTPResponse response, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    delete pack;

    if (response.Status != HTTPStatus_OK)
    {
        if (response.Status == HTTPStatus_NotFound)
        {
            LogMessage("[Maps.GetMapData] 404 Map Not Found, we'll add this map.");
            PrepareMapPostData(sMap);
            return;
        }

        LogError("[Maps.GetMapData] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jMap = view_as<JSONObject>(response.Data);

    char sName[MAX_NAME_LENGTH];
    jMap.GetString("Name", sName, sizeof(sName));

    Map.Id = jMap.GetInt("Id");
    Map.Tier = jMap.GetInt("Tier");
    Map.IsActive = jMap.GetBool("IsActive");

    LogMessage("[Maps.GetMapData] Map Found. Name: %s, Id: %d, Tier: %d, Active: %d", sName, Map.Id, Map.Tier, Map.IsActive);
}

void PrepareMapPostData(const char[] map)
{
    int iTier = GetMapTier(map);

    JSONObject jMap = new JSONObject();
    jMap.SetString("Name", map);
    jMap.SetInt("Tier", iTier);
    jMap.SetBool("IsActive", true);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map");
    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);

    DataPack pack = new DataPack();
    pack.WriteString(map);

    request.Post(jMap, PostMapData, pack);
    delete jMap;
}

public void PostMapData(HTTPResponse response, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    delete pack;
    delete response.Data;

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Maps.PostMapData] Can't post map data. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Maps.PostMapData] Success. Status Code: %d", response.Status);

    LoadMapData(sMap);
}

// If (fuckTimer_)GetMapTIer returns 0 or lower -> invalid map, map not found or tier entry didn't exist in the zone file
int GetMapTier(const char[] map)
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", map);

    if (!FileExists(sFile))
    {
        SetFailState("[Maps.GetMapTier] Zone file \"%s\" not found.");
        return 0;
    }

    KeyValues kv = new KeyValues("zones");

    if (!kv.ImportFromFile(sFile))
    {
        delete kv;
        
        SetFailState("[Maps.GetMapTier] Can not data read from file.");
        return 0;
    }

    if (!kv.JumpToKey("main0_start"))
    {
        delete kv;
        
        SetFailState("[Maps.GetMapTier] Can not find \"main0_start\" zone.");
        return 0;
    }

    if (!kv.JumpToKey("effects"))
    {
        delete kv;
        
        SetFailState("[Maps.GetMapTier] Can not find \"effects\" key.");
        return 0;
    }

    if (!kv.JumpToKey("fuckTimer"))
    {
        delete kv;
        
        SetFailState("[Maps.GetMapTier] Can not find \"fuckTimer\" effect.");
        return 0;
    }

    int iTier = kv.GetNum("Tier");
    delete kv;

    return iTier;
}

public int Native_GetCurrentMapId(Handle plugin, int numParams)
{
    return Map.Id;
}

public int Native_GetCurrentMapTier(Handle plugin, int numParams)
{
    return Map.Tier;
}

public any Native_GetMapTiers(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sName[MAX_NAME_LENGTH];
    GetNativeString(2, sName, sizeof(sName));

    Function fCallback = GetNativeFunction(3);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map/MatchName/%s", sName);
    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);
    
    DataPack pack = new DataPack();
    if (client > 0 && IsClientInGame(client))
    {
        pack.WriteCell(GetClientUserId(client));
    }
    else
    {
        pack.WriteCell(0);
    }
    pack.WriteString(sName);
    pack.WriteCell(view_as<int>(plugin));
    pack.WriteFunction(fCallback);
    request.Get(GetMapsData, pack);
}

public void GetMapsData(HTTPResponse response, DataPack pack, const char[] error)
{
    pack.Reset();

    int userid = pack.ReadCell();

    int client = userid == 0 ? 0 : GetClientOfUserId(userid);
    

    char sMap[MAX_NAME_LENGTH];
    pack.ReadString(sMap, sizeof(sMap));

    Handle hPlugin = view_as<Handle>(pack.ReadCell());

    Function fCallback = pack.ReadFunction();

    delete pack;

    if (response.Status != HTTPStatus_OK)
    {
        if (response.Status == HTTPStatus_NotFound)
        {
            LogMessage("[Maps.GetMapsData] 404 Map Not Found, we'll add this map.");
            PrepareMapPostData(sMap);
            return;
        }

        LogError("[Maps.GetMapsData] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONArray jArray = view_as<JSONArray>(response.Data);
    JSONObject jObj;

    StringMap smTiers = new StringMap();

    int iTier = 0;
    char sName[MAX_NAME_LENGTH];

    LogMessage("[Maps.GetMapsData] Found %d Maps", jArray.Length);
    
    for (int i = 0; i < jArray.Length; i++)
    {
        jObj = view_as<JSONObject>(jArray.Get(i));
        jObj.GetString("Name", sName, sizeof(sName));
        iTier = jObj.GetInt("Tier");

        LogMessage("[Maps.GetMapsData] Name: %s, Tier: %d", sName, iTier);

        smTiers.SetValue(sName, iTier);

        iTier = 0;
        sName[0] = '\0';

        delete jObj;
    }

    Call_StartFunction(hPlugin, fCallback);
    if (client > 0 && IsClientInGame(client))
    {
        Call_PushCell(GetClientUserId(client));
    }
    else
    {
        Call_PushCell(0);
    }
    Call_PushCell(smTiers);
    Call_Finish();
}
