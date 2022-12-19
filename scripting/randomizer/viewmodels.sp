char g_sViewModelsArms[][] = {
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

int ViewModels_GetFromClient(int iClient, bool bArms)
{
	int iWearable = INVALID_ENT_REFERENCE;
	while ((iWearable=FindEntityByClassname(iWearable, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
	{
		if (iClient != GetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity"))
			continue;
		
		int iParent = GetEntPropEnt(iWearable, Prop_Data, "m_pParent");
		if (bArms && IsClassname(iParent, "tf_viewmodel"))
			return iWearable;
		else if (!bArms && IsClassname(iParent, "tf_wearable_vm"))
			return iWearable;
	}
	
	return INVALID_ENT_REFERENCE;
}

void ViewModels_UpdateArms(int iClient)
{
	bool bSameClass;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
	if (iViewModel != INVALID_ENT_REFERENCE)
	{
		TFClassType nClass;
		
		if (iActiveWeapon != INVALID_ENT_REFERENCE)
			nClass = TF2_GetDefaultClassFromItem(iActiveWeapon);
		else
			nClass = TF2_GetPlayerClass(iClient);
		
		bSameClass = nClass == TF2_GetPlayerClass(iClient);
		if (bSameClass)
			RemoveEntityEffect(iViewModel, EF_NODRAW);
		else
			AddEntityEffect(iViewModel, EF_NODRAW);
		
		if (GetEntProp(iViewModel, Prop_Send, "m_nModelIndex") != GetModelIndex(g_sViewModelsArms[nClass]))
			SetEntityModel(iViewModel, g_sViewModelsArms[nClass]);
		
	}
	
	int iArms = ViewModels_GetFromClient(iClient, true);
	int iArmsModelIndex = GetModelIndex(g_sViewModelsArms[TF2_GetPlayerClass(iClient)]);
	if (iArms != INVALID_ENT_REFERENCE && GetEntProp(iArms, Prop_Send, "m_nModelIndex") != iArmsModelIndex)
	{
		RemoveEntity(iArms);
		iArms = INVALID_ENT_REFERENCE;
	}
	
	if (iArms == INVALID_ENT_REFERENCE)
		iArms = ViewModels_CreateWearable(iClient, iArmsModelIndex, iViewModel);
	
	if (bSameClass)
		AddEntityEffect(iArms, EF_NODRAW);
	else
		RemoveEntityEffect(iArms, EF_NODRAW);
	
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		int iWeaponModelIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iWorldModelIndex");
	
		int iWearable = ViewModels_GetFromClient(iClient, false);
		
		if (iWearable != INVALID_ENT_REFERENCE && (bSameClass || GetEntProp(iWearable, Prop_Send, "m_nModelIndex") != iWeaponModelIndex))
		{
			RemoveEntity(iWearable);
			iWearable = INVALID_ENT_REFERENCE;
		}
		
		if (!bSameClass && iWearable == INVALID_ENT_REFERENCE)
			iWearable = ViewModels_CreateWearable(iClient, iWeaponModelIndex, iArms);
		
		if (iWearable != INVALID_ENT_REFERENCE)
		{
			SetEntPropEnt(iArms, Prop_Send, "m_hWeaponAssociatedWith", iActiveWeapon);
			SetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith", iActiveWeapon);
		}
	}
	
	int iMaxWeapons = GetMaxWeapons();
	for (int i = 0; i < iMaxWeapons; i++)
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (iWeapon != INVALID_ENT_REFERENCE)
			SetEntProp(iWeapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(iWeapon, Prop_Send, "m_nModelIndex"));
	}
}

int ViewModels_CreateWearable(int iClient, int iModelIndex, int iParent)
{
	int iWearable = CreateEntityByName("tf_wearable_vm");
	
	float vecOrigin[3], vecAngles[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iClient, Prop_Send, "m_angRotation", vecAngles);
	TeleportEntity(iWearable, vecOrigin, vecAngles, NULL_VECTOR);
	
	SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iWearable, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntProp(iWearable, Prop_Send, "m_usSolidFlags", FSOLID_NOT_SOLID);
	SetEntProp(iWearable, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_WEAPON);
	SetEntProp(iWearable, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	
	SetEntProp(iWearable, Prop_Send, "m_nModelIndex", iModelIndex);
	
	DispatchSpawn(iWearable);
	
	SetVariantString("!activator");
	AcceptEntityInput(iWearable, "SetParent", iParent);
	
	return iWearable;
}

void ViewModels_RemoveAll()
{
	int iViewmodel = INVALID_ENT_REFERENCE;
	while ((iViewmodel=FindEntityByClassname(iViewmodel, "tf_wearable_vm")) != INVALID_ENT_REFERENCE)
		RemoveEntity(iViewmodel);
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;
		
		int iViewModel = GetEntPropEnt(iClient, Prop_Send, "m_hViewModel");
		if (iViewModel == INVALID_ENT_REFERENCE)
			continue;
		
		RemoveEntityEffect(iViewModel, EF_NODRAW);
		SetEntityModel(iViewModel, g_sViewModelsArms[TF2_GetPlayerClass(iClient)]);
	}
}
