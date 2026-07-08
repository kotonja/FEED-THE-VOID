local SafeCall = {}

function SafeCall.Call(label, callback, ...)
	local args = { ... }
	local results = nil
	local ok, err = xpcall(function()
		results = { callback(table.unpack(args)) }
	end, debug.traceback)
	if not ok then
		warn("[FEED THE VOID][SafeCall] " .. tostring(label or "call") .. " failed: " .. tostring(err))
		return false, err
	end
	return true, table.unpack(results or {})
end

function SafeCall.Try(label, fallback, callback, ...)
	local ok, result = SafeCall.Call(label, callback, ...)
	if ok then
		return result
	end
	return fallback
end

return SafeCall
