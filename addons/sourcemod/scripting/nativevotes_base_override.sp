#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <nativevotes_rework>
#include <left4dhooks>
#include <colors>


public Plugin myinfo =
{
    name        = "[NVR] BaseOverride",
    author      = "TouchMe",
    description = "N/a",
    version     = "build0004",
    url         = "https://github.com/TouchMe-Inc/l4d2_nativevotes_rework"
}


#define TEAM_SPECTATOR 1

#define VOTE_SHOWTIME 15

#define NativeVotesType_AlltalkAuto -1


enum VoteAccessType
{
    VAT_ReturnToLobby,
    VAT_RestartGame,
    VAT_ChangeDifficulty,
    VAT_ChangeMission,
    VAT_ChangeChapter,
    VAT_ChangeAllTalk,
    VAT_KickPlayer,

    VAT_Count
};

char g_szAccessFlag[VAT_Count][] = {
    "returntolobby_flag",
    "restartgame_flag",
    "changedifficulty_flag",
    "changemission_flag",
    "changechapter_flag",
    "changealltalk_flag",
    "kick_flag"
};

char g_szAccessCvarDescs[VAT_Count][] = {
    "Access flags required to initiate a \"Return to Lobby\" vote via ESC menu.",
    "Access flags required to initiate a \"Restart Chapter/Campaign\" vote via ESC menu.",
    "Access flags required to initiate a \"Change Difficulty\" vote via ESC menu.",
    "Access flags required to initiate a \"Start New Campaign\" vote via ESC menu.",
    "Access flags required to initiate a \"Change Chapter\" vote via ESC menu.",
    "Access flags required to initiate a \"Change All Talk\" vote via ESC menu.",
    "Access flags required to initiate a \"Kick Player\" vote via ESC menu."
};

ConVar g_cvAlltalk = null;
ConVar g_cvVoteAccessFlag[VAT_Count];
ConVar g_cvSpectatorIgnore = null;

StringMap g_smVoteType = null;

/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("nativevotes_base_override.phrases");

    g_smVoteType = new StringMap();
    FillVoteType(g_smVoteType);

    char szCvarName[64];
    for (int i = 0; i < view_as<int>(VAT_Count); i++)
    {
        FormatEx(szCvarName, sizeof szCvarName, "sm_nvr_%s", g_szAccessFlag[i]);
        g_cvVoteAccessFlag[i] = CreateConVar(szCvarName, "", g_szAccessCvarDescs[i]);
    }

    g_cvSpectatorIgnore = CreateConVar("sm_nvr_spectator_ignore", "1");

    g_cvAlltalk = FindConVar("sv_alltalk");

    AddCommandListener(Listener_CallVote, "callvote");
}

public Action Listener_CallVote(int iClient, const char[] command, int argc)
{
    if (!iClient || !IsClientInGame(iClient)) {
        return Plugin_Handled;
    }

    if (!NativeVotes_IsNewVoteAllowed())
    {
        if (NativeVotes_CheckVoteDelay() > 0) {
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "VOTE_COOLDOWN", iClient, NativeVotes_CheckVoteDelay());
        } else {
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "VOTE_IN_PROGRESS", iClient);
        }

        return Plugin_Handled;
    }

    char szVoteType[32];
    char szVoteArgument[32];

    GetCmdArg(1, szVoteType, sizeof szVoteType);
    GetCmdArg(2, szVoteArgument, sizeof szVoteArgument);

    StringToLower(szVoteType, szVoteType, sizeof szVoteType);

    NativeVotesType nvt;
    if (!g_smVoteType.GetValue(szVoteType, nvt)) {
        return Plugin_Continue;
    }

    int iClientTeam = GetClientTeam(iClient);

    if (g_cvSpectatorIgnore.BoolValue && iClientTeam == TEAM_SPECTATOR)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "SPECTATOR_IGNORE", iClient);
        return Plugin_Handled;
    }

    if (IsVoteAlltalk(nvt)) {
        nvt = g_cvAlltalk.BoolValue ? NativeVotesType_AlltalkOff : NativeVotesType_AlltalkOn;
    }

    if (!HasAccess(iClient, nvt))
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "VOTE_ACCESS_DENY", iClient);
        return Plugin_Handled;
    }

    if (nvt != NativeVotesType_Kick) {
        return Plugin_Continue;
    }

    int iTarget = GetClientOfUserId(StringToInt(szVoteArgument));

    if (!iTarget
    || iTarget == iClient /*< Block self-kick */
    || IsFakeClient(iTarget) /*< Block bot kick */
    || GetClientTeam(iTarget) != iClientTeam /*< Block kickvotes not aimed at players in the same team */
    ) {
        return Plugin_Handled;
    }

    AdminId ClientId = GetUserAdmin(iClient);
    AdminId TargetId = GetUserAdmin(iTarget);

    if (TargetId != INVALID_ADMIN_ID && !CanAdminTarget(ClientId, TargetId))
    {
        CPrintToChat(iTarget, "%T%T", "TAG", iTarget, "VOTE_KICK_ADMIN", iTarget, iClient);
        return Plugin_Handled;
    }

    NativeVote nv = new NativeVote(HandleVoteKick, NativeVotesType_Kick);
    nv.Initiator = iClient;
    nv.Target = iTarget;
    nv.Team = iClientTeam;

    int iTotalPlayers;
    int[] iPlayers = new int[MaxClients];

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        if (nv.Team != GetClientTeam(iPlayer)) {
            continue;
        }

        iPlayers[iTotalPlayers++] = iPlayer;
    }

    nv.DisplayVote(iPlayers, iTotalPlayers, VOTE_SHOWTIME);

    return Plugin_Handled;
}

bool HasAccess(int iClient, NativeVotesType nvt)
{
    VoteAccessType vat = GetAccessTypeForVote(nvt);

    char szFlag[16];
    g_cvVoteAccessFlag[vat].GetString(szFlag, sizeof szFlag);

    if (szFlag[0] == '\0') {
        return true;
    }

    return CheckCommandAccess(iClient, g_szAccessFlag[vat], ReadFlagString(szFlag));
}

public Action HandleVoteKick(NativeVote nv, VoteAction va, int iParam1, int iParam2)
{
    switch (va)
    {
        case VoteAction_Finish:
        {
            if (iParam1 == NATIVEVOTES_VOTE_NO)
            {
                nv.DisplayFail();
                return Plugin_Continue;
            }

            nv.DisplayPass();
            if (nv.Target > 0) {
                Kick(nv.Target);
            }
        }

        case VoteAction_Cancel: nv.DisplayFail();

        case VoteAction_End: nv.Close();
    }

    return Plugin_Continue;
}

bool IsVoteAlltalk(NativeVotesType nvt) {
    return (view_as<int>(nvt) == NativeVotesType_AlltalkAuto);
}

void FillVoteType(StringMap smVoteType)
{
    smVoteType.SetValue("changemission",    NativeVotesType_ChgCampaign);
    smVoteType.SetValue("changedifficulty", NativeVotesType_ChgDifficulty);
    smVoteType.SetValue("returntolobby",    NativeVotesType_ReturnToLobby);
    smVoteType.SetValue("changealltalk",    NativeVotesType_AlltalkAuto);
    smVoteType.SetValue("restartgame",      NativeVotesType_Restart);
    smVoteType.SetValue("kick",             NativeVotesType_Kick);
    smVoteType.SetValue("changechapter",    NativeVotesType_ChgLevel);
}

VoteAccessType GetAccessTypeForVote(NativeVotesType type)
{
    switch (type)
    {
        case NativeVotesType_ChgCampaign: return VAT_ChangeMission;
        case NativeVotesType_ChgDifficulty: return VAT_ChangeDifficulty;
        case NativeVotesType_ReturnToLobby: return VAT_ReturnToLobby;
        case NativeVotesType_AlltalkOn, NativeVotesType_AlltalkOff: return VAT_ChangeAllTalk;
        case NativeVotesType_Restart: return VAT_RestartGame;
        case NativeVotesType_Kick: return VAT_KickPlayer;
        case NativeVotesType_ChgLevel: return VAT_ChangeChapter;
    }

    return VAT_Count;
}

void Kick(int iClient)
{
    char szReason[128];
    FormatEx(szReason, sizeof szReason, "%T", "KICK_REASON", iClient);

    char szAuthId[MAX_AUTHID_LENGTH];
    if (GetClientAuthId(iClient, AuthId_Engine, szAuthId, sizeof szAuthId)
        && BanIdentity(szAuthId, 1, BANFLAG_AUTHID, szReason))
    {
        KickClient(iClient, "%s", szReason);
    }
    else
    {
        // Kick before addip, as BanClient does, so the client sees our message.
        KickClientEx(iClient, "%s", szReason);

        char szClientIp[32];
        GetClientIP(iClient, szClientIp, sizeof szClientIp);

        if (szClientIp[0] != '\0') {
            BanIdentity(szClientIp, 1, BANFLAG_IP, szReason);
        }
    }
}

void StringToLower(const char[] input, char[] output, int maxlen)
{
    int i = 0;
    while (input[i] != '\0' && i < maxlen - 1)
    {
        output[i] = CharToLower(input[i]);
        i++;
    }
    output[i] = '\0';
}
