#if defined _fT_stocks_included
    #endinput
#endif
#define _fT_stocks_included

#include <autoexecconfig>

#define fT_PLUGIN_NAME "fuckTimer - "
#define fT_PLUGIN_AUTHOR "fuckTimer Contributors"
#define fT_PLUGIN_DESCRIPTION ""
#define fT_PLUGIN_VERSION "1.0.0"
#define fT_PLUGIN_URL "github.com/fuckTimer"

#define fT_BASE_CLOUD_URL "https://fucktimer.cloud/file"

stock void fT_StartConfig(char[] file, char[] directory = "fuckTimer")
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile(file, directory);
}

stock void fT_EndConfig()
{
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}
