state("left4dead", "")
{

}

state("hl2", "")
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
	settings.Add("ILs", false, "Individual Campaigns", "splitOnce");
	settings.SetToolTip("ILs","You need to check every category above the category you are running because of how the splitter was made.");
	settings.Add("originalCampaigns", false, "Original Campaigns","ILs");
	settings.Add("allCampaigns", false, "All Campaigns","originalCampaigns");
	
	settings.Add("debug", false, "See internal values through DebugView");
	settings.SetToolTip("debug", "See the values that the splitter is using to make actions. Requires DebugView. This setting may cause additional lag, so only have this checked if needed.");
	
	vars.CurrentVersion="";
	refreshRate=30;
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
	IntPtr gameLoadingPtr = IntPtr.Zero;
	IntPtr cutscenePlayingPtr = IntPtr.Zero;
	IntPtr scoreboardLoadPtr = IntPtr.Zero;
	IntPtr hasControlPtr = IntPtr.Zero;
	IntPtr svCheatsPtr = IntPtr.Zero;
	Stopwatch sw = new Stopwatch();
	sw.Start();

	ProcessModuleWow64Safe engine = GetModule("engine.dll");
	ProcessModuleWow64Safe client = GetModule("client.dll");
	if (engine == null || client == null) {
		Thread.Sleep(250);
		throw new Exception("engine.dll and/or client.dll isn't loaded yet!"); }

	string engineHash;
	using (var md5 = System.Security.Cryptography.MD5.Create())
	using (var s = File.Open(engine.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
	engineHash = md5.ComputeHash(s).Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
	string clientHash;
	using (var md5 = System.Security.Cryptography.MD5.Create())
	using (var s = File.Open(client.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
	clientHash = md5.ComputeHash(s).Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
	switch (engineHash) {
		case "2653D0AD5873DF3791CFF5DDF8411A08":
			print("using 1005 engine offsets");
			gameLoadingPtr = engine.BaseAddress + 0x5D1E6C;
			break;
		case "D74562040EDA326FAA35E72A3F267422":
			print("using 1041 engine offsets");
			gameLoadingPtr = engine.BaseAddress + 0x5A79A4;
			break;
	}
	switch (clientHash) {
		case "D15C6196FF3F223236E90EEDCFE5BE44":
			print("using 1005 client offsets");
			cutscenePlayingPtr = client.BaseAddress + 0x522954;
			scoreboardLoadPtr = client.BaseAddress + 0x571BCD;
			hasControlPtr = client.BaseAddress + 0x545364;
			svCheatsPtr = client.BaseAddress + 0x571690;
			break;
		case "AA59CEC2593409E9F0808A67AB8CC382":
			print("using 1041 client offsets");
			cutscenePlayingPtr = client.BaseAddress + 0x546C14;
			scoreboardLoadPtr = client.BaseAddress + 0x5961CD;
			hasControlPtr = client.BaseAddress + 0x5696C4;
			svCheatsPtr = client.BaseAddress + 0x595C90;
			break;
	}
	if (gameLoadingPtr != IntPtr.Zero)
	{
		goto clientScans;
	}

	print("matched no known engine versions - sigscanning instead");
	var engineScanner = GetSignatureScanner("engine.dll");

	/* Commenting this and other references to it out - the code works, but it's currently not needed for the L4D1 autosplitter.
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
	} */

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
	cutscenePlayingPtr = IntPtr.Zero;
	// search for "C_GameInstructor" string reference
	IntPtr tmp = clientScanner.Scan(new SigScanTarget(GetByteStringS("C_GameInstructor") + "00"));
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
	scoreboardLoadPtr = IntPtr.Zero;
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
	hasControlPtr = clientScanner.Scan(new SigScanTarget(1, "BE ?? ?? ?? ?? 33 DB D9 EE 89 5E E4 D9"));
	hasControlPtr = game.ReadPointer(hasControlPtr)+0x10;

report:
	//ReportPointer(whatsLoadingPtr, "whats loading");
	ReportPointer(gameLoadingPtr, "game loading");
	ReportPointer(cutscenePlayingPtr, "cutscene playing");
	ReportPointer(scoreboardLoadPtr, "scoreboard loading");
	ReportPointer(hasControlPtr, "has control func");
	ReportPointer(svCheatsPtr, "sv_cheats");
	print("gameLoading offset: 0x" + ((int)gameLoadingPtr-(int)engine.BaseAddress).ToString("X") +
	"\ncutscenePlaying offset: 0x" + ((int)cutscenePlayingPtr-(int)client.BaseAddress).ToString("X") +
	"\nscoreboardLoad offset: 0x" + ((int)scoreboardLoadPtr-(int)client.BaseAddress).ToString("X") +
	"\nhasControl offset: 0x" + ((int)hasControlPtr-(int)client.BaseAddress).ToString("X") +
	"\nsv_cheats offset: 0x" + ((int)svCheatsPtr-(int)client.BaseAddress).ToString("X"));
	
	sw.Stop();
	print("Sigscanning done in " + sw.ElapsedMilliseconds / 1000f + " seconds");

#endregion

#region WATCHERS
	//vars.whatsLoading = new StringWatcher(whatsLoadingPtr, 256);
	vars.gameLoading = new MemoryWatcher<bool>(gameLoadingPtr);
	vars.cutscenePlaying = new MemoryWatcher<bool>(cutscenePlayingPtr);
	vars.scoreboardLoad = new MemoryWatcher<bool>(scoreboardLoadPtr);
	vars.hasControl = new MemoryWatcher<bool>(hasControlPtr);

	vars.mwList = new MemoryWatcherList()
	{
		//vars.whatsLoading,
		vars.gameLoading,
		vars.cutscenePlaying,
		vars.scoreboardLoad,
		vars.hasControl,
	};
#endregion
	
	vars.campaignsCompleted=0;
	if(settings["allCampaigns"])
		vars.totalCampaignNumber=6;
	else if (settings["originalCampaigns"])
		vars.totalCampaignNumber=4;
	else if (settings["ILs"])
		vars.totalCampaignNumber=1;
	else
		vars.totalCampaignNumber=-1;
	
	if(settings["splitOnce"] && !settings["campaignSplit"])
		print("Total campaign number is " + vars.totalCampaignNumber.ToString());
	
	vars.startRun=false;
	vars.cutsceneStart = DateTime.MaxValue;

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

	if(vars.gameLoading.Current && vars.hasControl.Current && !vars.startRun)
	{
		vars.startRun=true;
		print("(cutsceneless) Autostart triggered");
	}
	if (!vars.gameLoading.Current && vars.hasControl.Current && vars.startRun)
	{
		vars.startRun=false;
		vars.cutsceneStart = DateTime.MaxValue;
		print("(cutsceneless) Run autostarted");
		return true;
	}

	// Once we have control after a cutscene plays for at least a quarter of a second, we're ready to start.
	if (vars.hasControl.Current && !vars.gameLoading.Current)
	{
		if (DateTime.Now - vars.cutsceneStart > TimeSpan.FromSeconds(0.25))
		{
			print("CUSTSCENE RAN FOR " + (DateTime.Now - vars.cutsceneStart));
			vars.cutsceneStart = DateTime.MaxValue;
			vars.startRun=false;
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
	
	/* Old start logic, relies on cutscenePlaying which needs gameinstructor turned on, so we don't use it anymore
	if(vars.gameLoading.Old && vars.cutscenePlaying.Current && !vars.startRun)
	{
		vars.startRun=true;
		print("Autostart triggered");
	}
	
	else if(!vars.gameLoading.Current && vars.cutscenePlaying.Old && vars.startRun)
	{
		vars.startRun=false;
		print("Run autostarted");
		return true;
	}*/
}

split
{
	//Split on finales
	if(settings["campaignSplit"])
	{
		if(!vars.gameLoading.Current && vars.cutscenePlaying.Current && !vars.cutscenePlaying.Old)
		{
			vars.delayedSplitTimer.Start();
			print("Delayed split timer start");
		}
		if (vars.delayedSplitTimer.ElapsedMilliseconds >= 200)
		{
			vars.delayedSplitTimer.Reset();
			print("Split on finale (with a delay of 200ms)");
			return true;
		}
		//Split inbetween chapters
		if(settings["chapterSplit"])
		{
			if(settings["scoreboardVSgameLoading"])
			{
				if(!vars.scoreboardLoad.Old && vars.scoreboardLoad.Current)
				{
					print("Split at the end of a chapter at the scoreboard");
					return true;
				}
			}
			else
			{
				if(!vars.gameLoading.Old && vars.gameLoading.Current && !vars.cutscenePlaying.Current)
				{
					print("Split at the end of a chapter when it began to load");
					return true;
				}
			}
		}
	}
	
	
	//Split only when the run ends
	if(settings["splitOnce"])
	{
		if((vars.cutscenePlaying.Current) && !vars.cutscenePlaying.Old)
		{
			vars.campaignsCompleted++;
			print("Campaign count is now " + vars.campaignsCompleted.ToString());
		}
		if(vars.campaignsCompleted==vars.totalCampaignNumber)
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
	if(settings["debug"])
	{
		print("Values:\n current.gameLoading = " + vars.gameLoading.Current.ToString() +
		"\n current.cutscenePlaying = " + vars.cutscenePlaying.Current.ToString() +
		"\n current.scoreboardLoad = " + vars.scoreboardLoad.Current.ToString() +
		"\n current.hasControl = " + vars.hasControl.Current.ToString() +
		"\n vars.startRun = " + vars.startRun);
	}
}

exit
{
	print("Game closed.");
}