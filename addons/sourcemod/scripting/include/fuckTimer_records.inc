#if defined _fuckTimer_records_included
    #endinput
#endif
#define _fuckTimer_records_included

/**
 * IMPORTANT: Don't delete the Details IntMap! 
 *
 */
native bool fuckTimer_GetServerRecord(Styles style, int level, any[] record);
native bool fuckTimer_GetPlayerRecord(int client, Styles style, int level, any[] record);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_records_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetServerRecord");
    MarkNativeAsOptional("fuckTimer_GetPlayerRecord");
}
#endif

public SharedPlugin __pl_fuckTimer_records = 
{
    name = "fuckTimer_records",
    file = "records.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
