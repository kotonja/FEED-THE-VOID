$ErrorActionPreference = "Stop"

$bridge = "C:\Users\tommy\OneDrive\Documentos\New project 5\tools\bridge.cmd"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $root "generated"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Get-LiveSource([string]$path) {
	$json = & $bridge source $path
	if ($LASTEXITCODE -ne 0) {
		throw "Failed to read source: $path"
	}
	return ($json | ConvertFrom-Json).source
}

function Replace-Strict([string]$source, [string]$old, [string]$new, [string]$label) {
	if (-not $source.Contains($old)) {
		throw "Missing replacement anchor: $label"
	}
	return $source.Replace($old, $new)
}

function Write-Source([string]$name, [string]$source) {
	$path = Join-Path $out $name
	$source = $source.TrimStart([char]0xFEFF)
	$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
	[System.IO.File]::WriteAllText($path, $source, $utf8NoBom)
	return $path
}

function Apply-LivePatch([string]$target, [string]$file, [string]$summary) {
	& $bridge patch $target $file $summary
	if ($LASTEXITCODE -ne 0) {
		throw "Patch failed: $target"
	}
}

$main = Get-LiveSource "ServerScriptService.Server.Main"
$main = Replace-Strict $main 'local Remotes = ReplicatedStorage:WaitForChild("Remotes")' @'
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getRemoteEvent(remoteName)
	local remote = Remotes:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = Remotes
	end
	return remote
end
'@ "Main remote helper"
$main = Replace-Strict $main 'SyncPlayerData = Remotes:WaitForChild("SyncPlayerData"),' @'
		SyncPlayerData = Remotes:WaitForChild("SyncPlayerData"),
		PlayEffect = getRemoteEvent("PlayEffect"),
'@ "Main PlayEffect remote"
$main = Replace-Strict $main 'Phase 5 launch-ready server loaded.' 'Phase 6 premium polish server loaded.' "Main phase print"
$mainFile = Write-Source "Main.lua" $main

$snack = Get-LiveSource "ServerScriptService.Server.Services.SnackService"
$snack = Replace-Strict $snack @'
local visualAssetByType = {
	Round = "SnackRoundBase",
	Cube = "SnackCubeBase",
	Wrap = "SnackWrapBase",
}
'@ @'
local visualAssetByType = {
	Round = "SnackRoundBase",
	Cube = "SnackCubeBase",
	Wrap = "SnackWrapBase",
}

local function stageScaleFor(stage)
	return ({ 0.4, 0.7, 1 })[stage or 3] or 1
end
'@ "Snack stageScaleFor"
$snack = Replace-Strict $snack @'
local function getMutationConfig(mutationId)
	return SnackService.Context.Config.MutationConfig[mutationId or "Normal"]
end
'@ @'
local function getMutationConfig(mutationId)
	return SnackService.Context.Config.MutationConfig[mutationId or "Normal"]
end

local function targetPosition(target)
	if typeof(target) == "Vector3" then
		return target
	end
	if typeof(target) ~= "Instance" then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	end
	if target:IsA("Model") then
		return target:GetPivot().Position
	end
	local part = target:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function effectPayload(effectType, target, extra)
	local payload = type(extra) == "table" and table.clone(extra) or {}
	payload.Type = effectType
	if typeof(target) == "Instance" then
		payload.Target = target
	end
	payload.Position = payload.Position or targetPosition(target)
	return payload
end

local function fireEffect(player, effectType, target, extra)
	local context = SnackService.Context
	local remote = context and context.Remotes and context.Remotes.PlayEffect
	if player and remote then
		remote:FireClient(player, effectPayload(effectType, target, extra))
	end
end

local function fireEffectAll(effectType, target, extra)
	local context = SnackService.Context
	local remote = context and context.Remotes and context.Remotes.PlayEffect
	if remote then
		remote:FireAllClients(effectPayload(effectType, target, extra))
	end
end
'@ "Snack effect helpers"
$snack = Replace-Strict $snack @'
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 9
		prompt.Enabled = enabled
'@ @'
		prompt.HoldDuration = 0.12
		prompt.MaxActivationDistance = 10.5
		prompt.RequiresLineOfSight = false
		prompt.Enabled = enabled
'@ "Snack prompt readability"
$snack = Replace-Strict $snack 'local stageScale = ({ 0.45, 0.75, 1 })[stage or 3] or 1' 'local stageScale = stageScaleFor(stage or 3)' "Snack model stage scale"
$snack = Replace-Strict $snack @'
local function addDisplayLabel(model, text, passiveIncome)
	SnackService.Context.Services.AssetService.AddBillboard(model, text .. "\n+" .. tostring(passiveIncome) .. " coins/tick", Vector3.new(0, 2.8, 0))
end
'@ @'
local function addDisplayLabel(model, text, passiveIncome)
	SnackService.Context.Services.AssetService.AttachBillboard(model, {
		Name = "FTVDisplayLabel",
		Text = text .. "\n+" .. tostring(passiveIncome) .. " coins/tick",
		Size = UDim2.new(0, 160, 0, 44),
		StudsOffset = Vector3.new(0, 2.35, 0),
		MaxDistance = 52,
		BackgroundTransparency = 0.28,
	})
end
'@ "Snack compact display label"
$snack = Replace-Strict $snack @'
		GrowTime = context.Config.GameConfig.DebugFastGrowth and context.Config.GameConfig.FastGrowthTime or (snack.GrowTime / math.max(0.1, context.Services.UpgradeService.GetMultiplier(player, "GrowSpeed"))),
		Stage = 1,
	}
'@ @'
		GrowTime = context.Config.GameConfig.DebugFastGrowth and context.Config.GameConfig.FastGrowthTime or (snack.GrowTime / math.max(0.1, context.Services.UpgradeService.GetMultiplier(player, "GrowSpeed"))),
		Stage = 1,
		VisualScale = stageScaleFor(1),
		ReadyNotified = false,
	}
'@ "Snack active record fields"
$snack = Replace-Strict $snack @'
	context.Services.EconomyService.Sync(player)
	context.Services.EconomyService.Notify(player, "You planted " .. snack.DisplayName .. "!")
'@ @'
	context.Services.EconomyService.Sync(player)
	fireEffect(player, "Plant", model, {
		SnackId = snackId,
		DisplayName = snack.DisplayName,
		SoundKey = "Plant",
	})
	context.Services.EconomyService.Notify(player, "You planted " .. snack.DisplayName .. "!")
'@ "Snack plant effect"
$snack = Replace-Strict $snack 'elseif progress >= 0.5 then' 'elseif progress >= 0.4 then' "Snack stage 2 threshold"
$snack = Replace-Strict $snack @'
			if stage ~= record.Stage then
				record.Stage = stage
				record.Plate:SetAttribute("GrowthStage", stage)
				record.Model:SetAttribute("GrowthStage", stage)
				SnackService.Context.Services.AssetService.SetModelCFrame(record.Model, CFrame.new(record.Plate.Position + Vector3.new(0, 1.5 + stage * 0.25, 0)))
				if stage >= 3 then
					setPlatePrompt(record.Plate, "Harvest", true)
				end
			end
'@ @'
			if stage ~= record.Stage then
				record.Stage = stage
				record.Plate:SetAttribute("GrowthStage", stage)
				record.Model:SetAttribute("GrowthStage", stage)
				local nextVisualScale = stageScaleFor(stage)
				if record.VisualScale and record.VisualScale > 0 and nextVisualScale ~= record.VisualScale then
					SnackService.Context.Services.AssetService.ScaleModelSafely(record.Model, nextVisualScale / record.VisualScale)
				end
				record.VisualScale = nextVisualScale
				SnackService.Context.Services.AssetService.SetModelCFrame(record.Model, CFrame.new(record.Plate.Position + Vector3.new(0, 1.45 + stage * 0.28, 0)))
				local snack = getSnackConfig(record.SnackId)
				fireEffect(record.Player, stage >= 3 and "GrowthReady" or "GrowthStage", record.Model, {
					Stage = stage,
					SnackId = record.SnackId,
					DisplayName = snack and snack.DisplayName or record.SnackId,
					SoundKey = stage >= 3 and "GrowthReady" or "GrowthStage",
				})
				if stage >= 3 then
					setPlatePrompt(record.Plate, "Harvest", true)
					if not record.ReadyNotified then
						record.ReadyNotified = true
						SnackService.Context.Services.EconomyService.Notify(record.Player, (snack and snack.DisplayName or "Snack") .. " is ready to harvest.")
					end
				end
			end
'@ "Snack growth stage effect"
$snack = Replace-Strict $snack @'
	item.EstimatedSellValue = sellValue
	item.EstimatedVoidValue = voidValue
	item.PassiveIncome = passiveIncome
	context.Services.InventoryService.AddItem(player, item)
'@ @'
	item.EstimatedSellValue = sellValue
	item.EstimatedVoidValue = voidValue
	item.PassiveIncome = passiveIncome
	fireEffect(player, "Harvest", plate, {
		SnackId = item.SnackId,
		MutationId = item.MutationId,
		DisplayName = item.DisplayName,
		Text = "+" .. tostring(sellValue) .. " value",
		SoundKey = "Harvest",
	})
	context.Services.InventoryService.AddItem(player, item)
'@ "Snack harvest effect"
$snack = Replace-Strict $snack @'
	context.Services.EconomyService.AddCoins(player, value)
	context.Services.StatsService.Record(player, "SnacksSold", 1)
'@ @'
	context.Services.EconomyService.AddCoins(player, value)
	fireEffect(player, "Sell", station, {
		Text = "+" .. tostring(value) .. " coins",
		SoundKey = "Sell",
	})
	context.Services.StatsService.Record(player, "SnacksSold", 1)
'@ "Snack sell effect"
$snack = Replace-Strict $snack @'
	context.Services.QuestService.Record(player, "FeedVoid", 1)
	context.Services.TutorialService.RecordAction(player, "FeedVoid")
	context.Services.EconomyService.Notify(player, "You fed the Void! +" .. tostring(tokenReward) .. " Void Tokens.")
'@ @'
	context.Services.QuestService.Record(player, "FeedVoid", 1)
	context.Services.TutorialService.RecordAction(player, "FeedVoid")
	local voidTarget = feedStation or (world and world:FindFirstChild("CentralVoid") and world.CentralVoid:FindFirstChild("VoidCore"))
	fireEffectAll("FeedVoid", voidTarget, {
		Player = player,
		SnackId = item.SnackId,
		MutationId = item.MutationId,
		VoidValue = voidValue,
		Text = "+" .. tostring(tokenReward) .. " Void Tokens",
		SoundKey = "FeedVoid",
	})
	context.Services.EconomyService.Notify(player, "You fed the Void! +" .. tostring(tokenReward) .. " Void Tokens.")
'@ "Snack feed effect"
$snack = Replace-Strict $snack @'
	model:SetAttribute("DisplayName", item.DisplayName)
	addDisplayLabel(model, item.DisplayName, passiveIncome)
	displayedByWorldId[item.WorldId] = model
'@ @'
	model:SetAttribute("DisplayName", item.DisplayName)
	addDisplayLabel(model, item.DisplayName, passiveIncome)
	displayedByWorldId[item.WorldId] = model
	fireEffect(player, "Display", model, {
		SnackId = item.SnackId,
		MutationId = item.MutationId,
		DisplayName = item.DisplayName,
		Text = "+" .. tostring(passiveIncome) .. " coins/tick",
		SoundKey = "DisplaySnack",
	})
'@ "Snack display effect"
$snackFile = Write-Source "SnackService.lua" $snack

$voidmite = Get-LiveSource "ServerScriptService.Server.Services.VoidmiteService"
$voidmite = Replace-Strict $voidmite @'
local function countForPlot(plotId)
	local folder = getFolder()
	local count = 0
	if not folder then
		return 0
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("PlotId")) == tonumber(plotId) then
			count += 1
		end
	end
	return count
end
'@ @'
local function countForPlot(plotId)
	local folder = getFolder()
	local count = 0
	if not folder then
		return 0
	end
	for _, child in ipairs(folder:GetChildren()) do
		if tonumber(child:GetAttribute("PlotId")) == tonumber(plotId) then
			count += 1
		end
	end
	return count
end

local function targetPosition(target)
	if typeof(target) == "Vector3" then
		return target
	end
	if typeof(target) ~= "Instance" then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	end
	if target:IsA("Model") then
		return target:GetPivot().Position
	end
	local part = target:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function fireEffectAll(effectType, target, extra)
	local context = VoidmiteService.Context
	local remote = context and context.Remotes and context.Remotes.PlayEffect
	if not remote then
		return
	end
	local payload = type(extra) == "table" and table.clone(extra) or {}
	payload.Type = effectType
	if typeof(target) == "Instance" then
		payload.Target = target
	end
	payload.Position = payload.Position or targetPosition(target)
	remote:FireAllClients(payload)
end
'@ "Voidmite effect helpers"
$voidmite = Replace-Strict $voidmite @'
	context.Services.AssetService.ApplyMutationVisual(model, "VoidTouched")
	context.Services.AssetService.AddBillboard(model, "Voidmite", Vector3.new(0, 2.1, 0))
	local prompt = context.Services.AssetService.AddProximityPrompt(model, "Voidmite", "Cleanse")
	if prompt then
		prompt.Triggered:Connect(function(player)
			VoidmiteService.ClearVoidmite(player, model)
		end)
	end
	return model
'@ @'
	context.Services.AssetService.ApplyMutationVisual(model, "VoidTouched")
	context.Services.AssetService.AttachBillboard(model, {
		Name = "FTVVoidmiteLabel",
		Text = "Voidmite",
		Size = UDim2.new(0, 118, 0, 34),
		StudsOffset = Vector3.new(0, 2.05, 0),
		MaxDistance = 48,
		BackgroundTransparency = 0.32,
	})
	local prompt = context.Services.AssetService.AttachPrompt(model, {
		Name = "CleanseVoidmitePrompt",
		ObjectText = "Voidmite",
		ActionText = "Cleanse",
		HoldDuration = 0.12,
		MaxActivationDistance = 13,
		RequiresLineOfSight = false,
	})
	if prompt then
		prompt.Triggered:Connect(function(player)
			VoidmiteService.ClearVoidmite(player, model)
		end)
	end
	fireEffectAll("VoidmiteSpawn", model, {
		OwnerUserId = ownerUserId,
		Reward = reward,
		SoundKey = "VoidmiteSpawn",
	})
	local ownerPlayer = ownerPlayerFromUserId(ownerUserId)
	if ownerPlayer then
		context.Services.EconomyService.Notify(ownerPlayer, "A Voidmite is nibbling your display shelf.")
	end
	return model
'@ "Voidmite spawn prompt/effect"
$voidmite = Replace-Strict $voidmite @'
	local ownerUserId = tonumber(voidmite:GetAttribute("OwnerUserId"))
	local ownerPlayer = ownerPlayerFromUserId(ownerUserId)
	voidmite:Destroy()
	context.Services.EconomyService.AddCoins(player, reward)
'@ @'
	local ownerUserId = tonumber(voidmite:GetAttribute("OwnerUserId"))
	local ownerPlayer = ownerPlayerFromUserId(ownerUserId)
	fireEffectAll("VoidmiteCleanse", voidmite, {
		Player = player,
		Reward = reward,
		Text = "+" .. tostring(reward) .. " coins +1 token",
		SoundKey = "CleanseVoidmite",
	})
	voidmite:Destroy()
	context.Services.EconomyService.AddCoins(player, reward)
'@ "Voidmite cleanse effect"
$voidmiteFile = Write-Source "VoidmiteService.lua" $voidmite

$gameConfig = Get-LiveSource "ReplicatedStorage.Shared.GameConfig"
$gameConfig = Replace-Strict $gameConfig 'Phase = "5-launch-ready",' 'Phase = "6-premium-polish",' "GameConfig phase"
$gameConfig = Replace-Strict $gameConfig @'
		Plant = 0,
		Harvest = 0,
		Sell = 0,
		FeedVoid = 0,
'@ @'
		Plant = 0,
		GrowthStage = 0,
		GrowthReady = 0,
		Harvest = 0,
		Sell = 0,
		FeedVoid = 0,
		DisplaySnack = 0,
		VoidmiteSpawn = 0,
'@ "GameConfig sound keys"
$gameConfigFile = Write-Source "GameConfig.lua" $gameConfig

$mutation = Get-LiveSource "ReplicatedStorage.Shared.MutationConfig"
$mutation = Replace-Strict $mutation @'
	Rainbow = {
		DisplayName = "Rainbow",
		Weight = 25,
		ValueMultiplier = 8,
		Color = Color3.fromRGB(255, 88, 205),
		ScaleMultiplier = 1.1,
		Visual = "Rainbow",
		Material = Enum.Material.Neon,
	},
'@ @'
	Rainbow = {
		DisplayName = "Rainbow",
		Weight = 25,
		ValueMultiplier = 8,
		Color = Color3.fromRGB(255, 88, 205),
		ScaleMultiplier = 1.1,
		Visual = "Rainbow",
		Material = Enum.Material.SmoothPlastic,
	},
'@ "Mutation rainbow material"
$mutation = Replace-Strict $mutation @'
	VoidTouched = {
		DisplayName = "Void Touched",
		Weight = 10,
		ValueMultiplier = 15,
		Color = Color3.fromRGB(64, 22, 104),
		ScaleMultiplier = 1.15,
		Visual = "VoidGlow",
		Material = Enum.Material.Neon,
	},
'@ @'
	VoidTouched = {
		DisplayName = "Void Touched",
		Weight = 10,
		ValueMultiplier = 15,
		Color = Color3.fromRGB(64, 22, 104),
		ScaleMultiplier = 1.15,
		Visual = "VoidGlow",
		Material = Enum.Material.Glass,
	},
'@ "Mutation void material"
$mutation = Replace-Strict $mutation @'
	Glitched = {
		DisplayName = "Glitched",
		Weight = 8,
		ValueMultiplier = 25,
		Color = Color3.fromRGB(80, 255, 190),
		ScaleMultiplier = 1.05,
		Visual = "Glitch",
		Material = Enum.Material.Neon,
	},
'@ @'
	Glitched = {
		DisplayName = "Glitched",
		Weight = 8,
		ValueMultiplier = 25,
		Color = Color3.fromRGB(80, 255, 190),
		ScaleMultiplier = 1.05,
		Visual = "Glitch",
		Material = Enum.Material.SmoothPlastic,
	},
'@ "Mutation glitch material"
$mutationFile = Write-Source "MutationConfig.lua" $mutation

$clientMain = Get-LiveSource "StarterPlayer.StarterPlayerScripts.ClientMain"
$clientMain = Replace-Strict $clientMain 'FEED THE VOID Phase 5 loaded.' 'FEED THE VOID Phase 6 polish loaded.' "ClientMain phase notification"
$clientMainFile = Write-Source "ClientMain.lua" $clientMain

Apply-LivePatch "ServerScriptService.Server.Main" $mainFile "Phase 6 PlayEffect cosmetic remote"
Apply-LivePatch "ServerScriptService.Server.Services.SnackService" $snackFile "Phase 6 planting growth harvest feed display VFX hooks"
Apply-LivePatch "ServerScriptService.Server.Services.VoidmiteService" $voidmiteFile "Phase 6 voidmite VFX and prompt polish"
Apply-LivePatch "ReplicatedStorage.Shared.GameConfig" $gameConfigFile "Phase 6 config and optional sound keys"
Apply-LivePatch "ReplicatedStorage.Shared.MutationConfig" $mutationFile "Phase 6 non-neon mutation material pass"
Apply-LivePatch "StarterPlayer.StarterPlayerScripts.ClientMain" $clientMainFile "Phase 6 client load message"
Apply-LivePatch "StarterPlayer.StarterPlayerScripts.Controllers.EffectsController" (Join-Path $root "EffectsController.lua") "Phase 6 PDS texture-driven VFX controller"
Apply-LivePatch "StarterPlayer.StarterPlayerScripts.Controllers.SoundController" (Join-Path $root "SoundController.lua") "Phase 6 optional sound hook controller"
Apply-LivePatch "StarterPlayer.StarterPlayerScripts.Controllers.PromptController" (Join-Path $root "PromptController.lua") "Phase 6 mobile prompt tuning"

Write-Output "Phase 6 patches applied from $root"
