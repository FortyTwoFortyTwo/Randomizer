char g_sViewModelClass[][] = {
	"",
	"models/weapons/c_models/c_scout_arms.mdl",
	"models/weapons/c_models/c_sniper_arms.mdl",
	"models/weapons/c_models/c_soldier_arms.mdl",
	"models/weapons/c_models/c_demo_arms.mdl",
	"models/weapons/c_models/c_medic_arms.mdl",
	"models/weapons/c_models/c_heavy_arms.mdl",
	"models/weapons/c_models/c_pyro_arms.mdl",
	"models/weapons/c_models/c_spy_arms.mdl",
	"models/weapons/c_models/c_engineer_arms.mdl",
};

void ViewModel_Precache()
{
	for (int i = 1; i < sizeof(g_sViewModelClass); i++)
		PrecacheModel(g_sViewModelClass[i]);
}

bool ViewModel_GetFromItem(int iWeapon, char[] sModel, int iLength)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	int iSlot = TF2_GetSlotFromItem(iClient, iWeapon);
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
		{
			Format(sModel, iLength, g_sViewModelClass[iClass]);
			return true;
		}
	}
	
	return false;
}