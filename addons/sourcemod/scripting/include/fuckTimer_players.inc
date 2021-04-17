#if defined _fuckTimer_players_included
    #endinput
#endif
#define _fuckTimer_players_included

enum eInvalidKeyPref {
    IKBlock = 0,
    IKStop,
    IKRestart,
    IKNormal
}

native void fuckTimer_RegisterSetting(const char[] setting, const char[] defaultValue);
native bool fuckTimer_GetClientSetting(int client, const char[] setting, char[] value);
native void fuckTimer_SetClientSetting(int client, const char[] setting, char[] value);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_players_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_RegisterSetting");
    MarkNativeAsOptional("fuckTimer_GetClientSetting");
    MarkNativeAsOptional("fuckTimer_SetClientSetting");
}
#endif

public SharedPlugin __pl_fuckTimer_players = 
{
    name = "fuckTimer_players",
    file = "hud.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
