#if defined _fuckTimer_styles_included
    #endinput
#endif
#define _fuckTimer_styles_included

#define MAX_STYLE_NAME_LENGTH 32

#include <intmap>

enum struct Style {
    int Id;
    char Name[MAX_STYLE_NAME_LENGTH];
    bool IsActive;
}

enum Styles {
    StyleNone = 0,
    StyleNormal,
    StyleSideways,
    StyleHSW,
    StyleBackwards,
    StyleLowGravity,
    StyleSlowMotion
}

native bool fuckTimer_GetStyleName(Styles style, char[] name, int length);
native IntMap fuckTimer_GetStyles();

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_styles_SetNTVOptional()
{
    MarkNativeAsOptional("fuckTimer_GetStyleName");
    MarkNativeAsOptional("fuckTimer_GetStyles");
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
