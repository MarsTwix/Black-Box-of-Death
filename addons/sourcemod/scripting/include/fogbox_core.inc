#if defined fogbox_core_included
 #endinput
#endif

#define _fogbox_core_included

native void CreateBox(int client);
//native void RemoveBox(int client);

public SharedPlugin __pl_fogbox_core = 
{
    name = "fogbox_core",
    file = "fogbox_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_fogbox_core_SetNTVOptional()
{
    MarkNativeAsOptional("CreateBox");
}