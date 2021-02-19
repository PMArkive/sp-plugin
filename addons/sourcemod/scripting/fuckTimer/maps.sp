#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_core>
#include <fuckTimer_downloader>

char g_sBase[MAX_URL_LENGTH];
char g_sKey[MAX_URL_LENGTH];

HTTPClient g_hClient = null;

enum struct MapData {
    int Id;
    int Tier;
    bool IsActive;
}

MapData Map;

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
    CreateNative("fuckTimer_GetMapTier", Native_GetMapTier);

    RegPluginLibrary("fuckTimer_maps");

    return APLRes_Success;
}

public void fuckTimer_OnZoneDownload(const char[] map, bool success)
{
    if (!success)
    {
        SetFailState("[Maps.fuckTimer_OnZoneDownload] Can not add/update map.");
        return;
    }

    if (!fuckTimer_GetBaseURL(g_sBase, sizeof(g_sBase)))
    {
        SetFailState("[Maps.fuckTimer_OnZoneDownload] Can't receive base url.");
        return;
    }

    if (!fuckTimer_GetAPIKey(g_sKey, sizeof(g_sKey)))
    {
        SetFailState("[Maps.fuckTimer_OnZoneDownload] Can't receive api key.");
        return;
    }

    LoadMapData(map);
}

void LoadMapData(const char[] map)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map/Name/%s", map);
    
    DataPack pack = new DataPack();
    pack.WriteString(map);

    CheckHTTPClient();

    g_hClient.Get(sEndpoint, GetMapData, pack);
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

        LogError("[Maps.GetMapData] Something went wrong. Status Code: %d, Error: %d", response.Status, error);
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
    CheckHTTPClient();

    int iTier = GetMapTier(map);

    JSONObject jMap = new JSONObject();
    jMap.SetString("Name", map);
    jMap.SetInt("Tier", iTier);
    jMap.SetBool("IsActive", true);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map");

    DataPack pack = new DataPack();
    pack.WriteString(map);

    g_hClient.Post(sEndpoint, jMap, PostMapData, pack);
    delete jMap;
}

public void PostMapData(HTTPResponse response, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    delete pack;

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

void CheckHTTPClient()
{
    if (g_hClient == null)
    {
        g_hClient = new HTTPClient(g_sBase);

        char sBuffer[128];

        FormatEx(sBuffer, sizeof(sBuffer), "Bearer %s", g_sKey);
        g_hClient.SetHeader("Authorization", sBuffer);

        FormatEx(sBuffer, sizeof(sBuffer), "fuckTimer/%s", FUCKTIMER_PLUGIN_VERSION);
        g_hClient.SetHeader("User-Agent", sBuffer);
    }
}

public int Native_GetMapTier(Handle plugin, int numParams)
{
    return Map.Tier;
}
