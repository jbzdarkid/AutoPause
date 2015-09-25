#include <sourcemod>
#include <l4d2_direct>
#include <l4d2d_timers>

public Plugin:myinfo =
{
    name = "L4D2 Auto-pause",
    author = "Darkid, Griffin",
    description = "When a player disconnects due to crash, automatically pause the game. When they rejoin, give them a correct spawn timer.",
    version = "1.7",
    url = "https://github.com/jbzdarkid/AutoPause"
}

new Handle:enabled;
new Handle:force;
new Handle:crashedPlayers;

public OnPluginStart() {
    // Suggestion by Nati: Disable for any 1v1
    enabled = CreateConVar("autopause_enable", "1", "Whether or not to automatically pause when a player crashes.");
    force = CreateConVar("autopause_force", "0", "Whether or not to force pause when a player crashes.");

    crashedPlayers = CreateTrie();

    HookEvent("round_start", round_start);
    HookEvent("player_team", player_team);
    HookEvent("player_disconnect", player_disconnect, EventHookMode_Pre);
}

public round_start(Handle:event, const String:name[], bool:dontBroadcast) {
    ClearTrie(crashedPlayers);
}

public player_team(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients) return;
    decl String:steamId[64];
    GetClientAuthString(client, steamId, sizeof(steamId));

    LogMessage("Player %d (%s) joined team %d", client, steamId, GetEventInt(event, "team"));

    if (GetEventInt(event, "team") == 3) {
        new Float:spawnTime;
        if (GetTrieValue(crashedPlayers, steamId, spawnTime)) {
            new CountdownTimer:spawnTimer = L4D2Direct_GetSpawnTimer(client);
            CTimer_Start(spawnTimer, spawnTime);
            RemoveFromTrie(crashedPlayers, steamId);
            LogMessage("[AutoPause] Player %s rejoined, set spawn timer to %f.", steamId, spawnTime);
        }
    }
}

public player_disconnect(Handle:event, const String:name[], bool:dontBroadcast) {
    if (!GetConVarBool(enabled)) return;
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients) return;
    new oldTeam = GetEventInt(event, "oldteam");
    if (oldTeam != 2 && oldTeam != 3) return;
    decl String:steamId[64];
    GetClientAuthString(client, steamId, sizeof(steamId));
    if (strcmp(steamId, "BOT") == 0) return;

    decl String:reason[64];
    GetEventString(event, "reason", reason, sizeof(reason));
    decl String:playerName[128];
    GetEventString(event, "name", playerName, sizeof(playerName));
    
    LogMessage("Player %d (%s) [%s] disconnected from team %d (%s)", client, steamId, name, oldTeam, reason);
    
    decl String:timedOut[256];
    Format(timedOut, sizeof(timedOut), "%s timed out", playerName);
    if (strcmp(reason, timedOut) == 0 || strcmp(reason, "No Steam logon") == 0) {
        if (GetConVarBool(force)) {
            ServerCommand("sm_forcepause");
        } else {
            FakeClientCommand(client, "sm_pause");
        }
        PrintToChatAll("[AutoPause] Player %s crashed.", playerName);
    }

    if (oldTeam == 3) {
        new Float:timeLeft = -1.0;
        new CountdownTimer:spawnTimer = L4D2Direct_GetSpawnTimer(client);
        if (spawnTimer != CTimer_Null) {
            timeLeft = CTimer_GetRemainingTime(spawnTimer);
            LogMessage("Player crashed with %f time until spawn.", timeLeft);
            SetTrieValue(crashedPlayers, steamId, timeLeft);
        }
    }
}