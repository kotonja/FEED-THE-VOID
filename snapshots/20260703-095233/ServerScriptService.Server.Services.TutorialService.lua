local TutorialService = {}

local maxStep = 10

function TutorialService.Init(context)
	TutorialService.Context = context
end

function TutorialService.Start() end

function TutorialService.SendStep(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data or (data.TutorialStep or 1) > maxStep then
		return
	end
	local message = TutorialService.Context.Config.GameConfig.TutorialMessages[data.TutorialStep]
	if message then
		TutorialService.Context.Services.EconomyService.Notify(player, message)
	end
end

function TutorialService.Advance(player, targetStep)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data or (data.TutorialStep or 1) > maxStep then
		return
	end
	if targetStep and (data.TutorialStep or 1) < targetStep then
		data.TutorialStep = targetStep
	elseif not targetStep then
		data.TutorialStep += 1
	end
	if data.TutorialStep > maxStep then
		TutorialService.Context.Services.EconomyService.Notify(player, "Tutorial complete. Feed the Void your weirdest snacks.")
	else
		TutorialService.SendStep(player)
	end
	TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	TutorialService.Context.Services.EconomyService.Sync(player)
end

function TutorialService.RecordAction(player, action)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	local step = data.TutorialStep or 1
	if action == "Plant" and step <= 3 then
		TutorialService.Advance(player, 4)
	elseif action == "Harvest" and step <= 4 then
		TutorialService.Advance(player, 5)
	elseif action == "FeedVoid" and step <= 6 then
		TutorialService.Advance(player, 7)
	elseif action == "Display" and step <= 7 then
		TutorialService.Advance(player, 8)
	elseif action == "CleanseVoidmite" and step <= 8 then
		TutorialService.Advance(player, 9)
	elseif action == "BuyUpgrade" and step <= 9 then
		TutorialService.Advance(player, 10)
	end
end

function TutorialService.Skip(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	data.TutorialStep = maxStep + 1
	TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	TutorialService.Context.Services.EconomyService.Notify(player, "Tutorial skipped.")
	TutorialService.Context.Services.EconomyService.Sync(player)
end

return TutorialService
