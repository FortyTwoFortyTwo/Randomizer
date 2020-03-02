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
		// Nothing here
	}
	else
	{
		// Replace jnz short loc_104C0E8C with NOP because we don't need it if
		// we want to check for bfb speed bonus after the condition check
		Patch.PushArray({-83, 0x75, 0x90}); // 0x104C0E3C
		Patch.PushArray({-82, 0x4E, 0x90}); // 0x104C0E3D
		
		// Replace jz loc_104C0EE2 to jz 0x2B so that we jump to the bfb
		// check if player has no steak/crit-a-cola condition
		Patch.PushArray({-50, 0x81, 0x2B}); // 0x104C0E5D
		
		// Same as above
		Patch.PushArray({-14, 0x60, 0xA}); // 0x104C0E81
		
		// Replace a jump with NOP for a bfb check
		Patch.PushArray({-5, 0xEB, 0x90}); // 0x104C0E8A
		Patch.PushArray({-4, 0x51, 0x90}); // 0x104C0E8B
		
		// Basically replace bunch of jumps that are related
		// to the scout class check with NOP
		Patch.PushArray({0,  0x75, 0x90}); // 0x104C0E8F
		Patch.PushArray({1,  0x51, 0x90}); // 0x104C0E90
		Patch.PushArray({13, 0x74, 0x90}); // 0x104C0E9C
		Patch.PushArray({14, 0x44, 0x90}); // 0x104C0E9D
		
		g_Patches.SetValue("CTFPlayer::TeamFortress_CalculateMaxSpeed::BFBCheck", Patch.Clone());
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