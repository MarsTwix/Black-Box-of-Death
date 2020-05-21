#if defined blackboxofdeath_core_included
 #endinput
#endif

#define _blackboxofdeath_core_included

native void CreateBox(int client);
native void RemoveBox(int client);

public SharedPlugin __pl_turret_core = 
{
    name = "blackboxofdeath_core",
    file = "blackboxofdeath_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_blackboxofdeath_core_SetNTVOptional()
{
    MarkNativeAsOptional("CreateBox");
}