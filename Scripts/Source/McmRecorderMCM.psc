scriptName McmRecorderMCM extends SKI_ConfigBase

McmRecorder Recorder

int oid_Record
int oid_Stop
int[] oids_Recordings
string[] recordings
bool isPlayingRecording
string currentlyPlayingRecordingName
bool openRunOrPreviewStepsPrompt

bool IsSkyrimVR

event OnConfigInit()
    ModName = "MCM Recorder"
    Recorder = (self as Quest) as McmRecorder
    IsSkyrimVR = Game.GetModByName("SkyrimVR.esm") != 255
endEvent

event OnPageReset(string page)
    if McmRecorder.IsRecording()
        oid_Stop = AddTextOption("Currently Recording!", "STOP RECORDING", OPTION_FLAG_NONE)
        AddTextOption(McmRecorder.GetCurrentRecordingName(), "", OPTION_FLAG_DISABLED)
    else
        if IsSkyrimVR
            oid_Record = AddTextOption("Click to begin recording:", "BEGIN RECORDING", OPTION_FLAG_NONE)
        else
            oid_Record = AddInputOption("Click to begin recording:", "BEGIN RECORDING", OPTION_FLAG_NONE)
        endIf
        AddEmptyOption()
    endIf
    ListRecordings()
endEvent

function ListRecordings()
    recordings = McmRecorder.GetRecordingNames()
    if recordings.Length
        AddEmptyOption()
        AddEmptyOption()
        AddTextOption("Choose a recording to play:", "", OPTION_FLAG_NONE)
        AddEmptyOption()
        oids_Recordings = Utility.CreateIntArray(recordings.Length)
        int i = 0
        while i < recordings.Length
            string recordingName = recordings[i]
            oids_Recordings[i] = AddTextOption("", recordingName, OPTION_FLAG_NONE)
            int recordingInfo = McmRecorder.GetRecordingInfo(recordingName)
            string authorText = ""
            if JMap.getStr(recordingInfo, "author")
                authorText = "by " + JMap.getStr(recordingInfo, "author")
            endIf
            AddTextOption(authorText, JMap.getStr(recordingInfo, "version"), OPTION_FLAG_DISABLED)
            i += 1
        endWhile
    endIf
endFunction

event OnOptionSelect(int optionId)
    if IsSkyrimVR && optionId == oid_Record ; SkyrimVR
        if ! McmRecorder.IsRecording()
            McmRecorder.BeginRecording(GetRandomRecordingName())
            ForcePageReset()
        else
            McmRecorder.StopRecording() ; For SkyrimVR these OIDs are the same
            ForcePageReset()
        endIf
    elseIf optionId == oid_Stop
        McmRecorder.StopRecording()
        ForcePageReset()
    elseIf oids_Recordings.Find(optionId) > -1
        int recordingIndex = oids_Recordings.Find(optionId)
        string recordingName = recordings[recordingIndex]
        PromptToRunRecordingOrPreviewSteps(recordingName)
    endIf
endEvent

event OnOptionInputAccept(int optionId, string text)
    McmRecorder.BeginRecording(text)
    ForcePageReset()
    Debug.MessageBox("Recording Started!\n\nYou can now interact with MCM menus and all interactions will be recorded.\n\nWhen you are finished, return to this page to stop the recording (or quit the game).\n\nRecordings are saved in simple text files inside of Data\\McmRecorder\\ which you can edit to tweak your recording without completely re-recording it :)")
endEvent

event OnOptionInputOpen(int optionId)
    if optionId == oid_Record
        SetInputDialogStartText(GetRandomRecordingName())
    endIf
endEvent

string function GetRandomRecordingName()
    string[] currentTimeParts = StringUtil.Split(Utility.GetCurrentRealTime(), ".")
    return "Recording_" + currentTimeParts[0] + "_" + currentTimeParts[1]
endFunction

event OnMenuOpen(string menuName)
    if menuName == "Journal Menu"
        if isPlayingRecording
            Debug.MessageBox("MCM Recorder " + currentlyPlayingRecordingName + " playback in progress. Opening MCM menu not recommended!")            
        endIf
    endIf
endEvent

function PromptToRunRecordingOrPreviewSteps(string recordingName)
    int info = McmRecorder.GetRecordingInfo(recordingName)
    string[] stepNames = McmRecorder.GetRecordingStepNames(recordingName)

    string recordingDescription = recordingName
    if JMap.getStr(info, "version")
        recordingDescription += " (" + JMap.getStr(info, "version") + ")"
    endIf
    if JMap.getStr(info, "author")
        recordingDescription += "\n~ by " + JMap.getStr(info, "author") + " ~"
    endIf
    recordingDescription += "\nSteps: " + stepNames.Length

    if ShowMessage("Close the MCM to play the recording:\n\n" + recordingDescription + "\n\nYou can also preview all recording steps or play individual steps.\n\nWould you like to continue?", "No", "Yes", "Cancel")

        Debug.MessageBox("Close the MCM now to play the recording")

        UnregisterForMenu("Journal Menu")  
        RegisterForMenu("Journal Menu") ; Track when the menu opens so we can show a mesasge if a recording is playing

        string text = recordingName
        if JMap.getStr(info, "version")
            text += " (" + JMap.getStr(info, "version") + ")"
        endIf
        if JMap.getStr(info, "author")
            text += "\n~ by " + JMap.getStr(info, "author") + " ~"
        endIf
        text += "\n\n" + stepNames.Length + " steps\n"
        int i = 0
        while i < stepNames.Length && i < 11
            if i == 10
                text += "\n- ..."
            else
                text += "\n- " + StringUtil.Substring(stepNames[i], 0, StringUtil.Find(stepNames[i], ".json"))
            endIf
            i += 1
        endWhile
        text += "\n\nWould you like to play this recording?"

        string response = Recorder.GetUserResponseToRunRecording(text)

        if response == "Play All Steps"
            currentlyPlayingRecordingName = recordingName
            isPlayingRecording = true
            McmRecorder.PlayRecording(recordingName)
            currentlyPlayingRecordingName = ""
            isPlayingRecording = false
        elseIf response == "View Steps"
            ShowStepSelectionUI(recordingName, stepNames)
        endIf
    endIf
endFunction

function ShowStepSelectionUI(string recordingName, string[] stepNames)
    UIListMenu menu = UIExtensions.GetMenu("UIListMenu") as UIListMenu
    menu.AddEntryItem("[" + recordingName + "]")
    menu.AddEntryItem(" ")

    int i = 0
    while i < stepNames.Length
        string stepName = stepNames[i]
        menu.AddEntryItem(stepName)
        i += 1
    endWhile

    menu.OpenMenu()

    int selection = menu.GetResultInt()

    if selection < 2 ; Go Back
        ; TODO open the previous prompt! This isn't working...
        ; PromptToRunRecordingOrPreviewSteps(recordingName)
    else
        int stepIndex = selection - 2 ; Subtract the top 3 entry items
        string stepName = stepNames[stepIndex]
        McmRecorder.PlayStep(recordingName, stepName)
        Debug.MessageBox("MCM recording " + recordingName + " step " + StringUtil.Substring(stepName, 0, StringUtil.Find(stepName, ".json")) + " has finished playing.")
    endIf
endFunction
