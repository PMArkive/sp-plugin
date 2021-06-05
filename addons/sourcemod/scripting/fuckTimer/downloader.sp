#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_api>

enum struct PluginData
{
    GlobalForward OnZoneDownload;

    char Name[32];
}
PluginData Core;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Downloader",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    Core.OnZoneDownload = new GlobalForward("fuckTimer_OnZoneDownload", ET_Ignore, Param_String, Param_Cell);

    RegPluginLibrary("fuckTimer_downloader");

    return APLRes_Success;
}

public void OnMapStart()
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
        SetFailState("fuckZones as base plugin not found!");
        return;
    }

    delete hIter;
    delete hPlugin;

    ServerCommand("sm plugins unload %s", Core.Name);

    RequestFrame(Frame_DownloadZone);
}

public void Frame_DownloadZone()
{
    char sMap[64];
    fuckTimer_GetCurrentWorkshopMap(sMap, sizeof(sMap));

    LogMessage("[fuckTimer.Downloader] Download %s.zon...", sMap);
    
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

    if (FileExists(sFile))
    {
        DeleteFile(sFile);
    }
    
    char sEndpoint[128];
    FormatEx(sEndpoint, sizeof(sEndpoint), "fZones/%s.zon", sMap);
    HTTPRequest request = fuckTimer_NewCloudHTTPRequest(sEndpoint);

    DataPack pack = new DataPack();
    pack.WriteString(sMap);

    request.DownloadFile(sFile, OnZoneDownload, pack);
}

public void OnZoneDownload(HTTPStatus status, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    delete pack;

    if (status == HTTPStatus_OK)
    {
        LogMessage("[fuckTimer.Downloader] %s.zon downloaded!", sMap);
        LogMessage("[fuckTimer.Downloader] Download global_filters.cfg...");

        

        char sFile[PLATFORM_MAX_PATH + 1];
        FormatEx(sFile, sizeof(sFile), "addons/stripper/global_filters.cfg");
        bool bExist = FileExists(sFile);

        char sEndpoint[128];
        FormatEx(sEndpoint, sizeof(sEndpoint), "Stripper/global_filters.cfg");
        HTTPRequest request = fuckTimer_NewCloudHTTPRequest(sEndpoint);

        pack = new DataPack();
        pack.WriteString(sMap);
        pack.WriteCell(bExist);
        
        request.DownloadFile(sFile, OnStripperGlobalDownload, pack);

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
        
        SetFailState("API is currently not available");
    }
}

public void OnStripperGlobalDownload(HTTPStatus status, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    bool bExist = pack.ReadCell();

    delete pack;

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

        SetFailState("[fuckTimer.Downloader] global_filters.cfg doesn't exist!");
        return;
    }
    else
    {
        SetFailState("API is currently not available");
        return;
    }
    
    LogMessage("[fuckTimer.Downloader] Download %s.cfg if exists...", sMap);

    char sFile[PLATFORM_MAX_PATH + 1];
    FormatEx(sFile, sizeof(sFile), "addons/stripper/maps/%s.cfg", sMap);
    bool bMapExist = FileExists(sFile);

    char sEndpoint[128];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Stripper/%s.cfg", sMap);
    HTTPRequest request = fuckTimer_NewCloudHTTPRequest(sEndpoint);

    pack = new DataPack();
    pack.WriteString(sMap);
    pack.WriteCell(bExist);
    pack.WriteCell(bMapExist);
    
    request.DownloadFile(sFile, OnStripperMapDownload, pack);
}

public void OnStripperMapDownload(HTTPStatus status, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    bool bExist = pack.ReadCell();
    bool bMapExist = pack.ReadCell();

    delete pack;

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
        SetFailState("API is currently not available");
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
