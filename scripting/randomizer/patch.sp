#define PATCH_MAX	16

enum struct Patch
{
	Address pAddress;
	int iPatchCount;
	int iValueOriginal[PATCH_MAX];
	int iValueReplacement[PATCH_MAX];
	bool bEnable;
	
	bool Load(GameData hGameData, const char[] sPatchName)
	{
		this.pAddress = hGameData.GetAddress(sPatchName);
		if (!this.pAddress)
			return false;
		
		char sKeyValue[PATCH_MAX * 4];
		if (!hGameData.GetKeyValue(sPatchName, sKeyValue, sizeof(sKeyValue)))
		{
			LogError("Failed to find key value for %s", sPatchName);
			return true;
		}
		
		char sBytes[PATCH_MAX][4];
		this.iPatchCount = ExplodeString(sKeyValue, "\\x", sBytes, sizeof(sBytes), sizeof(sBytes[])) - 1;
		for (int i = 0; i < this.iPatchCount; i++)
		{
			this.iValueOriginal[i] = LoadFromAddress(this.pAddress + view_as<Address>(i), NumberType_Int8);
			this.iValueReplacement[i] = StringToInt(sBytes[i+1], 16);
		}
		
		return true;
	}
	
	void Enable()
	{
		if (this.bEnable)
			return;
		
		for (int i = 0; i < this.iPatchCount; i++)
		{
			//PrintToServer("%X: %02X -> %02X", this.pAddress + view_as<Address>(i), this.iValueOriginal[i], this.iValueReplacement[i]);
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
			//PrintToServer("%X: %02X -> %02X", this.pAddress + view_as<Address>(i), this.iValueReplacement[i], this.iValueOriginal[i]);
			StoreToAddress(this.pAddress + view_as<Address>(i), this.iValueOriginal[i], NumberType_Int8);
		}
		
		this.bEnable = false;
	}
}

static ArrayList g_aPatches;	//Arrays of Patch

void Patch_Init(GameData hGameData)
{
	g_aPatches = new ArrayList(sizeof(Patch));
	int iCount = 0;
	
	do
	{
		iCount++;
		char sName[16];
		Format(sName, sizeof(sName), "Patch_%d", iCount);
		
		Patch patch;
		if (!patch.Load(hGameData, sName))
			break;
		
		g_aPatches.PushArray(patch);
	}
	while (iCount);	//Infinite loop until break
}

void Patch_Enable()
{
	int iLength = g_aPatches.Length;
	for (int i = 0; i < iLength; i++)
	{
		Patch patch;
		g_aPatches.GetArray(i, patch);
		patch.Enable();
	}
}

void Patch_Disable()
{
	int iLength = g_aPatches.Length;
	for (int i = 0; i < iLength; i++)
	{
		Patch patch;
		g_aPatches.GetArray(i, patch);
		patch.Disable();
	}
}