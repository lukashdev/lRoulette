public SharedPlugin __pl_nox_bb_rpg = 
{
    name = "nox_bb_rpg",
    file = "nox_bb_rpg.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

native int GetClientCoins(int client);

native int SetClientCoins(int client, int amount);

native int SetClientExp(int client, int value);

native int GetClientExp(int client);

native int GetClientLevel(int client);

forward void BB_OnMoveBlock(int client);

#if  !defined REQUIRE_PLUGIN
public void __pl_nox_bb_rpg_SetNTVOptional()
{
    MarkNativeAsOptional("GetClientCoins");
    MarkNativeAsOptional("SetClientCoins");
    MarkNativeAsOptional("SetClientExp");
    MarkNativeAsOptional("GetClientExp");
    MarkNativeAsOptional("GetClientLevel");
}
#endif