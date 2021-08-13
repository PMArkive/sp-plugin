#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_maps>
#include <fuckTimer_api>

enum struct MapData {
    int Id;
    int Tier;

    MapStatus Status;

    char MapAuthor[MAX_NAME_LENGTH];
    char ZoneAuthor[MAX_NAME_LENGTH];
}
MapData Map;

enum struct PluginData
{
    char Name[64];

    StringMap MapTiers;

    GlobalForward OnZoneDownload;
    GlobalForward OnMapDataLoaded;
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
    Core.OnZoneDownload = new GlobalForward("fuckTimer_OnZoneDownload", ET_Ignore, Param_String, Param_Cell);
    Core.OnMapDataLoaded = new GlobalForward("fuckTimer_OnMapDataLoaded", ET_Ignore);

    CreateNative("fuckTimer_GetCurrentMapId", Native_GetCurrentMapId);
    CreateNative("fuckTimer_GetCurrentMapTier", Native_GetCurrentMapTier);
    CreateNative("fuckTimer_GetCurrentMapStatus", Native_GetCurrentMapStatus);

    CreateNative("fuckTimer_GetMapTiers", Native_GetMapTiers);

    RegPluginLibrary("fuckTimer_maps");

    return APLRes_Success;
}

public void OnAllPluginsLoaded()
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
        SetFailState("Download failed! 404 - maptiers.txt not found. Status Code: %d, Error: %s", status, error);
    }
    else
    {
        SetFailState("Something went wrong while downloading maptiers.txt.  Status Code: %d, Error: %s", status, error);
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
                    return;
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

        UnloadFuckZones();
    }
}

UnloadFuckZones()
{
    bool bFound = false;
    Handle hPlugin = null;
    Handle hIter = GetPluginIterator();

    while (MorePlugins(hIter))
    {
        hPlugin = ReadPlugin(hIter);
        GetPluginFilename(hPlugin, Core.Name, sizeof(Core.Name));

        if (StrContains(Core.Name, "fuckZones.smx", false) != -1)
        {
            bFound = true;
            break;
        }
    }

    if (!bFound)
    {
        SetFailState("Plugin \"fuckZones\" not found! Please install \"fuckZones\" to use \"fuckTimer\".");
        return;
    }

    delete hIter;
    delete hPlugin;

    ServerCommand("sm plugins unload %s", Core.Name);
    
    DownloadZoneFile();
}

void DownloadZoneFile()
{
    char sMap[MAX_NAME_LENGTH];
    fuckTimer_GetCurrentWorkshopMap(sMap, sizeof(sMap));

    LogMessage("[fuckTimer.Downloader] Download %s.zon...", sMap);
    
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

    if (FileExists(sFile))
    {
        DeleteFile(sFile);
    }

    int iTier = 0;
    Core.MapTiers.GetValue(sMap, iTier);

    if (iTier == 0)
    {
        SetFailState("Can not find map tier for \"%s\".", sMap);
        return;
    }
    
    char sEndpoint[128];
    FormatEx(sEndpoint, sizeof(sEndpoint), "zones/main/files/Tier%d/%s.zon", iTier, sMap);
    HTTPRequest request = fuckTimer_NewCloudHTTPRequest(sEndpoint);

    DataPack pack = new DataPack();
    pack.WriteString(sMap);

    request.DownloadFile(sFile, OnZoneDownload, pack);
}

public void OnZoneDownload(HTTPStatus status, any pack, const char[] error)
{
    view_as<DataPack>(pack).Reset();

    char sMap[MAX_NAME_LENGTH];
    view_as<DataPack>(pack).ReadString(sMap, sizeof(sMap));

    delete view_as<DataPack>(pack);

    if (status == HTTPStatus_OK)
    {
        LogMessage("[fuckTimer.Downloader] %s.zon downloaded!", sMap);
        LogMessage("[fuckTimer.Downloader] Download global_filters.cfg...");

        AddMapsToDatabase();

        char sFile[PLATFORM_MAX_PATH + 1];
        FormatEx(sFile, sizeof(sFile), "addons/stripper/global_filters.cfg");
        bool bExist = FileExists(sFile);

        char sEndpoint[128];
        FormatEx(sEndpoint, sizeof(sEndpoint), "stripper/main/files/global_filters.cfg");
        HTTPRequest request = fuckTimer_NewCloudHTTPRequest(sEndpoint);

        DataPack dpPack = new DataPack();
        dpPack.WriteString(sMap);
        dpPack.WriteCell(bExist);
        
        request.DownloadFile(sFile, OnStripperGlobalDownload, dpPack);

        CallZoneDownload(sMap, true);
    }
    else if (status == HTTPStatus_NotFound)
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

        if (FileExists(sFile))
        {
            DeleteFile(sFile);
        }

        CallZoneDownload(sMap, false);
        
        SetFailState("Zone file \"%s.zon\" not found", sMap);
    }
    else
    {
        CallZoneDownload(sMap, false);
        
        SetFailState("API is currently not available. Status Code: %d, Error: %s", status, error);
    }
}

void AddMapsToDatabase()
{
    JSONArray jMaps = new JSONArray();
    JSONObject jMap = null;

    char sMap[MAX_NAME_LENGTH];
    char sMapAuthor[MAX_NAME_LENGTH];
    char sZoneAuthor[MAX_NAME_LENGTH];

    int iTier = 0;

    StringMapSnapshot snap = Core.MapTiers.Snapshot();

    for (int i = 0; i < snap.Length; i++)
    {
        snap.GetKey(i, sMap, sizeof(sMap));
        Core.MapTiers.GetValue(sMap, iTier);

        GetAuthor(sMap, true, sMapAuthor, sizeof(sMapAuthor));
        GetAuthor(sMap, false, sZoneAuthor, sizeof(sZoneAuthor));

        jMap = new JSONObject();
        jMap.SetString("Name", sMap);
        jMap.SetInt("Tier", iTier);
        jMap.SetInt("Status", 0);
        jMap.SetString("MapAuthor", sMapAuthor);
        jMap.SetString("ZoneAuthor", sZoneAuthor);

        jMaps.Push(jMap);

        sMap[0] = '\0';
        sMapAuthor[0] = '\0';
        sZoneAuthor[0] = '\0';
        iTier = 0;
    }

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map");

    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);

    request.Post(jMaps, PostMaps);

    for (int i = 0; i < jMaps.Length; i++)
    {
        jMap = view_as<JSONObject>(jMaps.Get(i));
        delete jMap;
    }

    delete jMaps;
}

public void PostMaps(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Maps.PostMaps] Can't post maps. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Maps.PostMaps] Success. Status Code: %d", response.Status);

    char sMap[MAX_NAME_LENGTH];
    fuckTimer_GetCurrentWorkshopMap(sMap, sizeof(sMap));

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map/Name/%s", sMap);

    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);

    request.Get(GetMap);
}

public void GetMap(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        LogError("[Maps.GetMap] Can't get maps. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Maps.GetMap] Success. Status Code: %d", response.Status);

    JSONObject jMap = view_as<JSONObject>(response.Data);

    Map.Id = jMap.GetInt("Id");

    char sName[MAX_NAME_LENGTH];
    jMap.GetString("Name", sName, sizeof(sName));

    Map.Tier = jMap.GetInt("Tier");

    Map.Status = view_as<MapStatus>(jMap.GetInt("Status"));

    jMap.GetString("MapAuthor", Map.MapAuthor, sizeof(MapData::MapAuthor));
    jMap.GetString("ZoneAuthor", Map.ZoneAuthor, sizeof(MapData::ZoneAuthor));

    if (StrEqual(Map.MapAuthor, "", false) || StrEqual(Map.MapAuthor, "n/a", false) || StrEqual(Map.ZoneAuthor, "", false) || StrEqual(Map.ZoneAuthor, "n/a", false))
    {
        LogMessage("Unknown map/zone author for %s. Checking zone file for updates...", sName);
        UpdateAuthor(jMap);
    }

    jMap.GetString("MapAuthor", Map.MapAuthor, sizeof(MapData::MapAuthor));
    jMap.GetString("ZoneAuthor", Map.ZoneAuthor, sizeof(MapData::ZoneAuthor));

    LogMessage("Id: %d, Name: %s, Tier: %d, Status: %d, MapAuthor: %s, ZoneAuthor: %s", Map.Id, sName, Map.Tier, Map.Status, Map.MapAuthor, Map.ZoneAuthor);

    Call_StartForward(Core.OnMapDataLoaded);
    Call_Finish();
}

void UpdateAuthor(JSONObject map)
{
    char sMap[MAX_NAME_LENGTH];
    map.GetString("Name", sMap, sizeof(sMap));

    char sBuffer[MAX_NAME_LENGTH];
    GetAuthor(sMap, true, sBuffer, sizeof(sBuffer));

    if (StrEqual(sBuffer, "", false) || StrEqual(sBuffer, "n/a", false))
    {
        LogMessage("No update available, we'll skip this step.");
        return;
    }

    map.SetString("MapAuthor", sBuffer);

    GetAuthor(sMap, false, sBuffer, sizeof(sBuffer));
    map.SetString("ZoneAuthor", sBuffer);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map/Id/%d", map.GetInt("id"));

    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);

    request.Put(map, UpdateMap);
}

public void UpdateMap(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        LogError("[Maps.UpdateMap] Can't update map. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Maps.UpdateMap] Success. Status Code: %d", response.Status);
}

public void OnStripperGlobalDownload(HTTPStatus status, any pack, const char[] error)
{
    view_as<DataPack>(pack).Reset();

    char sMap[MAX_NAME_LENGTH];
    view_as<DataPack>(pack).ReadString(sMap, sizeof(sMap));

    bool bExist = view_as<DataPack>(pack).ReadCell();

    delete view_as<DataPack>(pack);

    if (status == HTTPStatus_OK)
    {
        LogMessage("[fuckTimer.Downloader] global_filters.cfg downloaded!");
    }
    else if (status == HTTPStatus_NotFound)
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        BuildPath(Path_SM, sFile, sizeof(sFile), "addons/stripper/global_filters.cfg");

        if (FileExists(sFile))
        {
            DeleteFile(sFile);
        }

        SetFailState("[fuckTimer.Downloader] global_filters.cfg doesn't exist! Status Code: %d, Error: %s", status, error);
        return;
    }
    else
    {
        SetFailState("API is currently not available. Status Code: %d, Error: %s", status, error);
        return;
    }
    
    LogMessage("[fuckTimer.Downloader] Download %s.cfg if exists...", sMap);

    char sFile[PLATFORM_MAX_PATH + 1];
    FormatEx(sFile, sizeof(sFile), "addons/stripper/maps/%s.cfg", sMap);
    bool bMapExist = FileExists(sFile);

    char sEndpoint[128];
    FormatEx(sEndpoint, sizeof(sEndpoint), "stripper/main/files/%s.cfg", sMap);
    HTTPRequest request = fuckTimer_NewCloudHTTPRequest(sEndpoint);

    DataPack dpPack = new DataPack();
    dpPack.WriteString(sMap);
    dpPack.WriteCell(bExist);
    dpPack.WriteCell(bMapExist);
    
    request.DownloadFile(sFile, OnStripperMapDownload, dpPack);
}

public void OnStripperMapDownload(HTTPStatus status, any pack, const char[] error)
{
    view_as<DataPack>(pack).Reset();

    char sMap[MAX_NAME_LENGTH];
    view_as<DataPack>(pack).ReadString(sMap, sizeof(sMap));

    bool bExist = view_as<DataPack>(pack).ReadCell();
    bool bMapExist = view_as<DataPack>(pack).ReadCell();

    delete view_as<DataPack>(pack);

    if (status == HTTPStatus_OK)
    {
        LogMessage("[fuckTimer.Downloader] %s.cfg downloaded!", sMap);
    }
    else if (status == HTTPStatus_NotFound)
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        BuildPath(Path_SM, sFile, sizeof(sFile), "addons/stripper/maps/%s.cfg", sMap);

        if (FileExists(sFile))
        {
            DeleteFile(sFile);
        }

        LogMessage("[fuckTimer.Downloader] %s.cfg doesn't exist!", sMap);

        // Set bMapExist to true to probably avoid infinity map reloading, because map doesn't exist on the server + cloud
        // so bExistMap is always false and should result into infinity map reloading
        bMapExist = true;
    }
    else
    {
        SetFailState("API is currently not available. Status Code: %d, Error: %s", status, error);
        return;
    }

    if (!bExist || !bMapExist)
    {
        LogMessage("[fuckTimer.Downloader] Reloading map to activate stripper config(s)...");
        ForceChangeLevel(sMap, "Stripper config(s) added");
        return;
    }

    ServerCommand("sm plugins load %s", Core.Name);
}

void CallZoneDownload(const char[] map, bool success)
{
    Call_StartForward(Core.OnZoneDownload);
    Call_PushString(map);
    Call_PushCell(success);
    Call_Finish();
}

void GetAuthor(const char[] map, bool mapAuthor, char[] author, int maxlen)
{
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", map);

    if (!FileExists(sFile))
    {
        FormatEx(author, maxlen, "n/a");
        return;
    }

    KeyValues kv = new KeyValues("zones");

    if (!kv.ImportFromFile(sFile))
    {
        delete kv;
        
        SetFailState("[Maps.GetAuthor] Can not data read from file.");
        return;
    }

    if (!kv.JumpToKey("main0_start"))
    {
        delete kv;
        
        SetFailState("[Maps.GetAuthor] Can not find \"main0_start\" zone.");
        return;
    }

    if (!kv.JumpToKey("effects"))
    {
        delete kv;
        
        SetFailState("[Maps.GetAuthor] Can not find \"effects\" key.");
        return;
    }

    if (!kv.JumpToKey("fuckTimer"))
    {
        delete kv;
        
        SetFailState("[Maps.GetAuthor] Can not find \"fuckTimer\" effect.");
        return;
    }

    kv.GetString(mapAuthor ? "MapAuthor" : "ZoneAuthor", author, maxlen);

    if (strlen(author) < 2)
    {
        FormatEx(author, maxlen, "n/a");
    }

    delete kv;
}

public int Native_GetCurrentMapId(Handle plugin, int numParams)
{
    return Map.Id;
}

public int Native_GetCurrentMapTier(Handle plugin, int numParams)
{
    return Map.Tier;
}

public any Native_GetCurrentMapStatus(Handle plugin, int numParams)
{
    return Map.Status;
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
