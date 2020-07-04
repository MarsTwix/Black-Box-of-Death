#if defined radiojammer_core_included
 #endinput
#endif

#define _radiojammer_core_included

native void CreateRadio(int client);
//native void RemoveRadio(int client);

public SharedPlugin __pl_radiojammer_core = 
{
    name = "radiojammer_core",
    file = "radiojammer_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_radiojammer_core_SetNTVOptional()
{
    MarkNativeAsOptional("CreateRadio");
}
#endif