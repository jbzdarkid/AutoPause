#include <sourcemod>

public Plugin:myinfo =
{
    name = "L4D2 Auto-pause",
    author = "Darkid",
    description = "When a player disconnects due to crash, automatically pause the game.",
    version = "1.0",
    url = "https://github.com/jbzdarkid/AutoPause"
}

public OnPluginStart() {
    HookEvent("round_start", round_start);
    HookEvent("player_disconnect", player_disconnect);
}

new activePlayers[8] = -1;

public bool:isPlayer(any:client) {
    for (new i=0; i<8; i++) {
        if (activePlayers[i] == client) return true;
    }
    return false;
}

public round_start(Handle:event, const String:name[], bool:dontBroadcast) {
    new index = 0;
    for (new client=1; client<=MaxClients; client++) {
        if (IsFakeClient(client)) continue;
        if (!IsClientConnected(client)) continue;
        new team = GetClientTeam(client);
        if (team != 2 && team != 3) continue;
        activePlayers[index] = client;
    }
    for (; index<8; index++) {
        activePlayers[index] = -1;
    }
}

public player_disconnect(Handle:event, const String:name[], bool:dontBroadcast) {
    if (!isPlayer(GetEventInt(event, "userid"))) return;
    decl String:reason[64];
    GetEventString(event, "reason", reason, sizeof(reason));
    if (strcmp(reason, "Player timed out.") == 0 || strcmp(reason, "No steam logon.") == 0) {
        ServerCommand("sm_pause");
    }
    decl String:playerName[128];
    GetEventString(event, "name", playerName, sizeof(playerName));
    PrintToChatAll("[AutoPause] Player %s crashed.", playerName);
}