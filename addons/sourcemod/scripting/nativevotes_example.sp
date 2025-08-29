
#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <nativevotes_rework>


public Plugin myinfo = {
    name        = "[NVR] Example",
    author      = "TouchMe",
    description = "Test",
    version     = "build_0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_nativevotes_rework"
}


public void OnPluginStart() {
    RegAdminCmd("voteyesno", Cmd_TestYesNo, ADMFLAG_VOTE, "Test Yes/No votes");
}

public Action Cmd_TestYesNo(int iClient, int args)
{
    if (!NativeVotes_IsNewVoteAllowed())
    {
        int seconds = NativeVotes_CheckVoteDelay();
        ReplyToCommand(iClient, "Vote is not allowed for %d more seconds", seconds);
        return Plugin_Handled;
    }

    NativeVote nv = new NativeVote(HandlerCustomYesNo, NativeVotesType_Custom_YesNo);

    nv.Initiator = iClient;
    nv.SetDetails("My static details");

    int iTotalPlayers;
    int[] iPlayers = new int[MaxClients];

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        iPlayers[iTotalPlayers++] = iPlayer;
    }

    nv.DisplayVote(iPlayers, iTotalPlayers, 20);

    return Plugin_Handled;
}

public Action HandlerCustomYesNo(NativeVote nv, VoteAction iAction, int iParam1, int iParam2)
{
    switch (iAction)
    {
        case VoteAction_Start: {
            PrintToChatAll("Voting has begun by %N", iParam1);
        }

        case VoteAction_Display:
        {
            char szDisplay[64];
            Format(szDisplay, sizeof(szDisplay), "%N sees this message", iParam1);
            nv.SetDetails(szDisplay);
            return Plugin_Changed;
        }

        case VoteAction_Select:
        {
            PrintToChatAll("Player %N select %s", iParam1, iParam2 == NATIVEVOTES_VOTE_YES ? "yes" : "no");
        }

        case VoteAction_Cancel: nv.DisplayFail();

        case VoteAction_Finish:
        {
            if (iParam1 == NATIVEVOTES_VOTE_NO)
            {
                nv.DisplayFail();
            }
            else
            {
                nv.DisplayPass("Test Yes/No Vote Passed!");
            }
        }

        case VoteAction_End: nv.Close();
    }

    return Plugin_Continue;
}
