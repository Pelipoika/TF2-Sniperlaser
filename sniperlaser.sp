#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required

ConVar g_cvarLaserEnabled;
ConVar g_cvarLaserRandom;
ConVar g_cvarLaserRED;
ConVar g_cvarLaserBLU;

int g_iEyeProp[MAXPLAYERS + 1];
int g_iSniperDot[MAXPLAYERS + 1];
int g_iDotController[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "[TF2] Sniperlaser",
	author = "Pelipoika",
	description = "Sniper rifles emit lasers",
	version = "2.0",
	url = ""
};

public void OnPluginStart()
{
	g_cvarLaserEnabled = CreateConVar("sniperlaser_enabled", "1", "Sniper rifles emit lasers", _, true, 0.0, true, 1.0);
	g_cvarLaserRandom = CreateConVar("sniperlaser_random_color", "0", "Sniper laser use random color?", _, true, 0.0, true, 1.0);
	g_cvarLaserRED = CreateConVar("sniperlaser_color_red", "255 0 0", "Sniper laser color RED");
	g_cvarLaserBLU = CreateConVar("sniperlaser_color_blu", "0 0 255", "Sniper laser color BLUE");
	
	for (int i = 1; i <= MaxClients; i++){
		OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
	g_iEyeProp[client] = INVALID_ENT_REFERENCE;
	g_iSniperDot[client] = INVALID_ENT_REFERENCE;
	g_iDotController[client] = INVALID_ENT_REFERENCE;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "env_sniperdot") && g_cvarLaserEnabled.BoolValue)
	{
		SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
	}
}

public Action SpawnPost(int entity)
{
	RequestFrame(SpawnPostPost, entity);	
}

public void SpawnPostPost(int ent)
{
	if (IsValidEntity(ent))
	{
		int client = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		if(client > 0 && client <= MaxClients && IsClientInGame(client))
		{
			if(GameRules_GetProp("m_bPlayingMannVsMachine") && TF2_GetClientTeam(client) != TFTeam_Red)
				return;
			
			///////////////////////////////////////////////
			float rgb[3]; 
			if(g_cvarLaserRandom.BoolValue)
			{
				rgb[0] = GetRandomFloat(0.0, 255.0);
				rgb[1] = GetRandomFloat(0.0, 255.0);
				rgb[2] = GetRandomFloat(0.0, 255.0);
			}
			else
			{
				char strrgb[PLATFORM_MAX_PATH];
			
				switch(TF2_GetClientTeam(client))
				{
					case TFTeam_Red:  g_cvarLaserRED.GetString(strrgb, PLATFORM_MAX_PATH);
					case TFTeam_Blue: g_cvarLaserBLU.GetString(strrgb, PLATFORM_MAX_PATH);
				}
				
				char rgbExploded[3][16];
				ExplodeString(strrgb, " ", rgbExploded, sizeof(rgbExploded), sizeof(rgbExploded[]));
				
				rgb[0] = StringToFloat(rgbExploded[0]);
				rgb[1] = StringToFloat(rgbExploded[1]);
				rgb[2] = StringToFloat(rgbExploded[2]);
			}
			
			char name[PLATFORM_MAX_PATH];
			Format(name, PLATFORM_MAX_PATH, "laser_%i", ent);
		
			//color controls the color and is for color only.//
			int color = CreateEntityByName("info_particle_system");
			DispatchKeyValue(color, "targetname", name);
			DispatchKeyValueVector(color, "origin", rgb);
			DispatchSpawn(color);
			
			//Start of beam -> parented to client.
			int a = CreateEntityByName("info_particle_system");
			DispatchKeyValue(a, "effect_name", "laser_sight_beam");
			DispatchKeyValue(a, "cpoint2", name);
			DispatchSpawn(a);
			
			SetVariantString("!activator");
			AcceptEntityInput(a, "SetParent", client);
			
			SetVariantString("eyeglow_R");
			AcceptEntityInput(a, "SetParentAttachment", client);
			
			//Dot controller, set as controlpointent on beam
			int dotController = CreateEntityByName("info_particle_system");
			float dotPos[3]; GetEntPropVector(ent, Prop_Send, "m_vecOrigin", dotPos);
			DispatchKeyValueVector(dotController, "origin", dotPos);
			DispatchSpawn(dotController);
			
			//Start of beam -> control point ent set to env_sniperdot
			SetEntPropEnt(a, Prop_Data, "m_hControlPointEnts", dotController);
			SetEntPropEnt(a, Prop_Send, "m_hControlPointEnts", dotController);
			
			ActivateEntity(a);
			AcceptEntityInput(a, "Start");
			
			SetVariantString("OnUser1 !self:kill::0.1:1");
			AcceptEntityInput(color, "AddOutput");
			AcceptEntityInput(color, "FireUser1");
			
			g_iEyeProp[client]   = EntIndexToEntRef(a);
			g_iSniperDot[client] = EntIndexToEntRef(ent);
			g_iDotController[client] = EntIndexToEntRef(dotController);
			
			//Hide original dot.
			SDKHook(ent, SDKHook_SetTransmit, OnDotTransmit);
		}
	}
}

public Action OnDotTransmit(int entity, int client)
{
	return Plugin_Handled;
}

public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		int env_sniperdot = EntRefToEntIndex(g_iSniperDot[i]);
		int dotController = EntRefToEntIndex(g_iDotController[i]);
		if(env_sniperdot > 0 && dotController > 0)
		{
			float dotPos[3]; GetEntPropVector(env_sniperdot, Prop_Send, "m_vecOrigin", dotPos);
			DispatchKeyValueVector(dotController, "origin", dotPos);
		}
		else
		{
			if(env_sniperdot <= 0 && dotController > 0)
			{
				DispatchKeyValue(dotController, "origin", "99999 99999 99999");
				
				SetVariantString("OnUser1 !self:kill::0.1:1");
				AcceptEntityInput(dotController, "AddOutput");
				AcceptEntityInput(dotController, "FireUser1");
				
				g_iDotController[i] = INVALID_ENT_REFERENCE;
			}
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if(TF2_GetPlayerClass(client) == TFClass_Sniper && condition == TFCond_Zoomed)
	{
		int iEyeProp = EntRefToEntIndex(g_iEyeProp[client])
		if(iEyeProp != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(iEyeProp, "ClearParent");
			AcceptEntityInput(iEyeProp, "Stop");
			
			DispatchKeyValue(iEyeProp, "origin", "99999 99999 99999");
			
			SetVariantString("OnUser1 !self:kill::0.1:1");
			AcceptEntityInput(iEyeProp, "AddOutput");
			AcceptEntityInput(iEyeProp, "FireUser1");
			
			g_iEyeProp[client] = INVALID_ENT_REFERENCE;
		}
	}
}