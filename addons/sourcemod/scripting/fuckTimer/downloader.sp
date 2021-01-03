#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckStocks>

#undef REQUIRE_PLUGIN
#include <fuckZones>

char g_sName[32];

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

public void Frame_DownloadZone()
{
    char sMap[64];
    fuckZones_GetCurrentWorkshopMap(sMap, sizeof(sMap));
    
    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/zones/%s.zon", sMap);

    if (FileExists(sFile))
    {
        DeleteFile(sFile);
    }
    
    char sCloudPath[128];
    FormatEx(sCloudPath, sizeof(sCloudPath), "fZones/%s.zon", sMap);

    HTTPClient hClient = new HTTPClient(fT_BASE_CLOUD_URL);
    DataPack pack = new DataPack();
    pack.WriteString(sMap);
    hClient.DownloadFile(sCloudPath, sFile, OnZoneDownload, pack);
}

public void OnZoneDownload(HTTPStatus status, DataPack pack, const char[] error)
{
    pack.Reset();

    char sMap[64];
    pack.ReadString(sMap, sizeof(sMap));

    delete pack;

    if (status == HTTPStatus_OK)
    {
        char sCloudPath[128];
        FormatEx(sCloudPath, sizeof(sCloudPath), "Stripper/%s.cfg", sMap);

        char sFile[PLATFORM_MAX_PATH + 1];
        FormatEx(sFile, sizeof(sFile), "addons/stripper/maps/%s.cfg", sMap);

        bool bExist = FileExists(sFile);

        pack = new DataPack();
        pack.WriteString(sMap);
        pack.WriteCell(bExist);
        
        HTTPClient hClient = new HTTPClient(fT_BASE_CLOUD_URL);
        hClient.DownloadFile(sCloudPath, sFile, OnStripperDownload, pack);
    }
    else if (status == HTTPStatus_NotFound)
    {
        SetFailState("Zone not found");
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
        if (!bExist)
        {
            ForceChangeLevel(sMap, "Added stripper config");
            return;
        }
    }
    else if (status != HTTPStatus_NotFound)
    {
        SetFailState("API is currently not available");
        return;
    }

    ServerCommand("sm plugins load %s", g_sName);
}
