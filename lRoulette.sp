#include <sourcemod>
#include <multicolors>
#undef REQUIRE_PLUGIN
#include <nox_basebuilder>
#include <case_opening>
#include <lShop>
#include <lvl_ranks>
#define REQUIRE_PLUGIN

#define CONFIG_FILE "addons/sourcemod/configs/lPlugins/lRoulette.cfg"

#pragma newdecls required
#pragma semicolon 1
#pragma tabsize 0

#define COLORSNUM 3

static const char g_sColors[][] = {"black", "red", "green"};

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsValidClient(%1))

native int Store_GetClientCredits(int client);
native int Store_SetClientCredits(int client, int value);
native int LR_SetClientStats(int iClient, LR_StatsType StatsType, int iPoints);


public Plugin myinfo = 
{
	name = "lRoulette",
	author = "lukash",
	description = "Ruletka za kredyty lol",
	version = "1.0.7",
	url = "lukashdev.pl"
};

enum struct Colors{
    int iPool;
}

enum struct Roulette {
    int iTime;
    int iLastColors[15];
    bool bActive;
}

enum struct Player {
    int iColor;
    int iWagered;
    int iWins;
    int iLoses;
    int iMoneyWon;
    int iMoneyLost;
    int iDisplayType;
    bool bIsLoad;
}

enum struct eCredits {
    bool bStore;
    bool bBBCredits;
    bool bCaseOpening;
    bool blShop;
    bool bLR;
}

enum struct Settings {
    char sTag[128];
    char sVipFlag[8];
    int iMinCredits;
    int iMaxCredits[2];
    int iDefaultDisplay;
    int iDelay;
}

int g_iRound;

Roulette g_eRoulette;
Colors g_eColors[COLORSNUM];
Player g_ePlayer[MAXPLAYERS + 1];
eCredits g_eCredits;
Settings g_eSettings;

Database DB;
int SQL_iDatabase = 0;

Handle hSync;

public void OnPluginStart()
{
    RegConsoleCmd("sm_ruletka", CMD_Roulette);
    RegConsoleCmd("sm_ru", CMD_Roulette);
    hSync = CreateHudSynchronizer();
    LoadTranslations("lRoulette.phrases");
    HookEvent("round_start", OnRoundStart);
    DatabaseConnect();
    LoopClients(i) {
        PrepareLoad(i);
    }
    
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Store_GetClientCredits");
    MarkNativeAsOptional("Store_SetClientCredits");
    MarkNativeAsOptional("GetClientCoins");
    MarkNativeAsOptional("SetClientCoins");
    MarkNativeAsOptional("Cases_SetClientBalance");
    MarkNativeAsOptional("Cases_GetClientBalance");
    MarkNativeAsOptional("lShop_GetClientCredits");
    MarkNativeAsOptional("lShop_SetClientCredits");
    MarkNativeAsOptional("LR_GetClientInfo");
    MarkNativeAsOptional("LR_SetPlayerStats");
    return APLRes_Success;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iRound++;
}

public void OnConfigsExecuted()
{
    if(LibraryExists("store_zephyrus"))
        g_eCredits.bStore = true;
    else if(LibraryExists("bb_credits"))
        g_eCredits.bBBCredits = true;
    else if(LibraryExists("case_opening"))
        g_eCredits.bCaseOpening = true;
    else if(LibraryExists("lShop"))
        g_eCredits.blShop = true;
    else if(LibraryExists("levelsranks"))
        g_eCredits.bLR = true;

    LoadConfig();
}

public void LoadConfig()
{
    KeyValues kv = CreateKeyValues("lRoulette - lukash");
    FileToKeyValues(kv, CONFIG_FILE);
    kv.GetString("chat tag", g_eSettings.sTag, 128);
    kv.GetString("vip flag", g_eSettings.sVipFlag, 8);
    g_eSettings.iDelay = kv.GetNum("delay");
    g_eSettings.iMinCredits = kv.GetNum("min credits to bet");
    g_eSettings.iMaxCredits[0] = kv.GetNum("max credits to bet");
    g_eSettings.iMaxCredits[1] = kv.GetNum("max credits to bet vip");
    g_eSettings.iDefaultDisplay = kv.GetNum("default display");
    delete kv;
}

public Action CMD_Roulette(int client, int args)
{
    if(args == 0)
        RouletteMenu(client);
    else if(g_eRoulette.bActive)
    {
        if(g_ePlayer[client].iWagered)
            return Plugin_Handled;
        char sBuffer[2][16];
        GetCmdArg(1, sBuffer[0], sizeof(sBuffer[]));
        GetCmdArg(2, sBuffer[1], sizeof(sBuffer[]));
        for(int i = 0; i <= strlen(sBuffer[0]); i++)
            sBuffer[0][i]=CharToLower(sBuffer[0][i]);
        if(!StringToInt(sBuffer[1]) || StringToInt(sBuffer[1]) < g_eSettings.iMinCredits || StringToInt(sBuffer[1]) > GetClientCredits(client))
        {
            CPrintToChat(client, "%s %T", g_eSettings.sTag, "wrong cmd usage", client);
            return Plugin_Handled;
        }
        int iWagered = StringToInt(sBuffer[1]);
        if(IsVip(client) && iWagered > g_eSettings.iMaxCredits[1])
        {
            CPrintToChat(client, "%s %T", g_eSettings.sTag, "max credits for normal user and vip", client, g_eSettings.iMaxCredits[0],g_eSettings.iMaxCredits[1]);
            return Plugin_Handled;
        }
        else if(iWagered > g_eSettings.iMaxCredits[0])
        {
            CPrintToChat(client, "%s %T", g_eSettings.sTag, "max credits for normal user and vip", client, g_eSettings.iMaxCredits[0],g_eSettings.iMaxCredits[1]);
            return Plugin_Handled;
        }
        if(StrEqual(sBuffer[0], "red"))
        {
            g_ePlayer[client].iColor = 1;
            g_ePlayer[client].iWagered = iWagered;
            g_eColors[g_ePlayer[client].iColor].iPool+=g_ePlayer[client].iWagered;
            SetClientCredits(client, GetClientCredits(client)-iWagered);
            LoopClients(i)
                CPrintToChat(i, "%s %T", g_eSettings.sTag, "player joined to roulette", i, client, g_ePlayer[client].iWagered);
        }
        else if(StrEqual(sBuffer[0], "black"))
        {
            g_ePlayer[client].iColor = 0;
            g_ePlayer[client].iWagered = iWagered;
            g_eColors[g_ePlayer[client].iColor].iPool+=g_ePlayer[client].iWagered;
            SetClientCredits(client, GetClientCredits(client)-iWagered);
            LoopClients(i)
                CPrintToChat(i, "%s %T", g_eSettings.sTag, "player joined to roulette", i, client, g_ePlayer[client].iWagered);
        }
        else if(StrEqual(sBuffer[0], "green"))
        {
            g_ePlayer[client].iColor = 2;
            g_ePlayer[client].iWagered = iWagered;
            g_eColors[g_ePlayer[client].iColor].iPool+=g_ePlayer[client].iWagered;
            SetClientCredits(client, GetClientCredits(client)-iWagered);
            LoopClients(i)
                CPrintToChat(i, "%s %T", g_eSettings.sTag, "player joined to roulette", i, client, g_ePlayer[client].iWagered);
        }
        else 
        {
            CPrintToChat(client, "%s %T", g_eSettings.sTag, "wrong cmd usage", client);
            return Plugin_Handled;
        }
    }
    else
        CPrintToChat(client, "%s %T", g_eSettings.sTag, "wrong cmd usage", client);
    return Plugin_Handled;
}

public void OnMapStart()
{
    CreateTimer(60.0, StartRouletteTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(1.0, ShowHud, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    for (int i; i < 14; i++)
    {
        g_eRoulette.iLastColors[i] = -1;
    }
}

public void StartRoulette()
{
    CreateTimer(15.0, FifteenTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(30.0, ThirtyTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(45.0, FortyFiveTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(57.0, LastThreeTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(58.0, LastTwoTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(59.0, LastSecondTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(60.0, EndRouletteTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    g_eRoulette.iTime = 60;
    g_eRoulette.bActive = true;
    LoopClients(i)
    {
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "roulette started", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "roulette command", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "roulette time 60", i);
    }
}

public Action ShowHud(Handle timer)
{
    if(!g_eRoulette.bActive || !g_eRoulette.iTime)
        return Plugin_Continue;
    g_eRoulette.iTime--;
	LoopClients(i)
		if(g_ePlayer[i].iDisplayType == 1)
			ShowHudToClient(i);
    return Plugin_Continue;
}

public void ShowHudToClient(int client)
{
	SetHudTextParamsEx(0.02, 0.89, 10.0, {26, 166, 10, 0}, {26, 166, 10, 0}, 1, 0.0, 0.0, 0.0);
    ShowSyncHudText(client, hSync, "%T: %i Black: %i Red: %i Green: %i ", "time", client, g_eRoulette.iTime, g_eColors[0].iPool, g_eColors[1].iPool, g_eColors[2].iPool);
}

public Action FifteenTimer(Handle timer)
{
    LoopClients(i)
    {
        if(g_ePlayer[i].iDisplayType != 0)
            continue;
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "last 45 seconds", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "roulette command", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "credits pool", i, g_eColors[0].iPool, g_eColors[1].iPool, g_eColors[2].iPool);
    }
    return Plugin_Continue;
}

public Action ThirtyTimer(Handle timer)
{
    LoopClients(i)
    {
        if(g_ePlayer[i].iDisplayType != 0)
            continue;
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "last 30 seconds", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "roulette command", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "credits pool", i, g_eColors[0].iPool, g_eColors[1].iPool, g_eColors[2].iPool);
    }
    return Plugin_Continue;
}

public Action FortyFiveTimer(Handle timer)
{
    LoopClients(i)
    {
        if(g_ePlayer[i].iDisplayType != 0)
            continue;
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "last 15 seconds", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "roulette command", i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "credits pool", i, g_eColors[0].iPool, g_eColors[1].iPool, g_eColors[2].iPool);
    }
    return Plugin_Continue;
}

public Action LastThreeTimer(Handle timer)
{
    LoopClients(i)
    {
        if(g_ePlayer[i].iDisplayType != 0)
            continue;
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "last 3 seconds", i);
    }
    return Plugin_Continue;
}

public Action LastTwoTimer(Handle timer)
{
    LoopClients(i)
    {
        if(g_ePlayer[i].iDisplayType != 0)
            continue;
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "last 2 seconds", i);
    }
    return Plugin_Continue;
}

public Action LastSecondTimer(Handle timer)
{
    LoopClients(i)
    {
        if(g_ePlayer[i].iDisplayType != 0)
            continue;
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "last 1 seconds", i);
    }
    return Plugin_Continue;
}

public Action EndRouletteTimer(Handle timer)
{
    EndRoulette();
    return Plugin_Continue;
}

public Action EndRoulette()
{
    float fRandom = GetRandomFloat(0.0, 100.0);
    if(fRandom >= 0.0 && fRandom <= 47.5)
        ColorWin(0);
    else if(fRandom > 47.5 && fRandom <= 95.0)
        ColorWin(1);
    else
        ColorWin(2);

    int iTime;
    GetMapTimeLeft(iTime);
    if(iTime > 105+g_eSettings.iDelay)
    {
        LoopClients(i)
            CPrintToChat(i, "%s %T", g_eSettings.sTag, "start in next seconds", i, g_eSettings.iDelay);
        CreateTimer(float(g_eSettings.iDelay), StartRouletteTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    else
        LoopClients(i)
            CPrintToChat(i, "%s %T", g_eSettings.sTag, "no next roulette", i);
    return Plugin_Continue;
}

public void ColorWin(int color)
{
    int iMultiplier = color == 0 || color == 1 ? 2 : 14;
    LoopClients(i)
    {
        if(g_ePlayer[i].iColor == color && g_ePlayer[i].iWagered)
        {
            SetClientCredits(i, GetClientCredits(i)+g_ePlayer[i].iWagered*iMultiplier);
            CPrintToChat(i, "%s %T", g_eSettings.sTag, "credits win", i, g_ePlayer[i].iWagered*iMultiplier);
            g_ePlayer[i].iWins++;
            g_ePlayer[i].iMoneyWon+=g_ePlayer[i].iWagered*iMultiplier;
        }
        else if(g_ePlayer[i].iWagered)
        {
            g_ePlayer[i].iLoses++;
            g_ePlayer[i].iMoneyLost+=g_ePlayer[i].iWagered;
        }
        g_ePlayer[i].iWagered = 0;
        g_ePlayer[i].iColor = -1;
        CPrintToChat(i, "%s %T %T", g_eSettings.sTag, "winner color", i, g_sColors[color], i);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "winner credits", i, g_eColors[color].iPool*iMultiplier);
        CPrintToChat(i, "%s %T", g_eSettings.sTag, "loses credits", i, g_eColors[color == 0 ? 1 : 0].iPool+g_eColors[color == 1 ? 2 : 1].iPool);
    }
    for(int i; i < 3; i++)
        g_eColors[i].iPool = 0;
    for(int i = 14; i >= 0; i--)
    {
        if(i != 0)
            g_eRoulette.iLastColors[i]=g_eRoulette.iLastColors[i-1];
        else
            g_eRoulette.iLastColors[i]=color;
    }
    g_eRoulette.bActive = false;
}

public Action StartRouletteTimer(Handle timer)
{
    StartRoulette();
    return Plugin_Continue;
}

public void RouletteMenu(int client)
{
    char sBuffer[128];
    Menu menu = new Menu(RouletteMenu_Handler);
    menu.SetTitle("%T", "select action", client);
    Format(sBuffer, sizeof(sBuffer), "%T", "display settings", client);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "%T", "roulette info", client);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "%T", "roulette top", client);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "%T", "last 15 colors", client);
    menu.AddItem("", sBuffer);
    menu.Display(client, MENU_TIME_FOREVER);
}

public int RouletteMenu_Handler(Menu menu, MenuAction menuAction, int client, int Position)
{
    switch(menuAction)
    {
        case MenuAction_Select: {
            switch(Position)
            {
                case 0: DisplaySettingsMenu(client);
                case 1: RouletteInfoMenu(client);
                case 2: RouletteTopMenu(client);
                case 3: LastFifteenColors(client);
            }
        }
        case MenuAction_End: delete menu;
    }
    return 0;
}

public void DisplaySettingsMenu(int client)
{
    Menu menu = new Menu(DisplaySettingsMenu_Handler);
    menu.SetTitle("%T", "select display type", client);
    char sBuffer[128];
    Format(sBuffer, sizeof(sBuffer), "[%s] %T", g_ePlayer[client].iDisplayType == 0 ? "■" : " ", "display on chat", client);
    menu.AddItem("", sBuffer, g_ePlayer[client].iDisplayType == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    Format(sBuffer, sizeof(sBuffer), "[%s] %T", g_ePlayer[client].iDisplayType == 1 ? "■" : " ", "display on hud", client);
    menu.AddItem("", sBuffer, g_ePlayer[client].iDisplayType == 1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    Format(sBuffer, sizeof(sBuffer), "[%s] %T", g_ePlayer[client].iDisplayType == 2 ? "■" : " ", "disable display", client);
    menu.AddItem("", sBuffer, g_ePlayer[client].iDisplayType == 2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int DisplaySettingsMenu_Handler(Menu menu, MenuAction menuAction, int client, int Position)
{
    switch(menuAction)
    {
        case MenuAction_Select: {
            g_ePlayer[client].iDisplayType = Position;
            DisplaySettingsMenu(client);
        }
        case MenuAction_Cancel: {
            if(Position == MenuCancel_ExitBack)
                RouletteMenu(client);
        }
        case MenuAction_End: delete menu;
    }
    return 0;
}

public void RouletteInfoMenu(int client)
{
    Menu menu = new Menu(RouletteInfoMenu_Handler);
    menu.SetTitle("%T\n%T\n%T\n%T", "black chance and multiplier", client, "red chance and multiplier", client, "green chance and multiplier", client, "roulette command menu", client);
    char sBuffer[128];
    Format(sBuffer, sizeof(sBuffer), "%T", "return", client);
    menu.AddItem("", sBuffer);
    Format(sBuffer, sizeof(sBuffer), "%T", "leave", client);
    menu.AddItem("", sBuffer);
    menu.ExitButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int RouletteInfoMenu_Handler(Menu menu, MenuAction menuAction, int client, int Position)
{
    switch(menuAction)
    {
        case MenuAction_Select: {
            if(Position == 0)
                RouletteMenu(client);
        }
        case MenuAction_End: delete menu;
    }
    return 0;
}

public void LastFifteenColors(int client)
{
    char sBuffer[128];
    Menu menu = new Menu(LastFifteenColors_Handler);
    menu.SetTitle("%T", "last 15 colors", client);
    for (int i; i < 14; i++)
    {
        if(g_eRoulette.iLastColors[i] < 0)
            continue;
        Format(sBuffer, sizeof(sBuffer), "%T", g_sColors[g_eRoulette.iLastColors[i]], client);
        menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int LastFifteenColors_Handler(Menu menu, MenuAction menuAction, int client, int Position)
{
    switch(menuAction)
    {
        case MenuAction_Cancel: {
            if(Position == MenuCancel_ExitBack)
                RouletteMenu(client);
        }
        case MenuAction_End: delete menu;
    }
    return 0;
}

public void OnMapEnd()
{
    LoopClients(i)
        SetClientCredits(i, GetClientCredits(i)+g_ePlayer[i].iWagered);
}

void RouletteTopMenu(int client, int top = 0)
{
    switch(top)
    {
        case 0: TopWinsMenu(client);
        case 1: TopLosesMenu(client);
        case 2: TopCreditsWonMenu(client);
        case 3: TopCreditsLostMenu(client);
    }
}

public void TopWinsMenu(int client)
{
    char sBuffer[256], sName[MAX_NAME_LENGTH];
    Menu menu = new Menu(RouletteTopMenu_Handler);
    menu.SetTitle("%T", "top wins", client);
    Format(sBuffer, sizeof(sBuffer), "[ %T ] | %T | %T | %T", "wins", client, "loses", client, "credits_won", client, "credits_lost", client);
    menu.AddItem("0", sBuffer);
    DBResultSet query = SQL_Query(DB, "SELECT `nick`, `wins` FROM `lRoulette` ORDER BY `wins` DESC LIMIT 5");
    while(SQL_FetchRow(query))
    {
        SQL_FetchString(query, 0, sName, sizeof(sName));
        Format(sBuffer, sizeof(sBuffer), "%s : %i", sName, SQL_FetchInt(query, 1));
        menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void TopLosesMenu(int client)
{
    char sBuffer[256], sName[MAX_NAME_LENGTH];
    Menu menu = new Menu(RouletteTopMenu_Handler);
    menu.SetTitle("%T", "top loses", client);
    Format(sBuffer, sizeof(sBuffer), "%T | [ %T ] | %T | %T", "wins", client, "loses", client, "credits_won", client, "credits_lost", client);
    menu.AddItem("1", sBuffer);
    DBResultSet query = SQL_Query(DB, "SELECT `nick`, `loses` FROM `lRoulette` ORDER BY `loses` DESC LIMIT 5");
    while(SQL_FetchRow(query))
    {
        SQL_FetchString(query, 0, sName, sizeof(sName));
        Format(sBuffer, sizeof(sBuffer), "%s : %i", sName, SQL_FetchInt(query, 1));
        menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void TopCreditsWonMenu(int client)
{
    char sBuffer[256], sName[MAX_NAME_LENGTH];
    Menu menu = new Menu(RouletteTopMenu_Handler);
    menu.SetTitle("%T", "top credits won", client);
    Format(sBuffer, sizeof(sBuffer), "%T | %T | [ %T ] | %T", "wins", client, "loses", client, "credits_won", client, "credits_lost", client);
    menu.AddItem("2", sBuffer);
    DBResultSet query = SQL_Query(DB, "SELECT `nick`, `money_won` FROM `lRoulette` ORDER BY `money_won` DESC LIMIT 5");
    while(SQL_FetchRow(query))
    {
        SQL_FetchString(query, 0, sName, sizeof(sName));
        Format(sBuffer, sizeof(sBuffer), "%s : %i", sName, SQL_FetchInt(query, 1));
        menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public void TopCreditsLostMenu(int client)
{
    char sBuffer[256], sName[MAX_NAME_LENGTH];
    Menu menu = new Menu(RouletteTopMenu_Handler);
    menu.SetTitle("%T", "top credits lost", client);
    Format(sBuffer, sizeof(sBuffer), "%T | %T | %T | [ %T ]", "wins", client, "loses", client, "credits_won", client, "credits_lost", client);
    menu.AddItem("3", sBuffer);
    DBResultSet query = SQL_Query(DB, "SELECT `nick`, `money_lost` FROM `lRoulette` ORDER BY `money_lost` DESC LIMIT 5");
    while(SQL_FetchRow(query))
    {
        SQL_FetchString(query, 0, sName, sizeof(sName));
        Format(sBuffer, sizeof(sBuffer), "%s : %i", sName, SQL_FetchInt(query, 1));
        menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
    }
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int RouletteTopMenu_Handler(Menu menu, MenuAction menuAction, int client, int Position)
{
    switch(menuAction)
    {
        case MenuAction_Select: {
            char sBuffer[16];
            menu.GetItem(Position, sBuffer, sizeof(sBuffer));
            RouletteTopMenu(client, StringToInt(sBuffer)+1 == 4 ? 0 : StringToInt(sBuffer)+1);
        }
        case MenuAction_Cancel: {
            if(Position == MenuCancel_ExitBack)
                RouletteMenu(client);
        }
        case MenuAction_End: delete menu;
    }
    return 0;
}

public void OnClientPutInServer(int client)
{
    PrepareLoad(client);
}

public void PrepareLoad(int client)
{
    if(!IsValidClient(client))
        return;
    char sid[64], sBuffer[256];
    GetClientAuthId(client, AuthId_Steam2, sid, sizeof(sid));
    g_ePlayer[client].bIsLoad = false;
    Format(sBuffer, sizeof(sBuffer), "SELECT `wins`, `loses`, `money_won`, `money_lost`, `display_type` FROM `lRoulette` WHERE `steamid`='%s';", sid);
    SQL_TQuery(DB, Load, sBuffer, client);
}

public void Load(Handle owner, Handle query, const char[] error, any client)
{
    if(query == INVALID_HANDLE)
	{
		LogError("Błąd przy ładowaniu danych: %s", error);
		return;
	}
    if(SQL_FetchRow(query))
    {
        g_ePlayer[client].iWins = SQL_FetchInt(query, 0);
        g_ePlayer[client].iLoses = SQL_FetchInt(query, 1);
        g_ePlayer[client].iMoneyWon = SQL_FetchInt(query, 2);
        g_ePlayer[client].iMoneyLost = SQL_FetchInt(query, 3);
        g_ePlayer[client].iDisplayType = SQL_FetchInt(query, 4);
    }
    else
    {
        g_ePlayer[client].iWins = 0;
        g_ePlayer[client].iLoses = 0;
        g_ePlayer[client].iMoneyWon = 0;
        g_ePlayer[client].iMoneyLost = 0;
        g_ePlayer[client].iDisplayType = g_eSettings.iDefaultDisplay;
    }
    g_ePlayer[client].bIsLoad = true;
}

public void OnClientDisconnect(int client)
{
    SaveData(client);
    g_ePlayer[client].iWagered = 0;
    g_ePlayer[client].iColor = -1;
}

public void SaveData(int client)
{
    if(!IsValidClient(client) || !g_ePlayer[client].bIsLoad)
        return;

    char sBuffer[512], sid[64], sName[MAX_NAME_LENGTH], sEscapeName[MAX_NAME_LENGTH*2+1];
    GetClientAuthId(client, AuthId_Steam2, sid, sizeof(sid));
    GetClientName(client, sName, sizeof(sName));
    SQL_EscapeString(DB, sName, sEscapeName, sizeof(sEscapeName));
    Format(sBuffer, sizeof(sBuffer), "INSERT INTO `lRoulette` (`nick`, `steamid`, `wins`, `loses`, `money_won`, `money_lost`, `display_type`) VALUES('%s', '%s', '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE `nick`=VALUES(`nick`), `wins`=VALUES(`wins`), `loses`=VALUES(`loses`), `money_won`=VALUES(`money_won`), `money_lost`=VALUES(`money_lost`), `display_type`=VALUES(`display_type`);", sEscapeName, sid, g_ePlayer[client].iWins, g_ePlayer[client].iLoses, g_ePlayer[client].iMoneyWon, g_ePlayer[client].iMoneyLost, g_ePlayer[client].iDisplayType);
    SQL_TQuery(DB, SaveData_Handler, sBuffer);
}

public void SaveData_Handler(Handle owner, Handle query, const char[] error, any data)
{
    if(query == INVALID_HANDLE)
	{
		LogError("Błąd przy zapisywaniu danych: %s", error);
		return;
	}
}

stock int GetClientCredits(int client)
{
    if(g_eCredits.bStore)
        return Store_GetClientCredits(client);
    else if(g_eCredits.bBBCredits)
        return GetClientCoins(client);
    else if(g_eCredits.bCaseOpening)
        return RoundToCeil(Cases_GetClientBalance(client));
    else if(g_eCredits.blShop)
        return lShop_GetClientCredits(client);
    else if(g_eCredits.bLR)
        return LR_GetClientInfo(client, ST_RANK);
    return -1;
}

stock void SetClientCredits(int client, int credits)
{
    if(g_eCredits.bStore)
        Store_SetClientCredits(client, credits);
    else if(g_eCredits.bBBCredits)
        SetClientCoins(client, credits);
    else if(g_eCredits.bCaseOpening)
        Cases_SetClientBalance(client, float(credits));
    else if(g_eCredits.blShop)
        lShop_SetClientCredits(client, credits);
    else if(g_eCredits.bLR)
        LR_SetClientStats(client, ST_RANK, credits);
}

public void DatabaseConnect()
{
    char error[1024];
    DB = SQL_Connect("lRoulette", true, error, sizeof(error));
    if(DB == INVALID_HANDLE)
    {
        LogError("Nie można się połączyć z bazą : %s", error);
        SQL_iDatabase = 0;
        return;
    }
	else if (SQL_iDatabase < 1)
	{
		SQL_iDatabase++;
		SQL_LockDatabase(DB);
		SQL_FastQuery(DB, "CREATE TABLE IF NOT EXISTS `lRoulette`(`nick` varchar(64) NOT NULL, `steamid` varchar(45) NOT NULL PRIMARY KEY, `wins` INT NOT NULL, `loses` INT NOT NULL, `money_won` INT NOT NULL, `money_lost` INT NOT NULL, `display_type` INT NOT NULL);");
		SQL_UnlockDatabase(DB);
		DatabaseConnect(); 
	}
}

stock bool IsVip(int client)
{
    if(ReadFlagString(g_eSettings.sVipFlag) & GetUserFlagBits(client) || ADMFLAG_ROOT & GetUserFlagBits(client)) 
        return true;
    return false;
}

stock bool IsValidClient(int client) 
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	if (IsFakeClient(client))return false;
	if (IsClientSourceTV(client))return false;
	return IsClientInGame(client);
}