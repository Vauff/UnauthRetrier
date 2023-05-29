#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Unauth Retrier",
	author = "Vauff",
	description = "Auto retries players without steam auth to prevent them breaking it for the entire server",
	version = "1.0",
	url = "https://github.com/Vauff/UnauthRetrier"
};

ConVar g_cvRetryDelay;

public void OnPluginStart()
{
	g_cvRetryDelay = CreateConVar("sm_unauth_retry_delay", "60", "How long to wait for a client to auth before forcing them to retry", _, true, 5.0);

	AutoExecConfig(true, "UnauthRetrier");
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client) || IsClientAuthorized(client))
		return;

	DataPack dp;
	CreateDataTimer(1.0, Timer_CheckAuth, dp, TIMER_FLAG_NO_MAPCHANGE);
	dp.WriteCell(GetClientUserId(client));
	dp.WriteCell(g_cvRetryDelay.IntValue);
}

Action Timer_CheckAuth(Handle timer, DataPack data)
{
	data.Reset();
	int userid = data.ReadCell();
	int client = GetClientOfUserId(userid);
	int seconds = data.ReadCell();

	if (client == 0 || IsClientAuthorized(client))
		return Plugin_Handled;

	if (seconds > 0)
	{
		if (seconds <= 15)
			PrintToChat(client, " \x04[SM] \x05Steam has not authenticated you yet, you will be auto retried in \x0F%i seconds \x05if auth does not succeed", seconds);

		DataPack dp;
		CreateDataTimer(1.0, Timer_CheckAuth, dp);
		dp.WriteCell(userid);
		dp.WriteCell(seconds - 1);
	}
	else
	{
		LogMessage("Retrying %L for Steam auth", client);
		ClientCommand(client, "retry");
	}

	return Plugin_Handled;
}