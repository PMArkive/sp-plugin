#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fT_stocks>

#undef REQUIRE_PLUGIN
#include <fuckZones>

char g_sName[32];

HTTPClient g_hClient = null;

public Plugin myinfo =
{
    name = fT_PLUGIN_NAME ... "Downloader",
    author = fT_PLUGIN_AUTHOR,
    description = fT_PLUGIN_DESCRIPTION,
    version = fT_PLUGIN_VERSION,
    url = fT_PLUGIN_URL
};

public void OnMapStart()
{
    bool bFound = false;
    Handle hPlugin = null;
    Handle hIter = GetPluginIterator();

    while (MorePlugins(hIter))
    {
        hPlugin = ReadPlugin(hIter);
        GetPluginFilename(hPlugin, g_sName, sizeof(g_sName));

        if (StrContains(g_sName, "fuckZones.smx") != -1)
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

    ServerCommand("sm plugins unload %s", g_sName);

    RequestFrame(Frame_DownloadZone);
}

void CheckHTTPClient()
{
    if (g_hClient == null)
    {
        g_hClient = new HTTPClient(fT_BASE_CLOUD_URL);
    }
}

public void Frame_DownloadZone()
{
    char sMap[64];
    fuckZones_GetCurrentWorkshopMap(sMap, sizeof(sMap));

    LogMessage("[fuckTimer.Downloader] Download %s.zon...", sMap);
    
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

    if (FileExists(sFile))
    {
        DeleteFile(sFile);
    }
    
    char sCloudPath[128];
    FormatEx(sCloudPath, sizeof(sCloudPath), "fZones/%s.zon", sMap);

    CheckHTTPClient();

    DataPack pack = new DataPack();
    pack.WriteString(sMap);
    g_hClient.DownloadFile(sCloudPath, sFile, OnZoneDownload, pack);
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
        LogMessage("[fuckTimer.Downloader] Download %s.cfg if exists...", sMap);

        char sCloudPath[128];
        FormatEx(sCloudPath, sizeof(sCloudPath), "Stripper/%s.cfg", sMap);

        char sFile[PLATFORM_MAX_PATH + 1];
        FormatEx(sFile, sizeof(sFile), "addons/stripper/maps/%s.cfg", sMap);

        bool bExist = FileExists(sFile);

        pack = new DataPack();
        pack.WriteString(sMap);
        pack.WriteCell(bExist);
        
        g_hClient.DownloadFile(sCloudPath, sFile, OnStripperDownload, pack);
    }
    else if (status == HTTPStatus_NotFound)
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

        if (FileExists(sFile))
        {
            DeleteFile(sFile);
        }

        SetFailState("Zone file \"%s.zon\" not found", sMap);
    }
    else
    {
        SetFailState("API is currently not available");
    }
}

public void OnStripperDownload(HTTPStatus status, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    bool bExist = pack.ReadCell();

    delete pack;

    if (status == HTTPStatus_OK)
    {
        LogMessage("[fuckTimer.Downloader] %s.cfg downloaded!", sMap);

        if (!bExist)
        {
            LogMessage("[fuckTimer.Downloader] Reloading map to activate stripper config...", sMap);
            ForceChangeLevel(sMap, "Stripper config added");
            return;
        }
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
    }
    else
    {
        SetFailState("API is currently not available");
        return;
    }
    

    ServerCommand("sm plugins load %s", g_sName);
}
