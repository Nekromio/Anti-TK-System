#pragma semicolon 1
#pragma newdecls required

#include <sdktools_functions>
#include <sdktools_stringtables>
#include <sdktools_entinput>
#include <sdkhooks>
#include <cstrike>
#include <smartdm>
#include <multicolors>
#include <csgo_colors>
#include <sdktools>

#undef REQUIRE_PLUGIN
#tryinclude <materialadmin>
#tryinclude <sourcebanspp>

#pragma newdecls required

#define ALLIES 2
#define AXIS 3

//ConVar cFriendlyFire;

bool
	bEnable,
	bReflect,
	bSlay,
	bFreeze,
	bBeacon,
	bFreezeBomb,
	bFireBomb,
	bTimeBomb,
	bBurn,
	bKillAttaker[MAXPLAYERS+1],
	bDebag,
	bChicken,
	bTKRoundKill[MAXPLAYERS+1],		//Если убил своего во время раунда
	bShake,
	bAutoKill,
	bHook[MAXPLAYERS+1],
	bTypeDmgGrenade,
	bTKRoundDmg[MAXPLAYERS+1],		//Наносил ли игрок урон в раунде своей команде
	bMsgFire,	//сообщение урон по своим !
	bDraw,		//Включить вид от 3 лица курице
	bPerformFade;

Handle
	hChicken,
	hDamage_reduction_bullets,
	hFriendlyFire;

float
	fDrugTime,
	fDamageRatio,
	fShakeAmp,
	fShakeTime,
	fEyeAngle,
	fChickenSpeed,
	fDamage_reduction_bullets,
	fDmgReduction;

int
	iMoney_offset = -1,
	iTKLimit,
	iForgive,
	iCount,
	iPunishMsg,
	iKickMsg,
	iSpawnProtect,
	iImmunity,
	iPunishMode,
	iPunishMent,
	iSlapDamage,
	iBanTime,
	iRemoveCash,
	iLogs,
	HideTeamswitchMsg[MAXPLAYERS + 1],
	TKCount[MAXPLAYERS + 1],
	TKerClient[MAXPLAYERS + 1] = {-1, ...},		//Массив состояния жертвы
	VictimClient[MAXPLAYERS + 1],
	SpawnTime[MAXPLAYERS + 1],
	iTKRoundLimit[MAXPLAYERS+1],		//Количество раундов которое игрок не убивал своих (или был прощён)
	iTKRound,	//Количество раундов после которого скинется предупреждение
	Engine_Version,
	iMethod,
	iTKDmg,
	iTKDmgLimit[MAXPLAYERS+1],		//Сумма урона игрока
	iSubtractDmg,		//Количество урона вычитаемое в начале раунда при хорошем поведении
	iFriendlyFire;

char
	PunishmentClient[MAXPLAYERS + 1][MAXPLAYERS + 1],
	sPath[PLATFORM_MAX_PATH],
	sChicken[256];
	
//char sChickenSec[][] =  { "ACT_WALK", "ACT_RUN", "ACT_IDLE", "ACT_JUMP", "ACT_GLIDE", "ACT_LAND", "ACT_HOP" };
//char sChickenAnim[][] =  { "ref", "walk01", "run01", "run01Flap", "idle01", "peck_idle2", "flap", "flap_falling", "bounce", "bunnyhop" };
	
#define GAME_UNDEFINED 0
#define GAME_CSS_34 1
#define GAME_CSS 2
#define GAME_CSGO 3

int GetCSGame()
{
	if (GetFeatureStatus(FeatureType_Native, "GetEngineVersion") == FeatureStatus_Available) 
	{
		switch (GetEngineVersion())
		{
			case Engine_SourceSDK2006: return GAME_CSS_34;
			case Engine_CSS: return GAME_CSS;
			case Engine_CSGO: return GAME_CSGO;
		}
	}
	return GAME_UNDEFINED;
}

public Plugin myinfo =
{
	name = "Anti-TK System",
	author = "Lebson506th, by Nek.'a 2x2 | ggwp.site , oleg_nelasy",
	description = "Anti-TK Система",
	version = "1.0.8",
	url = "http://hlmod.ru and https://ggwp.site/"
};

public APLRes AskPluginLoad2()
{
	Engine_Version = GetCSGame();
	if(Engine_Version == GAME_UNDEFINED)
		SetFailState("Game is not supported!");
		
	return APLRes_Success;
}

public void OnPluginStart()
{
	if(Engine_Version == GAME_CSS_34) LoadTranslations("antitk_cssv34");
	if(Engine_Version == GAME_CSS) LoadTranslations("antitk_css");
	if(Engine_Version == GAME_CSGO) LoadTranslations("antitk_csgo");
	LoadTranslations("common.phrases");
	
	ConVar cvar;
	cvar = CreateConVar("sm_tk_enabled", "1", "Включить/выключить плагин", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Enable);
	bEnable = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_debag", "0", "Включить/выключить дебаг", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Debag);
	bDebag = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_reflect", "1", "Включить/выключить отражение урона", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Reflect);
	bReflect = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_autokill", "0", "Убивать ли автоматически игрока за тим кил?", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_AutoKill);
	bAutoKill = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_shake", "1", "Включить/выключить тряску экрана при попадании по своим", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Shake);
	bShake = cvar.BoolValue;

	cvar = CreateConVar("sm_tk_limit", "5", "Количество ТК очков, которое должен получить игрок, преред тем как будет наказан", _, true, 1.0, true, 700.0);
	cvar.AddChangeHook(CVarChanged_TKLimit);
	iTKLimit = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_forgivemessage", "1", "Сообщения о прощении/наказании видят by. Никто(0), Все(1), Участники(2), Участники и Админы(3), Только Админы(4)", _, true, 0.0, true, 4.0);
	cvar.AddChangeHook(CVarChanged_Forgive);
	iForgive = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_countmessage", "2", "Кто видет посчёт TK Никто(0), Все(1), Игрок(2), Игрок и Админы(3), Только Админы(4)", _, true, 0.0, true, 4.0);
	cvar.AddChangeHook(CVarChanged_Count);
	iCount = cvar.IntValue;

	cvar = CreateConVar("sm_tk_punishmessage", "1", "Кто видет сообщения о наказании TK Никто(0), Все(1), Участники(2), Участники и Админы(3), Только Админы(4)", _, true, 0.0, true, 4.0);
	cvar.AddChangeHook(CVarChanged_PunishMsg);
	iPunishMsg = cvar.IntValue;

	cvar = CreateConVar("sm_tk_kickmessage", "1", "Сообщения о КИКЕ игрока видят Никто(0), Все(1), Только Админы(2)", _, true, 0.0, true, 2.0);
	cvar.AddChangeHook(CVarChanged_KickMsg);
	iKickMsg = cvar.IntValue;

	cvar = CreateConVar("sm_tk_protecttime", "10", "Автоматическое убийство любого атакующего игрока в течении этого времени при воскрешении", _, true, 0.0, true, 240.0);
	cvar.AddChangeHook(CVarChanged_SpawnProtect);
	iSpawnProtect = cvar.IntValue;

	cvar = CreateConVar("sm_tk_immunity", "0", "Режим иммунитета админа Отключить(0), К отражению и убийсту при спавне(1), К КИКУ(2), Варианты 1.2(3), Ко всему(4), 1 и 4(5), 2 и 4(6), 1,2 и 4(7)", _, true, 0.0, true, 7.0);
	cvar.AddChangeHook(CVarChanged_Immunity);
	iImmunity = cvar.IntValue;

	cvar = CreateConVar("sm_tk_punishmode", "1", "Режим дополнительных наказаний Нет(0), Выбирает жертва(1), Используется квар sm_tk_punishment(2)", _, true, 0.0, true, 2.0);
	cvar.AddChangeHook(CVarChanged_PunishMode);
	iPunishMode = cvar.IntValue;

	cvar = CreateConVar("sm_tk_punishment", "1", "Наказание TK, если квар sm_tk_punishmode = 2. 0 - Warn, 1 - Slay, 2 - Burn, 3 - Freeze, 4 - Beacon, 5 - Freeze Bomb, 6 - Fire Bomb, 7 - Time Bomb, 8 - Drug, 9 - Remove % Cash, 10 - Slap", _, true, 0.0, true, 10.0);
	cvar.AddChangeHook(CVarChanged_PunishMent);
	iPunishMent = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_allowslay", "1", "Если квар sm_tk_punishmode = 1, то убить нападающего в качестве наказания", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Slay);
	bSlay = cvar.BoolValue;

	cvar = CreateConVar("sm_tk_allowfreeze", "1", "Если квар sm_tk_punishmode = 1, то заморозить в качестве наказания", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Freeze);
	bFreeze = cvar.BoolValue;

	cvar = CreateConVar("sm_tk_allowbeacon", "1", "Если квар sm_tk_punishmode = 1, то поставить маяк в качестве наказания", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Beacon);
	bBeacon = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_allowfreezebomb", "1", "Если квар sm_tk_punishmode = 1, то замораживающая бомба в качестве наказания", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_FreezeBomb);
	bFreezeBomb = cvar.BoolValue;

	cvar = CreateConVar("sm_tk_allowfirebomb", "1", "Если квар sm_tk_punishmode = 1, то огненная бомба в качестве наказания", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_FireBomb);
	bFireBomb = cvar.BoolValue;

	cvar = CreateConVar("sm_tk_allowtimebomb", "1", "Если квар sm_tk_punishmode = 1, то бомба замедленного действия в качестве наказания", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_TimeBomb);
	bTimeBomb = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_drugtime", "10.0", "Опьянить, время для наказания, для отключения 0", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_DrugTime);
	fDrugTime = cvar.FloatValue;
	
	cvar = CreateConVar("sm_tk_damageratio", "0.7", "Коэффициент зеркального урона", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_DamageRatio);
	fDamageRatio = cvar.FloatValue;
	
	cvar = CreateConVar("sm_tk_amplitude", "50.0", "Сила тряски экрана при попадании по своим", _, true, 1.0, true, 100.0);
	cvar.AddChangeHook(CVarChanged_ShakeAmp);
	fShakeAmp = cvar.FloatValue;
	
	cvar = CreateConVar("sm_tk_shaketime", "0.5", "Продолжительность тряски экрана при попадании по своим", _, true, 0.1, true, 100.0);
	cvar.AddChangeHook(CVarChanged_ShakeTime);
	fShakeTime = cvar.FloatValue;
	
	cvar = CreateConVar("sm_tk_eyeangle", "15.0", "Рандомное значение смены угля экрана при выстрели по своим (дёргает прицел в сторону)", _, true, 0.0, true, 180.0);
	cvar.AddChangeHook(CVarChanged_EyeAngle);
	fEyeAngle = cvar.FloatValue;
	
	cvar = CreateConVar("sm_tk_chickenspeed", "0.85", "Скорость курицы, 1.0 - стандартная скорость", _, true, 0.0, true, 50.0);
	cvar.AddChangeHook(CVarChanged_ChickenSpeed);
	fChickenSpeed = cvar.FloatValue;

	cvar = CreateConVar("sm_tk_burntime", "1", "Включить поджигание для наказания, для отключения 0", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_Burn);
	bBurn = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_chicken", "1", "Включить превращение в курицу", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_Chicken);
	bChicken = cvar.BoolValue;

	cvar = CreateConVar("sm_tk_slapdamage", "5", "Если квар sm_tk_punishmode = 1, то шлёпните с указнным уроном действия в качестве наказания", _, true, 0.0, true, 1000.0);
	cvar.AddChangeHook(CVarChanged_SlapDamage);
	iSlapDamage = cvar.IntValue;

	cvar = CreateConVar("sm_tk_bantime", "5", "Время бана при лимите TK", _, true, -1.0, true, 9999.0);
	cvar.AddChangeHook(CVarChanged_BanTime);
	iBanTime = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_method", "3", "Способ наказания: 0 - Kick, 1 - Ban, 2 - SB Ban, 3 - MA Ban", _, true, 0.0, true, 3.0);
	cvar.AddChangeHook(CVarChanged_Method);
	iMethod = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_limitdamag", "350", "Максимальное количество дамага по союзникам", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_TKDmg);
	iTKDmg = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_subtractdmg", "50", "Количество урона вычитаемое в начале раунда при хорошем поведении", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_SubtractDmg);
	iSubtractDmg = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_removecash", "25", "Установить % денег, что заберёт жертва. Только CSS", _, true, 0.0, true, 100.0);
	cvar.AddChangeHook(CVarChanged_RemoveCash);
	iRemoveCash = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_logging", "1", "Режим логов. Отключить(0), Подробно(1), только TK и kick(2), только kick(3)", _, true, 0.0, true, 3.0);
	cvar.AddChangeHook(CVarChanged_Logs);
	iLogs = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_tkround", "2", "Количество раундов для хорошего поведения, для снятия 1 ТК убийства", _, true, 2.0, true, 100.0);
	cvar.AddChangeHook(CVarChanged_TKRound);
	iTKRound = cvar.IntValue;
	
	cvar = CreateConVar("sm_tk_msgfire", "1", "0 сообщение за урон по своим моментально убъёт, 1 огонь по своим будет активен через N секунд", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_MsgFire);
	bMsgFire = cvar.BoolValue;
	
	if(Engine_Version == GAME_CSGO)
	{
		hChicken = CreateConVar("sm_tk_models", "models/chicken/chicken.mdl", "Путь к модели mdl для превращения");
		GetConVarString(hChicken, sChicken, sizeof(sChicken));
		HookConVarChange(hChicken, OnConVarChanges_Chicken);
	}
	else
	{
		hChicken = CreateConVar("sm_tk_models", "models/lduke/chicken/chicken2.mdl", "Путь к модели mdl для превращения");
		GetConVarString(hChicken, sChicken, sizeof(sChicken));
		HookConVarChange(hChicken, OnConVarChanges_Chicken);
	}
	
	if(Engine_Version != GAME_CSGO)
	{
		cvar = CreateConVar("sm_tk_dmgreduction", "0.33", "Множитель урона по своим для подсчёта лимита урона", _, true, 0.0);
		cvar.AddChangeHook(CVarChanged_DmgReduction);
		fDmgReduction = cvar.FloatValue;
	}
	
	cvar = CreateConVar("sm_tk_draw", "1", "Включить вид от 3 лица курице", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Draw);
	bDraw = cvar.BoolValue;
	
	cvar = CreateConVar("sm_tk_performfade", "1", "Включить краску экрана при атаке по союзнику", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_PerformFade);
	bPerformFade = cvar.BoolValue;
	
	ConVar cvTemp;
	if((cvTemp = FindConVar("mp_friendlyfire")) != null) cvTemp.Flags = cvTemp.Flags & ~FCVAR_NOTIFY;
	if((cvTemp = FindConVar("sv_tags")) != null) cvTemp.Flags = cvTemp.Flags & ~FCVAR_NOTIFY;
	
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("round_start", Event_OnStart);
	//HookEvent("round_end", Event_OnEnd);
	if(Engine_Version != GAME_CSGO) HookUserMessage(GetUserMessageId("TextMsg"), Hook_TextMsg, true);
	
	Handle spawnprotect = FindConVar("mp_spawnprotectiontime");
	
	if(Engine_Version == GAME_CSGO)
	{
		hDamage_reduction_bullets = FindConVar("ff_damage_reduction_bullets");
		fDamage_reduction_bullets = GetConVarFloat(hDamage_reduction_bullets);
	}
	
	//cFriendlyFire = FindConVar("mp_friendlyfire");
	//ConVar cFriendlyFire = FindConVar("mp_friendlyfire");
	//cvar.BoolValue = true;
	
	hFriendlyFire = FindConVar("mp_friendlyfire");
	iFriendlyFire = 1;
	SetConVarInt(hFriendlyFire, iFriendlyFire);

	if( spawnprotect != INVALID_HANDLE )
		SetConVarInt(spawnprotect, 0);

	char sGameName[80];
	GetGameFolderName(sGameName, 80);

	if(Engine_Version != GAME_CSGO)
	{
		iMoney_offset = FindSendPropInfo("CCSPlayer", "m_iAccount");

		if(iMoney_offset == 1)
			SetFailState("Money offset could not be found.");
	}
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i)) OnClientPutInServer(i);
	AutoExecConfig(true, "anti-tk");
}



public void OnConVarChanges_Chicken(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(hChicken)
	{
		strcopy(sChicken, sizeof(sChicken), newValue);
	}
}

public void CVarChanged_Enable(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bEnable	= cvar.BoolValue;
}

public void CVarChanged_Debag(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bDebag	= cvar.BoolValue;
}

public void CVarChanged_Reflect(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bReflect = cvar.BoolValue;
}

public void CVarChanged_AutoKill(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bAutoKill = cvar.BoolValue;
}

public void CVarChanged_Shake(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bShake = cvar.BoolValue;
}

public void CVarChanged_TKLimit(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iTKLimit = cvar.IntValue;
}

public void CVarChanged_Forgive(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iForgive = cvar.IntValue;
}

public void CVarChanged_Count(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iCount = cvar.IntValue;
}

public void CVarChanged_PunishMsg(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iPunishMsg = cvar.IntValue;
}

public void CVarChanged_KickMsg(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iKickMsg = cvar.IntValue;
}

public void CVarChanged_SpawnProtect(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iSpawnProtect = cvar.IntValue;
}

public void CVarChanged_Immunity(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iImmunity = cvar.IntValue;
}

public void CVarChanged_PunishMode(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iPunishMode = cvar.IntValue;
}

public void CVarChanged_PunishMent(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iPunishMent = cvar.IntValue;
}

public void CVarChanged_Slay(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bSlay = cvar.BoolValue;
}

public void CVarChanged_Freeze(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bFreeze = cvar.BoolValue;
}

public void CVarChanged_Beacon(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bBeacon = cvar.BoolValue;
}

public void CVarChanged_FreezeBomb(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bFreezeBomb = cvar.BoolValue;
}

public void CVarChanged_FireBomb(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bFireBomb = cvar.BoolValue;
}

public void CVarChanged_TimeBomb(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bTimeBomb = cvar.BoolValue;
}

public void CVarChanged_DrugTime(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fDrugTime = cvar.FloatValue;
}

public void CVarChanged_DamageRatio(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fDamageRatio = cvar.FloatValue;
}

public void CVarChanged_ShakeAmp(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fShakeAmp = cvar.FloatValue;
}

public void CVarChanged_ShakeTime(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fShakeTime = cvar.FloatValue;
}

public void CVarChanged_EyeAngle(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fEyeAngle = cvar.FloatValue;
}

public void CVarChanged_Burn(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bBurn = cvar.BoolValue;
}

public void CVarChanged_Chicken(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bChicken = cvar.BoolValue;
}

public void CVarChanged_SlapDamage(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iSlapDamage = cvar.IntValue;
}

public void CVarChanged_BanTime(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iBanTime = cvar.IntValue;
}

public void CVarChanged_Method(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iMethod = cvar.IntValue;
}

public void CVarChanged_TKDmg(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iTKDmg = cvar.IntValue;
}

public void CVarChanged_SubtractDmg(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iSubtractDmg = cvar.IntValue;
}

public void CVarChanged_RemoveCash(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iRemoveCash = cvar.IntValue;
}

public void CVarChanged_Logs(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iLogs = cvar.IntValue;
}

public void CVarChanged_TKRound(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iTKRound = cvar.IntValue;
}

public void CVarChanged_ChickenSpeed(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fChickenSpeed = cvar.FloatValue;
}

public void CVarChanged_MsgFire(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bMsgFire = cvar.BoolValue;
}

public void CVarChanged_DmgReduction(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	fDmgReduction = cvar.FloatValue;
}

public void CVarChanged_Draw(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bDraw = cvar.BoolValue;
}

public void CVarChanged_PerformFade(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bPerformFade = cvar.BoolValue;
}

public void OnEnableChanged(Handle cvar, const char[] oldval, const char[] newval)
{
	if (strcmp(oldval, newval) != 0)
	{
		if (strcmp(newval, "0") == 0)
			UnhookEvent("player_death", Event_PlayerDeath);
		else if (strcmp(newval, "1") == 0)
			HookEvent("player_death", Event_PlayerDeath);
	}
}

public void OnReflectChanged(Handle cvar, const char[] oldval, const char[] newval)
{
	if (strcmp(oldval, newval) != 0)
	{
		if (strcmp(newval, "0") == 0 && iSpawnProtect <= 0)
			UnhookEvent("player_hurt", Event_PlayerHurt);
		else if (strcmp(newval, "1") == 0)
			HookEvent("player_hurt", Event_PlayerHurt);
	}
}

public void OnProtectChanged(Handle cvar, const char[] oldval, const char[] newval)
{
	if (strcmp(oldval, newval) != 0)
	{
		if (StringToInt(newval) <= 0)
		{
			if(!bReflect)
				UnhookEvent("player_hurt", Event_PlayerHurt);

			UnhookEvent("player_spawn", Event_PlayerSpawn);
		}
		else
		{
			if(!bReflect)	//
				HookEvent("player_hurt", Event_PlayerHurt);

			HookEvent("player_spawn", Event_PlayerSpawn);
		}
	}
}

/*
	Handlers to reset variables on disconnect and map start.
*/

public void OnMapStart()
{
	Downloader_AddFileToDownloadsTable(sChicken);
	if(sChicken[0]) PrecacheModel(sChicken);
	
	char sLink[64];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/anti-tk");
	
	if(!DirExists(sPath))
		CreateDirectory(sPath, 511);

	FormatTime(sLink, sizeof(sLink), "logs/anti-tk/stk_log_%d.%m.%Y.log");
	BuildPath(Path_SM, sPath, sizeof(sPath), sLink);
}

public void OnClientPostAdminCheck(int client)
{
	ResetVariables(client);
}

public void OnClientDisconnect(int client)
{
	ResetVariables(client);
}

public void ResetVariables(int client)
{
	TKCount[client] = 0;
	TKerClient[client] = -1;
	PunishmentClient[client] = "";
	VictimClient[client] = -1;
	HideTeamswitchMsg[client] = 0;
	iTKDmgLimit[client] = 0;
}

/*
	Handler to deal with slaying.
	Also deal with spawn slaying not working in DoD:S
*/

public void KillHandler(int victim, int attacker, bool spawn)
{
	//Нужно ли тут определение игры?
	char sGameName[32];
	bool NoForceKill;
	GetGameFolderName(sGameName, sizeof(sGameName));

	NoForceKill = StrEqual(sGameName, "insurgency", false);

	if(NoForceKill)
		ClientCommand(attacker, "kill");
	else
	{
		ForcePlayerSuicide(attacker);

		// Player wasn't killed. Usually happens in DoD:S when the player is in spawn.
		if(IsPlayerAlive(attacker))
		{
			//This code thanks to FeuerSturm.
			int Team = GetClientTeam(attacker);
			int OpTeam = Team == ALLIES ? AXIS : ALLIES;

			SecretTeamSwitch(attacker, OpTeam);
			SecretTeamSwitch(attacker, Team);
			//End of FeuerSturm's code.
		}
	}

	char sMsg[128], sMsgLog[128], sMsgSay[128];
	
	if(spawn)
	{
		SetGlobalTransTarget(attacker);
		FormatEx(sMsg, sizeof(sMsg), "%t", "Spawn Logs", attacker, victim);
		
		SetGlobalTransTarget(attacker);
		FormatEx(sMsgSay, sizeof(sMsgSay), "%t", "Tag", "Spawn");
	}
	else
	{		
		SetGlobalTransTarget(attacker);
		FormatEx(sMsgSay, sizeof(sMsgSay), "%t", "Tag", "TKSlayed");
		
		SetGlobalTransTarget(attacker);		//SetGlobalTransTarget(victim);
		FormatEx(sMsgLog, sizeof(sMsgLog), "%t", "TKSlayed Logs", attacker);
	}
	
	if(Engine_Version == GAME_CSGO) CGOPrintToChat(attacker, sMsgSay);
	else CPrintToChat(attacker, sMsgSay);

	if(iLogs == 1)
	{
		if(spawn) LogToFile(sPath, sMsg);
		else LogToFile(sPath, sMsgLog);
	}
}

//This code thanks to FeuerSturm.

/*
	Player team handler.
	Suppresses the team join message
	when a player is being switched silently.
*/

public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(HideTeamswitchMsg[client] == 1)
	{
		HideTeamswitchMsg[client] = 0;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/*
	Helper method to switch a player's team silently.
	Used to kill players in spawn if there is built in spawn protection.
*/

stock void SecretTeamSwitch(int iClient, int iNewTeam)
{
	HideTeamswitchMsg[iClient] = 1;
	ChangeClientTeam(iClient, iNewTeam);
	ShowVGUIPanel(iClient, iNewTeam == AXIS ? "class_ger" : "class_us", INVALID_HANDLE, false);
}

//End of FeuerSturm's code.

/*
	Player spawn handler.
	Remembers spawn time for spawn attack protection.
*/

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(iSpawnProtect > 0)
	{	
		if(client > 0 && IsClientInGame(client))
			SpawnTime[client] = GetTime();
	}

	for(int c = 1; c <= MaxClients; c++) if(c == client)
	{
		bKillAttaker[c] = false;
		//SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0); 
		if(bDebag) PrintToChatAll("Клиент [%N] | Индекс игрока [%d] | Значение индекса [%d]", client, c, bKillAttaker[c]);

		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
	}
}

/*
	Player hurt handler.
	Deals with reflecting damage and spawn slaying.
	Игрок обидел хэндлера.
	Имеет дело с отражением урона и убийством икры.
*/

stock void SetEntityArmor(int iClient, int iArmor)
{
	SetEntProp(iClient, Prop_Data, "m_ArmorValue", iArmor);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action Hook_TextMsg(UserMsg msg_id, Handle hBf, const char[] players, int playersNum, bool reliable, bool init)
{
	char sMessage[256];
	BfReadString(hBf, sMessage, sizeof(sMessage));

	if(Engine_Version == GAME_CSGO)
	{
		//if(StrContains(sMessage, "teammate") != -1)
		//return Plugin_Handled;
	}
	else
	{
		if(StrContains(sMessage, "teammate_attack") != -1)
        return Plugin_Handled;
	}
	return Plugin_Continue;
} 

public void SayWarnings(int iClient, int iDmg, int iVictim)
{
	if(!iTKDmg)
		return;
	
	//PrintToChat(iClient, "Сумма урона игрока [%N] - [%d]", iDmg, iTKDmgLimit[iClient]);
	//PrintToChat(iClient, "Сумма урона игрока [%d] - [%d]", iDmg, iTKDmgLimit[iClient]);
	if(Engine_Version == GAME_CSGO) CGOPrintToChat(iClient, "%t", "Tag", "Linit DMG", iDmg, iTKDmgLimit[iClient], iTKDmg);
	else CPrintToChat(iClient, "%t", "Tag", "Linit DMG", iDmg, iTKDmgLimit[iClient], iTKDmg);
	//PrintToChatAll("[%N] атаковал своего союзника [%N] !", iClient, iVictim);
	
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && i != iClient)
	{
		if(Engine_Version == GAME_CSGO) CGOPrintToChat(i, "%t", "Tag", "Linit DMG All", iClient, iVictim);
		else CPrintToChat(i, "%t", "Tag", "Linit DMG All", iClient, iVictim);
	}
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &Weapon, float fDamageForce[3], float fDamagePosition[3], int iDamageCustom)
{
	if(!iFriendlyFire)
		return Plugin_Handled;
	
	static char sMessage[256], sMsgKick[256];
	if (1 <= iAttacker <= MaxClients) FormatEx(sMessage, sizeof(sMessage), "%T", "TK Limit Reached damage", iAttacker);
	if (1 <= iAttacker <= MaxClients) FormatEx(sMsgKick, sizeof(sMsgKick), "%T", "Kicked Attaker damage", iAttacker);
	
	if(Engine_Version == GAME_CSGO)
	{
		for(int i = 1; i <= MaxClients; i++) if(i == iAttacker && IsClientInGame(iAttacker) && GetClientTeam(iVictim) == GetClientTeam(iAttacker) && !(iDamageType & DMG_BURN || iDamageType == 64) && !GameRules_GetProp("m_bWarmupPeriod"))
		{
			//PrintToChatAll("Размер множетеля [%.2f]", fDamage_reduction_bullets);
			iTKDmgLimit[i] += RoundFloat(fDamage * fDamage_reduction_bullets);
			bTKRoundDmg[i] = true;
			//PrintToChatAll("Сумма урона игрока [%N] - [%d]", i, iTKDmgLimit[i]);
			//PrintToChatAll("Клиент [%N] | Индекс игрока [%d] | Значение индекса [%d]", iAttacker, i, iTKDmgLimit[i]);
			//PrintToChatAll("Игрок [%N] нанёс [%.2f] урона [%N]", iAttacker, fDamage, iVictim);

			SayWarnings(i, RoundFloat(fDamage * fDamage_reduction_bullets), iVictim);
			
			if(iTKDmgLimit[i] >= iTKDmg && iTKDmg)
			{
				switch(iMethod)
				{
					case 0: {
						KickClient(iAttacker, sMsgKick);
					}
					case 1: {
						BanClient(iAttacker, iBanTime, BANFLAG_AUTO, sMessage);
					}
					case 2: {
						SBPP_BanPlayer(0, iAttacker, iBanTime, sMessage);
					}
					case 3: {
						MABanPlayer(0, iAttacker, MA_BAN_STEAM, iBanTime, sMessage);
					}
					default: {
						LogError("Method not found");
					}
				}
			}
		}
	}
	else
	{
		for(int i = 1; i <= MaxClients; i++) if(i == iAttacker && IsClientInGame(iAttacker) && GetClientTeam(iVictim) == GetClientTeam(iAttacker) && !(iDamageType & DMG_BURN || iDamageType == 64))
		{
			//iTKDmgLimit[i] += RoundFloat(fDamage);
			/*int iVictimLostHp = GetEventInt(event, "dmg_health");		//Потеряное ХП
			int iVictimHealth = GetClientHealth(victim) + iVictimLostHp;	//Количесиво здоровья жертвы
			int iAttackerHealth = GetClientHealth(attacker) - iVictimLostHp * RoundFloat(fDamageRatio);	//Количесиво здоровья атакера
			*/
			iTKDmgLimit[i] += RoundFloat(fDamage * fDmgReduction);
			bTKRoundDmg[i] = true;
			//PrintToChatAll("Сумма урона игрока [%N] - [%d]", i, iTKDmgLimit[i]);
			//PrintToChatAll("Клиент [%N] | Индекс игрока [%d] | Значение индекса [%d]", iAttacker, i, iTKDmgLimit[i]);
			//PrintToChatAll("Игрок [%N] нанёс [%.2f] урона [%N]", iAttacker, fDamage, iVictim);
			
			SayWarnings(i, RoundFloat(fDamage * fDmgReduction), iVictim);
			
			if(iTKDmgLimit[i] >= iTKDmg && iTKDmg)
			{
				switch(iMethod)
				{
					case 0: {
						KickClient(iAttacker, sMsgKick);    
					}
					case 1: {
						BanClient(iAttacker, iBanTime, BANFLAG_AUTO, sMessage);
					}
					case 2: {
						SBPP_BanPlayer(0, iAttacker, iBanTime, sMessage);
					}
					case 3: {
						MABanPlayer(0, iAttacker, MA_BAN_STEAM, iBanTime, sMessage);
					}
					default: {
						LogError("Method not found");
					}
				}
			}
		}
	}
	
	bTypeDmgGrenade = false;
	if(iDamageType & DMG_BURN || iDamageType == 64)
	{
		bTypeDmgGrenade = true;	
	}
	//PrintToChatAll("Индекс урона %d", iDamageType);
	return Plugin_Continue;
}

public void Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	if(!bEnable)
		return;
	
	int victim = GetClientOfUserId(GetEventInt(event,"userid"));		//Жертва
	int attacker = GetClientOfUserId(GetEventInt(event,"attacker"));	//Атакер
	

	if(attacker > 0 && IsClientInGame(attacker))
	{
		if((iImmunity == 1 || iImmunity == 3 || iImmunity == 7) && GetUserAdmin(attacker) != INVALID_ADMIN_ID)
			return;

		bool bFf = false;
		bool spawnAttack = ((GetTime() - SpawnTime[victim]) <= iSpawnProtect);
		float fVec[3];

		if(bReflect || spawnAttack)		//Зеркальный урон, Убийство при атаке на респе
		{
			if(victim > 0 && IsClientInGame(victim))
			{
				if(IsPlayerAlive(attacker) && GetClientTeam(attacker) == GetClientTeam(victim) && victim != attacker)
				{
					/*char weapon[15];
					GetEventString(event, "weapon_", weapon, 15);
					GetClientWeapon(attacker, weapon, 32);*/

					if(attacker && spawnAttack || attacker && !bTypeDmgGrenade && !spawnAttack)
					{
					//	PrintToChatAll("Игрок [%N] с оружием [%s]", attacker, weapon);
						//ХП
						int iVictimLostHp = GetEventInt(event, "dmg_health");		//Потеряное ХП
						int iVictimHealth = GetClientHealth(victim) + iVictimLostHp;	//Количесиво здоровья жертвы
						int iAttackerHealth = GetClientHealth(attacker) - iVictimLostHp * RoundFloat(fDamageRatio);	//Количесиво здоровья атакера
						
						//Бронь
						int iVictimLostAr = GetEventInt(event, "dmg_armor");		//Потеряное ХП
						int iVictimAr = GetClientHealth(victim) + iVictimLostAr;	//Количесиво здоровья жертвы
						int iAttackerAr = GetClientHealth(attacker) - iVictimLostAr * RoundFloat(fDamageRatio);	//Количесиво здоровья атакера

						if(iVictimHealth > 100 && bFf)		//Если количество хп больше 100
						{
							SetEntityHealth(victim, 100);	//То устанавливает здоровьте в 100
							//PrintToChatAll("Код отрабатывает");
						}
						else if(bFf)	//Если нет, то
						{
							SetEntityHealth(victim, iVictimHealth);
							SetEntityArmor(victim, iVictimAr);
						}
						if(spawnAttack)
						{
							KillHandler(victim, attacker, true);
						}
						else if(iAttackerHealth <= 0)
						{
							KillHandler(victim, attacker, false);
						}
						else
						{
							SetEntityHealth(attacker, iAttackerHealth);		//Изменить здоровья атакера
							SetEntityArmor(attacker, iAttackerAr);
							//PrintToChatAll("Здоровья [%N] изменено на [%d]", attacker, iAttackerHealth);
							//PrintToChatAll("Множитель урона [%.2f]", fDamageRatio);
							
							if(bShake) Shake(attacker);
							if(bPerformFade)
							{
								if(GetClientTeam(attacker) == 2)
								{
									int clr[4];
									clr[3] = 255;
									clr[0] = GetRandomInt(255, 255);
									clr[1] = GetRandomInt(102, 153);
									clr[2] = GetRandomInt(51, 0);
									PerformFade(attacker, 300, clr);
								}
								else
								{
									int clr[4];
									clr[3] = 255;
									clr[0] = GetRandomInt(100, 153);
									clr[1] = GetRandomInt(0, 10);
									clr[2] = GetRandomInt(190, 204);
									PerformFade(attacker, 300, clr);
								}
							}
							GetClientEyeAngles(attacker, fVec);		
							fVec[0] += GetRandomFloat(-fEyeAngle, fEyeAngle);
							fVec[1] += GetRandomFloat(-fEyeAngle, fEyeAngle);
							TeleportEntity(attacker, NULL_VECTOR, fVec, NULL_VECTOR);
							//PrintToChatAll("Позиция взгляда игрока [%N] сменилась на [%f]", attacker, fVec);
						}
					}
				}
			}
		}
	}
}

stock void Shake(int iClient)
{
	if(Engine_Version == GAME_CSGO) 
	{
		Handle hBf = StartMessageOne("Shake", iClient);
		if(hBf != INVALID_HANDLE)
		{
			PbSetInt(hBf, "command", 0);  
			PbSetFloat(hBf, "local_amplitude", fShakeAmp);  
			PbSetFloat(hBf, "frequency", 1.0);  
			PbSetFloat(hBf, "duration", fShakeTime);  
			EndMessage();
		}
	}
	else
	{
		Handle hBf = StartMessageOne("Shake", iClient);
		if(hBf != INVALID_HANDLE)
		{
			BfWriteByte(hBf,  0);
			BfWriteFloat(hBf, fShakeAmp);
			BfWriteFloat(hBf, 1.0);
			BfWriteFloat(hBf, fShakeTime);
			EndMessage();
		}
	}
}

stock void PerformFade(int client, int duration, int color[4]) 
{
	int iClients[1];
	Handle hMessage;
	iClients[0] = client;
	hMessage = StartMessage("Fade", iClients, 1); 
	if(GetUserMessageType() == UM_Protobuf) 
	{
		PbSetInt(hMessage, "duration", duration);
		PbSetInt(hMessage, "hold_time", 0);
		PbSetInt(hMessage, "flags", 0x0001);
		PbSetColor(hMessage, "clr", color);
	}
	else
	{
		BfWriteShort(hMessage, duration);
		BfWriteShort(hMessage, 0);
		BfWriteShort(hMessage, (0x0001));
		BfWriteByte(hMessage, color[0]);
		BfWriteByte(hMessage, color[1]);
		BfWriteByte(hMessage, color[2]);
		BfWriteByte(hMessage, color[3]);
	}
	EndMessage();
}

public void HudText(int userid)
{
	if(!bMsgFire)
	{
		int client = GetClientOfUserId(userid);
		char sFft[256], sFfct[256];
		FormatEx(sFft, sizeof(sFft), "%T", "Fire on your own is prohibited T", client, iSpawnProtect);
		FormatEx(sFfct, sizeof(sFfct), "%T", "Fire on your own is prohibited CT", client, iSpawnProtect);
		
		int iClr_t[4], iClr_t2[4], iClr_ct[4], iClr_ct2[4];
		iClr_t[0] = GetRandomInt(250, 255);
		iClr_t[1] = GetRandomInt(0, 153);
		iClr_t[2] = GetRandomInt(0, 153);
		iClr_t[3] = 255;
		iClr_t2[0] = GetRandomInt(0, 5);
		iClr_t2[1] = GetRandomInt(130, 153);
		iClr_t2[2] = GetRandomInt(35, 51);
		iClr_t2[3] = 255;
		
		iClr_ct[0] = GetRandomInt(0, 10);
		iClr_ct[1] = GetRandomInt(0, 10);
		iClr_ct[2] = GetRandomInt(180, 204);
		iClr_ct[3] = 255;
		iClr_ct2[0] = GetRandomInt(204, 221);
		iClr_ct2[1] = GetRandomInt(102, 153);
		iClr_ct2[2] = GetRandomInt(250, 255);
		iClr_ct2[3] = 255;
		
		//float fSpawnProtect = view_as<float>(iSpawnProtect);
		float fSpawnProtect = float(iSpawnProtect);
		
		if(iSpawnProtect > 0)
		{
			SetHudTextParamsEx(-1.0, 0.8, fSpawnProtect, iClr_t, iClr_t2, 2, 0.1, 0.1, 0.1);
			for(int i = 1; i <= MaxClients; i++) if(i && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_T) 
			{
				ShowHudText(i, -1, sFft);
			}
			
			SetHudTextParamsEx(-1.0, 0.8, fSpawnProtect, iClr_ct, iClr_ct2, 2, 0.1, 0.1, 0.1);
			for(int i = 1; i <= MaxClients; i++) if(i && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_CT) 
			{
				ShowHudText(i, -1, sFft);
			}
		}
	}
	else
	{
		int client = GetClientOfUserId(userid);
		char sFft[256], sFfct[256];
		FormatEx(sFft, sizeof(sFft), "%T", "Fire on your own is blocked T", client, iSpawnProtect);
		FormatEx(sFfct, sizeof(sFfct), "%T", "Fire on your own is blocked CT", client, iSpawnProtect);
		
		int iClr_t[4], iClr_t2[4], iClr_ct[4], iClr_ct2[4];
		iClr_t[0] = GetRandomInt(250, 255);
		iClr_t[1] = GetRandomInt(0, 153);
		iClr_t[2] = GetRandomInt(0, 153);
		iClr_t[3] = 255;
		iClr_t2[0] = GetRandomInt(0, 5);
		iClr_t2[1] = GetRandomInt(130, 153);
		iClr_t2[2] = GetRandomInt(35, 51);
		iClr_t2[3] = 255;
		
		iClr_ct[0] = GetRandomInt(0, 10);
		iClr_ct[1] = GetRandomInt(0, 10);
		iClr_ct[2] = GetRandomInt(180, 204);
		iClr_ct[3] = 255;
		iClr_ct2[0] = GetRandomInt(204, 221);
		iClr_ct2[1] = GetRandomInt(102, 153);
		iClr_ct2[2] = GetRandomInt(250, 255);
		iClr_ct2[3] = 255;
		
		//float fSpawnProtect = view_as<float>(iSpawnProtect);
		float fSpawnProtect = float(iSpawnProtect);
		
		if(iSpawnProtect > 0)
		{
			SetHudTextParamsEx(-1.0, 0.8, fSpawnProtect, iClr_t, iClr_t2, 2, 0.1, 0.1, 0.1);
			for(int i = 1; i <= MaxClients; i++) if(i && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_T) 
			{
				ShowHudText(i, -1, sFft);
			}
			
			SetHudTextParamsEx(-1.0, 0.8, fSpawnProtect, iClr_ct, iClr_ct2, 2, 0.1, 0.1, 0.1);
			for(int i = 1; i <= MaxClients; i++) if(i && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_CT) 
			{
				ShowHudText(i, -1, sFft);
			}
		}
	}
}

public Action HudTimer(Handle timer, any client)
{
	HudText(client);
}

public Action tFriendlyFire(Handle timer, any client)
{
	if(bMsgFire)
	{
		//ServerCommand("mp_friendlyfire 1");
		iFriendlyFire = 1;
		SetConVarInt(hFriendlyFire, iFriendlyFire, _, false);
		//cFriendlyFire.BoolValue = true;
		//cFriendlyFire.SetBool(true, false, false);
		//PrintToChatAll("Огонь по свои активирован !");
	}
}

public Action Event_OnStart(Handle event, const char[] name, bool dontBroadcast)
{
//	if(bMsgFire) bFriendlyFire = true;
//	else bFriendlyFire = false;
	if(bMsgFire)
	{
		//ServerCommand("mp_friendlyfire 0");
		iFriendlyFire = 0;
		SetConVarInt(hFriendlyFire, iFriendlyFire, _, false);
		//cFriendlyFire.BoolValue = false;
		//cFriendlyFire.SetBool(false, false, false);
		//PrintToChatAll("Огонь по свои отключён !");
	}
	else
	{
		iFriendlyFire = true;
		SetConVarInt(hFriendlyFire, iFriendlyFire);
	}
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	//float fSpawnProtect = view_as<float>(iSpawnProtect);
	//float fSpawnProtect = GetConVarFloat(iSpawnProtect);
	float fSpawnProtect = float(iSpawnProtect);

	CreateTimer(1.0, HudTimer, client);
	if(bMsgFire) CreateTimer(fSpawnProtect + 1.0, tFriendlyFire, client);
	
	for(int g = 1; g <= MaxClients; g++) if(IsClientInGame(g))
	{
			//PrintToChatAll("У игрока [%N] | Индекс игрока [%d] | Убил ли он в этом раунде? - [%d] | TK[%d]", attacker, g, bTKRoundKill[g], TKCount[g]);
		if(bTKRoundKill[g] == true)
		{
			iTKRoundLimit[g] = 0;
			bTKRoundKill[g] = false;
		}
		else
		{
			iTKRoundLimit[g]++;
		}
		if(iTKRoundLimit[g] == iTKRound)
		{
			iTKRoundLimit[g] = 0;
			if(TKCount[g] > 0)
				TKCount[g]--;
		}
		if(TKCount[g] > 0)
		{
			if(Engine_Version == GAME_CSGO) CGOPrintToChat(g, "%t", "Tag", "TK alerts at the beginning of the round", TKCount[g], iTKLimit);
			else CPrintToChat(g, "%t", "Tag", "TK alerts at the beginning of the round", TKCount[g], iTKLimit);
		}
		
		if(bTKRoundDmg[g] == false)
		{
			//PrintToChat(g, "Урон игрока до [%N] | [%d]", g, iTKDmgLimit[g]);
			if(iTKDmgLimit[g] > 0)
			{
				if(Engine_Version == GAME_CSGO) CGOPrintToChat(g, "%t", "Tag", "Good behavior dmg msg", iSubtractDmg, iTKDmgLimit[g], iTKDmg);
				else CPrintToChat(g, "%t", "Tag", "Good behavior dmg msg", iSubtractDmg, iTKDmgLimit[g], iTKDmg);
			}
			iTKDmgLimit[g] -= iSubtractDmg;
			
			if(0 > iTKDmgLimit[g]) iTKDmgLimit[g] = 0;
			//PrintToChat(g, "Урон игрока после [%N] | [%d]", g, iTKDmgLimit[g]);
		}
		bTKRoundDmg[g] = false;
	}
}
/*
public Action Event_OnEnd(Handle event, const char[] name, bool dontBroadcast)
{
	
}*/


/*
	Player Death handler.
	Calls the forgive menu if a TK occurs unless
	the attacker is an immune admin.
	Also handles reflecting a kill back onto the attacker.
*/

public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if(bEnable)
	{
		int victim = GetClientOfUserId(GetEventInt(event, "userid"));
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		
		for(int c = 1; c <= MaxClients; c++) if(c == victim)
		{
			bKillAttaker[c] = false;
			if(bDebag) PrintToChatAll("Игрока [%N] | Индекс игрока [%d] | Значение индекса [%d]", victim, c, bKillAttaker[c]);
		}
		if(attacker > 0 && victim > 0 && IsClientInGame(attacker) && IsClientInGame(victim))
		{
			if(GetClientTeam(attacker) == GetClientTeam(victim) && victim != attacker)
			{
				if((iImmunity == 6 || iImmunity == 7) && GetUserAdmin(attacker) != INVALID_ADMIN_ID)
				{
					char attackerName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH], ForgiveMsg[128];

					GetClientName(attacker, attackerName, MAX_NAME_LENGTH);
					GetClientName(victim, victimName, MAX_NAME_LENGTH);
					Format(ForgiveMsg, sizeof(ForgiveMsg), "%t", "Auto Forgave Admin", victimName, attackerName);

					DoChat(victim, attacker, ForgiveMsg, ForgiveMsg, iForgive, false);
					return;
				}

				if(IsPlayerAlive(attacker) && bAutoKill)
				{
					if((iImmunity != 1 && iImmunity != 3 && iImmunity != 5 && iImmunity != 7) || GetUserAdmin(attacker) == INVALID_ADMIN_ID)
					{
						KillHandler(victim, attacker, false);
					}
				}

				if(TKerClient[victim] == -1)
					ForgiveMenu(attacker, victim);
				else
				{
					char attackerName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH], ForgiveMsg[128];

					GetClientName(attacker, attackerName, MAX_NAME_LENGTH);
					GetClientName(victim, victimName, MAX_NAME_LENGTH);
					Format(ForgiveMsg, sizeof(ForgiveMsg), "%t", "Auto Forgave", victimName, attackerName);

					DoChat(victim, attacker, ForgiveMsg, ForgiveMsg, iForgive, false);
				}
			}
		}
	}
}

/*
	Forgive menu handlers.
*/

public Action ForgiveMenu(int iAttacker, int iVictim)
{
	if(iAttacker <= MaxClients && iVictim <= MaxClients && iAttacker && iVictim && IsClientInGame(iAttacker) && IsClientInGame(iVictim))
	{
		TKerClient[iVictim] = iAttacker;

		Handle hMenu = CreateMenu(AdminMenuHandler);
		char sAttackerName[32];

		GetClientName(iAttacker, sAttackerName, MAX_NAME_LENGTH);

		SetMenuTitle(hMenu, "%t", "ForgiveMenu", sAttackerName);

		char sYes[128], sNo[128];
		Format(sYes, sizeof(sYes), "%t", "Yes");
		AddMenuItem(hMenu, "yes", sYes);
		Format(sNo, sizeof(sNo), "%t", "No");
		AddMenuItem(hMenu, "no", sNo);

		SetMenuExitButton(hMenu, false);
		DisplayMenu(hMenu, iVictim, MENU_TIME_FOREVER);		//MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int AdminMenuHandler(Handle hMenu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select )
	{
		if(client > 0 && IsClientInGame(client))
		{
			int attacker = TKerClient[client];
			TKerClient[client] = -1;

			if(attacker > 0 && IsClientInGame(attacker))
			{
				char attackerName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH], info[32];

				GetClientName(attacker, attackerName, MAX_NAME_LENGTH);
				GetClientName(client, victimName, MAX_NAME_LENGTH);
				GetMenuItem(hMenu, itemNum, info, sizeof(info));

				if(strcmp(info, "yes") == 0)
				{
					char ForgiveMsg[128];
					Format(ForgiveMsg, sizeof(ForgiveMsg), "%t", "Forgave", victimName, attackerName);

					DoChat(client, attacker, ForgiveMsg, ForgiveMsg, iForgive, false);
				}
				else if(strcmp(info, "no") == 0)
					DidNotForgive(attacker, client, victimName);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		TKerClient[client] = -1;
	}
	else if ( action == MenuAction_End )
	{
		//CancelMenu(hMenu);
		CloseHandle(hMenu);
	}
}

/*
	Punishment menu handlers.
*/

public Action PunishMenu(int victim, int attacker)
{
	if(attacker <= MaxClients && victim <= MaxClients && attacker > 0 && victim)
	{
		if(IsClientInGame(attacker) && IsClientInGame(victim))
		{
			TKerClient[victim] = attacker;

			Handle menu = CreateMenu(PunishMenuHandler);
			char attackerName[MAX_NAME_LENGTH];

			GetClientName(attacker, attackerName, MAX_NAME_LENGTH);

			SetMenuTitle(menu, "%t", "PunishMenu", attackerName);

			char warn[128];
			Format(warn, sizeof(warn), "%t", "Warn", TKCount[attacker], iTKLimit);
			AddMenuItem(menu, "warn", warn);

			if(iSlapDamage > 0)
			{
				char slap[128];
				Format(slap, sizeof(slap), "%t", "Slap");
				AddMenuItem(menu, "slap", slap);
			}

			if(bSlay)
			{
				char slay[128];
				Format(slay, sizeof(slay), "%t", "Slay");
				AddMenuItem(menu, "slay", slay);
			}

			if(bBurn == true)
			{
				char burn[128];
				Format(burn, sizeof(burn), "%t", "Burn");
				AddMenuItem(menu, "burn", burn);
			}

			if(bFreeze)
			{
				char freeze[128];
				Format(freeze, sizeof(freeze), "%t", "Freeze");
				AddMenuItem(menu, "freeze", freeze);
			}

			if(bBeacon)
			{
				char beacon[128];
				Format(beacon, sizeof(beacon), "%t", "Beacon");
				AddMenuItem(menu, "beacon", beacon);
			}

			if(bFreezeBomb)
			{
				char freezebomb[128];
				Format(freezebomb, sizeof(freezebomb), "%t", "FreezeBomb");
				AddMenuItem(menu, "freezebomb", freezebomb);
			}

			if(bFireBomb)
			{
				char firebomb[128];
				Format(firebomb, sizeof(firebomb), "%t", "FireBomb");
				AddMenuItem(menu, "firebomb", firebomb);
			}

			if(bTimeBomb)
			{
				char timebomb[128];
				Format(timebomb, sizeof(timebomb), "%t", "TimeBomb");
				AddMenuItem(menu, "timebomb", timebomb);
			}

			if(fDrugTime > 0)
			{
				char drug[128];
				Format(drug, sizeof(drug), "%t", "Drug");
				AddMenuItem(menu, "drug", drug);
			}

			if(Engine_Version != GAME_CSGO && iRemoveCash > 0)
			{
				char cash[128];
				Format(cash, sizeof(cash), "%t", "RemoveCash", iRemoveCash);
				AddMenuItem(menu, "removecash", cash);
			}
			
			if(bChicken)
			{
				char sModelsSay[128];		//Курица
				Format(sModelsSay, sizeof(sModelsSay), "%t", "Menu_Model");
				AddMenuItem(menu, "Chicken", sModelsSay);
			}

			SetMenuExitButton(menu, false);
			DisplayMenu(menu, victim, MENU_TIME_FOREVER);
		}
	}
	return Plugin_Handled;
}

public int PunishMenuHandler(Handle hMenu, MenuAction action, int client, int itemNum)
{
	if ( action == MenuAction_Select )
	{
		if(client > 0 && IsClientInGame(client))
		{
			int attacker = TKerClient[client];
			TKerClient[client] = -1;

			if(attacker > 0 && IsClientInGame(attacker))
			{
				char info[32];
				GetMenuItem(hMenu, itemNum, info, sizeof(info));

				if(IsPlayerAlive(attacker))
					PunishHandler(client, attacker, info);
				else
				{
					PunishmentClient[attacker] = info;
					CreateTimer(5.0, WaitForSpawn, attacker, TIMER_FLAG_NO_MAPCHANGE);
					if(bDebag) PrintToChatAll("Убийца(%N) мёртв, повтор через %f секунд 2", attacker, 5.0);
				}
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		TKerClient[client] = -1;
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(hMenu);
	}
	/*switch(action)
	{
		case MenuAction_End:	 // Меню завершилось
		  {
				// Оно нам больше не нужно. Удалим его
				delete hMenu;
		  }
		case MenuAction_Cancel:	 // Меню было отменено
		  {
			if(client > 0 && IsClientInGame(client))
			{
				int attacker = TKerClient[client];
				TKerClient[client] = -1;

				if(attacker > 0 && IsClientInGame(attacker))
				{
					char info[32];
					GetMenuItem(hMenu, itemNum, info, sizeof(info));

					if(IsPlayerAlive(attacker))
					{
						PunishHandler(client, attacker, info);
					}
					else
					{
						PunishmentClient[attacker] = info;
						CreateTimer(5.0, WaitForSpawn, attacker, TIMER_FLAG_NO_MAPCHANGE);
						if(bDebag) PrintToChatAll("Убийца(%N) мёртв, повтор через %f секунд 2", attacker, 5.0);
					}
				}
			}
		}
	}*/
}

/*
	Handler for when a player is not forgiven.
	Made it a function because i used it twice.
	
	Обработчик для тех случаев, когда игрок не прощен.
	Сделал его функцией, потому что я использовал его дважды.
*/

public void DidNotForgive(int attacker, int client, char sNameVictim[MAX_NAME_LENGTH])
{
	if(attacker > 0 && client > 0 && IsClientInGame(attacker) && IsClientInGame(client))
	{
		char sNameAttaker[MAX_NAME_LENGTH];
		GetClientName(attacker, sNameAttaker, MAX_NAME_LENGTH);

		if((iImmunity != 2 && iImmunity != 3 && iImmunity != 6 && iImmunity != 7) || GetUserAdmin(attacker) == INVALID_ADMIN_ID)
		{
			TKCount[attacker] = TKCount[attacker] + 1;
			bTKRoundKill[attacker] = true;
			if(bDebag)
			{
				if(bTKRoundKill[attacker] == true)
					for(int g = 1; g <= MaxClients; g++) if(g == attacker) PrintToChatAll("У игрока [%N] | Индекс игрока [%d] | Убил ли он в этом раунде? - [%d]", attacker, g, bTKRoundKill[g]);
			}
			if(bDebag)
			{
				for(int g = 1; g <= MaxClients; g++) if(g == attacker)
				{
					PrintToChatAll("У игрока [%N] | Индекс игрока [%d] | Количество TK [%d]/[%d]", attacker, g, TKCount[attacker], iTKLimit);
					//PrintToChatAll("Убийца [%N] | Индекс игрока [%d] | Значение индекса [%d]", attacker, c, bKillAttaker[c]);
				}
			}
			
			if(iCount > 0 && iCount < 5)
			{
				char TKCountMsg[128];
				Format(TKCountMsg, sizeof(TKCountMsg), "%t", "TK Count Others", sNameAttaker, TKCount[attacker], iTKLimit);
				char TKCountMsg2[128];
				Format(TKCountMsg2, sizeof(TKCountMsg2), "%t", "TK Count", TKCount[attacker], iTKLimit);

				DoChat(client, attacker, TKCountMsg, TKCountMsg2, iCount, true);
			}
		}

		if(iForgive > 0 && iForgive < 5)
		{
			char DidNotForgiveMsg[128];
			Format(DidNotForgiveMsg, sizeof(DidNotForgiveMsg), "%t", "Did Not Forgive", sNameVictim, sNameAttaker);

			DoChat(client, attacker, DidNotForgiveMsg, DidNotForgiveMsg, iForgive, false);
		}
		
		//Бан
		if(TKCount[attacker] >= iTKLimit)
		{
			char sSteamID_Attaker[32];
			GetClientAuthId(attacker, AuthId_Steam2, sSteamID_Attaker, 31);
			
			static char sMessage[256], sMsgKick[256];
			FormatEx(sMessage, sizeof(sMessage), "%T", "TK Limit Reached", attacker);
			FormatEx(sMsgKick, sizeof(sMsgKick), "%T", "Kicked Attaker", attacker);

			switch(iMethod)
			{
				case 0: {
					KickClient(attacker, sMsgKick);    
				}
				case 1: {
					BanClient(attacker, iBanTime, BANFLAG_AUTO, sMessage);
				}
				case 2: {
					SBPP_BanPlayer(0, attacker, iBanTime, sMessage);
				}
				case 3: {
					MABanPlayer(0, attacker, MA_BAN_STEAM, iBanTime, sMessage);
				}
				default: {
					LogError("Method not found");
				}
			}
			if(iMethod == 0)
			{
				if(iLogs > 0)
					LogToFile(sPath, "%t", "Kicked", sNameAttaker, sSteamID_Attaker);

				if(iKickMsg == 1)
				{
					if(Engine_Version == GAME_CSGO) CGOPrintToChatAll("%t", "Tag", "Kicked withdrawal to players", sNameAttaker, sSteamID_Attaker);
					else CPrintToChatAll("%t", "Tag", "Kicked withdrawal to players", sNameAttaker, sSteamID_Attaker);
				}
				else if(iKickMsg == 2)
				{
					for(int a = 1; a<=MaxClients;a++)
					{
						if(IsClientInGame(a) && GetUserAdmin(a) != INVALID_ADMIN_ID && a != attacker)
						{
							if(Engine_Version == GAME_CSGO) CGOPrintToChat(a, "%t", "Tag", "Kicked withdrawal to players", sNameAttaker, sSteamID_Attaker);
							else CPrintToChat(a, "%t", "Tag", "Kicked withdrawal to players", sNameAttaker, sSteamID_Attaker);
						}
					}
				}
			}
		}
		else if((iImmunity < 4 && iImmunity >= 0) || GetUserAdmin(attacker) == INVALID_ADMIN_ID)
		{
			if(iPunishMode == 1)
				PunishMenu(client, attacker);
			else if(iPunishMode == 2)
			{
				char punishment[32];

				switch(iPunishMent)
				{
					case 0: punishment = "warn";
					case 1: punishment = "slay";
					case 2: punishment = "burn";
					case 3: punishment = "freeze";
					case 4: punishment = "beacon";
					case 5: punishment = "freezebomb";
					case 6: punishment = "firebomb";
					case 7: punishment = "timebomb";
					case 8: punishment = "drug";
					case 9: punishment = "removecash";
					case 10: punishment = "slap";
					case 11: punishment = "Chicken";
					default: punishment = "warn";
				}

				if(IsPlayerAlive(attacker))
				{
					PunishHandler(client, attacker, punishment);
					if(bDebag) PrintToChatAll("Убийца(%N) ЖИВ", attacker);
				}
				else
				{
					PunishmentClient[attacker] = punishment;
					VictimClient[attacker] = client;
					CreateTimer(5.0, WaitForSpawn, attacker, TIMER_FLAG_NO_MAPCHANGE);
					if(bDebag) PrintToChatAll("Убийца(%N) мёртв, повтор через %f секунд 3", attacker, 5.0);
				}
			}
		}
	}
}

/*
	Punishment helper method
*/

public void PunishHandler(int client, int attacker, char punishment[32])
{
	if(client > 0 && IsClientInGame(client))
	{
		if(attacker > 0 && IsClientInGame(attacker))
		{
			char attackerName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH], PunishMsg[128];

			GetClientName(attacker, attackerName, MAX_NAME_LENGTH);
			GetClientName(client, victimName, MAX_NAME_LENGTH);

			if ( strcmp(punishment, "warn", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Warned", victimName, attackerName);
			}
			else if ( strcmp(punishment, "slay", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Slayed", victimName, attackerName);

				KillHandler(client, attacker, false);
			}
			else if ( strcmp(punishment, "slap", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Slapped", victimName, attackerName, iSlapDamage);

				SlapPlayer(attacker, iSlapDamage);
			}
			else if ( strcmp(punishment, "burn", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Burnt", victimName, attackerName);

				ServerCommand("sm_burn \"%s\" 10", attackerName);
			}
			else if ( strcmp(punishment, "freeze", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Froze", victimName, attackerName);

				ServerCommand("sm_freeze \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "beacon", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Beaconed", victimName, attackerName);

				ServerCommand("sm_beacon \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "freezebomb", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "FreezeBombed", victimName, attackerName);

				ServerCommand("sm_freezebomb \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "firebomb", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "FireBombed", victimName, attackerName);

				ServerCommand("sm_firebomb \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "timebomb", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "TimeBombed", victimName, attackerName);

				ServerCommand("sm_timebomb \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "drug", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Drugged", victimName, attackerName);

				CreateTimer(fDrugTime, Undrug, attacker, TIMER_FLAG_NO_MAPCHANGE);
				ServerCommand("sm_drug \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "removecash", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "CashRemoved", victimName, iRemoveCash, attackerName);

				int divisor = iRemoveCash / 100;
				int cash = GetEntData(attacker, iMoney_offset) * divisor;
				SetEntData(attacker, iMoney_offset, cash);
			}
			else if(strcmp(punishment, "Chicken", false) == 0)
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Chicken", victimName, attackerName);
				SetEntityModel(attacker, sChicken);
				//DispatchKeyValue(attacker, "Solid", "0");
				SetEntPropFloat(attacker, Prop_Data, "m_flLaggedMovementValue", fChickenSpeed);
				bKillAttaker[attacker] = true;
				
				if(!bDraw)
				{
					SetEntPropEnt(attacker, Prop_Send, "m_hObserverTarget", 0);
					SetEntProp(attacker, Prop_Send, "m_iObserverMode", 1);
					SetEntProp(attacker, Prop_Send, "m_bDrawViewmodel", 0);
					SetEntProp(attacker, Prop_Send, "m_iFOV", 50);
				}
				//Проверка на модель
				/*char sBuffer[64];
				GetClientModel(attacker, sBuffer, sizeof(sBuffer));
				if(StrContains(sChicken, sBuffer, true) != -1)
				{
					PrintToChatAll("Курица %s", sChicken);
					PrintToChatAll("Буфер %s", sBuffer);
					funAnim(attacker);
				}*/
				
				if(bDebag)
				{
					if(bKillAttaker[attacker] == true)
						PrintToChatAll("Класс аттакер установлен на игрока %N", attacker);
					else
						PrintToChatAll("Не удалось установить класс атакер на игрока %N", attacker);
						
					for(int c = 1; c <= MaxClients; c++) if(c == attacker)
						PrintToChatAll("Убийца [%N] | Индекс игрока [%d] | Значение индекса [%d]", attacker, c, bKillAttaker[c]);
				}

				int iSlot, bomb = -1;
				for(int i; i < 5; i++)
				{
					if(i != -1) iSlot = GetPlayerWeaponSlot(attacker, i);
					if(iSlot && IsValidEntity(iSlot) && RemovePlayerItem(attacker, iSlot))
					{
						if((bomb = GetPlayerWeaponSlot(attacker, 4)) != -1)
							CS_DropWeapon(attacker, bomb, true, true);
						AcceptEntityInput(iSlot, "Kill");
					}
				}
				RemoveGrenade(attacker);
				
				SDKHook(attacker, SDKHook_WeaponCanUse, WeaponCanUse);
			}
			DoChat(client, attacker, PunishMsg, PunishMsg, iPunishMsg, false);
		}
	}
	else
	{
		if(attacker > 0 && IsClientInGame(attacker))
		{
			char attackerName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH], PunishMsg[128];

			GetClientName(attacker, attackerName, MAX_NAME_LENGTH);
			//if(IsValidEdict(attacker)) PunishHandler(victim, attacker, punishment);
			//if(attacker != -1) PunishHandler(victim, attacker, punishment);
			if(IsValidEdict(client)) GetClientName(client, victimName, MAX_NAME_LENGTH);

			if ( strcmp(punishment, "warn", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Warned", victimName, attackerName);
			}
			else if ( strcmp(punishment, "slay", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Slayed", victimName, attackerName);

				KillHandler(client, attacker, false);
			}
			else if ( strcmp(punishment, "slap", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Slapped", victimName, attackerName, iSlapDamage);

				SlapPlayer(attacker, iSlapDamage);
			}
			else if ( strcmp(punishment, "burn", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Burnt", victimName, attackerName);

				ServerCommand("sm_burn \"%s\" 10", attackerName);
			}
			else if ( strcmp(punishment, "freeze", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Froze", victimName, attackerName);

				ServerCommand("sm_freeze \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "beacon", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Beaconed", victimName, attackerName);

				ServerCommand("sm_beacon \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "freezebomb", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "FreezeBombed", victimName, attackerName);

				ServerCommand("sm_freezebomb \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "firebomb", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "FireBombed", victimName, attackerName);

				ServerCommand("sm_firebomb \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "timebomb", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "TimeBombed", victimName, attackerName);

				ServerCommand("sm_timebomb \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "drug", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Drugged", victimName, attackerName);

				CreateTimer(fDrugTime, Undrug, attacker, TIMER_FLAG_NO_MAPCHANGE);
				ServerCommand("sm_drug \"%s\"", attackerName);
			}
			else if ( strcmp(punishment, "removecash", false) == 0 )
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "CashRemoved", victimName, iRemoveCash, attackerName);

				int divisor = iRemoveCash / 100;
				int cash = GetEntData(attacker, iMoney_offset) * divisor;
				SetEntData(attacker, iMoney_offset, cash);
			}
			else if(strcmp(punishment, "Chicken", false) == 0)
			{
				Format(PunishMsg, sizeof(PunishMsg), "%t", "Chicken", victimName, attackerName);
				
				SetEntityModel(attacker, sChicken);
				SetEntPropFloat(attacker, Prop_Data, "m_flLaggedMovementValue", fChickenSpeed);
				//PrintToChatAll("Скорость курици: %.2f", fChickenSpeed);
				bKillAttaker[attacker] = true;
				
				if(bDraw)
				{
					SetEntPropEnt(attacker, Prop_Send, "m_hObserverTarget", 0);
					SetEntProp(attacker, Prop_Send, "m_iObserverMode", 1);
					SetEntProp(attacker, Prop_Send, "m_bDrawViewmodel", 0);
					SetEntProp(attacker, Prop_Send, "m_iFOV", 50);
				}
				
				if(bDebag)
				{
					if(bKillAttaker[attacker] == true)
						PrintToChatAll("Класс аттакер установлен на игрока %N", attacker);
					else
						PrintToChatAll("Не удалось установить класс атакер на игрока %N", attacker);
						
					for(int c = 1; c <= MaxClients; c++) if(c == attacker)
						PrintToChatAll("Убийца [%N] | Индекс игрока [%d] | Значение индекса [%d]", attacker, c, bKillAttaker[c]);
				}

				//Разоружаем
				int iSlot, iBomb = -1;
				for(int i; i < 5; i++)
				{
					if(i != -1)
						iSlot = GetPlayerWeaponSlot(attacker, i);
					if(iSlot && IsValidEntity(iSlot) && RemovePlayerItem(attacker, iSlot))
					{
						if((iBomb = GetPlayerWeaponSlot(attacker, 4)) != -1)
							CS_DropWeapon(attacker, iBomb, true, true);
						AcceptEntityInput(iSlot, "Kill");
					}
				}

				RemoveGrenade(attacker);

				SDKHook(attacker, SDKHook_WeaponCanUse, WeaponCanUse);
				
			}
			if(IsValidEdict(client)) DoChat(client, attacker, PunishMsg, PunishMsg, iPunishMsg, false);
		}
	}
}

//Рапрет подёма оружия
public Action WeaponCanUse(int attacker, int weapon)
{
	bHook[attacker] = true;
	if(bKillAttaker[attacker] && weapon != -1)
	{
		char sWeaponName[16];
		GetEntityClassname(weapon, sWeaponName, 16);
		if(strncmp(sWeaponName, "weapon_", 7) == 0)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

//Блокируем E
public Action OnPlayerRunCmd(int attacker, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(bKillAttaker[attacker] && buttons & IN_USE)
	{
		for(int d; d < MAXPLAYERS; d++)
		{
			if(bKillAttaker[d])
			{
				if(bDebag) PrintToChatAll("Проверка на Use Включена");
				buttons &= ~IN_USE;
			}
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action RemoveGrenade(int client)
{
	RemoveGrenades(client, "weapon_hegrenade");
	RemoveGrenades(client, "weapon_smokegrenade");
	RemoveGrenades(client, "weapon_flashbang");
	
	if(Engine_Version != GAME_CSGO)
		return;
	
	RemoveGrenades(client, "weapon_decoy");
	RemoveGrenades(client, "weapon_molotov");
	RemoveGrenades(client, "weapon_incgrenade");
	RemoveGrenades(client, "weapon_tagrenade");
	RemoveGrenades(client, "weapon_frag_grenade");
	RemoveGrenades(client, "weapon_diversion");
	RemoveGrenades(client, "weapon_firebomb");
	RemoveGrenades(client, "weapon_snowball");
	
	RemoveGrenades(client, "weapon_fists");
	RemoveGrenades(client, "weapon_hammer");
	RemoveGrenades(client, "weapon_spanner");
	RemoveGrenades(client, "weapon_axe");
	RemoveGrenades(client, "weapon_taser");
}

void RemoveGrenades(int client, char[] weapon)
{
	int iIndex = -1, owner;
	while ((iIndex = FindEntityByClassname(iIndex, weapon)) >= 0)
	{
		if (!IsValidEdict(iIndex))
			return;
		owner = GetEntPropEnt(iIndex, Prop_Send, "m_hOwner");
		if (owner == client && RemovePlayerItem(client, iIndex))
		AcceptEntityInput(iIndex, "Kill");
	}
	return;
}

/*
	Chat helper method.
*/

public void DoChat(int victim, int attacker, char msg1[128], char msg2[128], int cvar, bool isCount)
{
	if(iLogs && ((iLogs == 1) || ((iLogs == 2) && isCount)))
	{
		char sAttackerSteam[32], sVictimSteam[32];

		if(attacker) GetClientAuthId(attacker, AuthId_Steam2, sAttackerSteam, sizeof(sAttackerSteam));
		if(victim) GetClientAuthId(victim, AuthId_Steam2, sVictimSteam, sizeof(sVictimSteam));

		//LogToFile(sPath, "%s (A: %s V: %s)", msg1, aid, vid);
		//LogToFile(sPath, "%s (A: %s V: %s)", msg1, sAttackerSteam, sVictimSteam);
		LogToFile(sPath, "%t", "Do chat logs", msg1, sAttackerSteam, sVictimSteam);
		//PrintToChatAll("%s (A: %s V: %s)", msg1, sAttackerSteam, sVictimSteam);
	}

	if(cvar == 1)
	{
		if(Engine_Version == GAME_CSGO) CGOPrintToChatAll("%t", "Tag", "Do chat all", msg1);		//CGOPrintToChatAll("\x04[STK]\x01 %s", msg1);
		else CPrintToChatAll("%t", "Tag", "Do chat all", msg1);
	}
	else
	{
		if(cvar > 1 && cvar <= 4)
		{
			for(int a = 1; a <= MaxClients; a++)
			{
				if(IsClientInGame(a))
				{
					if(GetUserAdmin(a) != INVALID_ADMIN_ID)
					{
						if(cvar == 3 || cvar == 4)
						{
							if(Engine_Version == GAME_CSGO) CGOPrintToChat(a, "%t", "Tag", "Do chat admin", msg1);		//CGOPrintToChat(a, "%s %s", "Tag", msg1);
							else CPrintToChat(a, "%t", "Tag", "Do chat admin", msg1);
						}
					}
					else if(a == victim && (cvar == 2 || cvar == 3))
					{
						if(Engine_Version == GAME_CSGO) CGOPrintToChat(victim, "%t", "Tag", "Do chat victim", msg1);		//CGOPrintToChat(victim, "%s %s", "Tag", msg1);
						else CPrintToChat(victim, "%t", "Tag", "Do chat victim", msg1);
					}
					else if(a == attacker && (cvar == 2 || cvar== 3))
					{
						if(Engine_Version == GAME_CSGO) CGOPrintToChat(attacker, "%t", "Tag", "Do chat attacker", msg2);		//CGOPrintToChat(attacker, "%s %s", "Tag", msg2);
						else CPrintToChat(attacker, "%t", "Tag", "Do chat attacker", msg2);
					}
				}
			}
		}
	}
}

/*
	Undrug handler to undrug a player after sm_tk_drugtime
*/

public Action Undrug(Handle timer, any UserID)
{
	int client = GetClientOfUserId(UserID);
	if(client)
		ServerCommand("sm_undrug \"%s\"", client);
	return Plugin_Handled;
}

/*
	Handler to deal punishment to a TKer if he/she was dead when the punishment was to be dealt.
*/

public Action WaitForSpawn(Handle timer, any attacker)
{
	if(attacker > 0 && IsClientInGame(attacker))
	{
		int victim = VictimClient[attacker];
		VictimClient[attacker] = -1;

		if(IsPlayerAlive(attacker))
		{
			char punishment[32];
			strcopy(punishment, 31, PunishmentClient[attacker]);
			PunishmentClient[attacker] = "";
			//if(IsValidEdict(attacker)) PunishHandler(victim, attacker, punishment); 
			//if(attacker != -1) PunishHandler(victim, attacker, punishment);
			if(IsValidEdict(attacker) && attacker != -1) 
			{
				PunishHandler(victim, attacker, punishment);
				
				if(bDebag)
				{
					PrintToChatAll("Убийца[%N] | Наказание[%s]", attacker, punishment);
					PrintToChatAll("Убийца(%N) ЖИВ 2", attacker);
				}
			}
		}
		else
		{
			CreateTimer(5.0, WaitForSpawn, attacker, TIMER_FLAG_NO_MAPCHANGE);
			if(bDebag) PrintToChatAll("Убийца(%N) мёртв, повтор через %f секунд", attacker, 5.0);
		}
	}
	return Plugin_Handled;
}