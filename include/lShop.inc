#pragma tabsize 0
public SharedPlugin __pl_lShop = 
{
    name = "lShop",
    file = "lShop_Core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

typedef fnConfig = function bool(int itemid, KeyValues kv);
typedef fnUse = function void(int client, int dataid);
typedef fnRemove = function void(int client, int dataid);
typedef fnReset = function void();

native bool lShop_RegisterType(char[] name, char[] saveoption, fnConfig config, fnUse use, fnRemove remove, fnReset reset, bool disposable);

native int lShop_GetClientCredits(int client);

native bool lShop_SetClientCredits(int client, int value);

native bool lShop_IsClientFullyLoaded(int client);

native bool lShop_IsAdmin(int client);

native bool lShop_IsVip(int client);

native bool lShop_GivePlayerItemById(int client, int itemid);

native bool lShop_GivePlayerItemByTypeAndUniqueID(int client, char[] type, char[] uniqueid);

native bool lShop_SetItemDataID(int itemid, int dataid);

native bool lShop_GetChatTag(char[] buffer, int buflen);

#if !defined REQUIRE_PLUGIN
public void __pl_lShop_SetNTVOptional()
{
    MarkNativeAsOptional("lShop_RegisterType");
    MarkNativeAsOptional("lShop_GetClientCredits");
    MarkNativeAsOptional("lShop_SetClientCredits");
    MarkNativeAsOptional("lShop_IsClientFullyLoaded");
    MarkNativeAsOptional("lShop_IsAdmin");
    MarkNativeAsOptional("lShop_IsVip");
	MarkNativeAsOptional("lShop_GivePlayerItemById");
	MarkNativeAsOptional("lShop_GivePlayerItemByTypeAndUniqueID");
	MarkNativeAsOptional("lShop_SetItemDataID");
	MarkNativeAsOptional("lShop_GetChatTag");
}
#endif