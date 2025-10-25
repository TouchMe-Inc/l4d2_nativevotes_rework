#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>

#include "include/nativevotes_rework"


public Plugin myinfo = {
    name        = "NativeVotesRework",
    author      = "Powerlord, TouchMe",
    description = "Voting API to use the game's native vote panels",
    version     = "build_0005",
    url         = "https://github.com/TouchMe-Inc/l4d2_nativevotes_rework"
}


// Kick
#define L4D_VOTE_KICK_START     "#L4D_vote_kick_player"
#define L4D_VOTE_KICK_PASSED    "#L4D_vote_passed_kick_player"

// User vote to restart map.
#define L4D_VOTE_RESTART_START  "#L4D_vote_restart_game"
#define L4D_VOTE_RESTART_PASSED "#L4D_vote_passed_restart_game"

// User vote to change maps.
#define L4D_VOTE_CHANGECAMPAIGN_START "#L4D_vote_mission_change"
#define L4D_VOTE_CHANGECAMPAIGN_PASSED "#L4D_vote_passed_mission_change"
#define L4D_VOTE_CHANGELEVEL_START "#L4D_vote_chapter_change"
#define L4D_VOTE_CHANGELEVEL_PASSED "#L4D_vote_passed_chapter_change"

// User vote to return to lobby.
#define L4D_VOTE_RETURNTOLOBBY_START "#L4D_vote_return_to_lobby"
#define L4D_VOTE_RETURNTOLOBBY_PASSED "#L4D_vote_passed_return_to_lobby"

// User vote to change difficulty.
#define L4D_VOTE_CHANGEDIFFICULTY_START "#L4D_vote_change_difficulty"
#define L4D_VOTE_CHANGEDIFFICULTY_PASSED "#L4D_vote_passed_change_difficulty"

// While not a vote string, it works just as well.
#define L4D_VOTE_CUSTOM          "#L4D_TargetID_Player"

// User vote to change alltalk.
#define L4D2_VOTE_ALLTALK_START  "#L4D_vote_alltalk_change"
#define L4D2_VOTE_ALLTALK_PASSED "#L4D_vote_passed_alltalk_change"
#define L4D2_VOTE_ALLTALK_ENABLE "#L4D_vote_alltalk_enable"
#define L4D2_VOTE_ALLTALK_DISABLE "#L4D_vote_alltalk_disable"

// Vote controller params
#define VCP_VOTES_YES            "m_votesYes"
#define VCP_VOTES_NO             "m_votesNo"
#define VCP_POTENTIAL_VOTES      "m_potentialVotes"
#define VCP_TEAM                 "m_onlyTeamToVote"
#define VCP_ACTIVE_ISSUE         "m_activeIssueIndex"

// Vote controller issue
#define INVALID_ISSUE           -1
#define VALID_ISSUE              0

#define ISSUE_CHANGEDIFFICULTY   0
#define ISSUE_RESTARTGAME        1
#define ISSUE_KICK               2
#define ISSUE_CHANGEMISSION      3
#define ISSUE_RETURNTOLOBBY      4
#define ISSUE_CHANGECHAPTER      5
#define ISSUE_CHANGEALLTALK      6

// Vote info
#define VOTE_DETAILS_LENGTH      128
#define TRANSLATION_LENGTH       192

// Client info
#define VOTE_NOT_VOTING         -2
#define VOTE_PENDING            -1

//
#define ERR_INVALID_HANDLE      "NativeVotes handle %x is invalid"


enum struct VoteInfo
{
    int controller;
    NativeVote hndl;
    Handle timeout;
    int cooldown;
    int votes[MAXPLAYERS + 1];
}

float g_fLastTime = 0.0;

VoteInfo g_tVoteInfo;

ConVar g_cvVoteDelay = null;


/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param late        Whether or not the plugin was loaded "late" (after map load)
 * @param error       Error message buffer in case load failed
 * @param err_max     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    CreateNative("NativeVotes_Create", Native_Create);
    CreateNative("NativeVotes_Close", Native_Close);
    CreateNative("NativeVotes_SetDetails", Native_SetDetails);
    CreateNative("NativeVotes_GetDetails", Native_GetDetails);
    CreateNative("NativeVotes_SetTarget", Native_SetTarget);
    CreateNative("NativeVotes_GetTarget", Native_GetTarget);
    CreateNative("NativeVotes_DisplayVote", Native_DisplayVote);
    CreateNative("NativeVotes_DisplayPass", Native_DisplayPass);
    CreateNative("NativeVotes_DisplayFail", Native_DisplayFail);
    CreateNative("NativeVotes_GetType", Native_GetType);
    CreateNative("NativeVotes_SetTeam", Native_SetTeam);
    CreateNative("NativeVotes_GetTeam", Native_GetTeam);
    CreateNative("NativeVotes_SetInitiator", Native_SetInitiator);
    CreateNative("NativeVotes_GetInitiator", Native_GetInitiator);

    CreateNative("NativeVotes_IsVoteTypeSupported", Native_IsVoteTypeSupported);
    CreateNative("NativeVotes_Cancel", Native_Cancel);
    CreateNative("NativeVotes_IsVoteInProgress", Native_IsVoteInProgress);
    CreateNative("NativeVotes_CheckVoteDelay", Native_CheckVoteDelay);
    CreateNative("NativeVotes_IsClientInVotePool", Native_IsClientInVotePool);

    // Transitional syntax support
    CreateNative("NativeVote.NativeVote", Native_Create);
    CreateNative("NativeVote.Close", Native_Close);
    CreateNative("NativeVote.SetDetails", Native_SetDetails);
    CreateNative("NativeVote.GetDetails", Native_GetDetails);
    CreateNative("NativeVote.SetTarget", Native_SetTarget);
    CreateNative("NativeVote.GetTarget", Native_GetTarget);
    CreateNative("NativeVote.DisplayVote", Native_DisplayVote);
    CreateNative("NativeVote.DisplayPass", Native_DisplayPass);
    CreateNative("NativeVote.DisplayFail", Native_DisplayFail);
    CreateNative("NativeVote.VoteType.get", Native_GetType);
    CreateNative("NativeVote.Team.set", Native_SetTeam);
    CreateNative("NativeVote.Team.get", Native_GetTeam);
    CreateNative("NativeVote.Initiator.set", Native_SetInitiator);
    CreateNative("NativeVote.Initiator.get", Native_GetInitiator);
    CreateNative("NativeVote.Target.set", Native_SetTarget);
    CreateNative("NativeVote.Target.get", Native_GetTarget);

    RegPluginLibrary("nativevotes_rework");

    return APLRes_Success;
}

// native bool NativeVotes_IsVoteTypeSupported(NativeVotesType hVoteType);
public int Native_IsVoteTypeSupported(Handle hPlugin, int iParams)
{
    NativeVotesType hVoteType = GetNativeCell(1);

    return IsValidVoteType(hVoteType);
}

// native NativeVote NativeVotes_Create(NativeVotes_Handler hVoteHandler, NativeVotesType hVoteType);
public int Native_Create(Handle hPlugin, int iParams)
{
    Function handler = GetNativeFunction(1);

    if (handler == INVALID_FUNCTION) {
        ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes_Handler is invalid");
    }

    NativeVotesType hVoteType = GetNativeCell(2);

    NativeVote hVote;
    if (IsValidVoteType(hVoteType)) {
        hVote = Data_CreateVote(hVoteType);
    } else {
        return view_as<int>(INVALID_HANDLE);
    }

    Handle hForward = Data_GetHandler(hVote);

    AddToForward(hForward, hPlugin, handler);

    return view_as<int>(hVote);
}

// native void NativeVotes_Close(Handle hVote);
public int Native_Close(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);

    if (hVote == null) {
        return 0;
    }

    if (g_tVoteInfo.hndl == hVote) {
        FinishVote();
    }

    // Do the datatype-specific close operations
    Handle handler = Data_GetHandler(hVote);
    if (handler != null) {
        delete handler;
    }

    delete hVote;

    return 0;
}

// native bool NativeVotes_DisplayVote(Handle hVote, int[] iClients, int iCountClients, int iShowTime);
public int Native_DisplayVote(Handle hPlugin, int iParams)
{
    if (IsVoteAlreadyInProgress()) {
        ThrowNativeError(SP_ERROR_NATIVE, "A vote is already in progress");
    }

    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    int iTotalPlayers = GetNativeCell(3);
    int[] iPlayers = new int[iTotalPlayers];
    GetNativeArray(2, iPlayers, iTotalPlayers);

    int iShowTime = GetNativeCell(4);

    return DisplayVote(hVote, iPlayers, iTotalPlayers, iShowTime);

}

// native void NativeVotes_GetDetails(Handle hVote, char[] buffer, int maxlength);
public int Native_GetDetails(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    int iLength = GetNativeCell(3);

    char[] szDetails = new char[iLength];

    Data_GetDetails(hVote, szDetails, iLength);

    SetNativeString(2, szDetails, iLength);

    return 0;
}

// native void NativeVotes_SetDetails(Handle hVote, const char[] sFmt, any ...);
public int Native_SetDetails(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    char szDetails[VOTE_DETAILS_LENGTH];

    FormatNativeString(0, 2, 3, sizeof(szDetails), _, szDetails);

    hVote.SetString("details", szDetails);

    return 0;
}

// native bool NativeVotes_IsVoteInProgress();
public int Native_IsVoteInProgress(Handle hPlugin, int iParams) {
    return IsVoteAlreadyInProgress() || IsVoteControllerActive() || (GetEngineTime() - g_fLastTime <= 2.0);
}

// native NativeVotes_Cancel();
public int Native_Cancel(Handle hPlugin, int iParams)
{
    if (!IsVoteAlreadyInProgress()) {
        ThrowNativeError(SP_ERROR_NATIVE, "No vote is in progress");
    }

    AbortVote();

    return 0;
}

// native int NativeVotes_CheckVoteDelay();
public int Native_CheckVoteDelay(Handle hPlugin, int iParams)
{
    int iCurrentTime = GetTime();
    if (g_tVoteInfo.cooldown <= iCurrentTime) {
        return 0;
    }

    return (g_tVoteInfo.cooldown - iCurrentTime);
}

// native bool NativeVotes_IsClientInVotePool(int iClient);
public int Native_IsClientInVotePool(Handle hPlugin, int iParams)
{
    int iClient = GetNativeCell(1);

    if (!IsValidClient(iClient)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    if (!IsVoteAlreadyInProgress()) {
        ThrowNativeError(SP_ERROR_NATIVE, "No vote is in progress");
    }

    return !IsClientNotVoting(iClient);
}

// native NativeVotesType NativeVotes_GetType(Handle hVote);
public int Native_GetType(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    return view_as<int>(Data_GetType(hVote));
}

// native int NativeVotes_GetTeam(Handle hVote);
public int Native_GetTeam(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    return Data_GetTeam(hVote);
}

// native void NativeVotes_SetTeam(Handle hVote, int iTeam);
public int Native_SetTeam(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    int iTeam = GetNativeCell(2);

    hVote.SetNum("team", iTeam);

    return 0;
}

// native void NativeVotes_SetTeam(Handle hVote, int iTeam);
public int Native_GetInitiator(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    return hVote.GetNum("initiator", NATIVEVOTES_SERVER_INDEX);
}

// native void NativeVotes_SetInitiator(Handle hVote, int iClient);
public int Native_SetInitiator(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    int iInitiator = GetNativeCell(2);

    hVote.SetNum("initiator", iInitiator);

    return 0;
}

// native void NativeVotes_DisplayPass(Handle hVote, const char[] sFmt="", any ...);
public int Native_DisplayPass(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    NativeVotesType hVoteType = Data_GetType(hVote);

    char szTranslation[TRANSLATION_LENGTH];
    VoteTypeToPassed(hVoteType, szTranslation, sizeof szTranslation);

    char szDetails[VOTE_DETAILS_LENGTH];
    hVote.GetDetails(szDetails, sizeof szDetails);
    bool bDetailsChanged = VoteTypeToDetails(hVoteType, szDetails, sizeof szDetails);

    int iTeam = Data_GetTeam(hVote);

    char szDetailsBuffer[VOTE_DETAILS_LENGTH];
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient) || IsClientNotVoting(iClient)) {
            continue;
        }

        if (!bDetailsChanged)
        {
            SetGlobalTransTarget(iClient);
            FormatNativeString(0, 2, 3, sizeof szDetailsBuffer, _, szDetailsBuffer);

            if (szDetailsBuffer[0] != '\0')
            {
                strcopy(szDetails, sizeof szDetails, szDetailsBuffer);
            } else {
                SendVotePass(iClient, iTeam);
                continue;
            }
        }

        // Fix details '%s1'
        SendVotePass(iClient, iTeam, szTranslation, szDetails);
    }

    return 0;
}

// native void NativeVotes_DisplayFail(Handle hVote);
public int Native_DisplayFail(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    int iTeam = Data_GetTeam(hVote);

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient) || IsClientNotVoting(iClient)) {
            continue;
        }

        SendVoteFail(iClient, iTeam);
    }

    return 0;
}

// native int NativeVotes_GetTarget(Handle hVote);
public int Native_GetTarget(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null)
    {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
        return 0;
    }

    int iTarget = Data_GetTarget(hVote);

    if (!iTarget) {
        return -1;
    }

    return GetClientOfUserId(iTarget);
}

// native void NativeVotes_SetTarget(Handle hVote, int iClient);
public int Native_SetTarget(Handle hPlugin, int iParams)
{
    NativeVote hVote = GetNativeCell(1);
    if (hVote == null) {
        ThrowNativeError(SP_ERROR_NATIVE, ERR_INVALID_HANDLE, hVote);
    }

    int iClient = GetNativeCell(2);

    if (!IsValidClient(iClient) || !IsClientConnected(iClient)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    hVote.SetNum("target", GetClientUserId(iClient));

    return 0;
}

/**
 * Called when the plugin is fully initialized and all known external references are resolved.
 */
public void OnPluginStart()
{
    HookConVarChange(
        g_cvVoteDelay = CreateConVar(
            .name = "nativevotes_vote_delay",
            .defaultValue = "25",
            .description = "Sets the recommended time in between public votes",
            .hasMin = true,
            .min = 0.0
        ),
        CvChange_VoteDelay
    );
    AddCommandListener(Listener_Vote, "vote");
}

public void CvChange_VoteDelay(ConVar convar, const char[] sOldDelay, const char[] sNewDelay)
{
    /* See if the new vote delay isn't something we need to account for */
    if (convar.IntValue <= 0)
    {
        g_tVoteInfo.cooldown = 0;
        return;
    }

    if (g_tVoteInfo.cooldown > 0)
    {
        /* Subtract the original value, then add the new one. */
        g_tVoteInfo.cooldown -= StringToInt(sOldDelay);
        g_tVoteInfo.cooldown += StringToInt(sNewDelay);
    }
}

public Action Listener_Vote(int iClient, const char[] command, int argc)
{
    if (!IsVoteAlreadyInProgress() || !iClient || !IsClientVoting(iClient)) {
        return Plugin_Continue;
    }

    char szOption[32];
    GetCmdArgString(szOption, sizeof(szOption));

    int iItem = ParseVoteOption(szOption);

    if (iItem == NATIVEVOTES_VOTE_INVALID) {
        return Plugin_Handled;
    }

    SendClientSelectedItem(iClient, (g_tVoteInfo.votes[iClient] = iItem));

    int iVotesYes = GetVoteControllerParam(VCP_VOTES_YES);
    int iVotesNo = GetVoteControllerParam(VCP_VOTES_NO);
    int iVotesPotential = GetVoteControllerParam(VCP_POTENTIAL_VOTES);

    switch (iItem)
    {
        case NATIVEVOTES_VOTE_YES: SetVoteControllerParam(VCP_VOTES_YES, ++iVotesYes);
        case NATIVEVOTES_VOTE_NO: SetVoteControllerParam(VCP_VOTES_NO, ++iVotesNo);
    }

    FireEventVoteChanged(iVotesYes, iVotesNo, iVotesPotential);

    RunVoteAction(g_tVoteInfo.hndl, VoteAction_Select, iClient, iItem);

    if (iVotesYes + iVotesNo >= iVotesPotential) {
        FinishVote();
    }

    return Plugin_Handled;
}

int ParseVoteOption(const char[] szOption)
{
    if (StrEqual(szOption, "Yes", false)) {
        return NATIVEVOTES_VOTE_YES;
    } else if (StrEqual(szOption, "No", false)) {
        return NATIVEVOTES_VOTE_NO;
    }

    return NATIVEVOTES_VOTE_INVALID;
}

public void OnClientDisconnect(int iClient)
{
    if (!IsVoteAlreadyInProgress() || IsClientNotVoting(iClient)) {
        return;
    }

    g_tVoteInfo.votes[iClient] = VOTE_NOT_VOTING;
}

public void OnMapStart()
{
    if ((g_tVoteInfo.controller = FindVoteController()) == INVALID_ENT_REFERENCE) {
        SetFailState("VoteController not found!");
    }

    g_tVoteInfo.hndl = null;
    g_tVoteInfo.timeout = null;
}

public void OnMapEnd()
{
    if (IsVoteAlreadyInProgress()) {
        AbortVote();
    }
}

bool DisplayVote(NativeVote hVote, int[] iClients, int iCountClients, int iShowTime)
{
    g_tVoteInfo.hndl = hVote;
    InitTimeout(iShowTime);
    UpdateVoteDelay(iShowTime);

    /* Mark all clients as not voting */
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        g_tVoteInfo.votes[iClient] = VOTE_NOT_VOTING;
    }

    int iPotentialVotes = 0;

    for (int i = 0; i < iCountClients; ++i)
    {
        if (!IsValidClient(iClients[i]) || !IsClientInGame(iClients[i]) || IsFakeClient(iClients[i])) {
            continue;
        }

        g_tVoteInfo.votes[iClients[i]] = VOTE_PENDING;
        iPotentialVotes++;
    }

    if (iPotentialVotes <= 0)
    {
        FinishVote();
        return false;
    }

    // Team
    int iTeam = Data_GetTeam(hVote);

    // Prepare vote controller
    SetupVoteController(0, 0, iPotentialVotes, iTeam, VALID_ISSUE);

    NativeVotesType hVoteType = Data_GetType(hVote);

    // Translation
    char szTranslation[TRANSLATION_LENGTH];
    VoteTypeToDisplay(hVoteType, szTranslation, sizeof(szTranslation));

    // Details
    char szDetails[VOTE_DETAILS_LENGTH];
    if (!VoteTypeToDetails(hVoteType, szDetails, sizeof szDetails)) {
        Data_GetDetails(hVote, szDetails, sizeof szDetails);
    }

    if (hVoteType == NativeVotesType_Kick && szDetails[0] == '\0')
    {
        int iTarget = GetClientOfUserId(Data_GetTarget(hVote));

        if (IsValidClient(iTarget) && IsClientConnected(iTarget)) {
            GetClientName(iTarget, szDetails, sizeof szDetails);
        } else {
            strcopy(szDetails, sizeof szDetails, "...");
        }
    }

    // Initiator
    int iInitiator = hVote.GetNum("initiator", NATIVEVOTES_SERVER_INDEX);
    char szInitiatorName[MAX_NAME_LENGTH];
    if (iInitiator != NATIVEVOTES_SERVER_INDEX && IsValidClient(iInitiator) && IsClientInGame(iInitiator)) {
        GetClientName(iInitiator, szInitiatorName, sizeof szInitiatorName);
    }

    RunVoteAction(hVote, VoteAction_Start, iInitiator);

    // Display vote
    bool bCanChangeDetails = (hVoteType == NativeVotesType_Custom_YesNo);
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (IsClientNotVoting(iClient)) {
            continue;
        }

        if (bCanChangeDetails && RunVoteAction(hVote, VoteAction_Display, iClient) == Plugin_Changed) {
            Data_GetDetails(hVote, szDetails, sizeof szDetails);
        }

        SendClientVoteStart(iClient, iTeam, szTranslation, szDetails, iInitiator, szInitiatorName);
    }

    // Kick targets automatically vote no if they're in the pool
    if (hVoteType == NativeVotesType_Kick)
    {
        int iTarget = GetClientOfUserId(Data_GetTarget(hVote));

        if (IsValidClient(iTarget) && IsClientConnected(iTarget) && IsClientVoting(iInitiator)) {
            FakeClientCommand(iTarget, "Vote No");
        }
    }

    if (IsValidClient(iInitiator) && IsClientConnected(iInitiator) && IsClientVoting(iInitiator)) {
        FakeClientCommand(iInitiator, "Vote Yes");
    }

    return true;
}

Action RunVoteAction(NativeVote hVote, VoteAction action, int param1 = 0, int param2 = 0)
{
    Action aReturn = Plugin_Continue;

    Handle handler = CloneHandle(Data_GetHandler(hVote));

    Call_StartForward(handler);
    Call_PushCell(hVote);
    Call_PushCell(action);
    Call_PushCell(param1);
    Call_PushCell(param2);
    Call_Finish(aReturn);

    delete handler;
    return aReturn;
}

void FinishVote()
{
    DestroyTimeout();
    UpdateVoteDelay();

    NativeVote hVote = g_tVoteInfo.hndl;
    g_tVoteInfo.hndl = null;

    int iVotesYes = GetVoteControllerParam(VCP_VOTES_YES);
    int iVotesNo = GetVoteControllerParam(VCP_VOTES_NO);
    int iResult = (iVotesYes > iVotesNo) ? NATIVEVOTES_VOTE_YES : NATIVEVOTES_VOTE_NO;

    RunVoteAction(hVote, VoteAction_Finish, iResult);
    RunVoteAction(hVote, VoteAction_End, VoteEnd_VotingDone);

    ResetVoteController();

    g_fLastTime = GetEngineTime();
}

void AbortVote()
{
    DestroyTimeout();
    UpdateVoteDelay();

    NativeVote hVote = g_tVoteInfo.hndl;
    g_tVoteInfo.hndl = null;

    RunVoteAction(hVote, VoteAction_Cancel);
    RunVoteAction(hVote, VoteAction_End, VoteEnd_VotingCancelled);

    ResetVoteController();
}

bool IsVoteAlreadyInProgress() {
    return (g_tVoteInfo.hndl != null);
}

bool IsClientNotVoting(int iClient) {
    return (g_tVoteInfo.votes[iClient] == VOTE_NOT_VOTING);
}

bool IsClientVoting(int iClient) {
    return (g_tVoteInfo.votes[iClient] == VOTE_PENDING);
}

void UpdateVoteDelay(int iOffset = 0)
{
    int iVoteDelay = g_cvVoteDelay.IntValue;

    g_tVoteInfo.cooldown = (iVoteDelay <= 0) ? 0 : (GetTime() + iVoteDelay + iOffset);
}

void InitTimeout(int iShowTime) {
    g_tVoteInfo.timeout = CreateTimer(float(iShowTime), Timer_Timeout, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Timeout(Handle hTimer)
{
    g_tVoteInfo.timeout = null;

    FinishVote();

    return Plugin_Stop;
}

void DestroyTimeout()
{
    if (g_tVoteInfo.timeout != null)
    {
        delete g_tVoteInfo.timeout;
        g_tVoteInfo.timeout = null;
    }
}


// user message

void SendClientSelectedItem(int iClient, int iItem)
{
    BfWrite bfVoteRegistered = UserMessageToBfWrite(StartMessageOne("VoteRegistered", iClient, USERMSG_RELIABLE));
    bfVoteRegistered.WriteByte(iItem);
    EndMessage();
}

void SendClientVoteStart(int iClient, int iTeam, const char[] szTranslation, const char[] szDetails,  int iInitiator, const char[] szInitiatorName)
{
    BfWrite hVoteStart = UserMessageToBfWrite(StartMessageOne("VoteStart", iClient, USERMSG_RELIABLE));
    hVoteStart.WriteByte(iTeam);
    hVoteStart.WriteByte(iInitiator);
    hVoteStart.WriteString(szTranslation);
    hVoteStart.WriteString(szDetails);
    hVoteStart.WriteString(szInitiatorName);
    EndMessage();
}

void SendVotePass(int iClient, int iTeam, const char[] szTranslation = "", const char[] szDetails = "")
{
    BfWrite bfVotePass = UserMessageToBfWrite(StartMessageOne("VotePass", iClient, USERMSG_RELIABLE));
    bfVotePass.WriteByte(iTeam);
    bfVotePass.WriteString(szTranslation);
    bfVotePass.WriteString(szDetails);
    EndMessage();
}

void SendVoteFail(int iClient, int iTeam)
{
    BfWrite bfVoteFailed = UserMessageToBfWrite(StartMessageOne("VoteFail", iClient, USERMSG_RELIABLE));
    bfVoteFailed.WriteByte(iTeam);
    EndMessage();
}


// controller

int FindVoteController()
{
    int entity = FindEntityByClassname(-1, "vote_controller");

    if (entity != -1) {
        return EntIndexToEntRef(entity);
    }

    return INVALID_ENT_REFERENCE;
}

void ResetVoteController() {
    SetupVoteController(0, 0, 0, NATIVEVOTES_ALL_TEAMS, INVALID_ISSUE);
}

void SetupVoteController(int iVotesYes, int iVotesNo, int iVotesPotential, int iTeam, int iIssue)
{
    SetVoteControllerParam(VCP_VOTES_YES, iVotesYes);
    SetVoteControllerParam(VCP_VOTES_NO, iVotesNo);
    SetVoteControllerParam(VCP_POTENTIAL_VOTES, iVotesPotential);
    SetVoteControllerParam(VCP_TEAM, iTeam);
    SetVoteControllerParam(VCP_ACTIVE_ISSUE, iIssue);
}

void SetVoteControllerParam(const char[] szParam, int iValue) {
    SetEntProp(g_tVoteInfo.controller, Prop_Send, szParam, iValue);
}

int GetVoteControllerParam(const char[] szParam) {
    return GetEntProp(g_tVoteInfo.controller, Prop_Send, szParam);
}

bool IsVoteControllerActive() {
    return GetVoteControllerParam(VCP_ACTIVE_ISSUE) > INVALID_ISSUE;
}


// event

void FireEventVoteChanged(int iVotesYess, int iVotesNo, int iVotesPotential)
{
    Event eVoteChange = CreateEvent("vote_changed");
    eVoteChange.SetInt("yesVotes", iVotesYess);
    eVoteChange.SetInt("noVotes", iVotesNo);
    eVoteChange.SetInt("potentialVotes", iVotesPotential);
    eVoteChange.Fire();
}


// data-keyvalues

NativeVote Data_CreateVote(NativeVotesType voteType)
{
    Handle handler = CreateForward(ET_Single, Param_Cell, Param_Cell, Param_Cell, Param_Cell);

    KeyValues hVote = CreateKeyValues("NativeVote");

    hVote.SetNum("handler_callback", view_as<int>(handler));
    hVote.SetNum("vote_type", view_as<int>(voteType));
    hVote.SetString("details", "");
    hVote.SetNum("target", -1);
    hVote.SetNum("initiator", NATIVEVOTES_SERVER_INDEX);
    hVote.SetNum("team", NATIVEVOTES_ALL_TEAMS);

    return view_as<NativeVote>(hVote);
}

int Data_GetTeam(KeyValues hVote) {
    return hVote.GetNum("team", NATIVEVOTES_ALL_TEAMS);
}

void Data_GetDetails(KeyValues hVote, char[] szDetails, int iLength) {
    hVote.GetString("details", szDetails, iLength);
}

int Data_GetTarget(KeyValues hVote) {
    return hVote.GetNum("target");
}

NativeVotesType Data_GetType(KeyValues hVote) {
    return view_as<NativeVotesType>(hVote.GetNum("vote_type", view_as<int>(NativeVotesType_Custom_YesNo)));
}

Handle Data_GetHandler(KeyValues hVote)
{
    if (hVote == null) {
        return null;
    }

    return view_as<Handle>(hVote.GetNum("handler_callback"));
}

// votes type

void VoteTypeToDisplay(NativeVotesType hVoteType, char[] szTranslation, int iLength)
{
    if (hVoteType < NativeVotesType_None || hVoteType > NativeVotesType_ChgLevel) {
        hVoteType = NativeVotesType_Custom_YesNo;
    }

    static char szVoteDisplay[][] =
    {
        "", // NativeVotesType_None
        L4D_VOTE_CUSTOM, // NativeVotesType_Custom_YesNo (пример)
        L4D_VOTE_CHANGECAMPAIGN_START,
        L4D_VOTE_CHANGEDIFFICULTY_START,
        L4D_VOTE_RETURNTOLOBBY_START,
        L4D2_VOTE_ALLTALK_START, // AlltalkOn
        L4D2_VOTE_ALLTALK_START, // AlltalkOff
        L4D_VOTE_RESTART_START,
        L4D_VOTE_KICK_START,
        L4D_VOTE_CHANGELEVEL_START
    };

    strcopy(szTranslation, iLength, szVoteDisplay[hVoteType]);
}

void VoteTypeToPassed(NativeVotesType hVoteType, char[] szTranslation, int iLength)
{
    if (hVoteType < NativeVotesType_None || hVoteType > NativeVotesType_ChgLevel) {
        hVoteType = NativeVotesType_Custom_YesNo;
    }

    static char szVotePassed[][] =
    {
        "", // None
        L4D_VOTE_CUSTOM, // Custom_YesNo
        L4D_VOTE_CHANGECAMPAIGN_PASSED,
        L4D_VOTE_CHANGEDIFFICULTY_PASSED,
        L4D_VOTE_RETURNTOLOBBY_PASSED,
        L4D2_VOTE_ALLTALK_PASSED, // AlltalkOn
        L4D2_VOTE_ALLTALK_PASSED, // AlltalkOff
        L4D_VOTE_RESTART_PASSED,
        L4D_VOTE_KICK_PASSED,
        L4D_VOTE_CHANGELEVEL_PASSED
    };

    strcopy(szTranslation, iLength, szVotePassed[hVoteType]);
}

bool VoteTypeToDetails(NativeVotesType type, char[] szDetails, int iLength)
{
    switch (type)
    {
        case NativeVotesType_AlltalkOn: {
            strcopy(szDetails, iLength, L4D2_VOTE_ALLTALK_ENABLE);
            return true;
        }

        case NativeVotesType_AlltalkOff: {
            strcopy(szDetails, iLength, L4D2_VOTE_ALLTALK_DISABLE);
            return true;
        }
    }

    return false;
}

bool IsValidVoteType(NativeVotesType type)
{
    switch (type)
    {
        case NativeVotesType_Custom_YesNo, NativeVotesType_ChgCampaign, NativeVotesType_ChgDifficulty,
        NativeVotesType_ReturnToLobby, NativeVotesType_AlltalkOn, NativeVotesType_AlltalkOff,
        NativeVotesType_Restart, NativeVotesType_Kick, NativeVotesType_ChgLevel:
        {
            return true;
        }
    }

    return false;
}

bool IsValidClient(int iClient) {
    return (iClient > 0 && iClient <= MaxClients);
}
