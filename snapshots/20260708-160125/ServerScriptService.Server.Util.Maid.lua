local Maid = {}
Maid.__index = Maid

local function cleanupTask(taskItem)
	local taskType = typeof(taskItem)
	if taskType == "RBXScriptConnection" then
		if taskItem.Connected then
			taskItem:Disconnect()
		end
	elseif taskType == "Instance" then
		if taskItem.Parent then
			taskItem:Destroy()
		end
	elseif type(taskItem) == "function" then
		taskItem()
	elseif type(taskItem) == "table" and type(taskItem.DoCleaning) == "function" then
		taskItem:DoCleaning()
	elseif type(taskItem) == "table" and type(taskItem.Destroy) == "function" then
		taskItem:Destroy()
	elseif type(taskItem) == "thread" then
		task.cancel(taskItem)
	end
end

function Maid.new()
	return setmetatable({
		_tasks = {},
	}, Maid)
end

function Maid:GiveTask(taskItem)
	if taskItem == nil then
		return taskItem
	end
	table.insert(self._tasks, taskItem)
	return taskItem
end

function Maid:DoCleaning()
	local tasks = self._tasks
	self._tasks = {}
	for index = #tasks, 1, -1 do
		local ok, err = pcall(cleanupTask, tasks[index])
		if not ok then
			warn("[FEED THE VOID] Maid cleanup failed:", err)
		end
	end
end

function Maid:Cleanup()
	self:DoCleaning()
end

function Maid:Destroy()
	self:DoCleaning()
end

return Maid
