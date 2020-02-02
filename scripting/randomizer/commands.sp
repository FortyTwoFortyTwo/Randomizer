void Commands_Init()
{
	RegAdminCmd("class", Command_Class, ADMFLAG_CHANGEMAP);
	RegAdminCmd("weapon", Command_Weapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("generate", Command_Generate, ADMFLAG_CHANGEMAP);
}

public Action Command_Class(int iClient, int iArgs)
{
	if (iArgs <= 0)
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
	if (iArgs <= 1)
		return Plugin_Handled;
	
	char sArg1[256], sArg2[256];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	
	g_iClientWeaponIndex[iClient][StringToInt(sArg1)] = StringToInt(sArg2);
	
	return Plugin_Handled;
}

public Action Command_Generate(int iClient, int iArgs)
{
	GenerateRandonWeapon(iClient);
	TF2_RespawnPlayer(iClient);
}