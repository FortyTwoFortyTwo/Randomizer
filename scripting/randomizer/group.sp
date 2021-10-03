static RandomizedInfo g_eGroupInfo[MAX_GROUPS];	//List of groups on what to randomize

void Group_Init()
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
		g_eGroupInfo[i].Reset();
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
	const int iSize = view_as<int>(RandomizedType_MAX);	//SP compiler lmaooooo
	int bFound[iSize];
	
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
				Loadout_RandomizeClient(iClient, eInfo.nType);
				g_bClientRefresh[iClient] = true;
			}
			case RandomizedTarget_Global:
			{
				int[] iTargetList = new int[MaxClients];
				int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
				for (int j = 0; j < iTargetCount; j++)
				{
					Loadout_RandomizeClient(iTargetList[j], eInfo.nType);
					g_bClientRefresh[iTargetList[j]] = true;
				}
			}
			case RandomizedTarget_Same:
			{
				Loadout_RandomizeGroup(i, eInfo.nType);
				
				int[] iTargetList = new int[MaxClients];
				int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
				for (int j = 0; j < iTargetCount; j++)
					g_bClientRefresh[iTargetList[j]] = true;
			}
		}
	}
	
	for (int i = 0; i < sizeof(bFound); i++)
		if (!bFound[i])	//Client is not randomized, reset stuff
			Loadout_ResetClient(iClient, view_as<RandomizedType>(i));
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
				{
					Loadout_RandomizeClient(iTargetList[j], eInfo.nType);
					g_bClientRefresh[iTargetList[j]] = true;
				}
			}
			case RandomizedTarget_Same:
			{
				Loadout_RandomizeGroup(i, eInfo.nType);
				
				int[] iTargetList = new int[MaxClients];
				int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
				for (int j = 0; j < iTargetCount; j++)
					g_bClientRefresh[iTargetList[j]] = true;
			}
		}
	}
}

int Group_GetClientSameInfoPos(int iClient, RandomizedType nType)
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
		
		return i;
	}
	
	return -1;
}

bool Group_IsPosSameForClients(int[] iClients, int iCount, int iPos, RandomizedType nType)
{
	RandomizedInfo eInfo;
	eInfo = g_eGroupInfo[iPos];
	if (eInfo.nType != nType)
		return false;
	
	if (eInfo.nTarget != RandomizedTarget_Same)
		return false;
	
	int[] iTargetList = new int[MaxClients];
	int iTargetCount = Group_GetTargetList(eInfo.sTarget, iTargetList);
	for (int i = 0; i < iCount; i++)
		if (Group_IsInList(iClients[i], iTargetList, iTargetCount))
			return true;
	
	return false;
}

void Group_GetInfoFromPos(int iPos, RandomizedInfo eBuffer)
{
	eBuffer = g_eGroupInfo[iPos];
}

bool Group_GetInfoFromClient(int iClient, RandomizedType nType, RandomizedInfo eBuffer)
{
	for (int i = 0; i < sizeof(g_eGroupInfo); i++)
	{
		RandomizedInfo eInfo;
		eInfo = g_eGroupInfo[i];
		if (eInfo.nType != nType)
			continue;
		
		if (!Group_TargetsClient(eInfo.sTarget, iClient))
			continue;
		
		eBuffer = eInfo;
		return true;
	}
	
	return false;
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