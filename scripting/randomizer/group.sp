static RandomizedInfo g_eGroupInfo[32];	//List of groups on what to randomize
static RandomizedWeapon g_eGroupWeapon[32][CLASS_MAX+1];	//List of weapons to randomize for group

void Group_Init()
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		g_eGroupInfo[i].Reset();
		ResetWeaponIndex(g_eGroupWeapon[i]);
	}
}

void Group_ClearType(RandomizedType nType)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		if (g_eGroupInfo[i].nType == nType)
		{
			int[] iTargetList = new int[MaxClients];
			int iTargetCount = Group_GetTargetList(g_eGroupInfo[i].sTarget, iTargetList);
			
			g_eGroupInfo[i].Reset();
			ResetWeaponIndex(g_eGroupWeapon[i]);
			
			//Randomize client after his group removed
			for (int j = 0; j < iTargetCount; j++)
				Group_RandomizeClient(iTargetList[j], RandomizedReroll_Force);
		}
	}
}

void Group_Add(RandomizedInfo eInfo)
{
	//Find empty space to insert it
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		if (g_eGroupInfo[i].nType == RandomizedType_None)
		{
			g_eGroupInfo[i] = eInfo;
			
			//Refresh any clients using this
			int[] iTargetList = new int[MaxClients];
			int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
			for (int j = 0; j < iTargetCount; j++)
				Group_RandomizeClient(iTargetList[j], RandomizedReroll_Force);
			
			return;
		}
	}
}

bool Group_IsClientRandomized(int iClient, RandomizedType nType)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		if (!Group_TargetsClient(eInfo.sTarget, iClient))
			continue;
		
		return true;
	}
	
	return false;
}

void Group_RandomizeClient(int iClient, RandomizedReroll nReroll)
{
	bool bFound[view_as<int>(RandomizedType_MAX)];
	
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType == RandomizedType_None)
			continue;
		
		if (!Group_TargetsClient(eInfo.sTarget, iClient))
			continue;
		
		bFound[eInfo.nType] = true;
		
		if (!(eInfo.nReroll & nReroll))
			continue;
		
		switch (eInfo.nTarget)
		{
			case RandomizedTarget_Self:
			{
				Group_Randomize(iClient, eInfo.nType, g_eClientInfo[iClient], g_eClientWeapon[iClient]);
			}
			case RandomizedTarget_Global:
			{
				int[] iTargetList = new int[MaxClients];
				int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
				for (int j = 0; j < iTargetCount; j++)
					Group_Randomize(iTargetList[j], eInfo.nType, g_eClientInfo[iTargetList[j]], g_eClientWeapon[iTargetList[j]]);
			}
			case RandomizedTarget_Same:
			{
				Group_Randomize(0, eInfo.nType, g_eGroupInfo[i], g_eGroupWeapon[i]);
				
				int[] iTargetList = new int[MaxClients];
				int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
				for (int j = 0; j < iTargetCount; j++)
					g_bClientRefresh[iTargetList[j]] = true;
			}
		}
	}
	
	for (int i = 0; i < sizeof(bFound); i++)
		if (!bFound[i])	//Client is not randomized, reset stuff
			Group_ResetClient(iClient, i);
}

void Group_RandomizeAll(RandomizedReroll nReroll)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType == RandomizedType_None)
			continue;
		
		if (!(eInfo.nReroll & nReroll))
			continue;
		
		switch (eInfo.nTarget)
		{
			case RandomizedTarget_Self, RandomizedTarget_Global:
			{
				int[] iTargetList = new int[MaxClients];
				int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
				for (int j = 0; j < iTargetCount; j++)
					Group_Randomize(iTargetList[j], eInfo.nType, g_eClientInfo[iTargetList[j]], g_eClientWeapon[iTargetList[j]]);
			}
			case RandomizedTarget_Same:
			{
				Group_Randomize(0, eInfo.nType, g_eGroupInfo[i], g_eGroupWeapon[i]);
				
				int[] iTargetList = new int[MaxClients];
				int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
				for (int j = 0; j < iTargetCount; j++)
					g_bClientRefresh[iTargetList[j]] = true;
			}
		}
	}
}

void Group_Randomize(int iClient, RandomizedType nType, RandomizedInfo eInfo, RandomizedWeapon eWeapons[CLASS_MAX+1])
{
	if (iClient != 0)
		g_bClientRefresh[iClient] = true;
	
	switch (nType)
	{
		case RandomizedType_Class: RandomizeClass(eInfo);
		case RandomizedType_Weapons: RandomizeWeapon(eWeapons);
		case RandomizedType_Cosmetics: RandomizeCosmetics();
		case RandomizedType_Mannpower: RandomizeMannpower(eInfo);
	}
}

void Group_ResetClient(int iClient, RandomizedType nType)
{
	g_bClientRefresh[iClient] = true;
	
	switch (nType)
	{
		case RandomizedType_Class: g_eClientInfo[iClient].nClass = TFClass_Unknown;
		case RandomizedType_Weapons: ResetWeaponIndex(g_eClientWeapon[iClient]);
		case RandomizedType_Cosmetics: RandomizeCosmetics();	//TODO
		case RandomizedType_Mannpower: g_eClientInfo[iClient].iRuneType = -1;
	}
}

bool Group_GetClientSameInfo(int iClient, RandomizedType nType, RandomizedInfo eBuffer)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		if (eInfo.nTarget != RandomizedTarget_Same)
			continue;
		
		if (!Group_TargetsClient(eInfo.sTarget, iClient))
			continue;
		
		eBuffer = eInfo;
		return true;
	}
	
	return false;
}

void Group_SetInfo(RandomizedInfo eBuffer)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != eBuffer.nType)
			continue;
		
		if (eInfo.nTarget != eBuffer.nTarget)
			continue;
		
		if (!StrEqual(eInfo.sTarget, eBuffer.sTarget))
			continue;
		
		g_eGroupInfo[i] = eBuffer;
		return;
	}
}

bool Group_GetClientSameWeapon(int iClient, RandomizedType nType, RandomizedWeapon eWeapon[CLASS_MAX+1])
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		if (eInfo.nTarget != RandomizedTarget_Same)
			continue;
		
		if (!Group_TargetsClient(eInfo.sTarget, iClient))
			continue;
		
		CopyRandomizedWeapon(g_eGroupWeapon[i], eWeapon);
		return true;
	}
	
	return false;
}

void Group_SetWeapon(RandomizedInfo eBuffer, RandomizedWeapon eWeapon[CLASS_MAX+1])
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != eBuffer.nType)
			continue;
		
		if (eInfo.nTarget != eBuffer.nTarget)
			continue;
		
		if (!StrEqual(eInfo.sTarget, eBuffer.sTarget))
			continue;
		
		CopyRandomizedWeapon(eWeapon, g_eGroupWeapon[i]);
		return;
	}
}

int Group_GetTargetList(const char[] sTarget, int[] iTargetList, char sTargetName[MAX_TARGET_LENGTH] = NULL_STRING)
{
	bool bIsML;
	return ProcessTargetString(sTarget, 0, iTargetList, MaxClients, COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), bIsML);
}

bool Group_TargetsClient(const char[] sTarget, int iClient)
{
	int[] iTargetList = new int[MaxClients];
	int iTargetCount = Group_GetTargetList(sTarget, iTargetList);
	for (int i = 0; i < iTargetCount; i++)
		if (iTargetList[i] == iClient)
			return true;
	
	return false;
}

bool Group_IsTargetListGood(RandomizedType nType, const int[] iTargetList, int iTargetCount, char sTargetName[MAX_TARGET_LENGTH])
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo; 
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType && nType != RandomizedType_None)
			continue;
		
		if (eInfo.nTarget != RandomizedTarget_Same)
			continue;
		
		int[] iBufferList = new int[MaxClients];
		int iBufferCount = Group_GetTargetList(eInfo.sTarget, iBufferList, sTargetName);
		
		int iFound = 0;	//-1 if found none, 1 if found so far
		
		for (int j = 0; j < iBufferCount; j++)
		{
			if (Group_IsInList(iBufferList[j], iTargetList, iTargetCount))
			{
				if (iFound != -1)
					iFound = 1;
				else
					return false;
			}
			else
			{
				if (iFound != 1)
					iFound = -1;
				else
					return false;
			}
		}
	}
	
	return true;
}

bool Group_IsInList(int iClient, const int[] iTargetList, int iTargetCount)
{
	for (int i = 0; i < iTargetCount; i++)
		if (iTargetList[i] == iClient)
			return true;
	
	return false;
}