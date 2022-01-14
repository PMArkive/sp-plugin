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
    bool StripperGlobal;
    bool StripperMap;

    char Name[64];

    StringMap MapTiers;

    GlobalForward OnZoneDownload;
    GlobalForward OnMapDataLoaded;

    void ResetStripper()
    {
        this.StripperGlobal = false;
        this.StripperMap = false;
    }
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

public void OnMapStart()
{
    Core.ResetStripper();
}

public void fuckTimer_OnAPIReady()
{
    DownloadMapTiers();
}

void DownloadMapTiers()
{
    char sURL[MAX_URL_LENGTH];
    FormatEx(sURL, sizeof(sURL), "%s/zones/main/files/maptiers.json", FUCKTIMER_BASE_CLOUD_URL);
    HTTPRequest request = new HTTPRequest(sURL);
    request.Get(GetMapTiers);
}

public void GetMapTiers(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        LogError("[Maps.GetMapTiers] Error while loading \"maptiers.json\". Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Maps.GetMapTiers] Success. Status Code: %d", response.Status);

    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/fucktimer");

    if (!DirExists(sFile))
    {
        CreateDirectory(sFile, FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_EXEC);
    }

    Format(sFile, sizeof(sFile), "%s/maptiers.json", sFile);

    if (FileExists(sFile))
    {
        DeleteFile(sFile);
    }

    response.Data.ToFile(sFile, JSON_COMPACT);

    delete Core.MapTiers;
    Core.MapTiers = new StringMap();

    JSONObject jTiers = view_as<JSONObject>(response.Data);
    JSONObjectKeys jMaps = jTiers.Keys();
    int iTier = 0;

    char sMap[PLATFORM_MAX_PATH + 1];
    while (jMaps.ReadKey(sMap, sizeof(sMap)))
    {
        iTier = jTiers.GetInt(sMap);
        Core.MapTiers.SetValue(sMap, iTier);
    }

    delete jMaps;

    LogMessage("maptiers.json parsed and informations was saved.");
    UnloadFuckZones();
}

void UnloadFuckZones()
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

    LogMessage("[Maps.DownloadZoneFile] Download %s.zon...", sMap);
    
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

    if (FileExists(sFile))
    {
        if (FileSize(sFile) > 16)
        {
            LogMessage("[Maps.DownloadZoneFile] %s.zon already exist.", sMap);
            CallZoneDownload(sMap, true);

            char sEndpoint[MAX_URL_LENGTH];
            FormatEx(sEndpoint, sizeof(sEndpoint), "Map/Name/%s", sMap);
            fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetMap);

            DownloadStripperGlobal(sMap);
            return;
        }
        else
        {
            DeleteFile(sFile);
        }
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

    DataPack pack = new DataPack();
    pack.WriteString(sMap);

    fuckTimer_NewCloudHTTPRequest(sEndpoint).DownloadFile(sFile, OnZoneDownload, pack);
}

public void OnZoneDownload(HTTPStatus status, any pack, const char[] error)
{
    view_as<DataPack>(pack).Reset();

    char sMap[MAX_NAME_LENGTH];
    view_as<DataPack>(pack).ReadString(sMap, sizeof(sMap));

    delete view_as<DataPack>(pack);

    if (status == HTTPStatus_OK)
    {
        LogMessage("[Maps.OnZoneDownload] %s.zon downloaded!", sMap);

        AddMapsToDatabase();
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
        jMap.SetInt("Status", 1);
        jMap.SetString("MapAuthor", sMapAuthor);
        jMap.SetString("ZoneAuthor", sZoneAuthor);

        jMaps.Push(jMap);

        sMap[0] = '\0';
        sMapAuthor[0] = '\0';
        sZoneAuthor[0] = '\0';
        iTier = 0;
    }

    fuckTimer_NewAPIHTTPRequest("Map").Post(jMaps, PostMaps);

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
        LogError("[Maps.PostMaps] Error while adding maps to the database. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Maps.PostMaps] Success. Status Code: %d", response.Status);

    char sMap[MAX_NAME_LENGTH];
    fuckTimer_GetCurrentWorkshopMap(sMap, sizeof(sMap));

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Map/Name/%s", sMap);
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetMap);
}

public void GetMap(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        LogError("[Maps.GetMap] Error while loading maps. Status Code: %d, Error: %s", response.Status, error);
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
    int iResult = Call_Finish();
    PrintToServer("Call_Finish Good? %d", (iResult == SP_ERROR_NONE));

    DownloadStripperGlobal(sName);
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
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Put(map, UpdateMap);
}

public void UpdateMap(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        LogError("[Maps.UpdateMap] Error while updating database with map details. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Maps.UpdateMap] Success. Status Code: %d", response.Status);
}

void DownloadStripperGlobal(const char[] map)
{
    LogMessage("[Maps.DownloadStripperGlobal] Download global_filters.cfg...");
    
    char sFile[PLATFORM_MAX_PATH + 1];
    FormatEx(sFile, sizeof(sFile), "addons/stripper/global_filters.cfg");
    Core.StripperGlobal = FileExists(sFile);

    if (Core.StripperGlobal)
    {
        LogMessage("[Maps.DownloadStripperGlobal] global_filters.cfg already exist.");
        DownloadStripperMap(map);
        return;
    }

    DataPack dpPack = new DataPack();
    dpPack.WriteString(map);
    
    fuckTimer_NewCloudHTTPRequest("stripper/main/files/global_filters.cfg").DownloadFile(sFile, OnStripperGlobalDownload, dpPack);
}

public void OnStripperGlobalDownload(HTTPStatus status, any pack, const char[] error)
{
    view_as<DataPack>(pack).Reset();

    char sMap[MAX_NAME_LENGTH];
    view_as<DataPack>(pack).ReadString(sMap, sizeof(sMap));

    delete view_as<DataPack>(pack);

    if (status == HTTPStatus_OK)
    {
        LogMessage("[Maps.OnStripperGlobalDownload] global_filters.cfg downloaded!");
    }
    else if (status == HTTPStatus_NotFound)
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        FormatEx(sFile, sizeof(sFile), "addons/stripper/global_filters.cfg");

        if (FileExists(sFile))
        {
            DeleteFile(sFile);
        }

        SetFailState("[Maps.OnStripperGlobalDownload] global_filters.cfg doesn't exist! Status Code: %d, Error: %s", status, error);
        return;
    }
    else
    {
        SetFailState("API is currently not available. Status Code: %d, Error: %s", status, error);
        return;
    }
    
    DownloadStripperMap(sMap);
}

void DownloadStripperMap(const char[] map)
{
    LogMessage("[Maps.DownloadStripperMap] Download %s.cfg if exists...", map);

    char sFile[PLATFORM_MAX_PATH + 1];
    FormatEx(sFile, sizeof(sFile), "addons/stripper/maps/%s.cfg", map);
    Core.StripperMap = FileExists(sFile);

    if (Core.StripperMap)
    {
        LogMessage("[Maps.DownloadStripperMap] %s.cfg already exist.", map);

        CheckStatus(map);

        return;
    }

    char sEndpoint[128];
    FormatEx(sEndpoint, sizeof(sEndpoint), "stripper/main/files/%s.cfg", map);

    DataPack dpPack = new DataPack();
    dpPack.WriteString(map);
    
    fuckTimer_NewCloudHTTPRequest(sEndpoint).DownloadFile(sFile, OnStripperMapDownload, dpPack);
}

public void OnStripperMapDownload(HTTPStatus status, any pack, const char[] error)
{
    view_as<DataPack>(pack).Reset();

    char sMap[MAX_NAME_LENGTH];
    view_as<DataPack>(pack).ReadString(sMap, sizeof(sMap));

    delete view_as<DataPack>(pack);

    if (status == HTTPStatus_OK)
    {
        LogMessage("[Maps.OnStripperMapDownload] %s.cfg downloaded!", sMap);
    }
    else if (status == HTTPStatus_NotFound)
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        FormatEx(sFile, sizeof(sFile), "addons/stripper/maps/%s.cfg", sMap);

        if (FileExists(sFile))
        {
            DeleteFile(sFile);
        }

        LogMessage("[Maps.OnStripperMapDownload] %s.cfg doesn't exist!", sMap);

        // Set bMapExist to true to probably avoid infinity map reloading, because map doesn't exist on the server + cloud
        // so bExistMap is always false and should result into infinity map reloading
        Core.StripperMap = true;
    }
    else
    {
        SetFailState("API is currently not available. Status Code: %d, Error: %s", status, error);
        return;
    }

    CheckStatus(sMap);
}

void CheckStatus(const char[] map)
{
    if (!Core.StripperGlobal || !Core.StripperMap)
    {
        LogMessage("[Maps.CheckStatus] Reloading map to activate stripper config(s)...");
        ForceChangeLevel(map, "Stripper config(s) added");
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
        }

        sMap[0] = '\0';
        iTier = 0;
    }

    delete snap;

    Call_StartFunction(plugin, fCallback);
    if (client > 0 && IsClientInGame(client))
    {
        Call_PushCell(client);
    }
    else
    {
        Call_PushCell(0);
    }
    Call_PushCell(smList);
    Call_Finish();
    
    return 0;
}
