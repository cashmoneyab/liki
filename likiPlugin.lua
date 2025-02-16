if not plugin then return; end;

local ChangeHistoryService = game:GetService("ChangeHistoryService");
local HttpService = game:GetService("HttpService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local RunService = game:GetService("RunService");
local StudioService = game:GetService("StudioService");
local Selection = game:GetService("Selection");

local task_wait = task.wait;
local task_delay = task.delay;
local instance_new = Instance.new;
local task_defer = task.defer;
local task_cancel = task.cancel;

local pageSource, pattern;

pcall(function()
	pattern = [[<a href%="/RadiatedExodus/LuauCeption/releases/tag/(%d+%.%d+)]]
	pageSource = HttpService:GetAsync("https://github.com/RadiatedExodus/LuauCeption/releases")
end)

local latestVersion;
local currentVersion;

local module;

local function compile(...)
	if not module then
		return;
	end
	if module[plugin:GetSetting("compileFunction")] then
		return module[plugin:GetSetting("compileFunction")](...);
	else
		if plugin:GetSetting("compileFunction") then
			warn("resetting compileFunction because it doesn't work!")
		end
		plugin:SetSetting("compileFunction", nil)
	end

	if module.luau_compile then
		return module.luau_compile(...);
	elseif module.Compile then
		local success, c = module.Compile(...);
		if success then
			return c;
		end
	elseif module[_G.compileFunction] then
		plugin:SetSetting("compileFunction", _G.compileFunction);
		return module[_G.compileFunction](...);
	else
		warn("No compile function was found!", "if there is, please use _G.compileFunction to set the compileFunction")
		warn("_G.compileFunction -> string", "if it works, it automatically saves it!");
		warn("Find compile function in here, and then set _G.compileFunction to its name!",module);
	end
end

local function update(object, script, byteCode)
	if (pcall(loadstring("if true then return end; " .. script.Source))) then
		object.Value = script.Source;
		byteCode.Value = compile(script.Source):gsub(".", function(c)
			return "\\"..c:byte();	
		end)
		task_wait(.1);
	end
end

local function setWaypoint()
	ChangeHistoryService:SetWaypoint(HttpService:GenerateGUID());
end

local function convertToLIKI(script : Script)
	if not module then
		warn("No module found!");
		return;
	end

	local object = instance_new("StringValue");
	object.Name = script.Name .. ".liki";
	object.Value = (script.Source);

	local byteCode = instance_new("StringValue")
	byteCode.Parent = object;
	byteCode.Name = "ByteCode";

	local scriptObject = instance_new("ObjectValue")
	scriptObject.Parent = object;
	scriptObject.Name = "Script";
	scriptObject.Value = script;

	update(object, script, byteCode);
	object.Parent = script:FindFirstAncestorOfClass("Workspace") or workspace;

	setWaypoint();

	return object
end

local function saveCompilerFile()
	if RunService:IsRunning() then
		warn("Game is running, cannot save compiler while running!")
		return;
	end
	local file : File = StudioService:PromptImportFile({"luau", "lua"});
	if file then
		local contents = file:GetBinaryContents();

		if contents:match("Luau (%d+%.%d+)") then
			currentVersion = contents:match("Luau (%d+%.%d+)");

			if currentVersion and latestVersion then
				if currentVersion < latestVersion then
					warn("This is an outdated version of the luauCeption compiler");
				end
			end 
			plugin:SetSetting("module", contents);

			module = loadstring(contents)()

			task_delay(1, function()
				if plugin:GetSetting("module") ~= contents then
					warn("Did not save correctly!")
				end
			end)

			for i,v in next, workspace:GetDescendants() do
				if v:IsA("StringValue") and v.Name:match("%.liki$") and v:FindFirstChild("ByteCode") then 
					task_defer(function()
						local script = v:WaitForChild("Script").Value;
						local byteCode = v:WaitForChild("ByteCode");

						update(v, script, byteCode);
					end)
					task_wait();
				else
					continue;
				end
			end
		else
			warn("This isn't the compiler file!")
		end
	end
end

local function AddUpdateSource(liki : StringValue)
	pcall(function()
		local script = liki:WaitForChild("Script").Value;
		local byteCode = liki:WaitForChild("ByteCode");

		local line = 0;

		local thread = task_defer(function()
			while task_wait(5) do
				local ticket = line + 1;
				line += 1;
				if ticket == line then
					update(liki, script, byteCode);
				end
				script:GetPropertyChangedSignal("Source"):Wait();
			end
		end)

		local connection = liki.Changed:Connect(function(v)
			task_wait(.1)
			if v ~= script.Source then
				update(liki, script, byteCode);
			end
		end)

		local connection2; connection2 = liki.AncestryChanged:Connect(function(_, p)
			if p == nil then
				connection:Disconnect();
				task_cancel(thread);
				connection2:Disconnect();
				return;
			end
		end)
	end)
end

task_delay(2, function()
	pcall(function()
		latestVersion = (pageSource:match(pattern));

		if plugin:GetSetting("module") then
			module = loadstring(plugin:GetSetting("module"))()
		else
			warn("No compiler found!")
		end
	end)
end)

task_wait(1)

local menu = plugin:CreatePluginMenu("likiMenu", "liki menu")
local saveCompilerAction = menu:AddNewAction("saveCompilerAction", "Add compiler to plugin", "rbxassetid://11963355762")
local addNewLiki = plugin:CreatePluginAction("likiCreatorAction", "+ Create a LIKI", "Creates a liki instance");

local toolbar = plugin:CreateToolbar("liki");

task_wait(1)

local button1, button2 = 
	toolbar:CreateButton("Open Menu for LIKI", "openMenuLiki", "rbxassetid://12967351548", "Open Menu for LIKI"),
toolbar:CreateButton("Setup Simulation", "setupLiki", "rbxassetid://12974220219", "Setups the LIKI simulation")

button1.Click:Connect(function()
	menu:ShowAsync()
	task_delay(1, function()
		button1:SetActive(false);
	end)
end)

button2.Click:Connect(function()
	xpcall(function()
		require(game:GetObjects('rbxassetid://103947249417425')[1])();
		setWaypoint();
	end, function()
		warn("Something went wrong while loading the setup")
	end)
end)

menu:AddSeparator();
menu:AddAction(addNewLiki)

saveCompilerAction.Triggered:Connect(saveCompilerFile)

addNewLiki.Triggered:Connect(function()
	for i,v in next, Selection:Get() do
		if v:IsA("Script") then
			convertToLIKI(v);
		end
	end
end)

if RunService:IsRunning() and RunService:IsClient() then
	-- run and pause simulation

	local playAction = plugin:CreatePluginAction("playActionLiki", "LIKI: Play", "Pauses the simulation")
	local pausesAction = plugin:CreatePluginAction("pauseActionLiki", "LIKI: Pause", "Pauses the simulation");

	local pausePlay =  ReplicatedStorage:WaitForChild("pausePlay", 5);

	if pausePlay then
		local pausePlay = require(pausePlay);

		playAction.Triggered:Connect(function()
			pausePlay:Play()
		end)
		pausesAction.Triggered:Connect(function()
			pausePlay:Pause()
		end)

		menu:AddSeparator();
		menu:AddAction(playAction)
		menu:AddAction(pausesAction)
	end;
elseif RunService:IsRunning() == false then
	-- real-time source updater
	for i,v in next, workspace:GetDescendants() do
		if v:IsA("StringValue") and v.Name:match("%.liki$") and v:FindFirstChild("ByteCode") then 
			task_wait();
			AddUpdateSource(v);
		else
			continue;
		end
	end

	workspace.DescendantAdded:Connect(function(v)
		if v:IsA("StringValue") and v.Name:match("%.liki$") and v:FindFirstChild("ByteCode") then 
			task_wait();
			AddUpdateSource(v);
		end
	end)
end
