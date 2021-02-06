#if defined _fuckTimer_download_included
    #endinput
#endif
#define _fuckTimer_download_included

forward void fuckTimer_OnZoneDownload(const char[] map, bool success);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_download_SetNTVOptional()
{
    // MarkNativeAsOptional("<NativeName>");
}
#endif

public SharedPlugin __pl_fuckTimer_download = 
{
    name = "fuckTimer_downloader",
    file = "downloader.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
