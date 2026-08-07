--!optimize 2
--!native

--[[
[Broom] v0.1.0
u5eful's cleanup module
Provided cleanup method takes priority over defaults
Tables are checked for :Destroy and :Disconnect
Tweens default to :Destroy
:pop removes without cleanup
:remove removes with cleanup

For best performance:
-When a default is available, do not provide cleanup method
-Do not use keys
]]

export type Broom = {
	add: <T>(self: Broom, object: T, methodName: string?, key: string?) -> T,
	pop: (self: Broom, key: string) -> (),
	remove: (self: Broom, key: string) -> (),
	cleanup: (self: Broom) -> (),
	destroy: (self: Broom) -> (),
	linkToInstance: (self: Broom, instance: Instance) -> (),
}

type Entry = {
	object: any,
	callback: ((any) -> ())?,
	isFunction: boolean,
	isThread: boolean,
}

local SOURCE = "[Broom]"

local typeToMethod = {
	Instance = "Destroy",
	RBXScriptConnection = "Disconnect",
}

local keyedTemplate = {
	object = "whatever",
	isFunction = false,
	isThread = false,
	callback = "whatever",
}

local customTemplate = {
	object = "whatever",
	callback = "whatever",
}

local function warnMsg(msg: string)
	warn(SOURCE.." "..msg.."\n".. debug.traceback(nil, 2))
end

local function add<T>(self: Broom, object: T, methodName: string?, key: string?): T
	local objType = typeof(object)
	if key then
		local keyed = self._keyed
		if keyed[key] then
			error(SOURCE.." Cannot add duplicate keys to the same Broom object", 2)
		end
		local isFunction = objType == "function"
		local isThread = objType == "thread"
		local callback
		
		if not (isFunction or isThread) then
			if objType == "table" then
				methodName = methodName or (object.Disconnect and "Disconnect") or (object.Destroy and "Destroy")
			else
				methodName = methodName or typeToMethod[objType]
			end
			if not methodName then
				warnMsg("No cleanup method found for object of type "..objType)
			end	
			callback = object[methodName]
		end
		
		local entry = table.clone(keyedTemplate)
		entry.object = object
		entry.isFunction = isFunction
		entry.isThread = isThread
		entry.callback = callback
		keyed[key] = entry
		return object
	end
	
	if methodName then
		local entry = table.clone(customTemplate)
		entry.object = object
		entry.callback = object[methodName]
		table.insert(self._custom, entry)
		
	elseif objType == "table" then
		if object.Disconnect then
			table.insert(self._connections, object)
		elseif object.Destroy then
			table.insert(self._destroyable, object)
		else
			warnMsg("No cleanup method found for object of type "..objType)
		end
		
	elseif objType == "RBXScriptConnection" then
		table.insert(self._connections, object)
	
	elseif objType == "thread" then
		table.insert(self._threads, object)
		
	elseif objType == "Instance" then
		table.insert(self._destroyable, object)
	
	elseif objType == "function" then
		table.insert(self._callbacks, object)
		
	else
		error(SOURCE.." Unsupported object", 2)
	end
	return object
end

local function cleanEntry(entry: Entry)
	local object = entry.object
	local destroy = entry.callback

	if entry.isFunction then 
		object()		
	elseif entry.isThread then
		if coroutine.status(object) ~= "dead" then
			task.cancel(object)
		end		
	elseif destroy then
		destroy(object)
	end
end

local function pop(self: Broom, key: string)
	self._keyed[key] = nil
end

local function remove(self: Broom, key: string)
	local keyed = self._keyed
	local entry = keyed[key]
	if not entry then return end
	cleanEntry(entry)
	keyed[key] = nil
end

local function cleanup(self: Broom)
	local destroyable = self._destroyable
	local conns = self._connections
	local threads = self._threads
	local callbacks = self._callbacks
	local custom = self._custom
	local keyed = self._keyed
	
	for _, object in destroyable do
		object:Destroy()
	end
	table.clear(destroyable)
	
	for _, conn in conns do
		conn:Disconnect()
	end
	table.clear(conns)
	
	for _, thread in threads do
		if coroutine.status(thread) == "dead" then continue end
		task.cancel(thread)
	end
	table.clear(threads)
	
	for _, callback in callbacks do
		callback()
	end
	table.clear(callbacks)
	
	for _, entry in custom do
		local object = entry.object
		local callback = entry.callback
		if callback then callback(object) end
	end
	table.clear(custom)
	
	for _, entry in keyed do
		cleanEntry(entry)
	end
	table.clear(keyed)
end

local function destroy(self: Broom)
	cleanup(self)
	local linkConn = self._linkConn
	if linkConn then linkConn:Disconnect() end
	table.clear(self)
end

local function linkToInstance(self: Broom, instance: Instance)
	local currConn = self._linkConn
	if currConn then currConn:Disconnect() end
	self._linkConn = instance.Destroying:Once(function()
		self._linkConn = nil
		cleanup(self)
	end)
end

local function new(): Broom
	return {
		add = add,
		pop = pop,
		remove = remove,
		cleanup = cleanup,
		destroy = destroy,
	
		_keyed = {},
		_destroyable = {},
		_connections = {},
		_threads = {},
		_callbacks = {},
		_custom = {},
		
		_linkConn = nil,
	}
end

return {new = new}
