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
		ReplyToCommand(iClient, "Your active weapon is now transparent.");
	else
		ReplyToCommand(iClient, "Your active weapon is now fully visible.");
	
	return Plugin_Handled;
}

public Action Command_Class(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Format: sm_rndclass <@target> <class>");
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
	
	switch (g_cvRandomClass.IntValue)
	{
		case Mode_None:
		{
			ReplyToCommand(iClient, "randomizer_randomclass convar must be not at 0");
			return Plugin_Handled;
		}
		case Mode_Normal, Mode_NormalRound:
		{
			for (int i = 0; i < iTargetCount; i++) 
			{
				g_iClientClass[iTargetList[i]] = nClass;
				//Regenerate each slot beyond 2, as we generally don't want other classes to have watches/PDAs
				for (int iSlot = 3; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
					Weapons_GetRandomInfo(g_ClientWeaponInfo[iTargetList[i]][iSlot], iSlot, g_iClientClass[iTargetList[i]]);
			}
		}
		case Mode_Team:
		{
			bool bTargetTeam[TEAM_MAX+1];
			for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
			{
				if (IsClientInGame(iTarget))
				{
					if (IsClientInTargetList(iTarget, iTargetList, iTargetCount))
					{
						bTargetTeam[TF2_GetClientTeam(iTarget)] = true;
					}
					else if (bTargetTeam[TF2_GetClientTeam(iTarget)] == true)
					{
						ReplyToCommand(iClient, "Can only target teams with randomizer_randomclass set to 3");
						return Plugin_Handled;
					}
				}
			}
			
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
			{
				if (bTargetTeam[iTeam])
				{
					g_iTeamClass[iTeam] = nClass;
					//If doing normal random weapons, we need to regenerate pda slots for each player on the team
					if (g_cvRandomWeapons.IntValue == Mode_Normal || g_cvRandomWeapons.IntValue == Mode_NormalRound)
					{
						for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
							if (IsClientInGame(iTarget) && bTargetTeam[TF2_GetClientTeam(iTarget)])
								for (int iSlot = 3; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
									Weapons_GetRandomInfo(g_ClientWeaponInfo[iTarget][iSlot], iSlot, g_iTeamClass[iTeam]);
					}
					else if (g_cvRandomWeapons.IntValue == Mode_Team || g_cvRandomWeapons.IntValue == Mode_All)
					{
						for (int iSlot = WeaponSlot_PDABuild; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
							Weapons_GetRandomInfo(g_TeamWeaponInfo[iTeam][iSlot], iSlot, g_iTeamClass[iTeam]);
					}
				}
			}
		}
		case Mode_All:
		{
			for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
			{
				if (IsClientInGame(iTarget) && !IsClientInTargetList(iTarget, iTargetList, iTargetCount))
				{
					ReplyToCommand(iClient, "Can only target everyone with randomizer_randomclass set to 4");
					return Plugin_Handled;
				}
			}
			
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
			{
				g_iTeamClass[iTeam] = nClass;
				if (g_cvRandomWeapons.IntValue == Mode_Normal || g_cvRandomWeapons.IntValue == Mode_NormalRound)
				{
					for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
						if (IsClientInGame(iTarget))
							for (int iSlot = WeaponSlot_PDABuild; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
								Weapons_GetRandomInfo(g_ClientWeaponInfo[iTarget][iSlot], iSlot, g_iTeamClass[iTeam]);
				}
				else if (g_cvRandomWeapons.IntValue == Mode_Team || g_cvRandomWeapons.IntValue == Mode_All)
				{
					for (int iSlot = 3; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
						Weapons_GetRandomInfo(g_TeamWeaponInfo[iTeam][iSlot], iSlot, g_iTeamClass[iTeam]);
				}
			}
		}
	}
	
	for (int i = 0; i < iTargetCount; i++)
		UpdateClientWeapon(iTargetList[i], ClientUpdate_Spawn);
			
	ReplyToCommand(iClient, "Set %s class to %s", sTargetName, sClass);
	return Plugin_Handled;
}

public Action Command_Weapon(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 3)
	{
		ReplyToCommand(iClient, "Format: sm_rndweapon <@target> <slot> <weapon def index/name>");
		return Plugin_Handled;
	}
	
	WeaponInfo info;
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
	
	if (StringToIntEx(sIndex, iIndex))
	{
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			Weapons_GetInfoFromIndex(iIndex, info, iSlot, view_as<TFClassType>(iClass));
			if (info.iId)	//Found em
				break;
		}
		
		if (!info.iId)
		{
			ReplyToCommand(iClient, "Unable to find non-custom weapon def index '%d' at slot '%d'", iIndex, iSlot);
			return Plugin_Handled;
		}
	}
	else
	{
		//Grab whole args, skip first 2 args
		char sName[256];
		GetCmdArgString(sName, sizeof(sName));
		int iArg = 1, iLen = strlen(sName);
		for (int i = 1; i < iLen; i++)
		{
			if (sName[i] == ' ' && sName[i-1] != ' ')
				iArg++;
			
			if (iArg == 3)
			{
				Format(sName, sizeof(sName), sName[i+1]);
				break;
			}
		}
		
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			Weapons_GetInfoFromName(iClass, sName, info, iSlot, view_as<TFClassType>(iClass));
			if (info.iId)	//Found em
				break;
		}
		
		if (!info.iId)
		{
			ReplyToCommand(iClient, "Unable to find weapon by name '%s' at slot '%d'", sName, iSlot);
			return Plugin_Handled;
		}
	}
	
	int[] iTargetList = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool bIsML;
	
	int iTargetCount = ProcessTargetString(sTarget, iClient, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
	if (iTargetCount <= 0)
	{
		ReplyToCommand(iClient, "Could not find anyone to give weapon");
		return Plugin_Handled;
	}
	
	switch (g_cvRandomWeapons.IntValue)
	{
		case Mode_None:
		{
			ReplyToCommand(iClient, "randomizer_randomweapons convar must not be 0");
			return Plugin_Handled;
		}
		case Mode_Normal, Mode_NormalRound:
		{
			for (int i = 0; i < iTargetCount; i++)
				g_ClientWeaponInfo[iTargetList[i]][iSlot] = info;
		}
		case Mode_Team:
		{
			bool bTargetTeam[TEAM_MAX+1];
			for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
			{
				if (IsClientInGame(iTarget))
				{
					if (IsClientInTargetList(iTarget, iTargetList, iTargetCount))
					{
						bTargetTeam[TF2_GetClientTeam(iTarget)] = true;
					}
					else if (bTargetTeam[TF2_GetClientTeam(iTarget)] == true)
					{
						ReplyToCommand(iClient, "Can only target teams with randomizer_randomclass set to 3");
						return Plugin_Handled;
					}
				}
			}
			
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				if (bTargetTeam[iTeam])
					g_TeamWeaponInfo[iTeam][iSlot] = info;
		}
		case Mode_All:
		{
			for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
			{
				if (IsClientInGame(iTarget) && !IsClientInTargetList(iTarget, iTargetList, iTargetCount))
				{
					ReplyToCommand(iClient, "Can only target everyone with randomizer_randomclass set to 4");
					return Plugin_Handled;
				}
			}
			
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				g_TeamWeaponInfo[iTeam][iSlot] = info;
		}
	}
	
	for (int i = 0; i < iTargetCount; i++)
		UpdateClientWeapon(iTargetList[i], ClientUpdate_Spawn);
	
	ReplyToCommand(iClient, "Gave %s weapon '%t' at slot '%d'", sTargetName, info.sName, iSlot);
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
	
	int iModeClass = g_cvRandomClass.IntValue;
	int iModeWeapons = g_cvRandomWeapons.IntValue;
	
	if (iModeClass == Mode_None && iModeWeapons == Mode_None)
	{
		ReplyToCommand(iClient, "randomizer_randomclass and randomizer_randomweapons convar must not be 0");
		return Plugin_Handled;
	}
	else if (iModeClass == Mode_All || iModeWeapons == Mode_All)	//Should always be true if reached here
	{
		for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
		{
			if (IsClientInGame(iTarget) && !IsClientInTargetList(iTarget, iTargetList, iTargetCount))
			{
				ReplyToCommand(iClient, "Can only target everyone with randomizer_randomclass or randomizer_randomweapons set to 4");
				return Plugin_Handled;
			}
		}
		
		UpdateTeamWeapon();
	}
	else if (iModeClass == Mode_Team || iModeWeapons == Mode_Team)
	{
		bool bTargetTeam[TEAM_MAX+1];
		for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
		{
			if (IsClientInGame(iTarget))
			{
				if (IsClientInTargetList(iTarget, iTargetList, iTargetCount))
				{
					bTargetTeam[TF2_GetClientTeam(iTarget)] = true;
				}
				else if (bTargetTeam[TF2_GetClientTeam(iTarget)] == true)
				{
					ReplyToCommand(iClient, "Can only target teams with randomizer_randomclass or randomizer_randomweapons set to 3");
					return Plugin_Handled;
				}
			}
		}
		
		for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
			if (bTargetTeam[iTeam])
				UpdateTeamWeapon(view_as<TFTeam>(iTeam));
	}
	
	for (int i = 0; i < iTargetCount; i++)
		UpdateClientWeapon(iTargetList[i], ClientUpdate_Round);
	
	ReplyToCommand(iClient, "Regenerated %s class and weapons", sTargetName);
	return Plugin_Handled;
}

bool IsClientInTargetList(int iClient, const int[] iTargetList, int iTargetCount)
{
	for (int i = 0; i < iTargetCount; i++)
		if (iClient == iTargetList[i])
			return true;
	
	return false;
}