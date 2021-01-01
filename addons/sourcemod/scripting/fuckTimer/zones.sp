#pragma semicolon 1
#pragma newdecls required

// SourceMod
#include <sourcemod>
#include <ripext>
#include <fuckStocks>

#undef REQUIRE_PLUGIN
#include <fuckZones>

char g_sName[32];

public Plugin myinfo =
{
    name = fT_PLUGIN_NAME ... "Zones",
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

    while(MorePlugins(hIter))
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
    hClient.DownloadFile(sCloudPath, sFile, OnDownloaded);
}

public void OnDownloaded(HTTPStatus status, any value, const char[] error)
{
    if (status == HTTPStatus_OK)
    {
        ServerCommand("sm plugins load %s", g_sName);
    }
}
