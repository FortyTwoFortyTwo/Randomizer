void Commands_Init()
{
	RegConsoleCmd("sm_cantsee", Command_CantSee);
	
	RegAdminCmd("sm_class", Command_Class, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_weapon", Command_Weapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_generate", Command_Generate, ADMFLAG_CHANGEMAP);
}

public Action Command_CantSee(int iClient, int iArgs)
{
	if (iClient == 0)
		return Plugin_Handled;
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return Plugin_Handled;
	
	if (GetEntityRenderMode(iWeapon) == RENDER_TRANSCOLOR)
	{
		SetEntityRenderMode(iWeapon, RENDER_NORMAL); 
		SetEntityRenderColor(iWeapon, 255, 255, 255, 255);
		ReplyToCommand(iClient, "Your active weapon is now fully visible.");
	}
	else
	{
		SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iWeapon, 255, 255, 255, 75);
		ReplyToCommand(iClient, "Your active weapon is now transparent.");
	}
	
	return Plugin_Handled;
}

public Action Command_Class(int iClient, int iArgs)
{
	if (iClient == 0 || iArgs <= 0)
		return Plugin_Handled;
	
	char sClass[32];
	GetCmdArg(1, sClass, sizeof(sClass));
	TFClassType nClass = TF2_GetClass(sClass);
	if (nClass == TFClass_Unknown)
		return Plugin_Handled;
	
	g_iClientClass[iClient] = nClass;
	TF2_SetPlayerClass(iClient, nClass);
	
	if (IsPlayerAlive(iClient))
		TF2_RespawnPlayer(iClient);
	
	return Plugin_Handled;
}

public Action Command_Weapon(int iClient, int iArgs)
{
	if (iClient == 0 || iArgs <= 1)
		return Plugin_Handled;
	
	char sArg1[256], sArg2[256];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	
	g_iClientWeaponIndex[iClient][StringToInt(sArg1)] = StringToInt(sArg2);
	
	return Plugin_Handled;
}

public Action Command_Generate(int iClient, int iArgs)
{
	if (iClient == 0)
		return Plugin_Handled;
	
	GenerateRandonWeapon(iClient);
	TF2_RespawnPlayer(iClient);
	
	return Plugin_Handled;
}