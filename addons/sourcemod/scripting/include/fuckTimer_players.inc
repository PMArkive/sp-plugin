#if defined _fuckTimer_players_included
    #endinput
#endif
#define _fuckTimer_players_included

native Styles fuckTimer_GetPlayerStyle(int client);
native void fuckTimer_SetPlayerStyle(int client, Styles style);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_players_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetPlayerStyle");
    MarkNativeAsOptional("fuckTimer_SetPlayerStyle");
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
