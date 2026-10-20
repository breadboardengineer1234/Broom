--!optimize 2
--!native

export type Connection<T...> = {
	Connected: boolean,
	Disconnect: (self: Connection<T...>) -> (),
}

export type Signal<T...> = {
	new: () -> Signal<T...>,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local threads: {thread} = {}

local Signal = {}
local Conn = {}
Signal.__index = Signal
Conn.__index = Conn

local function runCallback(callback, thread, ...)
	callback(...)
	threads[#threads + 1] = thread
end

local function yieldThread()
	while true do
		runCallback(coroutine.yield())
	end
end

local function new<T...>(): Signal<T...>
	return setmetatable({_head = nil}, Signal)
end

local function connect<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection<T...>
	local head = self._head
	local node = {
		Connected = true, 
		_callback = callback, 
		_next = nil, 
		_prev = nil,
		_signal = self,
	}
	
	if head then
		head._prev = node
		node._next = head
	end
	self._head = node
	
	return setmetatable(node, Conn)
end

local function disconnect<T...>(self: Connection<T...>)
	if not self.Connected then return end
	self.Connected = false	
	if self._prev == nil then --head
		local nextNode = self._next
		if nextNode then
			nextNode._prev = nil
		end
		self._signal._head = nextNode
	else
		local prev = self._prev
		local nextNode = self._next
		prev._next = nextNode
		
		if nextNode then
			nextNode._prev = prev
		end
	end
end

local function disconnectAll<T...>(self: Signal<T...>)
	local node = self._head
	while node ~= nil do
		disconnect(node)
		node = node._next
	end
end

local function once<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection<T...>
	local conn 
	conn = connect(self, function(...)
		disconnect(conn)
		callback(...)
	end)
	return conn
end

local function wait<T...>(self: Signal<T...>): T...
	local cor = coroutine.running()
	local conn
	conn = connect(self, function(...)
		disconnect(conn)
		if coroutine.status(cor) == "suspended" then
			task.spawn(cor, ...)
		end
	end)
	return coroutine.yield()
end

local function fire<T...>(self: Signal<T...>, ...: T...)
	local node = self._head
	while node ~= nil do
		local numThreads = #threads
		local thread
		if numThreads > 0 then
			thread = threads[numThreads]
			threads[numThreads] = nil
		else
			thread = coroutine.create(yieldThread)
			coroutine.resume(thread)
		end		
		task.spawn(thread, node._callback, thread, ...)
		node = node._next
	end
end

Signal.new = new
Signal.Connect = connect
Signal.Fire = fire
Signal.Once = once
Signal.Wait = wait
Signal.DisconnectAll = disconnectAll

Conn.Disconnect = disconnect

return Signal
