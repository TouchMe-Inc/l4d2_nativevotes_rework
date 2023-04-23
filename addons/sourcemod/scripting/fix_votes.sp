#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <nativevotes_rework>
#include <colors>


public Plugin myinfo =
{
    name        = "FixVotes",
    author      = "TouchMe",
    description = "N/a",
    version     = "build0002",
    url         = "https://github.com/TouchMe-Inc/l4d2_nativevotes_rework"
}

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
    LoadTranslations("fix_votes.phrases");

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
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "VOTE_COULDOWN", iClient, NativeVotes_CheckVoteDelay());
        } else {
            CPrintToChat(iClient, "%T%T", "TAG", iClient, "VOTE_IN_PROGRESS", iClient);
        }

        return Plugin_Handled;
    }

    char sVoteType[32];
    char sVoteArgument[32];

    GetCmdArg(1, sVoteType, sizeof(sVoteType));
    GetCmdArg(2, sVoteArgument, sizeof(sVoteArgument));

    if (strcmp(sVoteType, "Kick", false) == 0)
    {
        int iTarget = GetClientOfUserId(StringToInt(sVoteArgument));

        if (!iTarget
        || iTarget == iClient /*< Block self-kick */
        || IsFakeClient(iTarget) /*< Block bot kick */
        || GetClientTeam(iTarget) != GetClientTeam(iClient)) { /*< Block kickvotes not aimed at players in the same team */
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}
