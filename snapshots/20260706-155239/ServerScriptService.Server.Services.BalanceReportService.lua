local BalanceReportService = {}

function BalanceReportService.Init(context)
	BalanceReportService.Context = context
end

function BalanceReportService.Start() end

local function addWarning(warnings, condition, message)
	if condition then
		table.insert(warnings, message)
	end
end

function BalanceReportService.Run(player)
	local context = BalanceReportService.Context
	local warnings = {}
	print("[FEED THE VOID][Balance] Snack economy report")
	for _, snackId in ipairs(context.Config.SnackConfig.Order or {}) do
		local snack = context.Config.SnackConfig[snackId]
		if type(snack) == "table" then
			local growTime = tonumber(snack.GrowTime)
			local seedCost = tonumber(snack.SeedCost)
			local sellValue = tonumber(snack.BaseSellValue)
			local voidValue = tonumber(snack.BaseVoidValue)
			local sellPerMinute = growTime and growTime > 0 and math.floor((sellValue or 0) / growTime * 60) or 0
			local passiveEstimate = math.max(1, math.floor((sellValue or 0) / 10))
			local notes = {}
			addWarning(notes, not growTime, "missing grow time")
			addWarning(notes, not snack.VisualType, "missing visual type")
			addWarning(notes, context.Config.RarityConfig[snack.Rarity] == nil, "invalid rarity")
			addWarning(notes, snack.Buyable ~= false and seedCost == nil, "buyable seed missing cost")
			addWarning(notes, seedCost and sellValue and sellValue < seedCost, "sell value below seed cost")
			if #notes > 0 then
				table.insert(warnings, snackId .. ": " .. table.concat(notes, ", "))
			end
			print(string.format(
				"[FEED THE VOID][Balance] %s | %s | grow=%ss | cost=%s | sell=%s | sell/min=%s | void=%s | passive~%s | %s",
				snack.DisplayName or snackId,
				tostring(snack.Rarity),
				tostring(growTime or "?"),
				tostring(seedCost or "locked"),
				tostring(sellValue or "?"),
				tostring(sellPerMinute),
				tostring(voidValue or "?"),
				tostring(passiveEstimate),
				#notes > 0 and table.concat(notes, "; ") or "ok"
			))
		end
	end
	for _, shopEntry in ipairs(context.Config.GameConfig.ShopRotatingSeeds or {}) do
		addWarning(warnings, context.Config.SnackConfig[shopEntry] == nil, "shop references invalid snack " .. tostring(shopEntry))
	end
	for mutationId, mutation in pairs(context.Config.MutationConfig or {}) do
		if type(mutation) == "table" and mutation.Weight then
			addWarning(warnings, tonumber(mutation.ValueMultiplier) == nil or tonumber(mutation.ValueMultiplier) <= 0, "mutation multiplier invalid for " .. tostring(mutationId))
		end
	end
	if #warnings > 0 then
		for _, warning in ipairs(warnings) do
			warn("[FEED THE VOID][Balance] WARN " .. warning)
		end
	else
		print("[FEED THE VOID][Balance] No suspicious values found.")
	end
	if player and context.Services.EconomyService then
		context.Services.EconomyService.Notify(player, "Balance report printed with " .. tostring(#warnings) .. " warnings.")
	end
	return warnings
end

return BalanceReportService
