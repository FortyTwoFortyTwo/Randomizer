static StringMap g_Patches;

static void ApplyPatches(GameData hGameData)
{
	StringMapSnapshot Snapshot = g_Patches.Snapshot();
	int iLen = Snapshot.Length;
	for (int i = 0; i < iLen; i++)
	{
		char sKey[256];
		Snapshot.GetKey(i, sKey, sizeof(sKey));
		
		any address = hGameData.GetAddress(sKey);
		if (address)
		{
			ArrayList Patch;
			if (g_Patches.GetValue(sKey, Patch))
			{
				int iPatchLen = Patch.Length;
				for (int j = 0; j < iPatchLen; j++)
				{
					int iArray[3];
					Patch.GetArray(j, iArray);
					
					int iVal = LoadFromAddress(address+iArray[0], NumberType_Int8);
					if (iVal == iArray[1])
					{
						StoreToAddress(address+iArray[0], iArray[2], NumberType_Int8);
					}
					else
					{
						// Don't continue if our initial value doesn't match up
						Patch_Reset(sKey, hGameData);
						LogError("Patch %s failed: %X (at %X) != %X", sKey, iVal, address, iArray[1]);
						break;
					}
				}
			}
		}
	}
	
	delete Snapshot;
}

void Patch_Init(GameData hGameData)
{
	bool bLinux = hGameData.GetOffset("DoWeHaveABetterWayOfGettingOS") != -1;
	
	g_Patches = new StringMap();
	ArrayList Patch = new ArrayList(3); // In array: 0 index is offset, 1 - inital value, 2 - replacement
	
	if (bLinux)
	{
		//Replace 'jz' (if '==' jump) to 'jmp' (always jump)
		Patch.PushArray({0, 0x0F, 0x90});
		Patch.PushArray({1, 0x84, 0xE9});
		
		g_Patches.SetValue("Patch_HeavyClassCheck", Patch.Clone());
		Patch.Clear();
		
		//Replace 'jmp' at steak cond failed to BFB weapon check
		Patch.PushArray({0, 0x0F, 0x0F});
		Patch.PushArray({1, 0x84, 0x84});
		Patch.PushArray({2, 0x25, 0xC2});
		Patch.PushArray({3, 0xFB, 0x00});
		Patch.PushArray({4, 0xFF, 0x00});
		Patch.PushArray({5, 0xFF, 0x00});
		
		g_Patches.SetValue("Patch_SteakCondFailed", Patch.Clone());
		Patch.Clear();
		
		//Replace 'jmp' at steak speed applied to BFB weapon check
		Patch.PushArray({0, 0xE9, 0xE9});
		Patch.PushArray({1, 0xFA, 0x97});
		Patch.PushArray({2, 0xFA, 0x00});
		Patch.PushArray({3, 0xFF, 0x00});
		Patch.PushArray({4, 0xFF, 0x00});
		
		g_Patches.SetValue("Patch_SteakCondPassed", Patch.Clone());
		Patch.Clear();
	}
	else
	{
		// Replace jnz short loc_104C0E8C with NOP because we don't need it if
		// we want to check for bfb speed bonus after the condition check
		Patch.PushArray({0, 0x75, 0x90});
		Patch.PushArray({1, 0x4E, 0x90});
		
		g_Patches.SetValue("Patch_HeavyClassCheck", Patch.Clone());
		Patch.Clear();
		
		// Replace jz loc_104C0EE2 to jz 0x2B so that we jump to the bfb
		// check if player has no steak/crit-a-cola condition
		Patch.PushArray({2, 0x81, 0x30}); // 0x104C0E5D
		
		g_Patches.SetValue("Patch_SteakCondFailed", Patch.Clone());
		Patch.Clear();
		
		// Replace 'jbe' to 'jmp short' and always go to BFB
		Patch.PushArray({0, 0x76, 0xEB}); // 0x104C0E81
		Patch.PushArray({1, 0x60, 0x0F}); // 0x104C0E81
		
		g_Patches.SetValue("Patch_SteakCondPassed", Patch.Clone());
		Patch.Clear();
	}
	
	delete Patch;
	
	ApplyPatches(hGameData);
}

void Patch_Reset(char[] sName, GameData hGameData = null)
{
	if (!hGameData)
	{
		hGameData = new GameData("randomizer");
		if (!hGameData)
			SetFailState("Could not find randomizer gamedata");
	}
	
	any address = hGameData.GetAddress(sName);
	if (address)
	{
		ArrayList Patch;
		if (g_Patches.GetValue(sName, Patch))
		{
			int iPatchLen = Patch.Length;
			for (int j = 0; j < iPatchLen; j++)
			{
				int iArray[3];
				Patch.GetArray(j, iArray);
				
				int iVal = LoadFromAddress(address+iArray[0], NumberType_Int8);
				if (iVal == iArray[1] || iVal == iArray[2])
					StoreToAddress(address+iArray[0], iArray[1], NumberType_Int8);
				else
					return;
			}
		}
	}
}

void Patch_ResetAll()
{
	StringMapSnapshot Snapshot = g_Patches.Snapshot();
	int iLen = Snapshot.Length;
	for (int i = 0; i < iLen; i++)
	{
		char sKey[256];
		Snapshot.GetKey(i, sKey, sizeof(sKey));
		
		Patch_Reset(sKey);
	}
	
	delete Snapshot;
}