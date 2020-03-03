#define PATCH_MAX	16

enum struct Patch
{
	Address pAddress;
	int iPatchCount;
	int iValueOriginal[PATCH_MAX];
	int iValueReplacement[PATCH_MAX];
	bool bEnable;
	
	void Load(GameData hGameData, const char[] sPatchName)
	{
		this.pAddress = hGameData.GetAddress(sPatchName);
		if (!this.pAddress)
		{
			LogError("Failed to find address for key %s", sPatchName);
			return;
		}
		
		char sKeyValue[PATCH_MAX * 4];
		if (!hGameData.GetKeyValue(sPatchName, sKeyValue, sizeof(sKeyValue)))
		{
			LogError("Failed to find key value for %s", sPatchName);
			return;
		}
		
		char sBytes[PATCH_MAX][4];
		this.iPatchCount = ExplodeString(sKeyValue, "\\x", sBytes, sizeof(sBytes), sizeof(sBytes[])) - 1;
		for (int i = 0; i < this.iPatchCount; i++)
		{
			this.iValueOriginal[i] = LoadFromAddress(this.pAddress + view_as<Address>(i), NumberType_Int8);
			this.iValueReplacement[i] = StringToInt(sBytes[i+1], 16);
		}
	}
	
	void Enable()
	{
		if (this.bEnable)
			return;
		
		for (int i = 0; i < this.iPatchCount; i++)
		{
			PrintToServer("%X: %02X -> %02X", this.pAddress + view_as<Address>(i), this.iValueOriginal[i], this.iValueReplacement[i]);
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueReplacement[i], NumberType_Int8);
		}
		
		this.bEnable = true;
	}
	
	void Disable()
	{
		if (!this.bEnable)
			return;
		
		for (int i = 0; i < this.iPatchCount; i++)
		{
			PrintToServer("%X: %02X -> %02X", this.pAddress + view_as<Address>(i), this.iValueReplacement[i], this.iValueOriginal[i]);
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueOriginal[i], NumberType_Int8);
		}
		
		this.bEnable = false;
	}
}

Patch g_patchHeavyClassCheck;
Patch g_patchSteakCondFailed;
Patch g_patchSteakCondPassed;

void Patch_Init(GameData hGameData)
{
	g_patchHeavyClassCheck.Load(hGameData, "Patch_HeavyClassCheck");
	g_patchSteakCondFailed.Load(hGameData, "Patch_SteakCondFailed");
	g_patchSteakCondPassed.Load(hGameData, "Patch_SteakCondPassed");
	
	g_patchHeavyClassCheck.Enable();
	g_patchSteakCondFailed.Enable();
	g_patchSteakCondPassed.Enable();
}

void Patch_ResetAll()
{
	g_patchHeavyClassCheck.Disable();
	g_patchSteakCondFailed.Disable();
	g_patchSteakCondPassed.Disable();
}