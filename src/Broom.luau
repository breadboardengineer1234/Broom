--!optimize 2
--!strict

--[[
Broom cleanup module by u5eful:
- Provided cleanup method takes priority over defaults
- Tables are checked for :Disconnect, :Destroy, and :destroy
- Tweens default to :Destroy
- :pop removes without cleanup
- :remove removes with cleanup
- Duplicate objects not allowed when custom method is provided
- Reentrant behavior undefined when keys are used (i.e. do not add during cleanup)

For best performance:
- When a default is available, do not provide cleanup method
- Do not use keys
]]
export type Broom = {
	add: <T>(self: Broom, object: T & Task, methodName: string?, key: any) -> T,
	addBulk: <T...>(self: Broom, T...) -> (),
	pop: (self: Broom, key: any) -> (),
	remove: (self: Broom, key: any) -> (),
	cleanup: (self: Broom) -> (),
	destroy: (self: Broom) -> (),
	linkToInstance: (self: Broom, instance: Instance) -> RBXScriptConnection,
}
export type Custom = {Disconnect: (self: Custom) -> (), Destroy: (self: Custom) -> (), destroy: (self: Custom) -> ()} | any
export type Task = RBXScriptConnection | Instance | thread | () -> () | Custom
type BroomInternal = Broom & {
	_keyed: {[any]: any}?,
	_custom: {[Task]: string}?,
	_tasks: {Task},
	_linkConn: RBXScriptConnection?
}

const SOURCE = "[Broom]"
const VERSION = "v0.2.0"
const POOL_SIZE = 10

local pool = {} :: {Broom}

local function warnMsg(msg: string)
	warn(`{SOURCE} {msg}\n{debug.traceback(nil, 2)}`)
end

local function storeCustom(self: BroomInternal, name: string, object: Task)
	local custom = self._custom
	if not custom then
		custom = {}
		self._custom = custom
	elseif custom[object] ~= nil then
		error(`{SOURCE} Unable to add object {object} with custom method {name}: object has already been added`, 2)
	end
	(custom :: any)[object] = name
end

local function add<T>(self: Broom, object: T & Task, methodName: string?, key: any): T
	if key ~= nil then
		if methodName then
			storeCustom(self :: BroomInternal, methodName, object)
		end
		local keyed = (self :: BroomInternal)._keyed
		if not keyed then
			keyed = {}
			(self :: BroomInternal)._keyed = keyed
			
		elseif keyed[key] ~= nil then
			error(`{SOURCE} Cannot add duplicate keys to the same Broom object`, 2)
		end
		(keyed :: any)[key] = object
		return object
	end
	if methodName ~= nil then
		storeCustom(self :: BroomInternal, methodName, object)
	else
		table.insert((self :: BroomInternal)._tasks, object)
	end
	return object
end

local function addBulk<T...>(self: Broom, ...: T...)
	local n = select("#", ...)
	for i = 1, n do
		local object = select(i, ...)
		add(self, object)
	end
end

local function cleanCustom(self: BroomInternal, object: any): boolean
	local custom = self._custom
	if not custom then return false end
	local methodName = custom[object]
	if methodName then
		object[methodName](object)
		custom[object] = nil
		return true
	end
	return false
end

local function removeCustom(self: BroomInternal, object: Task)
	local custom = self._custom
	if custom and custom[object] then
		custom[object] = nil
	end
end

local function cleanObject(self: BroomInternal, object: any)
	local objType = typeof(object)	
	if objType == "table" then
		if object.Disconnect :: any then
			object:Disconnect()		
		elseif object.destroy :: any then
			object:destroy()			
		elseif object.Destroy :: any then
			object:Destroy()
		else
			warnMsg(`Unable to cleanup {object}: missing cleanup method`)
		end
	
	elseif objType == "RBXScriptConnection" then
		object:Disconnect()

	elseif objType == "Instance" then
		object:Destroy()

	elseif objType == "function" then
		object()

	elseif objType == "thread" then
		if coroutine.status(object) == "suspended" then
			task.cancel(object)
		end
		
	else
		warnMsg(`Unable to cleanup {object}: unsupported type {objType}`)
	end
end

local function pop(self: Broom, key: any)
	local keyed = (self :: BroomInternal)._keyed
	if not keyed then return end
	local object = keyed[key]
	keyed[key] = nil
	removeCustom(self :: BroomInternal, object)
end

local function remove(self: Broom, key: any)
	local keyed = (self :: BroomInternal)._keyed
	if not keyed then return end
	local object = keyed[key]
	if not object then return end
	keyed[key] = nil
	if not cleanCustom(self :: BroomInternal, object) then		
		cleanObject(self :: BroomInternal, object)
	end
end

local function cleanup(self: Broom)
	local keyed = (self :: BroomInternal)._keyed
	if keyed then
		for _, object in keyed do
			if not cleanCustom(self :: BroomInternal, object) then
				cleanObject(self :: BroomInternal, object)
			end
		end
		table.clear(keyed)
	end
	
	local custom = (self :: BroomInternal)._custom
	if custom then
		for object, methodName in custom :: any do
			object[methodName](object)
		end
		table.clear(custom)
	end
	
	local tasks = (self :: BroomInternal)._tasks
	for _, object in (tasks) do
		cleanObject(self :: BroomInternal, object)
	end
	table.clear(tasks)
end

local function destroy(self: Broom)
	cleanup(self)
	local linkConn = (self :: BroomInternal)._linkConn
	if linkConn then linkConn:Disconnect() end
	(self :: BroomInternal)._linkConn = nil
	setmetatable(self, nil)
	
	local size = #pool
	if size < POOL_SIZE then
		pool[size + 1] = self
	else
		table.clear(self)
	end
end

local function linkToInstance(self: Broom, instance: Instance): RBXScriptConnection
	local currConn = (self :: BroomInternal)._linkConn
	if currConn then currConn:Disconnect() end
	local newConn = instance.Destroying:Once(function()
		(self :: BroomInternal)._linkConn = nil
		cleanup(self)
	end);
	(self :: BroomInternal)._linkConn = newConn
	return newConn
end

local Broom = {
	add = add,
	addBulk = addBulk,
	remove = remove,
	pop = pop,
	cleanup = cleanup,
	destroy = destroy,
	linkToInstance = linkToInstance,
}
Broom.__index = Broom

local function new(): Broom
	local size = #pool
	if size > 0 then
		local broom = pool[size]
		pool[size] = nil
		return setmetatable(broom :: Broom, Broom) :: Broom
	else
		return setmetatable({
			_tasks = {},
		}, Broom) :: Broom
	end
end

return {new = new}