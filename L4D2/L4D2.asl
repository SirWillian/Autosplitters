state("left4dead2", "")
{

}

startup
{
    settings.Add("AutomaticGameTime", true, "Automatically set splits to Game Time");
    settings.Add("campaignSplit", true, "Split after each campaign");
    settings.Add("chapterSplit", true, "Split inbetween chapters", "campaignSplit");
    settings.Add("scoreboardVSgameLoading", true, "Split chapters on Scoreboard vs Game Loading", "chapterSplit");
    settings.SetToolTip("scoreboardVSgameLoading", "Toggle between splitting chapters when the scoreboard shows up (checked) and when the loading between chapters begins (unchecked).");
    
    settings.Add("splitOnce", false, "Split only when the run ends");
    settings.SetToolTip("splitOnce","These checkboxes only matter if you didn't check \"Split after each campaign\". They indicate what category you are running.");
    settings.Add("ILs", false, "Individual Levels", "splitOnce");
    settings.SetToolTip("ILs","To select the category you are running, make sure you check all the checkboxes above it.");
    settings.Add("mainCampaigns", false, "Main Campaigns","ILs");
    settings.Add("allCampaignsLegacy", false, "All Campaigns Legacy","mainCampaigns");
    settings.Add("allCampaigns", false, "All Campaigns (14)","allCampaignsLegacy");
    
    settings.Add("cutscenelessStart", false, "Autostart on cutsceneless campaigns (SEE TOOLTIP)");
    settings.SetToolTip("cutscenelessStart", "Uses a different method to detect when to start the timer. Don't use this unless you are running a campaign like Drop Dead Gorges, otherwise you may run into issues.");
    
    /*
    settings.Add("debug", false, "See internal values through DebugView");
    settings.SetToolTip("debug", "See the values that the splitter is using to make actions. Requires DebugView. This setting may cause additional lag, so only have this checked if needed.");

    settings.CurrentDefaultParent = "debug";
    settings.Add("debugStart", false, "See values referring to autostart");
    settings.Add("debugSplit", false, "See values referring to autosplit");
    */

    refreshRate = 30;
    vars.campaignsLastMaps = new List<string>() {"c7m3_port", "c5m5_bridge", "c6m3_port", "c13m4_cutthroatcreek"};
}

init
{
#region SIGSCANNING FUNCTIONS
    print("Game process found");
    
    print("Game main module size is " + modules.First().ModuleMemorySize.ToString());

    Func<string, ProcessModuleWow64Safe> GetModule = (moduleName) =>
    {
        return modules.FirstOrDefault(x => x.ModuleName.ToLower() == moduleName);
    };

    Func<uint, string> GetByteStringU = (o) =>
    {
        return BitConverter.ToString(BitConverter.GetBytes(o)).Replace("-", " ");
    };

    Func<string, string> GetByteStringS = (o) =>
    {
        string output = "";
        foreach (char i in o)
            output += ((byte)i).ToString("x2") + " ";

        return output;
    };

    Func<string, SignatureScanner> GetSignatureScanner = (moduleName) =>
    {
        ProcessModuleWow64Safe proc = GetModule(moduleName);
        Thread.Sleep(1000);
        if (proc == null)
            throw new Exception(moduleName + " isn't loaded!");
        print("Module " + moduleName + " found at 0x" + proc.BaseAddress.ToString("X"));
        return new SignatureScanner(game, proc.BaseAddress, proc.ModuleMemorySize);
    };

    Func<SignatureScanner, uint, bool> IsWithinModule = (scanner, ptr) =>
    {
        uint nPtr = (uint)ptr;
        uint nStart = (uint)scanner.Address;
        return ((nPtr > nStart) && (nPtr < nStart + scanner.Size));
    };

    Func<SignatureScanner, uint, bool> IsLocWithinModule = (scanner, ptr) =>
    {
        uint nPtr = (uint)ptr;
        return ((nPtr % 4 == 0) && IsWithinModule(scanner, ptr));
    };

    Action<IntPtr, string> ReportPointer = (ptr, name) => 
    {
        if (ptr == IntPtr.Zero)
            print(name + " ptr was NOT found!!");
        else
            print(name + " ptr was found at 0x" + ptr.ToString("X"));
    };

    // throw an exception if given pointer is null
    Action<IntPtr, string> ShortOut = (ptr, name) =>
    {
        if (ptr == IntPtr.Zero)
        {
            Thread.Sleep(1000);
            throw new Exception(name + " ptr was NOT found!!");
        }
    };

    Func<IntPtr, int, int, IntPtr> ReadRelativeReference = (ptr, trgOperandOffset, totalSize) =>
    {
        int offset = memory.ReadValue<int>(ptr + trgOperandOffset, 4);
        if (offset == 0)
            return IntPtr.Zero; 
        IntPtr actualPtr = IntPtr.Add((ptr + totalSize), offset);
        return actualPtr;
    };
#endregion

#region SIGSCANNING
    Stopwatch sw = new Stopwatch();
    sw.Start();

    var clientScanner = GetSignatureScanner("client.dll");
    var engineScanner = GetSignatureScanner("engine.dll");

    //------ WHATSLOADING SCANNING ------
    // get reference to "vidmemstats.txt" string
    IntPtr tmp = engineScanner.Scan(new SigScanTarget(GetByteStringS("vidmemstats.txt")));
    IntPtr whatsLoadingPtr = IntPtr.Zero;
    tmp = engineScanner.Scan(new SigScanTarget(1, "68" + GetByteStringU((uint)tmp)));
    ShortOut(tmp, "vid mem stats ptr");
    // find the next immediate PUSH instruction
    for (int i = 0; i < 0x100; i++)
    {
        if (game.ReadValue<byte>(tmp + i) == 0x68 && IsLocWithinModule(engineScanner, game.ReadValue<uint>(tmp + i + 1)))
        {
            whatsLoadingPtr = game.ReadPointer(tmp + i + 1);
            break;
        }
    }

    //------ GAMELOADING SCANNING ------
    // add more as need be
    IntPtr gameLoadingPtr = engineScanner.Scan(new SigScanTarget(2, "38 1D ?? ?? ?? ?? 0F 85 ?? ?? ?? ?? 56 53"));
    gameLoadingPtr = game.ReadPointer(gameLoadingPtr);

    //------ CUTSCENEPLAYING SCANNING ------
    // may want to sigscan this offset...
    const int cutsceneOff1 = 0x44;
    IntPtr cutscenePlayingPtr = IntPtr.Zero;
    // search for "C_GameInstructor" string reference
    tmp = clientScanner.Scan(new SigScanTarget(GetByteStringS("C_GameInstructor") + "00"));
    tmp = clientScanner.Scan(new SigScanTarget(1, "68" + GetByteStringU((uint)tmp)));
    ShortOut(tmp, "C_GameInstructor string ref");
    // backtrack until we found the base pointer
    for (int i = 0; i < 0x100; i++)
    {
        if (game.ReadValue<byte>(tmp - i) == 0xBE && game.ReadValue<byte>(tmp - i + 5) == 0x83 &&  game.ReadValue<byte>(tmp - i + 7) == 0xFF)
        {
            cutscenePlayingPtr = game.ReadPointer(tmp - i + 1);
            if (IsLocWithinModule(clientScanner, (uint)cutscenePlayingPtr))
                break;
            cutscenePlayingPtr = IntPtr.Zero;
        }
    }
    ShortOut(cutscenePlayingPtr, "cutscenePlayingPtr");
    cutscenePlayingPtr = cutscenePlayingPtr - 0x10 + cutsceneOff1;

    var tmpScanner = new SignatureScanner(game, clientScanner.Address, 10);

    //------ SCOREBOARDLOADING SCANNING ------
    // find "$localcontrastenable" string reference
    IntPtr scoreboardLoadPtr = IntPtr.Zero;
    tmp = clientScanner.Scan(new SigScanTarget(GetByteStringS("$localcontrastenable")));
    tmp = clientScanner.Scan(new SigScanTarget("68" + GetByteStringU((uint)tmp)));
    ShortOut(tmp, "$localcontrastenable string reference");
    // scan backwards to target mov instruction
    for (int i = -1; i > -0x1000; i--)
    {
        byte[] bytes = game.ReadBytes(tmp + i, 10);
        if (bytes[0] == 0x80 && bytes[6] == 0x00 && bytes[7] == 0x0F && bytes[8] == 0x85)
        {
            var candidatePtr = game.ReadValue<uint>(tmp + i + 2);
            
            if (!IsWithinModule(clientScanner, candidatePtr))
                continue;

            scoreboardLoadPtr = (IntPtr)candidatePtr;
        }
    }
    if (scoreboardLoadPtr == IntPtr.Zero)
    {
        // maybe sigscan this...
        const int scoreboardLoad2Off = 0x125;
        // get "cl_reloadpostprocessparams" string reference
        tmp = clientScanner.Scan(new SigScanTarget(GetByteStringS("cl_reloadpostprocessparams")));
        tmp = game.ReadPointer(clientScanner.Scan(new SigScanTarget(1, "68 ?? ?? ?? ?? 68 " + GetByteStringU((uint)tmp))));
        tmpScanner = new SignatureScanner(game, tmp, 0x400);
        scoreboardLoadPtr = game.ReadPointer(tmpScanner.Scan(new SigScanTarget(2, "81 ?? ?? ?? ?? ?? e8"))) + scoreboardLoad2Off;
    }

    //------ HASCONTROL SCANNING ------
    // maybe sigscan this...
    const int hasControlOff = 0x2C;
    IntPtr hasControlPtr = IntPtr.Zero;
    IntPtr hasControlFunc = IntPtr.Zero;
    // get "weapon_muzzle_smoke" string address
    IntPtr muzzleSmokeStrPtr = clientScanner.Scan(new SigScanTarget(GetByteStringS("weapon_muzzle_smoke")));
    ShortOut(muzzleSmokeStrPtr, "muzzleSmokeStrPtr");
    // get "clientterrorgun.cpp" string reference
    IntPtr terrorGunStrPtr = clientScanner.Scan(new SigScanTarget(GetByteStringS("\\clientterrorgun.cpp\0")));
    ShortOut(terrorGunStrPtr, "terrorGunStrPtr");
    // try and find a result from sigscanning every byte until we get a result. expensive but this is the most reliable way to pull out a string reference
    while ((tmp = clientScanner.Scan(new SigScanTarget("68" + GetByteStringU((uint)terrorGunStrPtr)))) == IntPtr.Zero)
        terrorGunStrPtr = terrorGunStrPtr - 1;
    // init a tmp scanner for later
    tmpScanner = new SignatureScanner(game, clientScanner.Address, clientScanner.Size);
hasControlScanAgain:
    ShortOut(tmp, "terrorGunStrPtr ref");
    for (int i = 0; ; i++)
    {
        // assume there are at least 3 0xCC bytes at the tail of the function, if we've hit that, break the loop
        if (game.ReadBytes(tmp + i, 3).All(x => x == 0xCC))
            break;

        // there are 2 candidate functions that references terror gun string, if we hit a "weapon_muzzle_smoke" reference before we meet our desired function call
        // then mark this as false positive and try scanning for a reference again
        if (game.ReadValue<byte>(tmp + i) == 0x68 && Math.Abs(game.ReadValue<uint>(tmp + i + 1) - (uint)muzzleSmokeStrPtr) < 2)
        {
            tmpScanner = new SignatureScanner(game, tmp + 0x20, (int)(tmpScanner.Address + tmpScanner.Size) - (int)(tmp + 0x20));
            tmp = tmpScanner.Scan(new SigScanTarget("68" + GetByteStringU((uint)terrorGunStrPtr)));
            goto hasControlScanAgain;
        }

        // find our desired function call
        byte[] bytes = game.ReadBytes(tmp + i, 3);
        if (bytes.SequenceEqual(new byte[] {0x6A, 0xFF, 0xE8}))
        {
            hasControlFunc = ReadRelativeReference(tmp + i + 2, 1, 5);
            break;
        }
    }
    if (hasControlFunc != IntPtr.Zero)
    {
        tmpScanner = new SignatureScanner(game, hasControlFunc, 0x500);
        hasControlPtr = game.ReadPointer(tmpScanner.Scan(new SigScanTarget(3, "8D 04"))) + hasControlOff;
    }

    //------ FINALETRIGGER SCANNING ------
    IntPtr finaleTriggerPtr = IntPtr.Zero;
    // find "l4d_WeaponStatData" string reference
    IntPtr statDataStrRef = clientScanner.Scan(new SigScanTarget(GetByteStringS("l4d_WeaponStatData")));
    statDataStrRef = clientScanner.Scan(new SigScanTarget("68 " + GetByteStringU((uint)statDataStrRef)));
    ShortOut(statDataStrRef, "statDataStrRef");
    // find "l4d_stats_nogameplaycheck" string address
    IntPtr gameplayCheckStrPtr = clientScanner.Scan(new SigScanTarget(GetByteStringS("l4d_stats_nogameplaycheck")));
    tmpScanner = new SignatureScanner(game, clientScanner.Address, clientScanner.Size);
finaleTriggerScanAgain:
    tmp = tmpScanner.Scan(new SigScanTarget("68 " + GetByteStringU((uint)gameplayCheckStrPtr) + "B9"));
    ShortOut(tmp, "finale trigger 1 scan region");
    for (int i = 0; i < 0x400; i++)
    {
        // assume there are at least 3 0xCC bytes at the tail of the function, if we've hit that, break the loop
        if (game.ReadBytes(tmp + i, 3).All(x => x == 0xCC))
            break;

        // trace until seeing a possible instruction pattern
        byte[] bytes = game.ReadBytes(tmp + i, 6);
        if (bytes[0] == 0xB9 && bytes[5] == 0xE8)
            // check if call goes to the function which contains the statDataStrRef
            if ((uint)statDataStrRef - (uint)ReadRelativeReference(tmp + i + 5, 1, 5) < 0x200)
            {
                finaleTriggerPtr = game.ReadPointer(tmp + i + 1) + 0x128;
                goto end;
            }
    }
    // if we haven't found anything, then the string reference might be wrong
    tmpScanner = new SignatureScanner(game, tmp + 1, (int)(tmpScanner.Address + tmpScanner.Size) - (int)(tmp + 0x20));
    goto finaleTriggerScanAgain;
end:;

    ReportPointer(whatsLoadingPtr, "whats loading");
    ReportPointer(gameLoadingPtr, "game loading");
    ReportPointer(cutscenePlayingPtr, "cutscene playing");
    ReportPointer(scoreboardLoadPtr, "scoreboard loading");
    ReportPointer(hasControlPtr, "has control func");
    ReportPointer(finaleTriggerPtr, "finale trigger");
    
    sw.Stop();
    print("Sigscanning done in " + sw.ElapsedMilliseconds / 1000f + " seconds");

#endregion

#region WATCHERS
    vars.whatsLoading = new StringWatcher(whatsLoadingPtr, 256);
    vars.gameLoading = new MemoryWatcher<bool>(gameLoadingPtr);
    vars.cutscenePlaying = new MemoryWatcher<bool>(cutscenePlayingPtr);
    vars.scoreboardLoad = new MemoryWatcher<bool>(scoreboardLoadPtr);
    vars.hasControl = new MemoryWatcher<bool>(hasControlPtr);
    vars.finaleTrigger = new MemoryWatcher<bool>(finaleTriggerPtr);

    vars.mwList = new MemoryWatcherList()
    {
        vars.whatsLoading,
        vars.gameLoading,
        vars.cutscenePlaying,
        vars.scoreboardLoad,
        vars.hasControl,
        vars.finaleTrigger,
    };
#endregion
    
    vars.campaignsCompleted = 0;
    if (settings["allCampaigns"])
        vars.totalCampaignNumber = 14;
    else if (settings["allCampaignsLegacy"])
        vars.totalCampaignNumber = 13;
    else if (settings["mainCampaigns"])
        vars.totalCampaignNumber = 5;
    else if (settings["ILs"])
        vars.totalCampaignNumber = 1;
    else
        vars.totalCampaignNumber = -1;
    
    if (settings["splitOnce"] && !settings["campaignSplit"])
        print("Total campaign number is " + vars.totalCampaignNumber.ToString());
    
    vars.startRun = false;
    vars.cutsceneStart = DateTime.MaxValue;
    vars.lastSplit = null;
}

start
{
    if (settings["AutomaticGameTime"])
        timer.CurrentTimingMethod = TimingMethod.GameTime;

    if (settings["cutscenelessStart"])
    {
        if(vars.gameLoading.Old && !vars.startRun)
        {
            vars.startRun=true;
            print("(cutsceneless) Autostart triggered");
        }
        if (!vars.gameLoading.Current && vars.hasControl.Current && vars.startRun)
        {
            vars.startRun=false;
            print("(cutsceneless) Run autostarted");
            vars.lastSplit=null;
            return true;
        }
        return false;
    }
    else
    {
        // Once we have control after a cutscene plays for at least 1 second, we're ready to start.
        if (vars.hasControl.Current && !vars.gameLoading.Current)
        {
            if (DateTime.Now - vars.cutsceneStart > TimeSpan.FromSeconds(1))
            {
                print("CUSTSCENE RAN FOR " + (DateTime.Now - vars.cutsceneStart));
                vars.cutsceneStart = DateTime.MaxValue;
                vars.lastSplit=null;
                return true;
            }
            else if (vars.cutsceneStart != DateTime.MaxValue)
            {
                // Sometimes the game sets 'vars.hasControl.Current' to 'false', even when you have control. We need to detect those cases in order to reset the cutscene timer.
                print("FALSE POSITIVE!");
                vars.cutsceneStart = DateTime.MaxValue;
            }
        }
        
        // If we're not loading, and the player does not have control, a cutscene must be playing. Mark the time.
        if (!vars.hasControl.Old && !vars.hasControl.Current && !vars.gameLoading.Current && vars.cutsceneStart == DateTime.MaxValue)
        {
            print("CUSTSCENE START!");
            vars.cutsceneStart = DateTime.Now;
        }
        
        return false;
    }
        
    /*if (vars.gameLoading.Old && vars.cutscenePlaying.Current && !vars.startRun)
    {
        vars.startRun=true;
        print("Autostart triggered");
    }
    
    else if (!vars.gameLoading.Current && vars.cutscenePlaying.Old && !vars.cutscenePlaying.Current && vars.startRun)
    {
        vars.startRun=false;
        print("Run autostarted");
        vars.lastSplit=null;
        return true;
    }*/
}

split
{
    //Split on finales
    if (settings["campaignSplit"])
    {
        if (vars.finaleTrigger.Current && !vars.finaleTrigger.Old)
        {
            if (vars.whatsLoading.Current == vars.lastSplit)
            {
                print("Ceased double split attempt");
                return false;
            }
            print("Split on finale");
            vars.lastSplit = vars.whatsLoading.Current;
            return true;
        }
        else if (vars.cutscenePlaying.Current && !vars.cutscenePlaying.Old && vars.campaignsLastMaps.Contains(vars.whatsLoading.Current))
        {
            if (vars.whatsLoading.Current == vars.lastSplit)
            {
                print("Ceased double split attempt");
                return false;
            }
            print("Split on THE BEST CAMPAIGN EVER");
            vars.lastSplit = vars.whatsLoading.Current;
            return true;
        }
        //Split inbetween chapters
        if (settings["chapterSplit"])
        {
            if (settings["scoreboardVSgameLoading"])
            {
                if (!vars.finaleTrigger.Current && !vars.scoreboardLoad.Old && vars.scoreboardLoad.Current)
                {
                    print("Split at the end of a chapter at the scoreboard");
                    vars.lastSplit = vars.whatsLoading.Current; // should help prevent finale split failure if user's timer doesn't start automatically
                    return true;
                }
            }
            else
            {
                if (!vars.finaleTrigger.Current && !vars.gameLoading.Old && vars.gameLoading.Current && vars.scoreboardLoad.Current)
                {
                    print("Split at the end of a chapter when it began to load");
                    vars.lastSplit = vars.whatsLoading.Current; // should help prevent finale split failure if user's timer doesn't start automatically
                    return true;
                }
            }
        }
    }
    
    
    //Split only when the run ends
    if (settings["splitOnce"])
    {
        if (vars.finaleTrigger.Current && !vars.finaleTrigger.Old)
        {
            if (vars.whatsLoading.Current == vars.lastSplit)
            {
                print("Ceased double split attempt");
                return false;
            }
            vars.lastSplit = vars.whatsLoading.Current;
            vars.campaignsCompleted++;
            print("Campaign count is now " + vars.campaignsCompleted.ToString());
        }
        else if (vars.cutscenePlaying.Current && !vars.cutscenePlaying.Old && !vars.campaignsLastMaps.Contains(vars.whatsLoading))
        {
            if (vars.whatsLoading.Current == vars.lastSplit)
            {
                print("Ceased double split attempt");
                return false;
            }
            vars.lastSplit = vars.whatsLoading.Current;
            vars.campaignsCompleted++;
            print("Finished THE BEST CAMPAIGN EVER and the campaign sum is now " + vars.campaignsCompleted.ToString());
        }
        if (vars.campaignsCompleted == vars.totalCampaignNumber)
        {
            print("Ended the run.");
            return true;
        }
    }
}

isLoading
{
    return vars.gameLoading.Current;
}

update
{
    vars.mwList.UpdateAll(game);

    /*
    if (settings["debug"])
    {
        if (settings["debugStart"]) 
        {
            print("Autostart:\n vars.gameLoading.Current = " + vars.gameLoading.Current.ToString() +
            "\n vars.cutscenePlaying.Current = " + vars.cutscenePlaying.Current.ToString() +
            "\n current.cutscenePlaying2 = " + current.cutscenePlaying2.ToString() +
            "\n vars.hasControl.Current = " + vars.hasControl.Current.ToString() +
            "\n vars.startRun = " + vars.startRun.ToString());
        }
        if (settings["debugSplit"])
        {
            print("Autosplit:\n vars.finaleTrigger.Current = " + vars.finaleTrigger.Current.ToString() +
            "\n current.finaleTrigger2 = " + current.finaleTrigger2.ToString() +
            "\n vars.cutscenePlaying.Current = " + vars.cutscenePlaying.Current.ToString() +
            "\n current.cutscenePlaying2 = " + current.cutscenePlaying2.ToString() +
            "\n vars.whatsLoading.Current = " + vars.whatsLoading.Current);
            if (settings["chapterSplit"])
            {
                print(" vars.scoreboardLoad.Current = " + vars.scoreboardLoad.Current.ToString() +
                "\n current.scoreboardLoad2 = " + current.scoreboardLoad2.ToString() +
                "\n vars.gameLoading.Current = " + vars.gameLoading.Current.ToString());
            }
            if (settings["splitOnce"])
            {
                print(" vars.campaignsCompleted = " + vars.campaignsCompleted.ToString() +
                "\n vars.totalCampaignNumber = " + vars.totalCampaignNumber.ToString());
            }
        }
    }
    */
}

exit
{
    print("Game closed.");
}
