void Commands_Init()
{
	RegConsoleCmd("sm_cantsee", Command_CantSee);
	
	RegAdminCmd("sm_rndclass", Command_Class, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndweapon", Command_Weapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndgenerate", Command_Generate, ADMFLAG_CHANGEMAP);
}

public Action Command_CantSee(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iClient == 0)
		return Plugin_Handled;
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return Plugin_Handled;
	
	if (ViewModels_ToggleInvisible(iWeapon))
		ReplyToCommand(iClient, "Your active weapon is now fully visible.");
	else
		ReplyToCommand(iClient, "Your active weapon is now transparent.");
	
	return Plugin_Handled;
}

public Action Command_Class(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Format: sm_rndclass <@target> <class string>");
		return Plugin_Handled;
	}
	
	char sTarget[32], sClass[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sClass, sizeof(sClass));
	TFClassType nClass = TF2_GetClass(sClass);
	if (nClass == TFClass_Unknown)
	{
		ReplyToCommand(iClient, "Unable to get class '%s'", sClass);
		return Plugin_Handled;
	}
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set class");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iTargetCount; i++)
	{
		g_iClientClass[iClient] = nClass;
		TF2_SetPlayerClass(iClient, nClass);
		
		if (IsPlayerAlive(iClient))
			TF2_RespawnPlayer(iClient);
	}
	
	ReplyToCommand(iClient, "Set %s class to %s", sTargetName, sClass);
	return Plugin_Handled;
}

public Action Command_Weapon(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 3)
	{
		ReplyToCommand(iClient, "Format: sm_rndweapon <@target> <slot> <weapon def index>");
		return Plugin_Handled;
	}
	
	int iSlot, iIndex;
	char sTarget[32], sSlot[12], sIndex[12];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sSlot, sizeof(sSlot));
	GetCmdArg(3, sIndex, sizeof(sIndex));
	
	if (!StringToIntEx(sSlot, iSlot) || iSlot < 0 || iSlot > WeaponSlot_BuilderEngie)
	{
		ReplyToCommand(iClient, "Invalid slot '%s'", sSlot);
		return Plugin_Handled;
	}
	
	if (!StringToIntEx(sIndex, iIndex))
	{
		ReplyToCommand(iClient, "Invalid weapon def index '%s'", sIndex);
		return Plugin_Handled;
	}
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to set weapon def index");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iTargetCount; i++)
		g_iClientWeaponIndex[iTargetList[i]][iSlot] = iIndex;
	
	ReplyToCommand(iClient, "Set %s weapon def index at slot '%d' to '%d'", sTargetName, iSlot, iIndex);
	return Plugin_Handled;
}

public Action Command_Generate(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "Format: sm_rndgenerate <@target>");
		return Plugin_Handled;
	}
	
	char sTarget[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to regenerate class and weapons");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < iTargetCount; i++)
	{
		GenerateRandomWeapon(iTargetList[i]);
		
		if (TF2_GetClientTeam(iTargetList[i]) > TFTeam_Spectator)
			TF2_RespawnPlayer(iClient);
	}

	ReplyToCommand(iClient, "Regenerated %s class and weapons", sTargetName);
	return Plugin_Handled;
}