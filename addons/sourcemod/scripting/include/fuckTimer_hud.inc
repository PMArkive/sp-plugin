#if defined _fuckTimer_hud_included
    #endinput
#endif
#define _fuckTimer_hud_included

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
    HKStageTime,
    HKTimeInZone,
    HKPersonalRecord = 20,
    HKServerRecord,
    HKRank,
    HKTier = 30,
    HKZone,
    HKMap,
    HKMapType,
    HKAttempts,
    HKStyle = 40,
    HKCurrentStage = 50,
    HKValidator
}

enum struct HUDEntry
{
    int Side;
    int Line;
    int Key;
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

native void fuckTimer_SetClientHUDLayout(int client, char[] layout = "default");

native bool fuckTimer_MoveClientHUDKey(int client, eHUDKeys key = HKNone, bool side, int line, bool swapPositions = false);
 
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
