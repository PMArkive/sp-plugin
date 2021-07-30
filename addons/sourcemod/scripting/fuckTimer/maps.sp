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

    StringMap MapTiers;
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

public void OnPluginStart()
{
    DownloadMapTiers();
}

void DownloadMapTiers()
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/fucktimer");

    if (!DirExists(sFile))
    {
        CreateDirectory(sFile, FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_EXEC);
    }

    Format(sFile, sizeof(sFile), "%s/maptiers.txt", sFile);

    if (FileExists(sFile))
    {
        DeleteFile(sFile);
    }
    
    char sEndpoint[128];
    FormatEx(sEndpoint, sizeof(sEndpoint), "zones/main/files/maptiers.txt");
    HTTPRequest request = fuckTimer_NewCloudHTTPRequest(sEndpoint);
    request.DownloadFile(sFile, OnMapTiersDownload);
}

public void OnMapTiersDownload(HTTPStatus status, any value, const char[] error)
{
    if (status == HTTPStatus_OK)
    {
        LogMessage("maptiers.txt downloaded. Let's parse the file...");
        ParseMapTiersFile();

    }
    else if (status == HTTPStatus_NotFound)
    {
        SetFailState("Download failed! 404 - maptiers.txt not found.");
    }
    else
    {
        SetFailState("Something went wrong while downloading maptiers.txt. Status: %d, Error: %s", status, error);
    }
}

void ParseMapTiersFile()
{
    delete Core.MapTiers;
    Core.MapTiers = new StringMap();

    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/fucktimer/maptiers.txt");

    File fFile = OpenFile(sFile, "r");

    if (fFile != null)
    {
        char sLine[MAX_NAME_LENGTH];
        int iTier = 0;

        while (!fFile.EndOfFile() && fFile.ReadLine(sLine, sizeof(sLine)))
        {
            if (sLine[0] == '#')
            {
                iTier = StringToInt(sLine[7]);

                if (iTier == 0)
                {
                    SetFailState("Can not read map tier correctly.");
                }
            }
            else if (strlen(sLine) > 1)
            {
                TrimString(sLine);
                StripQuotes(sLine);

                Core.MapTiers.SetValue(sLine, iTier);
            }
        }

        delete fFile;

        LogMessage("maptiers.txt parsed and informations was saved.");

        fuckTimer_StartZoneDownload();
    }
}

public void fuckTimer_OnAPIReady()
{
    Core.API = true;

    char sMap[MAX_NAME_LENGTH];
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

void PrepareMapPostData(const char[] map, int tier = 0)
{
    if (tier == 0)
    {
        tier = GetMapTier(map);
    }

    JSONObject jMap = new JSONObject();
    jMap.SetString("Name", map);
    jMap.SetInt("Tier", tier);
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

    StringMapSnapshot snap = Core.MapTiers.Snapshot();
    StringMap smList = new StringMap();

    char sMap[MAX_NAME_LENGTH];
    int iTier = 0;

    for (int i = 0; i < snap.Length; i++)
    {
        snap.GetKey(i, sMap, sizeof(sMap));

        if (StrContains(sMap, sName, false) != -1)
        {
            Core.MapTiers.GetValue(sMap, iTier);
            smList.SetValue(sMap, iTier);

            LogMessage("[Maps.Native_GetMapTiers] Name: %s, Tier: %d", sMap, iTier);
        }

        sMap[0] = '\0';
        iTier = 0;
    }

    delete snap;

    LogMessage("[Maps.Native_GetMapTiers] Found %d Maps", smList.Size);

    Call_StartFunction(plugin, fCallback);
    if (client > 0 && IsClientInGame(client))
    {
        Call_PushCell(GetClientUserId(client));
    }
    else
    {
        Call_PushCell(0);
    }
    Call_PushCell(smList);
    Call_Finish();
}
