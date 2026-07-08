local TutorialService = {}

local function maxStep()
	return #(TutorialService.Context.Config.GameConfig.TutorialMessages or {})
end

function TutorialService.Init(context)
	TutorialService.Context = context
end

function TutorialService.Start() end

function TutorialService.SendStep(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data or data.TutorialCompleted or (data.TutorialStep or 1) > maxStep() then
		return
	end
	local message = TutorialService.Context.Config.GameConfig.TutorialMessages[data.TutorialStep]
	if message then
		TutorialService.Context.Services.EconomyService.Notify(player, message)
	end
end

function TutorialService.Complete(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	data.TutorialCompleted = true
	data.TutorialStep = maxStep() + 1
	TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	TutorialService.Context.Services.EconomyService.Notify(player, "Tutorial complete. Keep feeding The Void.")
	TutorialService.Context.Services.EconomyService.Sync(player)
end

function TutorialService.Advance(player, targetStep)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data or data.TutorialCompleted or (data.TutorialStep or 1) > maxStep() then
		return
	end
	if targetStep and (data.TutorialStep or 1) < targetStep then
		data.TutorialStep = targetStep
	elseif not targetStep then
		data.TutorialStep += 1
	end
	if data.TutorialStep > maxStep() then
		TutorialService.Complete(player)
	else
		TutorialService.SendStep(player)
		TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
		TutorialService.Context.Services.EconomyService.Sync(player)
	end
end

function TutorialService.RecordAction(player, action)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	if TutorialService.Context.Services.AnalyticsService then
		TutorialService.Context.Services.AnalyticsService.RecordAction(player, "Action " .. tostring(action))
	end
	local step = data.TutorialStep or 1
	if data.TutorialCompleted then
		return
	end
	if action == "Plant" and step <= 2 then
		TutorialService.Advance(player, 3)
	elseif action == "Harvest" and step <= 4 then
		TutorialService.Advance(player, 5)
	elseif action == "FeedVoid" and step <= 5 then
		TutorialService.Advance(player, 6)
	elseif action == "Display" and step <= 6 then
		TutorialService.Advance(player, 7)
	elseif action == "CleanseVoidmite" and step <= 7 then
		TutorialService.Advance(player, 8)
	elseif action == "BuyUpgrade" and step <= 8 then
		TutorialService.Advance(player, 9)
	elseif action == "CompleteObjective" and step <= 9 then
		TutorialService.Advance(player, 10)
	end
end

function TutorialService.Skip(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	data.TutorialCompleted = true
	data.TutorialStep = maxStep() + 1
	TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	TutorialService.Context.Services.EconomyService.Notify(player, "Tutorial skipped.")
	TutorialService.Context.Services.EconomyService.Sync(player)
end

function TutorialService.Reset(player)
	local data = TutorialService.Context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	data.TutorialStep = 1
	data.TutorialCompleted = false
	TutorialService.Context.Services.ProfileServiceWrapper.MarkDirty(player)
	TutorialService.Context.Services.EconomyService.Notify(player, "Tutorial reset for this test session.")
	TutorialService.SendStep(player)
	TutorialService.Context.Services.EconomyService.Sync(player)
end

return TutorialService
