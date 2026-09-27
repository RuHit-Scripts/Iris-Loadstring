local Iris = loadstring(game:HttpGet("https://raw.githubusercontent.com/RuHit-Scripts/Iris-Loadstring/main/bundle.lua"))()
Iris.Init()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local espOn = Iris.State(false)
local showBoxes = Iris.State(true)
local showNames = Iris.State(true)
local colorIndex = Iris.State(1)
local colors = {
	Color3.fromRGB(0, 170, 255),
	Color3.fromRGB(255, 60, 60),
	Color3.fromRGB(60, 255, 60),
}
local fov = Iris.State(120)

local function alive(p)
	if p == lp then return false end
	local c = p.Character
	if not c then return false end
	local h = c:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
end

local pool = {}
local function get(kind)
	pool[kind] = pool[kind] or {}
	for _, o in ipairs(pool[kind]) do
		if not o.inUse then
			o.inUse = true
			return o.obj
		end
	end
	local obj = Drawing.new(kind)
	table.insert(pool[kind], { obj = obj, inUse = true })
	return obj
end
local function reset()
	for _, list in pairs(pool) do
		for _, o in ipairs(list) do
			o.inUse = false
			o.obj.Visible = false
		end
	end
end

RunService.RenderStepped:Connect(function()
	reset()
	if not espOn.value then return end
	local col = colors[colorIndex.value] or colors[1]
	for _, p in ipairs(Players:GetPlayers()) do
		if alive(p) then
			local pos, on = cam:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
			if on then
				local h = p.Character.HumanoidRootPart.Size.Y * 8 / math.max(pos.Z, 1)
				local w = h * 0.55
				if showBoxes.value then
					local box = get("Square")
					box.Position = Vector2.new(pos.X - w / 2, pos.Y - h / 2)
					box.Size = Vector2.new(w, h)
					box.Color = col
					box.Filled = false
					box.Thickness = 1.4
					box.Visible = true
				end
				if showNames.value then
					local t = get("Text")
					t.Text = p.Name
					t.Position = Vector2.new(pos.X, pos.Y - h / 2 - 16)
					t.Center = true
					t.Outline = true
					t.Color = col
					t.Visible = true
				end
			end
		end
	end
end)

Iris:Connect(function()
	Iris.Window({"Example ESP"})
		if Iris.CollapsingHeader({"ESP"}).opened then
			espOn:set(Iris.Checkbox({"Enable ESP"}).checked)
			Iris.SameLine()
			showBoxes:set(Iris.Checkbox({"Boxes"}).checked)
			Iris.SameLine()
			showNames:set(Iris.Checkbox({"Names"}).checked)
			Iris.Separator()
			local combo = Iris.Combo({ "Color" }, { index = colorIndex })
			Iris.Selectable({ "Blue" }, { index = colorIndex })
			Iris.Selectable({ "Red" }, { index = colorIndex })
			Iris.Selectable({ "Green" }, { index = colorIndex })
			Iris.End()
			combo.changed()
			Iris.Separator()
			local s = Iris.SliderNum({"FOV", 10, 500, fov.value})
			if s.numberChanged() then
				fov:set(math.floor(s.number))
			end
			Iris.Text({ "Current FOV: " .. tostring(fov.value) })
		end
		if Iris.CollapsingHeader({"Info"}).opened then
			Iris.Text({ "Players in server: " .. tostring(#Players:GetPlayers()) })
			Iris.Text({ "Executor: " .. (identifyexecutor and identifyexecutor() or "unknown") })
		end
	Iris.End()
end)
