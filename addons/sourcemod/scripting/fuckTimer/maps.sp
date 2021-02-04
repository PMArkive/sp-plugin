#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_core>

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

public void OnMapStart()
{
    if (!fuckTimer_GetBaseURL(g_sBase, sizeof(g_sBase)))
    {
        SetFailState("[Maps.OnMapStart] Can't receive base url.");
        return;
    }

    if (!fuckTimer_GetAPIKey(g_sKey, sizeof(g_sKey)))
    {
        SetFailState("[Maps.OnMapStart] Can't receive api key.");
        return;
    }

    CheckHTTPClient();

    char sMap[64];
    fuckTimer_GetCurrentWorkshopMap(sMap, sizeof(sMap));

    LoadMapData(sMap);
}

void LoadMapData(const char[] map)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "MapName/%s/?API_KEY=%s", map, g_sKey);
    
    DataPack pack = new DataPack();
    pack.WriteString(map);

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
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map?API_KEY=%s", g_sKey);

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

int GetMapTier(const char[] map)
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

    // Check if file exist, but we should do this whole part after download
    //  - Adding forward to downloader after map download with status (true/false)
    // Then we're pretty sure if this file exist and didn't need to check it.
    if ()
}

void CheckHTTPClient()
{
    if (g_hClient == null)
    {
        g_hClient = new HTTPClient(g_sBase);
    }
}


