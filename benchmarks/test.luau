--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local packages = ReplicatedStorage.Scripts.Packages
local Broom = require(packages.Broom)
local Signal = require(packages.UsefulSignal)
local Janitor = require(packages.Janitor)
local Trove = require(packages.Trove)
local Maid = require(packages.Maid)
local Scythe = require(packages.Scythe)

local modules = {	
	Janitor = {
		new = Janitor.new,		
		addMethod = function(cleanObj: Janitor.Janitor, object: any)
			cleanObj:Add(object, "Disconnect")
		end,
		cleanup = "Cleanup",		
		destroy = "Destroy",
	},

	Trove = {
		new = Trove.new,	
		add = "Add",		
		cleanup = "Clean",		
		destroy = "Destroy",
	},

	Maid = {
		new = Maid.new,		
		add = "GiveTask",	
		cleanup = "DoCleaning",		
		destroy = "Destroy",
	},

	Broom = {
		new = Broom.new,
		add = "add",		
		cleanup = "cleanup",		
		destroy = "destroy",
	},

	Scythe = {
		new = Scythe.scope,

		addMethod = function(cleanObj: Scythe.Scope, object: any)
			Scythe.add(cleanObj, object)
		end,

		cleanupMethod = function(cleanObj: Scythe.Scope)
			Scythe.clean(cleanObj)
		end,

		destroyMethod = function(cleanObj: Scythe.Scope)
			Scythe.destroy(cleanObj)
		end,
	},
}

local function getMethod(name: string, cleanObj: any, methodName: string, methodName2: string)
	local info = modules[name]
	local method = info[methodName]
	if method then
		method = cleanObj[method]
	else
		method = info[methodName2]
	end
	return method
end

local function add(name: string, amount: number): number
	local info = modules[name]
	local cleanObj = info.new()
	local add = getMethod(name, cleanObj, "add", "addMethod")
	local destroy = getMethod(name, cleanObj, "destroy", "destroyMethod")
	local total = 0

	for i = 1, amount do
		local signal = Signal.new()
		local conn = signal:Connect(function()

		end)
		local t0 = os.clock()
		add(cleanObj, conn)
		total += os.clock() - t0
	end
	destroy(cleanObj)
	return total
end

local function cleanup(name: string, amount: number): number
	local info = modules[name]
	local cleanObj = info.new()
	local add = getMethod(name, cleanObj, "add", "addMethod")
	local cleanup = getMethod(name, cleanObj, "cleanup", "cleanupMethod")

	for i = 1, amount do
		local item = {Disconnect = function() end}
		add(cleanObj, item)
	end

	local t0 = os.clock()
	cleanup(cleanObj)
	return os.clock() - t0
end

local tests = {
	add = add,
	cleanup = cleanup,
}

local function test(name: string, testName: string, amount: number)
	local testFunc = tests[testName]	
	local duration = testFunc(name, amount)
	local txt = string.format("[%s] [%s]: %.5fs", name, testName, duration)
	print(txt)
	return duration
end

local function gcTest(name: string, count: number, iterations: number, duration: number)
	local objects = table.create(count)
	for i = 1, count do
		objects[i] = {Disconnect = function() end}
	end

	local info = modules[name]
	local new = info.new

	local numFrames = 0
	local elapsed = 0

	local conn = RunService.Heartbeat:Connect(function(dt)		
		for i = 1, iterations do
			local cleanObj = new()
			local add = getMethod(name, cleanObj, "add", "addMethod")
			local destroy = getMethod(name, cleanObj, "destroy", "destroyMethod")
			for _, obj in objects do
				add(cleanObj, obj)
			end
			destroy(cleanObj)
		end

		numFrames += 1
		elapsed += dt
	end)

	task.wait(duration)
	conn:Disconnect()
	print(string.format("[%s] [%s] FPS: %.3f", name, "gc", numFrames / elapsed))
end

local function bench(count: number, runAddCleanupTest: boolean?, runGCTest: boolean?)
	if runAddCleanupTest ~= false then
		local addTimes = {}
		local cleanupTimes = {}

		print("====Add Test====")
		for name, _ in modules do
			task.wait(1)
			local duration = test(name, "add", count)
			addTimes[name] = duration
		end

		print("\n====Cleanup Test====")
		task.wait(2)

		for name, _ in modules do
			task.wait(1)
			local duration = test(name, "cleanup", count)
			cleanupTimes[name] = duration
		end

		print("\n====Total Time====")
		for name, _ in modules do
			local total = addTimes[name] + cleanupTimes[name]
			local txt = string.format("[%s] [%s]: %.5fs", name, "Total time", total)
			print(txt)
		end
	end

	if runGCTest ~= false then	
		print("\n====GC Test====")
		for name, _ in modules do
			task.wait(3)
			gcTest(name, 10000, 10, 10)
		end
	end
end

task.wait(3)
bench(100000, true, true)




