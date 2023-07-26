char g_sViewModelsArms[][PLATFORM_MAX_PATH] = {
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

enum ViewModels
{
	ViewModels_Arm,
	ViewModels_Weapon,
	
	ViewModels_MAX,
}

static int g_iViewModels[MAXPLAYERS][ViewModels_MAX];

int ViewModels_GetFromClient(int iClient, ViewModels nViewModels, int iModelIndex, int iWeapon = INVALID_ENT_REFERENCE)
{
	if (!g_iViewModels[iClient][nViewModels] || !IsValidEntity(g_iViewModels[iClient][nViewModels]))
		g_iViewModels[iClient][nViewModels] = INVALID_ENT_REFERENCE;
	
	if (g_iViewModels[iClient][nViewModels] != INVALID_ENT_REFERENCE && GetEntProp(g_iViewModels[iClient][nViewModels], Prop_Send, "m_nModelIndex") != iModelIndex)
	{
		RemoveEntity(g_iViewModels[iClient][nViewModels]);
		g_iViewModels[iClient][nViewModels] = INVALID_ENT_REFERENCE;
	}
	
	if (g_iViewModels[iClient][nViewModels] == INVALID_ENT_REFERENCE)
		g_iViewModels[iClient][nViewModels] = ViewModels_CreateWearable(iClient, iModelIndex, iWeapon);
	
	return g_iViewModels[iClient][nViewModels];
}

void ViewModels_DeleteFromClient(int iClient, ViewModels nViewModels)
{
	if (g_iViewModels[iClient][nViewModels] && IsValidEntity(g_iViewModels[iClient][nViewModels]))
		RemoveEntity(g_iViewModels[iClient][nViewModels]);
	
	g_iViewModels[iClient][nViewModels] = INVALID_ENT_REFERENCE;
}

void ViewModels_UpdateArms(int iClient, int iForceWeapon = INVALID_ENT_REFERENCE)
{
	bool bSameClass;
	
	int iActiveWeapon = iForceWeapon == INVALID_ENT_REFERENCE ? GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") : iForceWeapon;
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
		
		char sModel[PLATFORM_MAX_PATH];
		int iTarget = iActiveWeapon == INVALID_ENT_REFERENCE ? iClient : iActiveWeapon;
		if (TF2Attrib_HookValueFloat(0.0, "wrench_builds_minisentry", iTarget))
			sModel = MODEL_ARMS_ROBOTARM;
		else if (IsClassname(iTarget, "tf_weapon_pda_spy"))	//Disguise kit have it's own viewmodel, ok valve?
			sModel = MODEL_ARMS_DISGUISE;
		else
			sModel = g_sViewModelsArms[nClass];
		
		int iModelIndex = GetModelIndex(sModel);
		if (GetEntProp(iViewModel, Prop_Send, "m_nModelIndex") != iModelIndex)
			SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", iModelIndex);
	}
	
	int iArmsModelIndex = GetModelIndex(g_sViewModelsArms[TF2_GetPlayerClass(iClient)]);
	int iArms = ViewModels_GetFromClient(iClient, ViewModels_Arm, iArmsModelIndex);
	
	if (bSameClass)
		AddEntityEffect(iArms, EF_NODRAW);
	else
		RemoveEntityEffect(iArms, EF_NODRAW);
	
	if (bSameClass)
	{
		ViewModels_DeleteFromClient(iClient, ViewModels_Weapon);
	}
	else if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		int iWeaponModelIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iWorldModelIndex");
		int iWearable = ViewModels_GetFromClient(iClient, ViewModels_Weapon, iWeaponModelIndex, iActiveWeapon);
		
		SetEntPropEnt(iArms, Prop_Send, "m_hWeaponAssociatedWith", iActiveWeapon);
		SetEntPropEnt(iWearable, Prop_Send, "m_hWeaponAssociatedWith", iActiveWeapon);
	}
	
	int iMaxWeapons = GetMaxWeapons();
	for (int i = 0; i < iMaxWeapons; i++)
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (iWeapon != INVALID_ENT_REFERENCE)
			SetEntProp(iWeapon, Prop_Send, "m_nCustomViewmodelModelIndex", GetEntProp(iWeapon, Prop_Send, "m_nModelIndex"));
	}
}

int ViewModels_CreateWearable(int iClient, int iModelIndex, int iWeapon = INVALID_ENT_REFERENCE)
{
	int iWearable = CreateEntityByName("tf_wearable_vm");
	
	if (iWeapon != INVALID_ENT_REFERENCE)	//Copy m_Item from weapon, so reskin stuffs can show
		SDKCall_SetItem(GetEntityAddress(iWearable) + view_as<Address>(g_iOffsetItem), GetEntityAddress(iWeapon) + view_as<Address>(g_iOffsetItem));
	
	float vecOrigin[3], vecAngles[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(iClient, Prop_Send, "m_angRotation", vecAngles);
	TeleportEntity(iWearable, vecOrigin, vecAngles, NULL_VECTOR);
	
	SetEntProp(iWearable, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntPropEnt(iWearable, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iWearable, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntProp(iWearable, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	
	DispatchSpawn(iWearable);
	
	SetEntProp(iWearable, Prop_Send, "m_nModelIndex", iModelIndex);	// After DispatchSpawn, otherwise CEconItemView overrides it
	
	SetVariantString("!activator");
	AcceptEntityInput(iWearable, "SetParent", GetEntPropEnt(iClient, Prop_Send, "m_hViewModel"));
	
	return EntIndexToEntRef(iWearable);
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