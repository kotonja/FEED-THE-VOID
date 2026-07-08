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
	data.LastLogout = os.time()
	context.Services.ProfileServiceWrapper.MarkDirty(player)
end

return VisitRewardService
