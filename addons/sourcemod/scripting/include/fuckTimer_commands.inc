#if defined _fuckTimer_commands_included
    #endinput
#endif
#define _fuckTimer_commands_included

forward void fuckTimer_OnClientRestart(int client);

native void fuckTimer_RestartClient(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_commands_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_RestartClient");
}
#endif

public SharedPlugin __pl_fuckTimer_commands = 
{
    name = "fuckTimer_commands",
    file = "commands.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
