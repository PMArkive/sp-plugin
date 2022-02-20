#if defined _fuckTimer_styles_included
    #endinput
#endif
#define _fuckTimer_styles_included

#define MAX_STYLE_NAME_LENGTH 32
#define MAX_STYLES 24

#include <intmap>

enum StyleStatus {
    ssActive = 0,
    ssInactive = 1
}

enum struct Style {
    int Id;
    
    char Name[MAX_STYLE_NAME_LENGTH];

    StyleStatus Status;
}

forward void fuckTimer_OnStylesLoaded();

native IntMap fuckTimer_GetStyles();

native bool fuckTimer_GetStyleName(Styles style, char[] name, int length);
native StyleStatus fuckTimer_GetStyleStatus(int id);

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_styles_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetStyles");

    MarkNativeAsOptional("fuckTimer_GetStyleName");
    MarkNativeAsOptional("fuckTimer_GetStyleStatus");
}
#endif

public SharedPlugin __pl_fuckTimer_styles = 
{
    name = "fuckTimer_styles",
    file = "styles.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
