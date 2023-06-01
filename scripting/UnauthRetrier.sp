#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Unauth Retrier",
	author = "Vauff",
	description = "Auto retries players without steam auth to prevent them breaking it for the entire server",
	version = "1.1",
	url = "https://github.com/Vauff/UnauthRetrier"
};

ConVar g_cvRetryDelay;
ConVar g_cvBulkThreshold;

bool g_bBulkRetryTimerEnabled = false;

public void OnPluginStart()
{
	g_cvRetryDelay = CreateConVar("sm_unauth_retry_delay", "60", "How long to wait for a client to auth before forcing them to retry", _, true, 5.0);
	g_cvBulkThreshold = CreateConVar("sm_unauth_bulk_threshold", "3", "How many clients need to be unauthenticated to enable simultaneous bulk retries", _, true, 2.0);

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

public void OnMapStart()
{
	g_bBulkRetryTimerEnabled = false;
}

Action Timer_CheckAuth(Handle timer, DataPack data)
{
	data.Reset();
	int userid = data.ReadCell();
	int client = GetClientOfUserId(userid);
	int seconds = data.ReadCell();

	if (client == 0 || IsClientAuthorized(client))
		return Plugin_Handled;

	if (BulkRetryEnabled())
	{
		if (seconds < 15)
			PrintToChat(client, " \x04[SM] \x05Auto retry postponed for technical reasons, a new timer will begin shortly if auth does not succeed");

		if (!g_bBulkRetryTimerEnabled)
		{
			CreateTimer(1.0, Timer_BulkRetry, g_cvRetryDelay.IntValue, TIMER_FLAG_NO_MAPCHANGE);
			g_bBulkRetryTimerEnabled = true;
		}

		return Plugin_Handled;
	}

	if (seconds > 0)
	{
		if (seconds <= 15)
			SendRetryMsg(client, seconds);

		DataPack dp;
		CreateDataTimer(1.0, Timer_CheckAuth, dp, TIMER_FLAG_NO_MAPCHANGE);
		dp.WriteCell(userid);
		dp.WriteCell(seconds - 1);
	}
	else
	{
		Retry(client);
	}

	return Plugin_Handled;
}

Action Timer_BulkRetry(Handle timer, int seconds)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || IsClientAuthorized(client))
			continue;

		if (seconds > 0 && seconds <= 15)
			SendRetryMsg(client, seconds);

		if (seconds == 0)
			Retry(client);
	}

	if (seconds > 0)
	{
		CreateTimer(1.0, Timer_BulkRetry, seconds - 1, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		RequestFrame(DisableBulkRetryTimer);
		LogMessage("Finished bulk retry");
	}

	return Plugin_Handled;
}

void SendRetryMsg(int client, int seconds)
{
	PrintToChat(client, " \x04[SM] \x05Steam has not authenticated you yet, you will be auto retried in \x0F%i seconds \x05if auth does not succeed", seconds);
}

void Retry(int client)
{
	LogMessage("Retrying %L for Steam auth", client);
	ClientCommand(client, "retry");
}

void DisableBulkRetryTimer()
{
	g_bBulkRetryTimerEnabled = false;
}

bool BulkRetryEnabled()
{
	int unauthCount = 0;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientAuthorized(client))
			unauthCount++;
	}

	return unauthCount >= g_cvBulkThreshold.IntValue;
}