local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetReferences = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetReferences"))

local AssetOrganizerService = {}

local lastReport = nil

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function ensureRoot()
	local assets = ensureFolder(ReplicatedStorage, "Assets")
	local models = ensureFolder(assets, "Models")
	for _, folderName in ipairs(AssetReferences.ModelFolders or {}) do
		ensureFolder(models, folderName)
	end
	ensureFolder(assets, "Duplicates")
	return assets, models
end

local function normalizePath(pathValue)
	if type(pathValue) == "string" then
		local parts = {}
		for part in string.gmatch(pathValue, "[^%.]+") do
			table.insert(parts, part)
		end
		return parts
	end
	return pathValue
end

local function findByPath(pathParts)
	pathParts = normalizePath(pathParts)
	if type(pathParts) ~= "table" then
		return nil
	end
	local current = nil
	for index, partName in ipairs(pathParts) do
		if index == 1 then
			local ok, service = pcall(function()
				return game:GetService(partName)
			end)
			current = ok and service or game:FindFirstChild(partName)
		else
			current = current and current:FindFirstChild(partName)
		end
		if not current then
			return nil
		end
	end
	return current
end

local function targetParentFor(ref)
	local pathParts = normalizePath(ref.Path)
	if type(pathParts) ~= "table" or #pathParts < 2 then
		return nil
	end
	local parentPath = {}
	for index = 1, #pathParts - 1 do
		table.insert(parentPath, pathParts[index])
	end
	return findByPath(parentPath)
end

local function uniqueDuplicateName(folder, baseName)
	local name = baseName .. "_Duplicate"
	local index = 1
	while folder:FindFirstChild(name) do
		index += 1
		name = baseName .. "_Duplicate" .. tostring(index)
	end
	return name
end

local function applySetup(assetService, model)
	if assetService and model and model:IsA("Model") then
		assetService.ApplySafeModelSetup(model)
	end
end

function AssetOrganizerService.Init(context)
	AssetOrganizerService.Context = context
end

function AssetOrganizerService.Start()
	task.defer(function()
		AssetOrganizerService.Run("server-start")
	end)
end

function AssetOrganizerService.Run(reason)
	local context = AssetOrganizerService.Context
	local assets = ensureRoot()
	local duplicates = ensureFolder(assets, "Duplicates")
	local report = {
		Reason = reason or "manual",
		CreatedFolders = true,
		Moved = {},
		Duplicates = {},
		Missing = {},
		Checked = 0,
	}

	for assetKey, ref in pairs(AssetReferences) do
		if type(ref) == "table" and ref.Path then
			report.Checked += 1
			local target = findByPath(ref.Path)
			local sourceName = ref.SourceName or ref.Path[#ref.Path]
			local loose = workspace:FindFirstChild(sourceName)
			local parent = targetParentFor(ref)
			if loose and parent then
				if target and target ~= loose then
					loose.Name = uniqueDuplicateName(duplicates, sourceName)
					loose.Parent = duplicates
					table.insert(report.Duplicates, assetKey)
				else
					loose.Parent = parent
					loose.Name = sourceName
					applySetup(context.Services.AssetService, loose)
					table.insert(report.Moved, assetKey)
				end
			elseif not target then
				table.insert(report.Missing, assetKey)
			elseif target and target:IsA("Model") then
				applySetup(context.Services.AssetService, target)
			end
		end
	end

	lastReport = report
	print(string.format(
		"[FEED THE VOID][AssetOrganizer] checked=%d moved=%d duplicates=%d missing=%d reason=%s",
		report.Checked,
		#report.Moved,
		#report.Duplicates,
		#report.Missing,
		tostring(report.Reason)
	))
	return report
end

function AssetOrganizerService.GetLastReport()
	return lastReport
end

function AssetOrganizerService.PrintReport(player)
	local report = lastReport or AssetOrganizerService.Run("debug-command")
	print(string.format(
		"[FEED THE VOID][AssetOrganizer] last moved=%d duplicates=%d missing=%d",
		#(report.Moved or {}),
		#(report.Duplicates or {}),
		#(report.Missing or {})
	))
	if player and AssetOrganizerService.Context.Services.EconomyService then
		AssetOrganizerService.Context.Services.EconomyService.Notify(player, "Asset organizer: " .. tostring(#(report.Moved or {})) .. " moved, " .. tostring(#(report.Missing or {})) .. " missing.")
	end
	return report
end

return AssetOrganizerService
