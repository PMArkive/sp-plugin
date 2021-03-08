#if defined _fuckTimer_styles_included
    #endinput
#endif
#define _fuckTimer_styles_included

#define MAX_STYLE_NAME_LENGTH 32

enum struct Style {
    int Id;
    char Name[MAX_STYLE_NAME_LENGTH];
    bool IsActive;
}

enum Styles {
    StyleNormal = 1,
    StyleSideways
}

#if !defined REQUIRE_PLUGIN
public void __pl_fuckTimer_styles_SetNTVOptional()
{
    // MarkNativeAsOptional("");
}
#endif

public SharedPlugin __pl_fuckTimer_styles = 
{
    name = "fuckTimer_styles",
    file = "maps.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
