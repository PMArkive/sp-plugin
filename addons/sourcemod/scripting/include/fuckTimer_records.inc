#if defined _fuckTimer_records_included
    #endinput
#endif
#define _fuckTimer_records_included

#include <fuckTimer_styles>

/**
 * If serverRecord is false, then it's a player record
 * oldTime is 0.0, when no record exist before.
 * Note: Get Bonus from recordDetails and use this as index for oldRecord IntMap to get the correct record as RecordDetails enum struct
*/
forward void fuckTimer_OnNewRecord(int client, bool serverRecord, StringMap recordDetails, float oldTime);

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
