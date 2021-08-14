#if defined _fuckTimer_records_included
    #endinput
#endif
#define _fuckTimer_records_included

native bool fuckTimer_GetServerRecord(Styles style, int level, any[] record);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_records_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetServerRecord");
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
