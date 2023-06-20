state("left4dead2", "")
{

}

startup
{
    settings.Add("AutomaticGameTime", true, "Automatically set splits to Game Time");
    settings.Add("campaignSplit", true, "Split after each campaign");
    settings.Add("burhac", false, "Split at the end of intro cutscenes", "campaignSplit");
    settings.SetToolTip("burhac", "WORKS ONLY FOR VALVE CAMPAIGNS - Split upon taking control after a cutscene (useful for determining IL time during a fullgame run)");
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
    vars.campaignsFirstMaps = new List<string>() {
        "c1m1_hotel", 
        "c2m1_highway",
        "c3m1_plankcountry",
        "c4m1_milltown_a",
        "c5m1_waterfront",
        "c6m1_riverbank",
        "c7m1_docks",
        "c8m1_apartment",
        "c9m1_alleys",
        "c10m1_caves",
        "c11m1_greenhouse",
        "c12m1_hilltop",
        "c13m1_alpinecreek",
        "c14m1_junkyard"
    };
    vars.delayedSplitTimer = new Stopwatch();
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
    IntPtr whatsLoadingPtr = IntPtr.Zero;
    IntPtr gameLoadingPtr = IntPtr.Zero;
    IntPtr cutscenePlayingPtr = IntPtr.Zero;
    IntPtr scoreboardLoadPtr = IntPtr.Zero;
    IntPtr hasControlPtr = IntPtr.Zero;
    IntPtr finaleTriggerPtr = IntPtr.Zero;
    IntPtr svCheatsPtr = IntPtr.Zero;
    Stopwatch sw = new Stopwatch();
    sw.Start();
    // check for known versions
    ProcessModuleWow64Safe engine = GetModule("engine.dll");
    ProcessModuleWow64Safe client = GetModule("client.dll");
    if (engine == null || client == null) {
        Thread.Sleep(250);
        throw new Exception("engine.dll and/or client.dll isn't loaded yet!"); }
    /* I like how this autosplitter really has gone full circle lmao
     * There's a chance I have made a mistake copying/pasting the known versions - and this is also probably violating several laws of Good Programming Practices. */
    string engineHash;
    using (var md5 = System.Security.Cryptography.MD5.Create())
    using (var s = File.Open(engine.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
    engineHash = md5.ComputeHash(s).Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
    string clientHash;
    using (var md5 = System.Security.Cryptography.MD5.Create())
    using (var s = File.Open(client.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
    clientHash = md5.ComputeHash(s).Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
    switch (engineHash) {
        case "6CBADAA9132AD6138F3D50920BB9ECFE":
            print("using 2000 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x3C9988;
            gameLoadingPtr = engine.BaseAddress + 0x5CC89C;
            break;
        case "F79518A744FE34538726AAC4A9E43593":
            print("using 2012 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x3CD988;
            gameLoadingPtr = engine.BaseAddress + 0x5D091C;
            break;
        case "6BD61059254B425464507486F096D209":
            print("using 2027 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x3CF988;
            gameLoadingPtr = engine.BaseAddress + 0x5D291C;
            break;
        case "9B767FB9EC1AA2C35401F1A7310B0943":
            print("using 2045 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x3D2A00;
            gameLoadingPtr = engine.BaseAddress + 0x5DE494;
            break;
        case "C7BA3CF5AC8722BCA7CBCA0BFB4BCB5B":
            print("using 2075 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x3CF630;
            gameLoadingPtr = engine.BaseAddress + 0x5DA8CC;
            break;
        case "074A3EF53F97661C724C5FD5FE7F33D8":
            print("using 2091 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x3CF630;
            gameLoadingPtr = engine.BaseAddress + 0x5E19D4;
            break;
        case "7899154C8A5263F8919A8E272E1C65AD":
            print("using 2147 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x42F240;
            gameLoadingPtr = engine.BaseAddress + 0x46C54C;
            break;
        case "D6DCB5F35F8CA379E1649AE5E5BD0B52":
            print("using 2203 engine offsets");
            whatsLoadingPtr = engine.BaseAddress + 0x435240;
            gameLoadingPtr = engine.BaseAddress + 0x47264C;
            break;
    }
    switch (clientHash) {
        case "B23B95981DE30C91C8C9C3E3FD7F3E84":
            print("using 2000 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x66CEEC;
            scoreboardLoadPtr = client.BaseAddress + 0x6DB58D;
            hasControlPtr = client.BaseAddress + 0x68FBD4;
            finaleTriggerPtr = client.BaseAddress + 0x6ED414;
            svCheatsPtr = client.BaseAddress + 0x6DB040;
            break;
        case "474DB57CBCDC9819AA36FBFA55CCFBF5":
            print("using 2012 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x67647C;
            scoreboardLoadPtr = client.BaseAddress + 0x6E4C85;
            hasControlPtr = client.BaseAddress + 0x699164;
            finaleTriggerPtr = client.BaseAddress + 0x6F6B14;
            svCheatsPtr = client.BaseAddress + 0x6E4738;
            break;
        case "263E9AE9ABA9C751A14663DF432EE9EA":
            print("using 2027 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x676584;
            scoreboardLoadPtr = client.BaseAddress + 0x6E4D6D;
            hasControlPtr = client.BaseAddress + 0x699264;
            finaleTriggerPtr = client.BaseAddress + 0x6F6BF4;
            svCheatsPtr = client.BaseAddress + 0x6E4820;
            break;
        case "281AE29C235AACDEC83EE7471175D390":
            print("using 2045 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x686F7C;
            scoreboardLoadPtr = client.BaseAddress + 0x6F57BD;
            hasControlPtr = client.BaseAddress + 0x6A9C64;
            finaleTriggerPtr = client.BaseAddress + 0x707824;
            svCheatsPtr = client.BaseAddress + 0x6F5270;
            break;
        case "352E7987A4D778EEA082D2CCB8967EEB":
            print("using 2075 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x688E14;
            scoreboardLoadPtr = client.BaseAddress + 0x6F761D;
            hasControlPtr = client.BaseAddress + 0x6ABAC4;
            finaleTriggerPtr = client.BaseAddress + 0x709634;
            svCheatsPtr = client.BaseAddress + 0x6F70D0;
            break;
        case "9A88102D7D7D7D55A2DCBF67406378F7":
            print("using 2091 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x688E64;
            scoreboardLoadPtr = client.BaseAddress + 0x6F7685;
            hasControlPtr = client.BaseAddress + 0x6ABB24;
            finaleTriggerPtr = client.BaseAddress + 0x7096AC;
            svCheatsPtr = client.BaseAddress + 0x6F7138;
            break;
        case "D75DD50CBB1A8B9F6106B7B38A5293F7":
            print("using 2147 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x702C64;
            scoreboardLoadPtr = client.BaseAddress + 0x775AB5;
            hasControlPtr = client.BaseAddress + 0x72767C;
            finaleTriggerPtr = client.BaseAddress + 0x787E14;
            svCheatsPtr = client.BaseAddress + 0x775568;
            break;
        case "1339CD4EF916923DA04B04904C1B544C":
            print("using 2203 client offsets");
            cutscenePlayingPtr = client.BaseAddress + 0x70F804;
            scoreboardLoadPtr = client.BaseAddress + 0x782E55;
            hasControlPtr = client.BaseAddress + 0x73421C;
            finaleTriggerPtr = client.BaseAddress + 0x7951D4;
            svCheatsPtr = client.BaseAddress + 0x782908;
            break;
    }
    if (whatsLoadingPtr != IntPtr.Zero)
    {
        goto clientScans;
    }

    print("matched no known engine versions - sigscanning instead");
    var engineScanner = GetSignatureScanner("engine.dll");

    //------ WHATSLOADING SCANNING ------
    // get reference to "vidmemstats.txt" string
    IntPtr tmp = engineScanner.Scan(new SigScanTarget(GetByteStringS("vidmemstats.txt")));
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
    gameLoadingPtr = engineScanner.Scan(new SigScanTarget(2, "38 1D ?? ?? ?? ?? 0F 85 ?? ?? ?? ?? 56 53"));
    gameLoadingPtr = game.ReadPointer(gameLoadingPtr);

clientScans:
    if (cutscenePlayingPtr != IntPtr.Zero)
    {
        goto report;
    }
    print("matched no known client versions - sigscanning instead");
    var clientScanner = GetSignatureScanner("client.dll");
    //------ SV_CHEATS SCANNING ------
    svCheatsPtr = clientScanner.Scan(new SigScanTarget(2, "83 3D ?? ?? ?? ?? 00 56 57"));
    svCheatsPtr = game.ReadPointer(svCheatsPtr);

    //------ CUTSCENEPLAYING SCANNING ------
    // may want to sigscan this offset...
    const int cutsceneOff1 = 0x44;
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
report:
    ReportPointer(whatsLoadingPtr, "whats loading");
    ReportPointer(gameLoadingPtr, "game loading");
    ReportPointer(cutscenePlayingPtr, "cutscene playing");
    ReportPointer(scoreboardLoadPtr, "scoreboard loading");
    ReportPointer(hasControlPtr, "has control func");
    ReportPointer(finaleTriggerPtr, "finale trigger");
    ReportPointer(svCheatsPtr, "sv_cheats");
    print("whatsLoading offset: 0x" + ((int)whatsLoadingPtr-(int)engine.BaseAddress).ToString("X") +
    "\ngameLoading offset: 0x" + ((int)gameLoadingPtr-(int)engine.BaseAddress).ToString("X") +
    "\ncutscenePlaying offset: 0x" + ((int)cutscenePlayingPtr-(int)client.BaseAddress).ToString("X") +
    "\nscoreboardLoad offset: 0x" + ((int)scoreboardLoadPtr-(int)client.BaseAddress).ToString("X") +
    "\nhasControl offset: 0x" + ((int)hasControlPtr-(int)client.BaseAddress).ToString("X") +
    "\nfinaleTrigger offset: 0x" + ((int)finaleTriggerPtr-(int)client.BaseAddress).ToString("X") +
    "\nsv_cheats offset: 0x" + ((int)svCheatsPtr-(int)client.BaseAddress).ToString("X"));
    
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
    vars.lastSplit = "";

    vars.GetCvarValue = (Func<IntPtr, bool>)((cvarPointer) =>
    {
        return memory.ReadValue<int>(game.ReadPointer(cvarPointer)+0x30) != 0;
    });
    vars.svCheatsPtr = svCheatsPtr;
}

onStart
{
    if (settings["AutomaticGameTime"])
        timer.CurrentTimingMethod = TimingMethod.GameTime;
}

start
{

    if (vars.GetCvarValue(vars.svCheatsPtr))
    {
        vars.startRun=false;
        vars.cutsceneStart = DateTime.MaxValue;
        return false;
    }

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
            vars.lastSplit = "";
            return true;
        }
        return false;
    }
    else
    {
        // Once we have control after a cutscene plays for at least 1 second, we're ready to start.
        if (vars.hasControl.Current && !vars.gameLoading.Current)
        {
            if (DateTime.Now - vars.cutsceneStart > TimeSpan.FromSeconds(0.25))
            {
                print("CUSTSCENE RAN FOR " + (DateTime.Now - vars.cutsceneStart));
                vars.cutsceneStart = DateTime.MaxValue;
                vars.lastSplit = "";
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
        
    /* Old start logic, relies on cutscenePlaying which needs gameinstructor turned on, so we don't use it anymore
    if (vars.gameLoading.Old && vars.cutscenePlaying.Current && !vars.startRun)
    {
        vars.startRun=true;
        print("Autostart triggered");
    }
    
    else if (!vars.gameLoading.Current && vars.cutscenePlaying.Old && !vars.cutscenePlaying.Current && vars.startRun)
    {
        vars.startRun=false;
        print("Run autostarted");
        vars.lastSplit = vars.whatsLoading.Current;
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
            vars.delayedSplitTimer.Start();
            if (vars.whatsLoading.Current == vars.lastSplit)
            {
                vars.delayedSplitTimer.Reset();
                print("Ceased double split attempt");
                return false;
            }
        }
        if (vars.delayedSplitTimer.ElapsedMilliseconds >= 200)
        {
            vars.delayedSplitTimer.Reset();
            print("Split on THE BEST CAMPAIGN EVER (with a delay of 200ms)");
            vars.lastSplit = vars.whatsLoading.Current;
            return true;
        }
        if (settings["burhac"]) // VERY JANKY, probably not efficient and is hardcoded to the 14 official maps, but it's the only way we can do it when gameinstructor is turned off
        {
            // We are not loading, haven't split already and are on a campaign's first map
            if (!vars.gameLoading.Current && !vars.whatsLoading.Current.Equals(vars.lastSplit) && !vars.lastSplit.Equals("") && vars.campaignsFirstMaps.Contains(vars.whatsLoading.Current)) {
                // Once we have control after a cutscene plays for at least 1 second, we're ready to split
                if (vars.hasControl.Current)
                {
                    if (DateTime.Now - vars.cutsceneStart > TimeSpan.FromSeconds(0.25))
                    {
                        print("(burhacSplit) CUTSCENE RAN FOR " + (DateTime.Now - vars.cutsceneStart));
                        vars.cutsceneStart = DateTime.MaxValue;
                        vars.lastSplit = vars.whatsLoading.Current;
                        return true;
                    }
                }
                // If we're not loading, and the player does not have control, a cutscene must be playing. Mark the time if it hasn't been marked yet.
                else if (vars.cutsceneStart == DateTime.MaxValue)
                {
                    print("(burhacSplit) CUTSCENE START!");
                    vars.cutsceneStart = DateTime.Now;
                }
            }
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
            vars.delayedSplitTimer.Start();
            if (vars.whatsLoading.Current == vars.lastSplit)
            {
                vars.delayedSplitTimer.Reset();
                print("Ceased double split attempt");
                return false;
            }
        }
        if (vars.delayedSplitTimer.ElapsedMilliseconds >= 200)
        {
            vars.delayedSplitTimer.Reset();
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
