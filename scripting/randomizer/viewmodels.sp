#define FILEPATH_CONFIG_VIEWMODELS "configs/randomizer/viewmodels.cfg"

methodmap WeaponClassList < StringMap
{
	public WeaponClassList()
	{
		return view_as<WeaponClassList>(new StringMap());
	}
	
	public void Load(KeyValues kv, const char[] sKey)
	{
		this.Clear();
		
		if (kv.JumpToKey(sKey))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sClassname[CONFIG_MAXCHAR], sTF2Class[CONFIG_MAXCHAR];
					kv.GetSectionName(sClassname, sizeof(sClassname));
					kv.GetString(NULL_STRING, sTF2Class, sizeof(sTF2Class));
					TFClassType nClass = TF2_GetClass(sTF2Class);
					
					bool bInvisible[10];
					this.GetArray(sClassname, bInvisible, sizeof(bInvisible));
					bInvisible[nClass] = true;
					this.SetArray(sClassname, bInvisible, sizeof(bInvisible));
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			
			kv.GoBack();
		}
	}
	
	public bool Exists(int iWeapon, TFClassType nClass)
	{
		char sClassname[CONFIG_MAXCHAR];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		
		bool bInvisible[10];
		this.GetArray(sClassname, bInvisible, sizeof(bInvisible));
		return bInvisible[nClass];
	}
}

static WeaponClassList g_mViewModelsInvisible;
static WeaponClassList g_mViewModelsRobotArm;

void ViewModels_Init()
{
	g_mViewModelsInvisible = new WeaponClassList();
	g_mViewModelsRobotArm = new WeaponClassList();
}

void ViewModels_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_VIEWMODELS, "ViewModels");
	if (!kv)
		return;
	
	g_mViewModelsInvisible.Load(kv, "Invisible");
	g_mViewModelsRobotArm.Load(kv, "RobotArm");
	
	delete kv;
}

bool ViewModels_ShouldBeInvisible(int iWeapon, TFClassType nClass)
{
	return g_mViewModelsInvisible.Exists(iWeapon, nClass);
}

bool ViewModels_ToggleInvisible(int iWeapon)
{
	if (GetEntityRenderMode(iWeapon) == RENDER_NORMAL)
	{
		ViewModels_EnableInvisible(iWeapon);
		return true;
	}
	else
	{
		ViewModels_DisableInvisible(iWeapon);
		return false;
	}
}

void ViewModels_EnableInvisible(int iWeapon)
{
	SetEntityRenderMode(iWeapon, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iWeapon, 255, 255, 255, 75);
}

void ViewModels_DisableInvisible(int iWeapon)
{
	SetEntityRenderMode(iWeapon, RENDER_NORMAL); 
	SetEntityRenderColor(iWeapon, 255, 255, 255, 255);
}

bool ViewModels_ShouldUseRobotArm(int iClient, int iWeapon)
{
	return g_mViewModelsRobotArm.Exists(iWeapon, TF2_GetPlayerClass(iClient));
}