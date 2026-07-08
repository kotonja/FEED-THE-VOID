local VisitRewardService = {}

function VisitRewardService.Init(context)
	VisitRewardService.Context = context
end

function VisitRewardService.Start() end

function VisitRewardService.ApplyJoinReward(player)
	local context = VisitRewardService.Context
	local data = context.Services.ProfileServiceWrapper.GetData(player)
	if not data then
		return
	end
	local startStep = math.clamp(tonumber(data.TutorialStep) or 1, 1, #context.Config.GameConfig.TutorialMessages)
	for index = startStep, #context.Config.GameConfig.TutorialMessages do
		task.delay((index - startStep) * 3, function()
			if player.Parent then
				context.Services.EconomyService.Notify(player, context.Config.GameConfig.TutorialMessages[index])
			end
		end)
	end
	data.TutorialStep = #context.Config.GameConfig.TutorialMessages
	context.Services.ProfileServiceWrapper.MarkDirty(player)
end

return VisitRewardService
