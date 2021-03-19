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

native Styles fuckTimer_GetClientStyle(int client);
native void fuckTimer_SetClientStyle(int client, Styles style);

native eInvalidKeyPref fuckTimer_GetClientInvalidKeyPref(int client);
native void fuckTimer_SetClientInvalidKeyPref(int client, eInvalidKeyPref preference);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_players_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetClientStyle");
    MarkNativeAsOptional("fuckTimer_SetClientStyle");

    MarkNativeAsOptional("fuckTimer_GetClientInvalidKeyPref");
    MarkNativeAsOptional("fuckTimer_SetClientInvalidKeyPref");
}
#endif

public SharedPlugin __pl_fuckTimer_players = 
{
    name = "fuckTimer_players",
    file = "maps.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
