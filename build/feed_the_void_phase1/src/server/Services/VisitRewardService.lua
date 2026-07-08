local VisitRewardService = {}

function VisitRewardService.Init(context)
	VisitRewardService.Context = context
end

function VisitRewardService.Start() end

function VisitRewardService.ApplyJoinReward(player)
	VisitRewardService.Context.Services.EconomyService.Notify(player, "Welcome to FEED THE VOID. Grow snacks, feed the Void, and help other labs.")
end

return VisitRewardService
