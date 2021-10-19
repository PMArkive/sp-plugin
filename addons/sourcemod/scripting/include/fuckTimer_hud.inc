#if defined _fuckTimer_hud_included
    #endinput
#endif
#define _fuckTimer_hud_included

#include <fuckTimer_players>

#define MAX_HUD_LINES 6
#define HUD_SIDE_LEFT 0
#define HUD_SIDE_RIGHT 1

enum eHUDSeparator
{
    HSTabs = 0,
    HSBar
}

enum eHUDSpeed
{
    HSXY = 0,
    HSXYZ,
    HSZ
}

enum eHUDTime
{
    HTMinimal = 0,
    HTFull
}

enum eHUDKeys
{
    HKNone = 0,
    HKSpeed,
    HKTime = 10,
    HKCSTime,
    HKTimeInZone,
    HKPersonalRecord = 20,
    HKServerRecord,
    HKRank,
    HKTier = 30,
    HKZone,
    HKMap,
    HKMapType,
    HKAttempts,
    HKAVGSpeed,
    HKJumps,
    HKStyle = 40,
    HKCurrentStage = 50,
    HKValidator
}

enum eCompareLocation
{
    CLOff = 0,
    CLHUD,
    CLChat,
    CLBoth
}

enum eCompareAgainst
{
    CANONE = -1,
    CAPR = 0,
    CASR,
    CABoth
}

enum eCompareMode
{
    CMFull = 0,
    CMDifference
}

enum struct HUDEntry
{
    int Side;
    int Line;
    int Key;
}

enum eHUDStyle
{
    HUD_Default = 0,
    HUD_KSF,
    HUD_SH,
    HUD_HORIZON,
    HUD_GOFREE
}

#define HUD_DEFAULT_SEPARATOR HSTabs
#define HUD_DEFAULT_FONTSIZE "m"
#define HUD_DEFAULT_STRING_LENGTH 16
#define HUD_DEFAULT_LEFT_SIDE { 10, 11, 20, 30, 0, 0 }
#define HUD_DEFAULT_RIGHT_SIDE  { 1, 50, 21, 40, 0, 0 }

#define HUD_KSF_SEPARATOR HSBar
#define HUD_KSF_FONTSIZE "m"
#define HUD_KSF_STRING_LENGTH 16
#define HUD_KSF_LEFT_SIDE { 10, 33, 1, 0, 0, 0 }
#define HUD_KSF_RIGHT_SIDE  { 0, 40, 20, 0, 0, 0 }

#define HUD_SH_SEPARATOR HSBar
#define HUD_SH_FONTSIZE "m"
#define HUD_SH_STRING_LENGTH 16
#define HUD_SH_LEFT_SIDE { 10, 21, 1, 0, 0, 0 }
#define HUD_SH_RIGHT_SIDE  { 0, 50, 0, 0, 0, 0 }

#define HUD_HORIZON_SEPARATOR HSBar
#define HUD_HORIZON_FONTSIZE "m"
#define HUD_HORIZON_STRING_LENGTH 16
#define HUD_HORIZON_LEFT_SIDE { 10, 50, 1, 0, 0, 0 }
#define HUD_HORIZON_RIGHT_SIDE  { 20, 30, 40, 0, 0, 0 }

#define HUD_GOFREE_SEPARATOR HSTabs
#define HUD_GOFREE_FONTSIZE "m"
#define HUD_GOFREE_STRING_LENGTH 16
#define HUD_GOFREE_LEFT_SIDE { 10, 20, 33, 0, 0, 0 }
#define HUD_GOFREE_RIGHT_SIDE  { 21, 22, 1, 0, 0, 0 }

native void fuckTimer_SetClientHUDLayout(int client, eHUDStyle style = HUD_Default);

native bool fuckTimer_MoveClientHUDKey(int client, eHUDKeys key = HKNone, bool side, int line, bool swapPositions = false);

stock eCompareLocation fuckTimer_GetClientCompareLocation(int client)
{
    char sValue[4];
    fuckTimer_GetClientSetting(client, "HUDCompareLocation", sValue);
    return view_as<eCompareLocation>(StringToInt(sValue));
}

stock eCompareAgainst fuckTimer_GetClientCompareAgainst(int client)
{
    char sValue[4];
    fuckTimer_GetClientSetting(client, "HUDCompareAgainst", sValue);
    return view_as<eCompareAgainst>(StringToInt(sValue));
}

stock eCompareMode fuckTimer_GetClientCompareMode(int client)
{
    char sValue[4];
    fuckTimer_GetClientSetting(client, "HUDCompareMode", sValue);
    return view_as<eCompareMode>(StringToInt(sValue));
}

stock int fuckTimer_GetClientCompareTime(int client)
{
    char sValue[4];
    fuckTimer_GetClientSetting(client, "HUDCompareTime", sValue);
    return StringToInt(sValue);
}
 
#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_hud_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_SetClientHUDLayout");
    MarkNativeAsOptional("fuckTimer_MoveClientHUDKey");
}
#endif

public SharedPlugin __pl_fuckTimer_hud = 
{
    name = "fuckTimer_hud",
    file = "hud.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
