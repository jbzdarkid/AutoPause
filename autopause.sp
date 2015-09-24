#include <sourcemod>
#include <l4d2_direct>
#include <l4d2d_timers>

public Plugin:myinfo =
{
    name = "L4D2 Auto-pause",
    author = "Darkid",
    description = "When a player disconnects due to crash, automatically pause the game. When they rejoin, give them a correct spawn timer.",
    version = "1.5",
    url = "https://github.com/jbzdarkid/AutoPause"
}

new Handle:enabled;
new Handle:force;

public OnPluginStart() {
    // Suggestion by Nati: Disable for any 1v1
    enabled = CreateConVar("autopause_enable", "1", "Whether or not to automatically pause when a player crashes.");
    force = CreateConVar("autopause_force", "0", "Whether or not to force pause when a player crashes.");
    
    HookEvent("round_start", round_start);
    HookEvent("player_team", player_team);
    HookEvent("player_disconnect", player_disconnect, EventHookMode_Pre);
}

new String:activePlayers[8][64];
new Float:spawnTimers[8];

public round_start(Handle:event, const String:name[], bool:dontBroadcast) {
    new index = 0;
    for (new client=1; client<=MaxClients; client++) {
        if (!IsClientInGame(client)) continue;
        if (IsFakeClient(client)) continue;
        new team = GetClientTeam(client);
        if (team != 2 && team != 3) continue;
        decl String:steamId[64];
        GetClientAuthString(client, steamId, sizeof(steamId));
        activePlayers[index] = steamId;
        spawnTimers[index] = 0.0;
        index++;
    }
    for (; index<8; index++) {
        activePlayers[index] = "";
        spawnTimers[index] = -1.0;
    }
}

public player_team(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients) return;
    decl String:steamId[64];
    GetClientAuthString(client, steamId, sizeof(steamId));

    new firstOpen = -1;
    for (new i=0; i<8; i++) {
        if (firstOpen == -1 && strcmp(activePlayers[i], "") == 0) {
            firstOpen = i;
        } else if (strcmp(activePlayers[i], steamId) == 0) {
            switch (GetEventInt(event, "team")) {
            case 1: { // Joined spectator, remove.
                activePlayers[i] = "";
                spawnTimers[i] = -1.0;
            }
            case (2, 3): { // Joined team, set spawn timer.
                new CountdownTimer:spawnTimer = L4D2Direct_GetSpawnTimer(client);
                if (spawnTimers[i] != -1.0) {
                    CTimer_Start(spawnTimer, spawnTimers[i]);
                    LogMessage("[AutoPause] Player %s rejoined, set spawn timer to %f.", steamId, spawnTimers[i]);
                }
            }
            }
            return;
        }
    }
    if (firstOpen == -1) {
        LogMessage("[AutoPause] Error: Player joined team but couldn't find open spot.");
    } else if (strcmp(steamId, "BOT") != 0) { // Don't add bots.
        activePlayers[firstOpen] = steamId;
        spawnTimers[firstOpen] = -1.0;
    }
}

public player_disconnect(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients) return;
    if (!GetConVarBool(enabled)) return;
    decl String:steamId[64];
    GetClientAuthString(client, steamId, sizeof(steamId));
    if (strcmp(steamId, "BOT") == 0) return;
    for (new i=0; i<8; i++) {
        if (strcmp(activePlayers[i], steamId) == 0) {
            new Float:timeLeft = -1.0;
            new CountdownTimer:spawnTimer = L4D2Direct_GetSpawnTimer(client);
            if (spawnTimer != CTimer_Null) {
                timeLeft = CTimer_GetRemainingTime(spawnTimer);
            }
            spawnTimers[i] = timeLeft;
            decl String:reason[64];
            GetEventString(event, "reason", reason, sizeof(reason));
            if (strcmp(reason, "Client timed out") == 0 || strcmp(reason, "No Steam logon") == 0) {
                if (GetConVarBool(force)) {
                    ServerCommand("sm_forcepause");
                } else {
                    ServerCommand("sm_pause");
                }
                decl String:playerName[128];
                GetEventString(event, "name", playerName, sizeof(playerName));
                PrintToChatAll("[AutoPause] Player %s crashed.", playerName);
            }
            break;
        }
    }
}