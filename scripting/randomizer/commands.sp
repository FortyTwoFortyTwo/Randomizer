void Commands_Init()
{
	RegConsoleCmd("sm_cantsee", Command_CantSee);
	
	RegAdminCmd("sm_rndclass", Command_Class, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndweapon", Command_Weapon, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndgenerate", Command_Generate, ADMFLAG_CHANGEMAP);
	RegAdminCmd("sm_rndgiveweapon", Command_GiveWeapon, ADMFLAG_CHANGEMAP);
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
				g_iClientClass[iTargetList[i]] = nClass;
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
					g_iTeamClass[iTeam] = nClass;
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
				g_iTeamClass[iTeam] = nClass;	 
		}
	}
	
	for (int i = 0; i < iTargetCount; i++)
		if (IsPlayerAlive(iTargetList[i]) && IsClassRandomized(iTargetList[i]))
			TF2_RespawnPlayer(iTargetList[i]);
			
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
	
	if (!StringToIntEx(sSlot, iSlot) || iSlot < 0 || iSlot > WeaponSlot_Building)
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
	
	switch (g_cvRandomWeapons.IntValue)
	{
		case Mode_None:
		{
			ReplyToCommand(iClient, "randomizer_randomweapons convar must be not at 0");
			return Plugin_Handled;
		}
		case Mode_Normal, Mode_NormalRound:
		{
			for (int i = 0; i < iTargetCount; i++)
				SetRandomizedWeaponBySlot(g_eClientWeapon[iTargetList[i]], iIndex, iSlot);
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
						ReplyToCommand(iClient, "Can only target teams with randomizer_randomweapons set to 3");
						return Plugin_Handled;
					}
				}
			}
			
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				if (bTargetTeam[iTeam])
					SetRandomizedWeaponBySlot(g_eTeamWeapon[iTeam], iIndex, iSlot);
		}
		case Mode_All:
		{
			for (int iTarget = 1; iTarget <= MaxClients; iTarget++)
			{
				if (IsClientInGame(iTarget) && !IsClientInTargetList(iTarget, iTargetList, iTargetCount))
				{
					ReplyToCommand(iClient, "Can only target everyone with randomizer_randomweapons set to 4");
					return Plugin_Handled;
				}
			}
			
			for (int iTeam = TEAM_MIN; iTeam <= TEAM_MAX; iTeam++)
				SetRandomizedWeaponBySlot(g_eTeamWeapon[iTeam], iIndex, iSlot);
		}
	}
	
	for (int i = 0; i < iTargetCount; i++)
		if (IsPlayerAlive(iTargetList[i]) && IsWeaponRandomized(iTargetList[i]))
			TF2_RespawnPlayer(iTargetList[i]);
	
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
	
	int iModeClass = g_cvRandomClass.IntValue;
	int iModeWeapons = g_cvRandomWeapons.IntValue;
	
	if (iModeClass == Mode_None && iModeWeapons == Mode_None)
	{
		ReplyToCommand(iClient, "randomizer_randomclass and randomizer_randomweapons convar must be not at 0");
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
		
		RandomizeTeamWeapon();
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
				RandomizeTeamWeapon(view_as<TFTeam>(iTeam));
	}
	
	if (iModeClass == Mode_Normal || iModeClass == Mode_NormalRound || iModeWeapons == Mode_Normal || iModeWeapons == Mode_NormalRound)
	{
		for (int i = 0; i < iTargetCount; i++)
			RandomizeClientWeapon(iTargetList[i]);
	}
	
	for (int i = 0; i < iTargetCount; i++)
		if (IsPlayerAlive(iTargetList[i]) && (IsClassRandomized(iTargetList[i]) || IsWeaponRandomized(iTargetList[i])))
			TF2_RespawnPlayer(iTargetList[i]);
	
	ReplyToCommand(iClient, "Regenerated %s class and weapons", sTargetName);
	return Plugin_Handled;
}

public Action Command_GiveWeapon(int iClient, int iArgs)
{
	if (!g_bEnabled)
		return Plugin_Continue;
	
	if (iArgs < 3)
	{
		ReplyToCommand(iClient, "Format: sm_rndgiveweapon <@target> <slot> <weapon def index>");
		return Plugin_Handled;
	}
	
	int iSlot, iIndex;
	char sTarget[32], sSlot[12], sIndex[12];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sSlot, sizeof(sSlot));
	GetCmdArg(3, sIndex, sizeof(sIndex));
	
	if (!StringToIntEx(sSlot, iSlot) || iSlot < 0 || iSlot > WeaponSlot_Building)
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
	{
		int iWeapon;
		
		Address pItem = TF2_FindReskinItem(iTargetList[i], iIndex);
		if (pItem)
			iWeapon = TF2_GiveNamedItem(iTargetList[i], pItem, iSlot);
		else
			iWeapon = TF2_CreateWeapon(iTargetList[i], iIndex, iSlot);
		
		if (iWeapon == INVALID_ENT_REFERENCE)
		{
			PrintToChat(iTargetList[i], "Unable to create weapon! index (%d)", iIndex);
			LogError("Unable to create weapon! index (%d)", iIndex);
		}
		
		//CTFPlayer::ItemsMatch doesnt like normal item quality, so lets use unique instead
		if (view_as<TFQuality>(GetEntProp(iWeapon, Prop_Send, "m_iEntityQuality")) == TFQual_Normal)
			SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		
		TF2_EquipWeapon(iTargetList[i], iWeapon);
		
		if (ViewModels_ShouldBeInvisible(iWeapon, TF2_GetPlayerClass(iTargetList[i])))
			ViewModels_EnableInvisible(iWeapon);
		
		g_eClientWeapon[iTargetList[i]][TF2_GetPlayerClass(iTargetList[i])].Add(iIndex, iSlot, iWeapon);
		
		//TODO remove this, gas passer...
		if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") && GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType") != -1)
		{
			Ammo_SetForceWeapon(iWeapon);
			GivePlayerAmmo(iTargetList[i], 1000, GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"));
		}
	}
	
	ReplyToCommand(iClient, "Gave %s weapon def index at slot '%d' to '%d'", sTargetName, iSlot, iIndex);
	return Plugin_Handled;
}

bool IsClientInTargetList(int iClient, const int[] iTargetList, int iTargetCount)
{
	for (int i = 0; i < iTargetCount; i++)
		if (iClient == iTargetList[i])
			return true;
	
	return false;
}