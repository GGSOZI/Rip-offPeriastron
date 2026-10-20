--[[
	Rip-off Rainbow Pariastron OMEGA v6 - CLIENT-SIDE
	Execute once. Gives "Rip-off Rainbow Pariastron OMEGA" to your Backpack (re-given every respawn).
	Equip it and the buttons appear. Click / tap the screen = swing the sword (swing animation + small slash).

	  [Nova]         (Z)  the style's main ability (see below)
	  [Angel's Past] (X)  1st press: leave a statue / 2nd press: teleport back + shockwave, 80% -> 30% of NPC max health by distance
	  [Lunge]        (V)  dash forward, cutting through NPCs on the way
	  [Second]       (F)  the style's second ability
	  [Third]        (G)  the style's third ability: Shadow Tendrils / Seraph Wings / Chrono Rupture / Gamma Cyclone / Crystal Prism / Blood Moon / Midas Shatter
	  [Sim radius]   (T)  cycles SimulationRadius 50 > 500 > 1000 > 5000 > 10000 (needs sethiddenproperty)
	  [Style]        (B)  cycles the Periastron: Noir Psi > Ivory > Azure Alpha > Chartreuse Gamma > Amethyst Kappa > Crimson Mu > Grimgold Beta
	  [Destructive]  (C)  right above the Style button: bigger, faster, deadlier version of whichever style is picked

	  Style             Nova (Z)            Second (F)
	  Noir Psi          Black Hole          Lights Out
	  Ivory             Heaven's Ascension  Judgement
	  Azure Alpha       Phantom Slash       Sword Prison
	  Chartreuse Gamma  Green Forcefield    Green Laser
	  Amethyst Kappa    Amethyst Comet      Meteoroids
	  Crimson Mu        Crimson Pillars     Crescent Wave
	  Grimgold Beta     Sonar               Echo Strike

	NPC DAMAGE: every ability hurts NPCs (any Humanoid model that is not a player). Damage = % of the NPC's max health per hit (kept low so abilities don't one-shot; Noir destructive is the exception). EXECUTE: any attack on an NPC at or under 10% health kills it instantly.
	Noir Black Hole: NPCs + owned parts are dragged up into an End-portal style void, then it explodes: 100% (center) -> 10% (edge) of max health,
	everything is launched away. Destructive Noir = instant kill for everything in range.
	Unanchored parts you have NETWORK OWNERSHIP of are pushed / pulled / launched by the abilities too.
	Your own character and other players are never damaged or pushed.

	Sounds: charge-ups, dash, black hole and crimson laser use the Roblox audio IDs in the SFX table.
	Run again to replace the old copy.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")

local player = Players.LocalPlayer

local TOOL_NAME = "Rip-off Rainbow Pariastron OMEGA"
local LEGACY_NAMES = { "Rip-off Ivory Pariastron" }
local STATUE_NAME = "Angel's Past"
local ACT = {
	nova = "IvoryNova", statue = "IvoryStatue", mode = "IvoryMode",
	step = "IvoryStep", theme = "IvoryTheme", judge = "IvoryJudge", third = "IvoryThird", sim = "IvorySim",
}

local TAU = math.pi * 2
local rand = math.random
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local NEON = Enum.Material.Neon
local V3 = Vector3.new

---------------------------------------------------------------- cleanup of old run
local connections, ownedInstances = {}, {}

local function cleanup()
	for _, c in ipairs(connections) do pcall(c.Disconnect, c) end
	for _, i in ipairs(ownedInstances) do pcall(i.Destroy, i) end
	table.clear(connections)
	table.clear(ownedInstances)
	for _, name in pairs(ACT) do pcall(CAS.UnbindAction, CAS, name) end
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		for _, nm in ipairs({ TOOL_NAME, table.unpack(LEGACY_NAMES) }) do
			local old = holder and holder:FindFirstChild(nm)
			if old then old:Destroy() end
		end
	end
end

if getgenv then
	local env = getgenv()
	if env.IvoryCleanup then pcall(env.IvoryCleanup) end
	env.IvoryCleanup = cleanup
end
cleanup()

---------------------------------------------------------------- config
local CHARGE_TIME = 1.5
local RANGE_NORMAL = 1000 -- aim / scan range, normal mode
local RANGE_BIG = 3000 -- aim / scan range, destructive mode
local METEOR_TIME = 1.2
local METEOR_FAR = 3200
local METEOR_HIGH = 1700
local METEOR_CURVE = 450
local BLAST_RADIUS = 36
local SHARD_COUNT = 20
local FLASH_RANGE = 170

local STATUE_COOLDOWN = 0.6
local STEP_DISTANCE = 70
local STEP_COOLDOWN = 2.5
local JUDGE_COOLDOWN = 6
local GRAVITY = 140
local SHELL_TRANSPARENCY = 0.5
local STATUE_DOT_RATE = 22 -- dots spawned per second across the whole statue
local TOUCH_BUTTON_DISTANCE = 2.7 -- x jump-button size

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFD700")

---------------------------------------------------------------- styles (the 7 Periastrons) / palettes
-- pal = { bright, mid-tone, base }
local function hex(h) return Color3.fromHex(h) end

local STYLES = {
	{ id = "noir", name = "Noir Periastron Psi", short = "Noir Psi", q = "Black Hole", e = "Lights Out", u = "Shadow Tendrils", step = "Shadow Lunge",
		dark = true, pal = { hex("B4B4C8"), hex("55556A"), hex("08080C") }, glow = hex("9A9AB8") },
	{ id = "ivory", name = "Ivory Periastron", short = "Ivory", q = "Heaven's Ascension", e = "Judgement", u = "Seraph Wings", step = "Halo Step",
		pal = { hex("87CEEB"), hex("6495ED"), WHITE }, glow = hex("EAFBFF"), accent = GOLD, flash = WHITE },
	{ id = "azure", name = "Azure Periastron Alpha", short = "Azure Alpha", q = "Phantom Slash", e = "Sword Prison", u = "Chrono Rupture", step = "Azure Lunge",
		pal = { hex("8FD8FF"), hex("2F7BFF"), hex("0A2C8C") }, glow = hex("A5E4FF") },
	{ id = "chartreuse", name = "Chartreuse Periastron Gamma", short = "Chartreuse Gamma", q = "Green Forcefield", e = "Green Laser", u = "Gamma Cyclone", step = "Green Lunge",
		pal = { hex("CCFF66"), hex("5BD63B"), hex("0B6B22") }, glow = hex("DFFF8F") },
	{ id = "amethyst", name = "Amethyst Periastron Kappa", short = "Amethyst Kappa", q = "Amethyst Comet", e = "Meteoroids", u = "Crystal Prism", step = "Amethyst Dash",
		pal = { hex("E0B0FF"), hex("9B4DFF"), hex("3B0B7C") }, glow = hex("E8C0FF") },
	{ id = "crimson", name = "Crimson Periastron Mu", short = "Crimson Mu", q = "Crimson Pillars", e = "Crescent Wave", u = "Blood Moon", step = "Crimson Lunge",
		pal = { hex("FF8080"), hex("E0132D"), hex("640010") }, glow = hex("FF5050") },
	{ id = "grimgold", name = "Grimgold Periastron Beta", short = "Grimgold Beta", q = "Sonar", e = "Echo Strike", u = "Midas Shatter", step = "Gold Lunge",
		pal = { hex("FFE070"), hex("FF9A1F"), hex("8A4A00") }, glow = hex("FFB62E") },
}

-- two modes per style: normal (x1) and destructive (x5.4)
local MODES = {}
for i, st in ipairs(STYLES) do
	for d = 1, 2 do
		local big = d == 2
		local p = st.pal
		local m = {
			id = st.id, style = i, big = big, name = st.short .. (big and " Destructive" or ""),
			scale = big and 5.4 or 1, cooldown = big and 2 or 10, dark = st.dark or false,
			pal = p, glow = st.glow, accent = st.accent, mid = p[2], hi = p[1],
		}
		if m.dark then
			m.flash = p[2]
			m.tint = p[1]:Lerp(WHITE, 0.3)
			m.hi = p[1]:Lerp(WHITE, 0.5)
		else
			m.flash = st.flash or p[1]:Lerp(WHITE, 0.7)
			m.tint = WHITE
		end
		MODES[(i - 1) * 2 + d] = m
	end
end

local styleIdx, bigMode = 2, false -- starts on Ivory
local function maxRange() return bigMode and RANGE_BIG or RANGE_NORMAL end
local function mode() return MODES[(styleIdx - 1) * 2 + (bigMode and 2 or 1)] end

---------------------------------------------------------------- helpers
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end

local function ti(t, style, dir) return TweenInfo.new(t, style or ES.Quad, dir or ED.Out) end
local function rf(a, b) return a + rand() * (b - a) end

local function tw(inst, t, goal, style, dir)
	local x = TweenService:Create(inst, ti(t, style, dir), goal)
	x:Play()
	return x
end

local function tweenKill(inst, t, goal, style, dir, life)
	tw(inst, t, goal, style, dir)
	Debris:AddItem(inst, life or (t + 0.1))
end

local FX_DEFAULTS = {
	Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
	CastShadow = false, Material = NEON,
}
local function fxPart(props, parent)
	local p = Instance.new("Part")
	for k, v in pairs(FX_DEFAULTS) do p[k] = v end
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent or workspace
	return p
end

local function colorSeq(pal, i)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, pal[i % 3 + 1]),
		ColorSequenceKeypoint.new(0.5, pal[(i + 1) % 3 + 1]),
		ColorSequenceKeypoint.new(1, pal[(i + 2) % 3 + 1]),
	})
end

-- palette pick; Heaven drops its rare gold accent into every 7th piece
local function pick(m, i)
	if m.accent and i % 7 == 0 then return m.accent end
	return m.pal[i % 3 + 1]
end

local function disc(pos, diameter, thickness, color, transparency, parent)
	return fxPart({
		Shape = Enum.PartType.Cylinder, Color = color, Transparency = transparency,
		Size = V3(thickness, diameter, diameter),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
	}, parent)
end

local function ballPart(pos, size, color, transparency, extra)
	local props = { Shape = Enum.PartType.Ball, Color = color, Transparency = transparency or 0, Size = V3(size, size, size), Position = pos }
	if extra then for k, v in pairs(extra) do props[k] = v end end
	return fxPart(props)
end

local function anchorPart(position, life)
	local a = fxPart({ Transparency = 1, Size = Vector3.one, Position = position })
	Debris:AddItem(a, life or 5)
	return a
end

local function shockwave(pos, radius, duration, delay, color)
	local function go()
		local ring = disc(pos + V3(0, 0.3, 0), 2, 0.5, color or WHITE, 0.1)
		tweenKill(ring, duration, { Size = V3(0.15, radius * 2, radius * 2), Transparency = 1 })
	end
	if delay and delay > 0 then task.delay(delay, go) else go() end
end

---------------------------------------------------------------- particle templates (rebuilt per mode)
local fxFolder = Instance.new("Folder")
fxFolder.Name = "StarParticles"
table.insert(ownedInstances, fxFolder)

local EMITTERS = {
	{ name = "Core",       size = 9,   life = { 0.6, 1 },   speed = { 0, 0 },    count = 8 },
	{ name = "Rays_Thick", size = 3.5, life = { 0.5, 0.9 }, speed = { 45, 70 },  count = 40, drag = 2 },
	{ name = "Rays_Thin",  size = 1.2, life = { 0.5, 1.1 }, speed = { 80, 120 }, count = 80, drag = 2 },
	{ name = "Supernova",  size = 11,  life = { 1, 1.8 },   speed = { 25, 40 },  count = 50, drag = 3 },
	{ name = "Stardust",   size = 0.7, life = { 2, 3 },     speed = { 5, 18 },   count = 110 },
	{ name = "Stars",      size = 1.8, life = { 1, 2 },     speed = { 10, 35 },  count = 35 },
}

local function buildFx()
	fxFolder:ClearAllChildren()
	local m = mode()
	local s = m.scale
	for i, cfg in ipairs(EMITTERS) do
		local color = colorSeq(m.pal, i)
		if cfg.name == "Stars" and m.accent then
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, m.accent),
				ColorSequenceKeypoint.new(0.5, WHITE),
				ColorSequenceKeypoint.new(1, m.pal[1]),
			})
		end
		local e = make("ParticleEmitter", {
			Name = cfg.name, Enabled = false, Rate = 0, Color = color,
			LightEmission = m.dark and 0.25 or 1,
			Lifetime = NumberRange.new(cfg.life[1], cfg.life[2]),
			Speed = NumberRange.new(cfg.speed[1] * s, cfg.speed[2] * s),
			SpreadAngle = Vector2.new(360, 360),
			Size = NumberSequence.new(cfg.size * (s ^ 0.7), 0),
			Transparency = NumberSequence.new(m.dark and 0.1 or 0, 1),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			Drag = cfg.drag or 0,
		}, fxFolder)
		e:SetAttribute("EmitCount", math.floor(cfg.count * (s > 1 and 1.7 or 1)))
	end
end
buildFx()

local function burst(parent, names)
	for _, source in ipairs(fxFolder:GetChildren()) do
		if not names or table.find(names, source.Name) then
			local e = source:Clone()
			e.Parent = parent
			e:Emit(source:GetAttribute("EmitCount") or 20)
		end
	end
end

---------------------------------------------------------------- tool template (YOUR sword - unchanged look)
local template = Instance.new("Tool")
template.Name = TOOL_NAME
template.ToolTip = "Click = swing  |  Nova [Z]  |  Angel's Past [X]  |  Destructive [C]  |  Lunge [V]  |  Style [B]  |  Second ability [F]  |  Third ability [G]  |  Sim radius [T]"
template.TextureId = "rbxassetid://157345185" -- inventory icon (the sword texture)
template.CanBeDropped = false
template.RequiresHandle = true
template.Grip = CFrame.new(0, 0, -2) * CFrame.fromOrientation(0, math.rad(-90), math.rad(-90))
table.insert(ownedInstances, template)

local handle = make("Part", {
	Name = "Handle", Size = V3(2, 2, 6), CanCollide = false,
	BottomSurface = Enum.SurfaceType.Smooth, TopSurface = Enum.SurfaceType.Smooth,
}, template)

make("SpecialMesh", {
	MeshType = Enum.MeshType.FileMesh, MeshId = "rbxassetid://80557857",
	TextureId = "rbxassetid://157345185", Scale = Vector3.one,
}, handle)

-- blade runs along the handle's Z axis; swap the sign of these if the tip is on the other end
local topTrail = make("Attachment", { Name = "TopTrail", Position = V3(0, 0, -3) }, handle)
local bottomTrail = make("Attachment", { Name = "BottomTrail", Position = V3(0, 0, 0.5) }, handle)
make("Attachment", { Name = "ChargeAttachment", Position = V3(0, 0, -3) }, handle)

make("Trail", {
	Name = "Trail", Attachment0 = topTrail, Attachment1 = bottomTrail, Lifetime = 0.35,
	Color = colorSeq(MODES[1].pal, 0), Transparency = NumberSequence.new(0.2, 1),
	LightEmission = 1, FaceCamera = true, Enabled = false,
}, handle)

make("PointLight", { Name = "PointLight", Color = MODES[1].glow, Brightness = 1, Range = 8, Shadows = false }, handle)

make("ParticleEmitter", { -- white sparkles streaming off the sword (always white)
	Name = "WhiteSparkles", Color = ColorSequence.new(WHITE), LightEmission = 1, Rate = 20,
	Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(1, 5),
	SpreadAngle = Vector2.new(180, 180),
	Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0),
	}),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
}, handle)

make("ParticleEmitter", { -- faint mode-colored motes (recolored when the mode changes)
	Name = "ModeMotes", Color = colorSeq(MODES[1].pal, 0), LightEmission = 1, Rate = 8,
	Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(1, 3),
	SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.3, 0),
	Transparency = NumberSequence.new(0.2, 1),
}, handle)

local function applyModeToTool(tool)
	local h = tool and tool:FindFirstChild("Handle")
	if not h then return end
	local m = mode()
	local trail, motes, light = h:FindFirstChild("Trail"), h:FindFirstChild("ModeMotes"), h:FindFirstChildOfClass("PointLight")
	if trail then trail.Color = colorSeq(m.pal, 0) end
	if motes then
		motes.Color = colorSeq(m.pal, 1)
		motes.LightEmission = m.dark and 0.3 or 1
	end
	if light then light.Color = m.glow end
end

---------------------------------------------------------------- screen gui + screen effects
local okHui, hui = pcall(function() return gethui and gethui() end)
local guiParent = (okHui and hui) or player:WaitForChild("PlayerGui")

local flashGui = make("ScreenGui", { Name = "IvoryBlind", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10 }, guiParent)
table.insert(ownedInstances, flashGui)

local flashFrame = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
}, flashGui)

local toast = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.12, 0), Size = UDim2.fromOffset(420, 40),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 26,
	TextTransparency = 1, TextStrokeTransparency = 1, Text = "",
}, flashGui)

local toastToken = 0
local function showToast(text, color)
	toastToken += 1
	local my = toastToken
	toast.Text = text
	toast.TextColor3 = color
	toast.TextStrokeColor3 = Color3.new(0, 0, 0)
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(1.6, function()
		if toastToken == my then tw(toast, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 }) end
	end)
end

-- lighting effects are created ONCE and re-used (disabled when idle) instead of spawned per flash
local cc = make("ColorCorrectionEffect", { Enabled = false }, Lighting)
local bloom = make("BloomEffect", { Enabled = false, Intensity = 0, Size = 40, Threshold = 0.7 }, Lighting)
local blur = make("BlurEffect", { Enabled = false, Size = 0 }, Lighting)
table.insert(ownedInstances, cc)
table.insert(ownedInstances, bloom)
table.insert(ownedInstances, blur)

-- sky darkening (Amethyst comet / meteoroids, Noir black hole + Lights Out): tweens the lighting down and back
local skyCC = make("ColorCorrectionEffect", { Enabled = false }, Lighting)
table.insert(ownedInstances, skyCC)
local skyBase, skyToken = nil, 0

local function skyOn(strength, tint, dur)
	skyToken += 1
	if not skyBase then
		skyBase = {
			ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		}
	end
	local b = skyBase
	local dim = tint:Lerp(Color3.new(0, 0, 0), 0.75)
	tw(Lighting, dur, {
		ClockTime = b.ClockTime > 12 and 24 or 0,
		Brightness = b.Brightness * (1 - 0.75 * strength),
		Ambient = b.Ambient:Lerp(dim, strength),
		OutdoorAmbient = b.OutdoorAmbient:Lerp(dim, strength),
	})
	skyCC.Enabled = true
	tw(skyCC, dur, { Brightness = -0.28 * strength, Saturation = -0.25 * strength, TintColor = WHITE:Lerp(tint, 0.45 * strength) })
end

local function skyOff(dur)
	local my = skyToken
	local b = skyBase
	if not b then return end
	tw(Lighting, dur, { ClockTime = b.ClockTime, Brightness = b.Brightness, Ambient = b.Ambient, OutdoorAmbient = b.OutdoorAmbient })
	tw(skyCC, dur, { Brightness = 0, Saturation = 0, TintColor = WHITE }).Completed:Connect(function()
		if skyToken == my then
			skyCC.Enabled = false
			skyBase = nil
		end
	end)
end

-- if the script is re-run mid-effect, put the lighting back
table.insert(connections, { Disconnect = function()
	if skyBase then
		for k, v in pairs(skyBase) do pcall(function() Lighting[k] = v end) end
		skyBase = nil
	end
end })

local function strengthAt(position, m)
	local camera = workspace.CurrentCamera
	if not camera then return 0 end
	local range = FLASH_RANGE * math.sqrt(m and m.scale or 1)
	return math.clamp(1 - (camera.CFrame.Position - position).Magnitude / range, 0, 1)
end

local flashToken = 0
local function flash(position, scale, m)
	m = m or mode()
	local strength = strengthAt(position, m) * (scale or 1)
	if strength <= 0 then return end
	flashToken += 1
	local my = flashToken

	flashFrame.BackgroundColor3 = m.flash
	flashFrame.BackgroundTransparency = 1 - strength * (m.dark and 0.85 or 1)
	tw(flashFrame, 1.6, { BackgroundTransparency = 1 })

	cc.Enabled = true
	cc.Brightness = (m.dark and -0.25 or 0.35) * strength
	cc.TintColor = m.dark and m.tint or WHITE
	tw(cc, 1.8, { Brightness = 0, TintColor = WHITE })

	if strength > 0.15 then
		bloom.Enabled, blur.Enabled = true, true
		bloom.Intensity = (m.dark and 0.8 or 1.5) * strength
		blur.Size = 22 * strength
		tw(bloom, 2, { Intensity = 0 })
		tw(blur, 0.9, { Size = 0 })
	end
	task.delay(2.2, function()
		if flashToken == my then cc.Enabled, bloom.Enabled, blur.Enabled = false, false, false end
	end)
end

local function fovPunch(amount, dur)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local base = cam.FieldOfView
	local up = TweenService:Create(cam, ti(0.08), { FieldOfView = math.min(base + amount, 120) })
	up.Completed:Connect(function() tw(cam, dur, { FieldOfView = base }) end)
	up:Play()
end

local function shake(duration, magnitude)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if not hum.Parent then conn:Disconnect() return end
		if t >= duration then
			conn:Disconnect()
			hum.CameraOffset = Vector3.zero
			return
		end
		local fall = 1 - t / duration
		hum.CameraOffset = V3((rand() - 0.5) * magnitude * fall, (rand() - 0.5) * magnitude * fall, 0)
	end)
end

---------------------------------------------------------------- flung ground chunks (client-only, untouchable)
-- Chunks are anchored + non-collidable and moved by ONE ballistic step per frame, written with a single BulkMoveTo.
local debrisFolder = make("Folder", { Name = "IvoryDebris" }, workspace)
table.insert(ownedInstances, debrisFolder)
local flung, flingConn = {}, nil
local bulkP, bulkC = {}, {}

local function flingStep()
	local now = os.clock()
	local n = 0
	table.clear(bulkP)
	table.clear(bulkC)
	for i = #flung, 1, -1 do
		local it = flung[i]
		local p = it.part
		if not p.Parent then
			table.remove(flung, i)
		else
			local el = now - it.t0
			if el < it.tl then
				n += 1
				bulkP[n] = p
				bulkC[n] = CFrame.new(it.p0 + it.v * el + V3(0, -0.5 * GRAVITY * el * el, 0))
					* CFrame.Angles(it.spin.X * el, it.spin.Y * el, it.spin.Z * el) * it.rot
			else
				if not it.landed then
					it.landed = true
					local pos = it.p0 + it.v * it.tl
					p.CFrame = CFrame.new(pos.X, it.p0.Y - p.Size.Y * 0.2, pos.Z)
						* CFrame.Angles(it.spin.X * it.tl, it.spin.Y * it.tl, it.spin.Z * it.tl) * it.rot
				end
				local a = (el - (it.tl + it.life)) / 1.2
				if a >= 1 then
					p:Destroy()
					table.remove(flung, i)
				elseif a > 0 then
					p.Transparency = a
				end
			end
		end
	end
	if n > 0 then workspace:BulkMoveTo(bulkP, bulkC, Enum.BulkMoveMode.FireCFrameChanged) end
	if #flung == 0 and flingConn then
		flingConn:Disconnect()
		flingConn = nil
	end
end

-- part must already be parented to debrisFolder
local function flingPart(p, vel, spin, life)
	table.insert(flung, {
		part = p, p0 = p.Position, rot = p.CFrame - p.Position,
		v = vel, spin = spin, t0 = os.clock(),
		tl = 2 * math.max(vel.Y, 5) / GRAVITY, life = life or 2.5,
	})
	if not flingConn then
		flingConn = RunService.Heartbeat:Connect(flingStep)
		table.insert(connections, flingConn)
	end
end

local function rayParams(...)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { debrisFolder, ... }
	return params
end

-- rips chunks out of the real ground (same color + material) and flings them away
local function flingGround(position, R, s)
	local sc = math.sqrt(s)
	local params = rayParams(player.Character)
	local terrain = workspace.Terrain
	for _ = 1, (s > 1 and 170 or 46) do
		local ang = rand() * TAU
		local r = R * math.sqrt(rand()) * 0.85
		local hit = workspace:Raycast(position + V3(math.cos(ang) * r, 60, math.sin(ang) * r), V3(0, -220, 0), params)
		if hit and not hit.Instance:FindFirstAncestor(STATUE_NAME) then
			local inst = hit.Instance
			local color = Color3.fromRGB(110, 110, 110)
			if inst:IsA("Terrain") then color = terrain:GetMaterialColor(hit.Material)
			elseif inst:IsA("BasePart") then color = inst.Color end
			local size = V3(rf(1.2, 3.6) * sc, rf(0.8, 2.6) * sc, rf(1.2, 3.6) * sc)
			local chunk = fxPart({
				Name = "GroundChunk", Material = hit.Material, Color = color, Size = size, CastShadow = true,
				CFrame = CFrame.new(hit.Position + V3(0, size.Y / 2, 0)) * CFrame.Angles(rand() * TAU, rand() * TAU, rand() * TAU),
			}, debrisFolder)
			local out = rf(35, 110) * sc * (1.15 - 0.5 * (r / R))
			local vel = V3(math.cos(ang), 0, math.sin(ang)) * out + V3(rf(-12, 12), rf(55, 150) * sc, rf(-12, 12))
			flingPart(chunk, vel, V3(rf(-6, 6), rf(-6, 6), rf(-6, 6)), rf(2, 3.5))
		end
	end
end

---------------------------------------------------------------- shared world effects
local function pillar(position, diam, color, trans, dur)
	local p = fxPart({
		Shape = Enum.PartType.Cylinder, Color = color, Transparency = trans,
		Size = V3(400, diam, diam),
		CFrame = CFrame.new(position + V3(0, 200, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tweenKill(p, dur, { Size = V3(400, 1, 1), Transparency = 1 }, ES.Quad, ED.In)
end

local function scorch(position, R, m)
	local a = disc(position + V3(0, 0.15, 0), R * 1.5, 0.1, m.dark and m.pal[3] or m.pal[1], 0.2)
	tweenKill(a, 4, { Transparency = 1 }, ES.Sine, ED.In)
	local b = disc(position + V3(0, 0.2, 0), R * 0.9, 0.1, m.mid, 0.3)
	tweenKill(b, 3, { Transparency = 1 }, ES.Sine, ED.In)
end

local function cracks(position, R, m, n)
	for i = 1, n do
		local len = R * rf(0.8, 1.3)
		local base = CFrame.new(position + V3(0, 0.2, 0)) * CFrame.Angles(0, (i / n) * TAU + rand() * 0.2, 0)
		local c = fxPart({ Color = pick(m, i), Size = V3(0.5, 0.12, 1), CFrame = base * CFrame.new(0, 0, -0.5) })
		tw(c, 0.4, { Size = V3(0.5, 0.12, len), CFrame = base * CFrame.new(0, 0, -len / 2) }).Completed:Connect(function()
			tw(c, 2.2, { Transparency = 1 }, ES.Sine, ED.In)
		end)
		Debris:AddItem(c, 3)
	end
end

---------------------------------------------------------------- MAGIC CIRCLE (the telegraph that shows before the Nova lands)
-- One flat invisible part carries a SurfaceGui. The rings / ticks / octagram are UI frames, so the whole
-- circle is a handful of instances. Rotation speeds up while charging and goes white-hot when it locks on.
local function magicCircle(pos, R, m, dur)
	local sq = math.sqrt(m.scale)
	local c1 = m.dark and m.glow or m.pal[1]
	local c2 = m.mid
	local c3 = m.dark and m.hi or WHITE
	local accent = m.accent or c3
	local canvas = 1024
	local u = canvas / (2 * R) * sq
	local function th(studs) return math.max(2, math.floor(studs * u + 0.5)) end

	local base = fxPart({ Size = V3(R * 2, 0.05, R * 2), Position = pos + V3(0, 0.25, 0), Transparency = 1 })
	Debris:AddItem(base, dur + 8)
	local gui = make("SurfaceGui", {
		Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(canvas, canvas), LightInfluence = 0, Brightness = 2,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, base)

	local function frame(parent, size, rot)
		return make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(size, size), Rotation = rot or 0,
			BackgroundTransparency = 1, BorderSizePixel = 0,
		}, parent)
	end
	local lockables = {}
	local function stroke(f, thick, color, trans, round)
		if round then make("UICorner", { CornerRadius = UDim.new(1, 0) }, f) end
		local st = make("UIStroke", { Color = color, Thickness = thick, Transparency = trans }, f)
		table.insert(lockables, st)
		return st
	end

	local root = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0,
	}, gui)
	tw(root, 0.45, { Size = UDim2.fromScale(1, 1) }, ES.Back)

	-- outer double ring
	local outerStroke = stroke(frame(root, 1), th(1.1), c1, 0.05, true)
	stroke(frame(root, 0.965), th(0.35), c2, 0.35, true)

	-- tick ring (every 6th tick is long + accent colored)
	local tickRing = frame(root, 0.9)
	for i = 1, 36 do
		local long = i % 6 == 1
		local holder = frame(tickRing, 1, (i - 1) * 10)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(th(0.35), th(long and 3 or 1.5)),
			BackgroundColor3 = long and accent or c1, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		}, holder)
	end

	-- mid ring with 4 diamond nodes
	local midRing = frame(root, 0.78)
	stroke(midRing, th(0.4), c2, 0.15, true)
	for i = 0, 3 do
		local holder = frame(midRing, 1, i * 90)
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(th(2.2), th(2.2)), Rotation = 45,
			BackgroundColor3 = i % 2 == 0 and accent or c1, BorderSizePixel = 0,
		}, holder)
	end

	-- counter-rotating octagram (two squares)
	local star1 = frame(root, 0.54, 0)
	stroke(star1, th(0.35), c1, 0.1)
	local star2 = frame(root, 0.54, 45)
	stroke(star2, th(0.35), c3, 0.1)

	-- inner rings + center diamond
	local innerStroke = stroke(frame(root, 0.34), th(0.5), c1, 0.1, true)
	stroke(frame(root, 0.2), th(0.3), c3, 0.2, true)
	stroke(frame(root, 0.07, 45), th(0.6), c3, 0)

	-- radar sweep
	local sweep = frame(root, 1)
	local line = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, th(0.5), 0.5, 0), BackgroundColor3 = c3, BorderSizePixel = 0,
	}, sweep)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }),
	}, line)

	-- targeting column of light rising from the center
	local d = 1.2 * sq
	local column = disc(pos + V3(0, 0.1, 0), d, 0.1, c3, 0.35)
	column.CFrame = CFrame.new(pos + V3(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Size = V3(0.1, d, d)
	tw(column, dur, { Size = V3(160, d, d), CFrame = CFrame.new(pos + V3(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, ES.Quad, ED.In)
	Debris:AddItem(column, dur + 8)

	-- geyser of sparks up the column
	local sparks = make("ParticleEmitter", {
		Color = colorSeq(m.pal, 1), LightEmission = m.dark and 0.5 or 1, Rate = 34 * sq,
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(18 * sq, 40 * sq),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(18, 18),
		Size = NumberSequence.new(0.5 * sq, 0), Transparency = NumberSequence.new(0.1, 1),
	}, base)

	local t0, locked = os.clock(), false
	local aT, aM, aS, aW = 0, 0, 0, 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		local k = math.min(t / dur, 1)
		local boost = locked and 4 or (1 + k * 2)
		aT += dt * 40 * boost
		aM += dt * 55 * boost
		aS += dt * 70 * boost
		aW += dt * 180 * boost
		tickRing.Rotation = aT
		midRing.Rotation = -aM
		star1.Rotation = aS
		star2.Rotation = 45 - aS
		sweep.Rotation = aW
		local pulse = 0.5 + 0.5 * math.sin(t * (locked and 24 or 7 + k * 8))
		outerStroke.Transparency = 0.05 + 0.3 * pulse
		innerStroke.Transparency = 0.1 + 0.4 * (1 - pulse)
	end)
	table.insert(connections, conn)

	local circle = {}
	function circle.lock()
		locked = true
		for _, st in ipairs(lockables) do tw(st, 0.12, { Color = WHITE }) end
		tw(column, 0.2, { Size = V3(160, d * 2.2, d * 2.2) })
		tw(root, 0.1, { Size = UDim2.fromScale(1.05, 1.05) }).Completed:Connect(function()
			if root.Parent then tw(root, 0.25, { Size = UDim2.fromScale(1, 1) }, ES.Back) end
		end)
		shockwave(pos, R * 1.15, 0.45, 0, WHITE)
	end
	function circle.destroy()
		conn:Disconnect()
		sparks.Enabled = false
		base:Destroy()
		column:Destroy()
	end
	return circle
end

---------------------------------------------------------------- Supernova impact
local function explode(position, m)
	local s, pal = m.scale, m.pal
	local big, dark = s > 1, m.dark
	local R = BLAST_RADIUS * s
	local sq = math.sqrt(s)
	local HOLD, FADE = 3, 2.5 -- the explosion bubble holds ~3s, then fades out slowly

	burst(anchorPart(position))

	-- big light flash on the ground
	local lt = make("PointLight", {
		Color = m.glow, Brightness = dark and 12 or 25, Range = math.min(R * 2, 60), Shadows = false,
	}, anchorPart(position + V3(0, 4, 0), 0.9 + HOLD + FADE + 0.5))
	tw(lt, 0.9 + HOLD + FADE, { Brightness = 0 }, ES.Sine, ED.InOut)

	-- layered fireballs (one per palette color)
	for i = 1, 3 do
		local ball = ballPart(position, 2, pal[i], 0.1)
		tweenKill(ball, 0.6 + i * 0.15, { Size = Vector3.one * R * (1.9 - i * 0.35), Transparency = 1 }, nil, nil, 1.2)
	end

	-- void modes: a black core that swells then collapses
	if dark then
		local void = ballPart(position + V3(0, R * 0.15, 0), 2, pal[3], 0, { Material = Enum.Material.SmoothPlastic })
		tw(void, 0.45, { Size = Vector3.one * R * 1.1 }).Completed:Connect(function()
			tw(void, 0.55, { Size = Vector3.one * 0.5, Transparency = 1 }, ES.Quad, ED.In)
		end)
		Debris:AddItem(void, 1.3)
	end

	-- the explosion bubble: swells, HOLDS for ~3s with lightning arcing inside, then slowly fades
	local bubbleR = R * 1.15
	local bubbles = {}
	local function bubble(material, color, transparency, finalSize)
		local p = ballPart(position, 2, color, transparency, { Material = material })
		tw(p, 0.9, { Size = Vector3.one * finalSize })
		Debris:AddItem(p, 0.9 + HOLD + FADE + 0.3)
		table.insert(bubbles, p)
	end
	bubble(Enum.Material.ForceField, m.mid, 0, bubbleR * 2)
	if dark then
		bubble(Enum.Material.SmoothPlastic, pal[3], 0.1, bubbleR * 1.9) -- solid body
		bubble(NEON, pal[1], 0.7, bubbleR * 2.05)                       -- rim glow
	else
		bubble(NEON, pal[2], 0.72, bubbleR * 1.9)
		bubble(NEON, WHITE, 0.45, bubbleR * 0.8) -- white heart
		bubble(NEON, pal[1], 0.85, bubbleR * 2.05)
	end
	task.delay(0.9 + HOLD, function()
		for _, p in ipairs(bubbles) do
			if p.Parent then tw(p, FADE, { Transparency = 1 }, ES.Sine, ED.InOut) end
		end
	end)

	-- lightning crawling around inside the bubble while it holds
	local arcAnchor = anchorPart(position + V3(0, bubbleR * 0.2, 0), HOLD + FADE + 1.5)
	local arcs = {}
	for i = 1, (big and 14 or 9) do
		local a0 = make("Attachment", {}, arcAnchor)
		local a1 = make("Attachment", {}, arcAnchor)
		local beam = make("Beam", {
			Attachment0 = a0, Attachment1 = a1,
			Color = ColorSequence.new(dark and (i % 2 == 0 and m.glow or m.hi) or pal[i % 3 + 1]),
			LightEmission = dark and 0.6 or 1, LightInfluence = 0,
			Width0 = 1.2 * sq, Width1 = 0.5 * sq, Segments = 14, FaceCamera = true,
		}, arcAnchor)
		arcs[i] = { a0, a1, beam }
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.9 + HOLD and arcAnchor.Parent do
			for _, arc in ipairs(arcs) do
				local d = V3(rf(-1, 1), rf(-1, 1), rf(-1, 1))
				d = d.Magnitude > 0.1 and d.Unit or Vector3.yAxis
				arc[1].Position = d * bubbleR * 0.08
				arc[2].Position = d * bubbleR * rf(0.75, 1)
				arc[3].CurveSize0 = rf(-1, 1) * bubbleR * 0.5
				arc[3].CurveSize1 = rf(-1, 1) * bubbleR * 0.5
				arc[3].Enabled = rand() > 0.25
			end
			task.wait(0.09)
		end
		for _, arc in ipairs(arcs) do arc[3].Enabled = false end
	end)

	-- crown of light: Heaven = a halo that rises and widens, Void = a ring sucked inward
	local crown = big and 56 or 36
	for i = 1, crown do
		local ang = i / crown * TAU
		local cs, sn = math.cos(ang), math.sin(ang)
		local tangent = V3(-sn, 0, cs)
		local p0, p1
		if dark then
			p0 = position + V3(cs * R * 0.95, 4, sn * R * 0.95)
			p1 = position + V3(cs * R * 0.05, R * 0.5, sn * R * 0.05)
		else
			p0 = position + V3(cs * R * 0.35, 6, sn * R * 0.35)
			p1 = position + V3(cs * R * 0.6, R * 0.9, sn * R * 0.6)
		end
		local piece = fxPart({
			Color = pick(m, i), Size = V3(0.9 * sq, 0.9 * sq, 5 * sq), Transparency = 0.1,
			CFrame = CFrame.lookAt(p0, p0 + tangent),
		})
		tweenKill(piece, 2.8, { CFrame = CFrame.lookAt(p1, p1 + tangent), Transparency = 1 }, ES.Sine, ED.InOut, 3)
	end

	-- ground shockwaves
	local rings = big and 6 or 4
	for i = 1, rings do
		shockwave(position, R * (1.6 - (i - 1) * (1.1 / rings)), 0.7 + i * 0.05, (i - 1) * 0.1, pal[(i - 1) % 3 + 1])
	end

	-- pillars of light
	pillar(position, 18 * s, pal[1], 0.3, 1.5)
	pillar(position, 13 * s, m.mid, 0.35, 1.3)
	pillar(position, 8 * s, dark and m.mid or WHITE, 0.1, 1.1)

	scorch(position, R, m)
	cracks(position, R, m, big and 30 or 18)

	-- spears of light shooting outward
	local thick = 0.5 * sq
	for i = 1, (big and 30 or 16) do
		local start = CFrame.new(position + V3(0, 1.5, 0)) * CFrame.Angles(0, (i / (big and 30 or 16)) * TAU, 0)
			* CFrame.Angles(math.rad(rf(10, 45)), 0, 0)
		local sp = fxPart({ Color = pick(m, i), Size = V3(thick, thick, rf(5, 10) * s), CFrame = start })
		tweenKill(sp, rf(0.9, 1.3), { CFrame = start * CFrame.new(0, 0, -R * rf(0.9, 1.7)), Transparency = 1 }, nil, nil, 1.5)
	end

	-- glowing shards + chunks of the REAL ground flung away (all untouchable)
	for i = 1, (big and 70 or SHARD_COUNT) do
		local size = rf(0.3, 0.7) * sq
		local shard = fxPart({
			Name = "StarShard", Color = pick(m, i), Size = V3(size, size, rf(1.5, 3.2) * sq),
			CFrame = CFrame.new(position + V3(0, 1, 0)) * CFrame.Angles(rand() * TAU, rand() * TAU, rand() * TAU),
		}, debrisFolder)
		flingPart(shard, V3(rf(-1, 1) * 75 * s, rf(40, 110) * sq, rf(-1, 1) * 75 * s), V3(rf(-8, 8), rf(-8, 8), rf(-8, 8)), rf(0.5, 1.5))
	end
	flingGround(position, R, s)

	flash(position, 1, m)
	shake(0.9, 2 * sq)
	fovPunch(8 * sq, 0.7)

	-- destructive modes get a second blast
	if big then
		task.delay(0.55, function()
			burst(anchorPart(position), { "Supernova", "Rays_Thick", "Stars" })
			for i = 1, 4 do shockwave(position, R * (1.3 - i * 0.2), 0.7, (i - 1) * 0.09, pal[i % 3 + 1]) end
			pillar(position, 11 * s, pal[1], 0.4, 0.9)
			flingGround(position, R * 0.8, s * 0.6)
			flash(position, 0.6, m)
			shake(0.6, 1.5)
		end)
	end
end

---------------------------------------------------------------- aiming
local function aimPoint()
	local camera = workspace.CurrentCamera
	local char = player.Character
	if not camera or not char then return nil end
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * maxRange(), rayParams(char))
	return hit and hit.Position or (ray.Origin + ray.Direction * maxRange())
end

local function groundTarget(targetPos, root, character)
	local offset = targetPos - root.Position
	if offset.Magnitude > maxRange() then targetPos = root.Position + offset.Unit * maxRange() end
	local ground = workspace:Raycast(targetPos + V3(0, 50, 0), V3(0, -300, 0), rayParams(character))
	return ground and ground.Position or targetPos
end

local function liveChar()
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and root then return character, hum, root end
end

---------------------------------------------------------------- Heaven's meteor (only the Heaven style calls one down)
local function meteorFlight(targetPos, root, m, sizeMul)
	local s, pal, dark = m.scale, m.pal, m.dark
	-- the meteor: starts VERY far away, flies a curved path, accelerates into the target
	local k = (s ^ 0.6) * (sizeMul or 1)
	local up = Vector3.yAxis
	local flatDir = V3(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
	if flatDir.Magnitude < 1 then
		local r = rand() * TAU
		flatDir = V3(math.cos(r), 0, math.sin(r))
	end
	flatDir = flatDir.Unit
	local P0 = targetPos + flatDir * METEOR_FAR + up * METEOR_HIGH
	local side = flatDir:Cross(up) * (rand() < 0.5 and -1 or 1)
	local P2 = targetPos
	local P1 = (P0 + P2) / 2 + side * METEOR_CURVE + up * 250

	local starCore = ballPart(P0, 8 * k, dark and pal[3] or WHITE, 0)
	local shell1 = ballPart(P0, 13 * k, pal[1], 0.45)
	local shell2 = ballPart(P0, 18 * k, m.mid, 0.75)
	-- the three balls swell 40% on the way in (one tween each instead of a per-frame resize)
	for _, b in ipairs({ starCore, shell1, shell2 }) do
		tw(b, METEOR_TIME, { Size = b.Size * 1.4 }, ES.Quad, ED.In)
	end
	make("PointLight", { Brightness = 10, Range = 60, Color = m.glow }, starCore)

	local dust = fxFolder:FindFirstChild("Stardust")
	if dust then
		local e = dust:Clone()
		e.Rate = 160
		e.LockedToPart = true
		e.Enabled = true
		e.Parent = starCore
	end

	local tailLen = 650 * k
	local tail = fxPart({
		Shape = Enum.PartType.Cylinder, Color = m.mid, Transparency = 0.4,
		Size = V3(tailLen, 4 * k, 4 * k), Position = P0,
	})
	local tail2 = fxPart({
		Shape = Enum.PartType.Cylinder, Color = dark and pal[1] or WHITE, Transparency = 0.15,
		Size = V3(tailLen * 0.7, 1.8 * k, 1.8 * k), Position = P0,
	})
	local flight = { starCore, shell1, shell2, tail, tail2 }
	local flightCFs = {}
	local rot90 = CFrame.Angles(0, math.rad(90), 0)

	local tStart = os.clock()
	while true do
		local raw = math.min((os.clock() - tStart) / METEOR_TIME, 1)
		local u = raw ^ 1.5 -- accelerates toward the target
		local pos = (1 - u) ^ 2 * P0 + 2 * (1 - u) * u * P1 + u ^ 2 * P2
		local vel = 2 * (1 - u) * (P1 - P0) + 2 * u * (P2 - P1)
		local cf = CFrame.new(pos)
		flightCFs[1], flightCFs[2], flightCFs[3] = cf, cf, cf
		if vel.Magnitude > 0.01 then
			local look = CFrame.lookAt(pos, pos + vel)
			-- the tail is a rigid straight beam pointing straight back along the flight direction
			flightCFs[4] = look * CFrame.new(0, 0, tailLen / 2) * rot90
			flightCFs[5] = look * CFrame.new(0, 0, tailLen * 0.35) * rot90
		end
		workspace:BulkMoveTo(flight, flightCFs, Enum.BulkMoveMode.FireCFrameChanged)
		if raw >= 1 then break end
		RunService.Heartbeat:Wait()
	end

	for _, p in ipairs(flight) do p:Destroy() end
end

---------------------------------------------------------------- SOUNDS
local SFX = {
	charge = 115377603904778,      -- Rainbow Periastron laser: big charge-ups
	smallCharge = 1844684832,      -- Headline News: short charge-ups
	crimsonLoop = 70530513393189,  -- Crimson Periastron laser loop
	bhLaunch = 136676558602030,    -- black hole launch / explosion
	bhLoop = 117145376517208,      -- black hole ambience
	dash = 97563704134676,         -- Destroyer Blast: the dash
	laserBeam = 139620337204036,   -- Laser beam: beams / sustained rushes
	impactExp = 115412246102825,   -- Laser Impact Explosion 2: impacts / explosions
	swing = 131811476310735,       -- lightning crit: the sword swing and cuts
	swordSlash = 7118966167,       -- Sword Slash (RoninMek)
	fireSlash = 6455691350,        -- sword fire slash (Pitaschio)
	thunderHuge = 9126099976,      -- Thunder Constant Huge Hissing Strikes (ProSoundEffects)
	thunderBoom = 9120021541,      -- Thunder Sharp Booming Strikes Rumbling 2 (ProSoundEffects)
	thunderStrike = 6734393210,    -- thunder strike (ClicheChloe)
	magicCast = 93989620006639,    -- Magic Spell Cast (GleonoffG)
	magicCaster = 87633794002285,  -- Magic spell caster (comet_lad)
	whooshBoom = 9120769331,       -- Wind Whoosh Sonic Boom Low End Impact (ProSoundEffects)
	windLoop = 9120698415,         -- Whoosh By Howling Wind Light Rumbling (ProSoundEffects)
	explosion2 = 9114362625,       -- Explosions 2 (ProSoundEffects)
	glass = 139826391278483,       -- glass_shatter_09
	energyCharge = 9125973433,     -- Spaceship Blast High Pitch Energy Charge Up (ProSoundEffects)
	darkCharge = 100719595855360,  -- Dark Energy Charge Up (Hiyori_Komichi)
}

-- preload every sound once so the FIRST use is not delayed while the asset downloads
task.spawn(function()
	local list = {}
	for _, id in pairs(SFX) do
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		list[#list + 1] = s
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(list) end)
	for _, s in ipairs(list) do s:Destroy() end
end)

-- plays a sound. parent = a part/attachment for 3D sound, or nil for a flat (screen) sound.
-- returns the Sound; call stopSfx(sound) to fade it out early.
local function sfx(id, volume, parent, looped, speed)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = volume or 1
	s.Looped = looped or false
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 400
	s.RollOffMinDistance = 30
	s.Parent = parent or flashGui
	s:Play()
	if not looped then Debris:AddItem(s, 12) end
	return s
end

local function stopSfx(s, fade)
	if not s or not s.Parent then return end
	local t = TweenService:Create(s, TweenInfo.new(fade or 0.25), { Volume = 0 })
	t:Play()
	Debris:AddItem(s, (fade or 0.25) + 0.1)
end

---------------------------------------------------------------- NETWORK-OWNED PHYSICS
-- Only UNANCHORED parts this client has NETWORK OWNERSHIP of can be pushed around (props near you, tools you
-- dropped, ...). This client simulates them, so what we write replicates. Characters / NPCs are handled by the
-- NPC functions below instead.
local MAX_ASSEMBLIES = 300
local MAX_SPEED = 420

local function isOwned(part)
	if part.Anchored then return false end
	if isnetworkowner then -- executor helper, exact answer
		local ok, res = pcall(isnetworkowner, part)
		if ok then return res end
	end
	return part.ReceiveAge == 0 -- fallback: a part we simulate is never "received" from the server
end

local function isCharacter(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then return true end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function ownedRoots(position, radius)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { debrisFolder, player.Character }
	params.MaxParts = 2000
	local roots, seen = {}, {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, params)) do
		local root = part.AssemblyRootPart
		if root and not seen[root] then
			seen[root] = true
			if not root.Anchored and isOwned(root) and not isCharacter(root) then
				roots[#roots + 1] = root
				if #roots >= MAX_ASSEMBLIES then break end
			end
		end
	end
	return roots
end

local function flat(v) return V3(v.X, 0, v.Z) end

local function flatDir(v)
	if v.Magnitude > 0.05 then return v.Unit end
	local a = rand() * TAU
	return V3(math.cos(a), 0, math.sin(a))
end

local function randomSpin(a) return V3(rf(-a, a), rf(-a, a), rf(-a, a)) end

local function kick(root, vel, spin)
	if vel.Magnitude > MAX_SPEED then vel = vel.Unit * MAX_SPEED end
	root.AssemblyLinearVelocity = vel
	if spin then root.AssemblyAngularVelocity = spin end
end

local function physBlast(center, R, s) -- shockwave: owned parts blasted outward + up
	local sc = math.sqrt(s)
	for _, root in ipairs(ownedRoots(center, R)) do
		local off = root.Position - center
		local fall = math.clamp(1 - off.Magnitude / R, 0.15, 1)
		kick(root, flatDir(flat(off)) * 120 * sc * fall + V3(0, 95 * sc * fall, 0), randomSpin(8))
	end
end

local function groundAt(position, params)
	local hit = workspace:Raycast(position + V3(0, 60, 0), V3(0, -250, 0), params)
	return hit and hit.Position or position
end

---------------------------------------------------------------- NPC DAMAGE
-- An NPC = any Model with a living Humanoid that is not a player's character.
-- hurt(n, pct) = percent of max health. Health is changed on this client; for NPCs your
-- client spawned (like the DuaKNo spawner) that is the real thing.
local function npcsIn(position, radius)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { debrisFolder, player.Character }
	params.MaxParts = 6000
	local list, seen = {}, {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] then
			seen[model] = true
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not Players:GetPlayerFromCharacter(model) then
				local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				if root then list[#list + 1] = { model = model, hum = hum, root = root } end
			end
		end
	end
	return list
end

-- EXECUTE: every attack checks the NPC's current health first; at or under 10% the hit is an instant kill
local EXECUTE_BELOW = 0.10
local function executeCheck(n)
	local hum = n.hum
	if hum.MaxHealth > 0 and hum.Health / hum.MaxHealth <= EXECUTE_BELOW then
		hum.Health = 0
		if n.root and n.root.Parent then burst(anchorPart(n.root.Position, 2), { "Stars" }) end
		return true
	end
	return false
end

local function hurt(n, pct) -- pct = percent of the NPC's MAX health
	local hum = n.hum
	if not hum.Parent or hum.Health <= 0 then return end
	if executeCheck(n) then return end
	hum.Health = math.max(0, hum.Health - hum.MaxHealth * pct / 100)
end

local function hurtFrac(n, frac) -- frac of the NPC's MAX health (1 = dead)
	local hum = n.hum
	if not hum.Parent or hum.Health <= 0 then return end
	if executeCheck(n) then return end
	if frac >= 0.999 then hum.Health = 0 else hum.Health = math.max(0, hum.Health - hum.MaxHealth * frac) end
end

local function kill(n)
	if n.hum.Parent then n.hum.Health = 0 end
end

local function modelVel(model, vel, spin)
	if vel.Magnitude > MAX_SPEED * 1.2 then vel = vel.Unit * MAX_SPEED * 1.2 end
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Anchored then p.Anchored = false end
			p.AssemblyLinearVelocity = vel
			if spin then p.AssemblyAngularVelocity = spin end
		end
	end
end

-- throws an NPC. Living NPCs get PlatformStand for `stun` seconds so they fly instead of walking it off.
local function launch(n, vel, stun)
	local hum = n.hum
	if hum.Parent and hum.Health > 0 then
		hum.PlatformStand = true
		task.delay(stun or 0.9, function()
			if hum.Parent and hum.Health > 0 then hum.PlatformStand = false end
		end)
	end
	modelVel(n.model, vel, randomSpin(10))
	if hum.Parent and hum.Health <= 0 then -- dead: the joints break a moment later, so throw the pieces again
		task.delay(0.06, function()
			if n.model.Parent then modelVel(n.model, vel, randomSpin(14)) end
		end)
	end
end

local slowed = {}
local function slowNpc(n, factor, dur)
	local hum = n.hum
	if not hum.Parent then return end
	local rec = slowed[hum]
	if not rec then
		rec = { speed = hum.WalkSpeed }
		slowed[hum] = rec
	end
	hum.WalkSpeed = rec.speed * factor
	rec.untilT = os.clock() + dur
	if not rec.running then
		rec.running = true
		task.spawn(function()
			while os.clock() < rec.untilT and hum.Parent do task.wait(0.1) end
			if hum.Parent then hum.WalkSpeed = rec.speed end
			slowed[hum] = nil
		end)
	end
end

-- fades a model / part out in `color`, then deletes it (this client only)
local function dissolve(inst, dur, color)
	local function one(d)
		if d:IsA("BasePart") then
			d.Material = NEON
			tw(d, dur, { Color = color, Transparency = 1 })
		elseif d:IsA("Decal") or d:IsA("Texture") then
			tw(d, dur, { Transparency = 1 })
		end
	end
	one(inst)
	for _, d in ipairs(inst:GetDescendants()) do one(d) end
	Debris:AddItem(inst, dur + 0.1)
end

local function segDist(p, a, b)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function tipPos(character, root)
	local tool = character and character:FindFirstChild(TOOL_NAME)
	local h = tool and tool:FindFirstChild("Handle")
	if h then return h.CFrame:PointToWorldSpace(V3(0, 0, -3)) end
	return root.Position + V3(0, 2, 0)
end

---------------------------------------------------------------- homing bolts (one Heartbeat for all of them)
local bolts, boltConn = {}, nil

local function boltStep(dt)
	local ps, cs = {}, {}
	for i = #bolts, 1, -1 do
		local b = bolts[i]
		if not b.part.Parent then
			table.remove(bolts, i)
		else
			local target, npc = b.fallback, b.npc
			if npc and npc.hum.Parent and npc.hum.Health > 0 and npc.root.Parent then target = npc.root.Position end
			local want = target - b.pos
			local dist = want.Magnitude
			local age = os.clock() - b.t0
			if dist <= b.hitRadius or age > b.life then
				table.remove(bolts, i)
				b.part:Destroy()
				pcall(b.onHit, b.pos, dist <= b.hitRadius * 1.5 and npc or nil)
			else
				b.dir = (b.dir + want.Unit * b.turn * dt * (1 + age)).Unit
				b.speed += b.accel * dt
				b.pos += b.dir * b.speed * dt
				ps[#ps + 1] = b.part
				cs[#cs + 1] = CFrame.lookAt(b.pos, b.pos + b.dir)
			end
		end
	end
	if #ps > 0 then workspace:BulkMoveTo(ps, cs, Enum.BulkMoveMode.FireCFrameChanged) end
	if #bolts == 0 and boltConn then
		boltConn:Disconnect()
		boltConn = nil
	end
end

-- o: pos, dir, npc, fallback, speed, accel, turn, life, hitRadius, size, ball, color, onHit(pos, npc)
local function launchBolt(o)
	local size = o.size or V3(0.8, 0.8, 5)
	local part = fxPart({
		Shape = o.ball and Enum.PartType.Ball or Enum.PartType.Block,
		Color = o.color, Size = size, Transparency = 0.05, CFrame = CFrame.lookAt(o.pos, o.pos + o.dir),
	})
	local r = math.max(size.X, size.Y) * 0.45
	local a0 = make("Attachment", { Position = V3(0, r, 0) }, part)
	local a1 = make("Attachment", { Position = V3(0, -r, 0) }, part)
	make("Trail", {
		Attachment0 = a0, Attachment1 = a1, Lifetime = o.trailTime or 0.4, FaceCamera = true, LightEmission = 1,
		Color = ColorSequence.new(o.color, o.color2 or WHITE), Transparency = NumberSequence.new(0.1, 1),
	}, part)
	bolts[#bolts + 1] = {
		part = part, pos = o.pos, dir = o.dir.Unit, npc = o.npc, fallback = o.fallback, speed = o.speed or 100,
		accel = o.accel or 0, turn = o.turn or 5, life = o.life or 3, hitRadius = o.hitRadius or 3,
		t0 = os.clock(), onHit = o.onHit or function() end,
	}
	if not boltConn then
		boltConn = RunService.Heartbeat:Connect(boltStep)
		table.insert(connections, boltConn)
	end
end

---------------------------------------------------------------- small shared effects
-- a spike that bursts out of the ground, holds, then sinks back
local function spikeAt(base, width, height, bodyColor, glowColor, rise, hold)
	local yaw = rand() * TAU
	local tilt = CFrame.Angles(rf(-0.12, 0.12), 0, rf(-0.12, 0.12))
	local function cfAt(h) return CFrame.new(base) * CFrame.Angles(0, yaw, 0) * tilt * CFrame.new(0, h / 2 - h * 0.06, 0) end
	local function build(w, color, material, transparency)
		local p = fxPart({ Color = color, Material = material, Transparency = transparency, Size = V3(w, 0.3, w), CFrame = cfAt(0.3) })
		pcall(function() make("SpecialMesh", { MeshType = Enum.MeshType.Pyramid }, p) end)
		Debris:AddItem(p, rise + hold + 1)
		return p
	end
	local body = build(width, bodyColor, Enum.Material.Slate, 0)
	local glow = build(width * 1.12, glowColor, NEON, 0.55)
	tw(body, rise, { Size = V3(width, height, width), CFrame = cfAt(height) }, ES.Back)
	tw(glow, rise, { Size = V3(width * 1.12, height * 1.03, width * 1.12), CFrame = cfAt(height * 1.03) }, ES.Back)
	task.delay(rise + hold, function()
		for _, p in ipairs({ body, glow }) do
			if p.Parent then
				tw(p, 0.5, { Size = V3(p.Size.X, 0.3, p.Size.Z), CFrame = cfAt(0.3), Transparency = 1 }, ES.Quad, ED.In)
			end
		end
	end)
end

-- a flat ring (circle outline) on a SurfaceGui, visible from above and below
local function haloRing(pos, diameter, color)
	local p = fxPart({ Size = V3(diameter, 0.05, diameter), Position = pos, Transparency = 1 })
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
		local gui = make("SurfaceGui", {
			Face = face, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(512, 512),
			LightInfluence = 0, Brightness = 2,
		}, p)
		local f = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		make("UIStroke", { Color = color, Thickness = 20 }, f)
	end
	Debris:AddItem(p, 6)
	return p
end

-- sword charge-up (sparkles, trail, light, shake + charge sound). returns finish()
local function chargeUp(tool, dur, small)
	local s = mode().scale
	local h = tool and tool:FindFirstChild("Handle")
	local trail = h and h:FindFirstChild("Trail")
	local att = h and h:FindFirstChild("ChargeAttachment")
	local light = h and h:FindFirstChildOfClass("PointLight")
	if trail then trail.Enabled = true end
	local emitters = {}
	if att then
		for _, name in ipairs({ "Core", "Stars", "Stardust" }) do
			local source = fxFolder:FindFirstChild(name)
			if source then
				local e = source:Clone()
				e.Rate = 30
				e.Enabled = true
				e.Parent = att
				table.insert(emitters, e)
			end
		end
	end
	local baseB, baseR
	if light then
		baseB, baseR = light.Brightness, light.Range
		tw(light, dur, { Brightness = 7, Range = 24 })
	end
	shake(dur, 0.25 * s)
	local snd = sfx(small and SFX.smallCharge or SFX.charge, 0.9, h)
	return function()
		for _, e in ipairs(emitters) do
			e.Enabled = false
			Debris:AddItem(e, 2)
		end
		if trail then trail.Enabled = false end
		if light then light.Brightness, light.Range = baseB, baseR end
		stopSfx(snd, 0.2)
	end
end

-- 8 orbs spiralling around you while you charge. returns stop()
local function chargeOrbs(root, m, dur)
	local pal = m.pal
	local orbs = {}
	for i = 1, 8 do
		local orb = ballPart(root.Position, 0.8, pal[i % 3 + 1], 0)
		local a0 = make("Attachment", { Position = V3(0, 0.4, 0) }, orb)
		local a1 = make("Attachment", { Position = V3(0, -0.4, 0) }, orb)
		make("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 0.4, FaceCamera = true,
			LightEmission = m.dark and 0.3 or 1, Color = colorSeq(pal, i), Transparency = NumberSequence.new(0, 1),
		}, orb)
		orbs[i] = orb
	end
	local t0, cfs = os.clock(), {}
	local conn = RunService.Heartbeat:Connect(function()
		if not root.Parent then return end
		local t = os.clock() - t0
		local k = math.min(t / dur, 1)
		local r = 5 * (1 - k * 0.75)
		for i = 1, 8 do
			local ang = t * (4 + k * 6) + i / 8 * TAU
			cfs[i] = CFrame.new(root.Position + V3(math.cos(ang) * r, -2 + k * 5 + math.sin(t * 3 + i) * 0.6, math.sin(ang) * r))
		end
		workspace:BulkMoveTo(orbs, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	table.insert(connections, conn)
	return function()
		conn:Disconnect()
		for _, o in ipairs(orbs) do pcall(o.Destroy, o) end
	end
end

-- magic circle + filling disc + fence of light posts around the target. returns { circle, destroy }
local function telegraph(targetPos, R, m, chargeDur, circleDur)
	local sq = math.sqrt(m.scale)
	local circle = magicCircle(targetPos, R, m, circleDur or chargeDur)
	local fill = disc(targetPos + V3(0, 0.18, 0), 1, 0.08, m.mid, 0.35)
	tw(fill, chargeDur, { Size = V3(0.08, R * 2, R * 2) }, ES.Quad, ED.In)
	local fence = {}
	local n = m.scale > 1 and 44 or 28
	for i = 1, n do
		local ang = i / n * TAU
		local p = targetPos + V3(math.cos(ang) * R, 0, math.sin(ang) * R)
		local h = rf(9, 18) * sq
		local post = fxPart({ Color = pick(m, i), Size = V3(0.7, 0.2, 0.7), Position = p + V3(0, 0.1, 0), Transparency = 0.15 })
		tw(post, chargeDur, { Size = V3(0.7, h, 0.7), Position = p + V3(0, h / 2, 0) }, ES.Quad, ED.In)
		fence[i] = post
	end
	local t = { circle = circle, done = false }
	function t.destroy()
		if t.done then return end
		t.done = true
		circle.destroy()
		fill:Destroy()
		for _, post in ipairs(fence) do tweenKill(post, 0.5, { Transparency = 1 }, nil, nil, 0.6) end
	end
	return t
end

---------------------------------------------------------------- Ability 1: NOVA (Z) - a different one for every Periastron
local busy = false
local lastCast = -math.huge
local NOVAS = {}

-- supernova damage used by the Ivory star and the Amethyst comet: 100% at the center -> 35% at the edge,
-- instant kill for everything in range when Destructive is on
local function supernovaDamage(target, ER, m, sq)
	sfx(SFX.impactExp, 1.5, anchorPart(target, 6), false, 0.85)
	for _, n in ipairs(npcsIn(target, ER)) do
		local d = (n.root.Position - target).Magnitude
		local near = 1 - math.clamp(d / ER, 0, 1)
		if m.big then hurtFrac(n, 0.4 + 0.35 * near) else hurtFrac(n, 0.25 + 0.45 * near) end
		local fall = math.clamp(1 - d / ER, 0.2, 1)
		launch(n, flatDir(flat(n.root.Position - target)) * 130 * sq * fall + V3(0, 110 * sq * fall, 0), 1.2)
	end
	physBlast(target, ER, m.scale)
	if m.big then task.delay(0.55, function() physBlast(target, ER * 0.8, m.scale * 0.6) end) end
end

-- a small homing meteoroid (Amethyst)
local function meteoroid(m, from, npc, fallback, idx)
	local sq = math.sqrt(m.scale)
	local goal = npc and npc.root.Position or fallback
	launchBolt({
		pos = from, dir = (goal - from).Unit, npc = npc, fallback = fallback, speed = 90, accel = 140, turn = 4.5, life = 4,
		hitRadius = 4 * sq, size = Vector3.one * 3 * sq, ball = true, color = pick(m, idx), color2 = m.pal[3], trailTime = 0.55,
		onHit = function(pos)
			shockwave(pos + V3(0, 0.3, 0), 14 * sq, 0.45, 0, pick(m, idx))
			sfx(SFX.impactExp, 0.6, anchorPart(pos, 4), false, rf(0.95, 1.4))
			burst(anchorPart(pos, 2), { "Stars", "Rays_Thick" })
			for _, n in ipairs(npcsIn(pos, 14 * sq)) do
				hurt(n, 35)
				launch(n, flatDir(flat(n.root.Position - pos)) * 90 + V3(0, 80, 0), 0.9)
			end
			physBlast(pos, 14 * sq, 0.5)
			shake(0.15, 0.4)
		end,
	})
end

-- IVORY: Heaven's Ascension. A column of light opens over the target: every NPC and owned part in it is lifted up
-- in a slow spiral between rising halos, hangs at the top for a heartbeat, then a colossal sword of light falls
-- and drives everything back into the ground.
NOVAS.ivory = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local R = 70 * sq
	local H = 140 * sq
	local target = groundTarget(ctx.aim, root, character)

	sfx(SFX.magicCast, 1.3, root) -- plays the instant the button is pressed
	local stopOrbs = chargeOrbs(root, m, 0.7)
	local tele = telegraph(target, R, m, 0.7, 1.7)
	task.wait(0.7)
	stopOrbs()
	tele.circle.lock()

	task.spawn(function()
		local ok, err = pcall(function()
			task.wait(0.2)
			tele.destroy()
			sfx(SFX.thunderBoom, 1.3, anchorPart(target, 8), false, 1.1)
			flash(target, 0.6, m)
			shake(0.5, 1.2 * sq)

			local col = fxPart({
				Shape = Enum.PartType.Cylinder, Color = pal[1], Transparency = 0.6, Size = V3(1, R * 1.9, R * 1.9),
				CFrame = CFrame.new(target + V3(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			})
			local core = fxPart({
				Shape = Enum.PartType.Cylinder, Color = WHITE, Transparency = 0.3, Size = V3(1, R * 0.5, R * 0.5),
				CFrame = CFrame.new(target + V3(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			})
			tw(col, 0.5, { Size = V3(H, R * 1.9, R * 1.9), CFrame = CFrame.new(target + V3(0, H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, ES.Quad)
			tw(core, 0.5, { Size = V3(H, R * 0.5, R * 0.5), CFrame = CFrame.new(target + V3(0, H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, ES.Quad)
			Debris:AddItem(col, 6)
			Debris:AddItem(core, 6)
			skyOn(0.45, pal[1], 0.6)

			local RINGS = 7
			local rings = {}
			for i = 1, RINGS do rings[i] = disc(target + V3(0, i * H / RINGS, 0), R * 1.7, 0.5, pick(m, i), 0.2) end
			local ringCF = {}

			local ASC = m.big and 3.6 or 3.0
			local tracked, ownedMap = {}, {}
			local t0, lastScan, lastBurst = os.clock(), -1, 0
			while true do
				local dt = RunService.Heartbeat:Wait()
				local t = os.clock() - t0
				if t >= ASC then break end
				local k = t / ASC

				for i, r in ipairs(rings) do
					local y = ((t * 38 + (i - 1) * H / RINGS) % H)
					ringCF[i] = CFrame.new(target + V3(0, y, 0)) * CFrame.Angles(0, t * (i % 2 == 0 and 2 or -2), math.rad(90))
					r.Transparency = 0.15 + 0.7 * (y / H) ^ 2
				end
				workspace:BulkMoveTo(rings, ringCF, Enum.BulkMoveMode.FireCFrameChanged)

				if t - lastBurst > 0.18 then
					lastBurst = t
					local a = rand() * TAU
					burst(anchorPart(target + V3(math.cos(a) * R * 0.7, rf(0, H * 0.7), math.sin(a) * R * 0.7), 2), { "Stars" })
				end

				if os.clock() - lastScan > 0.3 then
					lastScan = os.clock()
					for _, n in ipairs(npcsIn(target + V3(0, H / 2, 0), R * 1.1)) do
						if not tracked[n.model] and flat(n.root.Position - target).Magnitude <= R then
							local off = flat(n.root.Position - target)
							tracked[n.model] = { n = n, a = math.atan2(off.Z, off.X), r = math.max(off.Magnitude, R * 0.15), y = n.root.Position.Y - target.Y }
							n.hum.PlatformStand = true
							for _, p in ipairs(n.model:GetDescendants()) do
								if p:IsA("BasePart") and p.Anchored then p.Anchored = false end
							end
						end
					end
					for _, r2 in ipairs(ownedRoots(target + V3(0, H / 2, 0), R * 1.1)) do
						if not ownedMap[r2] and flat(r2.Position - target).Magnitude <= R then
							local off = flat(r2.Position - target)
							ownedMap[r2] = { a = math.atan2(off.Z, off.X), r = math.max(off.Magnitude, R * 0.15), y = r2.Position.Y - target.Y }
						end
					end
				end

				local function lift(r2, s, spin)
					s.a += dt * (1.6 + 2.4 * k)
					s.y += dt * (H * 0.62 / ASC) * (0.6 + 0.8 * k)
					s.r += (R * 0.28 - s.r) * math.min(1, dt * 1.2)
					r2.CFrame = CFrame.new(target + V3(math.cos(s.a) * s.r, s.y, math.sin(s.a) * s.r)) * CFrame.Angles(0, s.a * spin, 0)
					r2.AssemblyLinearVelocity = V3(0, 0, 0)
					r2.AssemblyAngularVelocity = V3(0, 0, 0)
				end
				for model, s in pairs(tracked) do
					if model.Parent and s.n.root.Parent and s.n.hum.Health > 0 then lift(s.n.root, s, 1.5) end
				end
				for r2, s in pairs(ownedMap) do
					if r2.Parent and not r2.Anchored then lift(r2, s, 2.5) end
				end
			end

			-- the apex: everything hangs for a beat while the sword of light is called
			sfx(SFX.thunderHuge, 1.4, anchorPart(target, 8), false, 1)
			flash(target + V3(0, H * 0.8, 0), 0.9, m)
			local blade = fxPart({ Color = WHITE, Size = V3(R * 0.22, R * 3.2, R * 0.06), Position = target + V3(0, H * 2.4, 0) })
			local glowB = fxPart({ Color = pal[1], Transparency = 0.45, Size = V3(R * 0.5, R * 3.4, R * 0.2), Position = target + V3(0, H * 2.4, 0) })
			local guard = fxPart({ Color = pal[1], Size = V3(R * 0.9, R * 0.1, R * 0.12), Position = target + V3(0, H * 2.4 + R * 1.6, 0) })
			Debris:AddItem(blade, 3)
			Debris:AddItem(glowB, 3)
			Debris:AddItem(guard, 3)
			task.wait(0.35)
			local land = target + V3(0, R * 1.6 + 2, 0)
			tw(blade, 0.22, { Position = land }, ES.Quad, ED.In)
			tw(glowB, 0.22, { Position = land }, ES.Quad, ED.In)
			tw(guard, 0.22, { Position = land + V3(0, R * 1.6, 0) }, ES.Quad, ED.In)
			task.wait(0.22)

			-- SMITE
			sfx(SFX.explosion2, 1.6, anchorPart(target, 8), false, 0.9)
			sfx(SFX.impactExp, 1.4, anchorPart(target, 8), false, 0.8)
			for i = 1, 5 do shockwave(target, R * (1.5 - i * 0.2) * 1.4, 0.7, (i - 1) * 0.07, pal[(i - 1) % 3 + 1]) end
			pillar(target, 16 * sq, pal[1], 0.2, 1.2)
			pillar(target, 7 * sq, WHITE, 0.05, 1)
			scorch(target, R * 0.8, m)
			cracks(target, R * 0.8, m, m.big and 30 or 20)
			flingGround(target, R * 0.6, m.scale * 0.8)
			burst(anchorPart(target + V3(0, 3, 0)), { "Rays_Thick", "Supernova", "Stars", "Stardust" })
			shake(1, 2.5 * sq)
			fovPunch(8, 0.7)
			skyOff(1.5)
			tweenKill(col, 0.5, { Transparency = 1 })
			tweenKill(core, 0.5, { Transparency = 1 })
			tweenKill(blade, 0.4, { Transparency = 1 })
			tweenKill(glowB, 0.4, { Transparency = 1 })
			tweenKill(guard, 0.4, { Transparency = 1 })
			for _, r in ipairs(rings) do tweenKill(r, 0.4, { Transparency = 1 }) end

			for model, s in pairs(tracked) do
				local n = s.n
				if model.Parent and n.hum.Parent and n.hum.Health > 0 then
					hurtFrac(n, m.big and 0.55 or 0.4)
					launch(n, V3(rf(-30, 30), -260, rf(-30, 30)), 1.4)
				end
			end
			for _, n in ipairs(npcsIn(target, R * 1.1)) do
				if not tracked[n.model] then
					hurtFrac(n, 0.25)
					launch(n, flatDir(flat(n.root.Position - target)) * 120 + V3(0, 90, 0), 1)
				end
			end
			for r2 in pairs(ownedMap) do
				if r2.Parent and not r2.Anchored then
					kick(r2, flatDir(flat(r2.Position - target)) * rf(60, 160) + V3(0, -120, 0), randomSpin(12))
				end
			end
			physBlast(target, R * 1.1, m.scale * 0.8)
		end)
		tele.destroy()
		skyOff(1)
		if not ok then warn("[IvoryPeriastron] ivory nova: " .. tostring(err)) end
	end)
end

-- End-portal void: a camera-facing CIRCULAR disc showing an endless starfield tunnel (parallax layers zooming +
-- spinning). The gui sits in a CanvasGroup so it is clipped to a true circle, inside a round stone + glowing green
-- frame with a ring of green "eyes". center can move; call update(center) each frame.
local function endPortal(center, D)
	local TEAL = Color3.fromRGB(0, 28, 34)
	local STAR_COLORS = {
		Color3.fromRGB(0, 255, 230), Color3.fromRGB(70, 140, 255), Color3.fromRGB(160, 90, 255),
		Color3.fromRGB(90, 255, 150), Color3.fromRGB(255, 255, 255),
	}
	local face = fxPart({
		Transparency = 1, Size = V3(D, D, 0.2), CFrame = CFrame.new(center), Material = Enum.Material.SmoothPlastic,
	})
	local gui = make("SurfaceGui", {
		Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(512, 512),
		LightInfluence = 0, Brightness = 1.6, AlwaysOnTop = false,
	}, face)
	-- CanvasGroup + UICorner = real circular clipping (a plain Frame would leave rectangular edges)
	local clip = make("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = TEAL, BorderSizePixel = 0, GroupTransparency = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, clip)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(0, 70, 80), Color3.fromRGB(0, 6, 10)), Rotation = 0,
	}, clip)

	local layers = {}
	for i = 1, 6 do
		local g = make("CanvasGroup", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, GroupTransparency = 1,
		}, clip)
		local sc = make("UIScale", { Scale = 1 }, g)
		for _ = 1, 42 do
			local s = rf(3, 9)
			local f = make("Frame", {
				Size = UDim2.fromOffset(s, s), Position = UDim2.fromScale(rand(), rand()), BorderSizePixel = 0,
				BackgroundColor3 = STAR_COLORS[rand(#STAR_COLORS)], BackgroundTransparency = rf(0, 0.35),
			}, g)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		end
		layers[i] = { g = g, sc = sc, dir = (i % 2 == 0) and 1 or -1 }
	end
	local glow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.2),
		BackgroundColor3 = Color3.fromRGB(190, 255, 245), BackgroundTransparency = 0.35, BorderSizePixel = 0,
	}, clip)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, glow)
	make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, glow)
	-- soft dark vignette on the rim so the tunnel looks deep
	local vig = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0,
	}, clip)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, vig)
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.78, 1), NumberSequenceKeypoint.new(1, 0.25) }),
	}, vig)

	-- round frame: two concentric discs behind the face (stone, glowing green) + ring of eyes
	local stone = fxPart({
		Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(62, 70, 56), Material = Enum.Material.Slate, Size = V3(D * 0.08, D * 1.2, D * 1.2),
	})
	local greenRing = fxPart({
		Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(70, 255, 140), Size = V3(D * 0.06, D * 1.09, D * 1.09),
	})
	local EYES = 20
	local eyes, eyeOff = {}, {}
	for i = 1, EYES do
		local a = i / EYES * TAU
		eyes[i] = ballPart(center, D * 0.06, Color3.fromRGB(150, 255, 190), 0)
		eyeOff[i] = CFrame.new(math.cos(a) * D * 0.575, math.sin(a) * D * 0.575, -D * 0.02)
	end
	local all = { face, stone, greenRing }
	for _, e in ipairs(eyes) do all[#all + 1] = e end
	local axis = CFrame.Angles(0, math.rad(90), 0) -- cylinder X axis -> view axis

	local P = { alive = true }
	local t0 = os.clock()
	local cl = {}
	function P.update(c)
		if not P.alive then return end
		local cam = workspace.CurrentCamera
		local base = cam and CFrame.lookAt(c, cam.CFrame.Position) or CFrame.new(c)
		cl[1] = base
		cl[2] = base * CFrame.new(0, 0, D * 0.07) * axis
		cl[3] = base * CFrame.new(0, 0, D * 0.04) * axis
		for i = 1, EYES do cl[3 + i] = base * eyeOff[i] end
		workspace:BulkMoveTo(all, cl, Enum.BulkMoveMode.FireCFrameChanged)

		local t = os.clock() - t0
		for i, L in ipairs(layers) do
			local ph = (t * 0.32 + i / #layers) % 1
			L.sc.Scale = 0.12 + ph ^ 1.7 * 2.6
			L.g.GroupTransparency = 1 - math.sin(ph * math.pi) ^ 0.6
			L.g.Rotation = t * 22 * L.dir + i * 31
		end
		glow.BackgroundTransparency = 0.35 + math.sin(t * 5) * 0.12
		for i, e in ipairs(eyes) do
			e.Transparency = 0.1 + 0.5 * (0.5 + 0.5 * math.sin(t * 3 + i))
		end
	end
	function P.destroy()
		if not P.alive then return end
		P.alive = false
		for _, p in ipairs(all) do
			if p ~= face then tweenKill(p, 0.5, { Transparency = 1 }) end
		end
		tw(clip, 0.5, { GroupTransparency = 1 })
		Debris:AddItem(face, 0.7)
	end
	P.update(center)
	return P
end

-- NOIR: a black hole with an End-portal void. Everything (NPCs + owned parts) is dragged in hard, then it detonates.
-- Normal: damage 100% at the center -> 10% at the edge of the pull. Destructive: instant kill for everything.
NOVAS.noir = function(ctx)
	local m, root = ctx.m, ctx.root
	local s, pal = m.scale, m.pal
	local sq = math.sqrt(s)
	local PR = 160 * sq -- pull + blast radius
	local target = groundTarget(ctx.aim, root, ctx.character)
	local hole = target + V3(0, 70 * sq, 0) -- floats high above the ground
	local CH = 1
	local stopOrbs = chargeOrbs(root, m, CH)
	local tele = telegraph(target, PR * 0.35, m, CH, CH + 1)
	local endCharge = chargeUp(ctx.tool, CH)
	task.wait(CH)
	endCharge()
	stopOrbs()
	tele.circle.lock()

	task.spawn(function()
		local loopSnd, portal
		local ok, err = pcall(function()
			task.wait(0.25)
			tele.destroy()
			local D = 46 * sq -- portal diameter
			local lens = ballPart(hole, 1, m.glow, 0.85, { Material = Enum.Material.ForceField })
			tw(lens, 1.4, { Size = Vector3.one * D * 1.25 })
			portal = endPortal(hole, D)
			local field = disc(target + V3(0, 0.2, 0), PR * 2, 0.1, pal[3], 0.55)
			Debris:AddItem(field, 12)
			-- a column of dark light tying the portal to the ground
			local col = fxPart({ Color = pal[3], Transparency = 0.6, Size = V3(D * 0.12, hole.Y - target.Y, D * 0.12), Position = (hole + target) / 2 })
			Debris:AddItem(col, 9)
			skyOn(0.6, pal[2], 1.2)
			flash(hole, 0.5, m)
			burst(anchorPart(hole), { "Core", "Stardust" })
			loopSnd = sfx(SFX.bhLoop, 1.4, anchorPart(hole, 12), true)

			-- accretion: stars spiralling into the portal
			local coreD = D
			local starCount = m.big and 150 or 90
			local stars, sp, cfs = {}, {}, {}
			for i = 1, starCount do
				local star = ballPart(hole, rf(0.4, 1.3) * sq, pick(m, i), 1)
				tw(star, 1, { Transparency = 0.05 })
				stars[i] = star
				sp[i] = { r = rf(coreD * 0.6, PR * 0.85), a = rand() * TAU, y = rf(-0.3, 0.3), spd = rf(0.8, 1.2) }
			end

			-- the pull: positions are driven directly (velocity pulls just made NPCs spin on the spot)
			local PULL = 7
			local t0, lastScan, lastRing = os.clock(), -1, 0
			local tracked, ownedList = {}, {}
			while true do
				local dt = RunService.Heartbeat:Wait()
				local t = os.clock() - t0
				if t >= PULL then break end
				local k = t / PULL
				portal.update(hole)

				for i, st in ipairs(sp) do
					st.r -= (14 + 60 * (1 - math.min(st.r / (PR * 0.85), 1))) * st.spd * dt
					st.a += dt * (300 / (st.r + 14)) * st.spd * 3
					if st.r < coreD * 0.45 then
						st.r = PR * rf(0.5, 0.85)
						st.a = rand() * TAU
					end
					cfs[i] = CFrame.new(hole + V3(math.cos(st.a) * st.r, st.y * st.r, math.sin(st.a) * st.r))
				end
				workspace:BulkMoveTo(stars, cfs, Enum.BulkMoveMode.FireCFrameChanged)

				if t - lastRing > 0.45 then
					lastRing = t
					local ring = disc(target + V3(0, 0.3, 0), PR * 2, 0.15, pal[1], 0.5)
					tweenKill(ring, 1.2, { Size = V3(0.15, D, D), Transparency = 1 }, ES.Quad, ED.In)
				end

				if os.clock() - lastScan > 0.4 then
					lastScan = os.clock()
					for _, n in ipairs(npcsIn(hole, PR)) do
						if not tracked[n.model] then
							tracked[n.model] = n
							n.hum.PlatformStand = true
							for _, p in ipairs(n.model:GetDescendants()) do
								if p:IsA("BasePart") and p.Anchored then p.Anchored = false end
							end
						end
					end
					ownedList = ownedRoots(hole, PR)
				end

				local function drag(r2, boost, spin)
					local off = hole - r2.Position
					local dist = off.Magnitude
					local frac = 1 - math.min(dist / PR, 1)
					local speed = (35 + 190 * k ^ 1.2) * (0.5 + 1.4 * frac) * boost
					if dist > D * 0.3 then
						local dirv = off.Unit
						local tang = V3(-dirv.Z, 0, dirv.X)
						local mv = dirv * math.min(speed * dt, dist) + tang * speed * dt * 0.25 * (1 - frac)
						r2.CFrame = (r2.CFrame + mv) * CFrame.Angles(0, dt * spin, 0)
					else
						r2.CFrame = r2.CFrame:Lerp(CFrame.new(hole + V3(rf(-1, 1), rf(-1, 1), rf(-1, 1))), math.min(1, dt * 6)) * CFrame.Angles(0, dt * spin, 0)
					end
					r2.AssemblyLinearVelocity = V3(0, 0, 0)
					r2.AssemblyAngularVelocity = V3(0, 0, 0)
				end
				for model, n in pairs(tracked) do
					local r2 = n.root
					if model.Parent and r2.Parent and n.hum.Health > 0 then drag(r2, 1, 5 + 6 * k) end
				end
				for _, r2 in ipairs(ownedList) do
					if r2.Parent and not r2.Anchored then drag(r2, 0.85, 4 + 5 * k) end
				end
			end

			-- collapse
			stopSfx(loopSnd, 0.4)
			tw(lens, 0.4, { Size = Vector3.one * 2, Transparency = 1 }, ES.Quad, ED.In)
			for _, st in ipairs(stars) do tweenKill(st, 0.4, { Position = hole, Transparency = 1 }, ES.Quad, ED.In) end
			local t1 = os.clock()
			while os.clock() - t1 < 0.4 do
				RunService.Heartbeat:Wait()
				portal.update(hole)
			end
			portal.destroy()
			lens:Destroy()
			skyOff(2)

			-- BOOM
			sfx(SFX.bhLaunch, 1.6, anchorPart(hole, 8))
			sfx(SFX.impactExp, 1.6, anchorPart(hole, 8), false, 0.8)
			local bright = setmetatable({ dark = false, flash = WHITE, tint = WHITE }, { __index = m })
			flash(hole, 1, bright)
			burst(anchorPart(hole), { "Core", "Supernova", "Rays_Thick", "Rays_Thin", "Stars" })
			local blast = ballPart(hole, 2, WHITE, 0.05)
			tweenKill(blast, 0.8, { Size = Vector3.one * PR * 2, Transparency = 1 }, ES.Quad, ED.Out, 1)
			local blast2 = ballPart(hole, 2, pal[3], 0.1, { Material = Enum.Material.SmoothPlastic })
			tweenKill(blast2, 0.6, { Size = Vector3.one * PR * 1.4, Transparency = 1 }, ES.Quad, ED.Out, 0.8)
			for i = 1, 5 do shockwave(target, PR * (1.2 - i * 0.12), 0.8, (i - 1) * 0.08, pal[(i - 1) % 3 + 1]) end
			pillar(target, 18 * sq, pal[1], 0.2, 1.4)
			pillar(target, 9 * sq, WHITE, 0.05, 1.2)
			scorch(target, PR * 0.5, m)
			cracks(target, PR * 0.5, m, m.big and 30 or 20)
			flingGround(target, PR * 0.4, s * 0.9)
			shake(1.4, 3 * sq)
			fovPunch(10, 0.9)

			-- damage + launch: 100% (center) -> 10% (edge); Destructive kills everything
			local hitSet = {}
			for _, n in ipairs(npcsIn(hole, PR)) do
				hitSet[n.model] = true
				local off = n.root.Position - hole
				local d = off.Magnitude
				local near = 1 - math.clamp(d / PR, 0, 1)
				if m.big then kill(n) else hurtFrac(n, 0.1 + 0.9 * near) end
				local away = d > 0.5 and off.Unit or Vector3.yAxis
				launch(n, away * (220 + 300 * near) * (m.big and 1.5 or 1) + V3(0, 60 + 100 * near, 0), 1.5)
			end
			for model, n in pairs(tracked) do
				if not hitSet[model] and n.hum.Parent and n.hum.Health > 0 then n.hum.PlatformStand = false end
			end
			for _, r2 in ipairs(ownedRoots(hole, PR)) do
				local off = r2.Position - hole
				local d = off.Magnitude
				local near = 1 - math.clamp(d / PR, 0, 1)
				kick(r2, (d > 0.5 and off.Unit or Vector3.yAxis) * (160 + 220 * near) + V3(0, 60, 0), randomSpin(14))
			end
		end)
		if loopSnd then stopSfx(loopSnd, 0.2) end
		if portal then portal.destroy() end
		tele.destroy()
		skyOff(1.5)
		if not ok then warn("[IvoryPeriastron] noir nova: " .. tostring(err)) end
	end)
end

-- AZURE: Phantom Slash. You blink through every NPC in range (nearest-neighbour chain), cutting each one three
-- times (each cut flings the NPC into the air and freezes it in a glass-blue "time lock"), snap back to where you
-- started and the whole chain is torn open by an Azure Cross that slams NPCs + owned parts into the ground.
NOVAS.azure = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local MAXN = m.big and 24 or 8
	local HIT = m.big and 14 or 10 -- % of max health per cut
	local FIN = m.big and 35 or 30 -- % of max health from the Azure Cross
	local gap = m.big and 0.045 or 0.075

	local pool = npcsIn(root.Position, maxRange())
	local chain, from = {}, root.Position
	while #chain < MAXN and #pool > 0 do
		local bi, bd
		for i, n in ipairs(pool) do
			local d = (n.root.Position - from).Magnitude
			if not bd or d < bd then bi, bd = i, d end
		end
		local n = table.remove(pool, bi)
		chain[#chain + 1] = n
		from = n.root.Position
	end
	if #chain == 0 then
		showToast("Phantom Slash: no target in range", m.hi)
		return
	end

	local home = root.CFrame
	flash(root.Position, 0.3, m)
	sfx(SFX.dash, 0.9, root)

	local function streakBetween(a, b, thick)
		local len = (b - a).Magnitude
		if len < 1 then return end
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		local st = fxPart({ Shape = Enum.PartType.Cylinder, Color = pal[1], Transparency = 0.2, Size = V3(len, thick, thick), CFrame = cf })
		tweenKill(st, 0.4, { Size = V3(len, 0.1, 0.1), Transparency = 1 })
		local st2 = fxPart({ Shape = Enum.PartType.Cylinder, Color = WHITE, Transparency = 0.05, Size = V3(len, thick * 0.4, thick * 0.4), CFrame = cf })
		tweenKill(st2, 0.3, { Size = V3(len, 0.05, 0.05), Transparency = 1 })
	end

	local function cut(p, i)
		for j = 1, 2 do
			local c = CFrame.lookAt(p, p + V3(rf(-1, 1), rf(-1, 1), rf(-1, 1)))
			local sl = fxPart({ Color = j == 1 and WHITE or pick(m, i + j), Size = V3(0.5, 0.5, 18 * sq), CFrame = c })
			tweenKill(sl, 0.22, { Size = V3(0.05, 0.05, 30 * sq), Transparency = 1 })
		end
		burst(anchorPart(p, 2), { "Stars" })
	end

	local locks = {}
	local wasAnchored = root.Anchored
	local ok, err = pcall(function()
		root.Anchored = true
		local last = root.Position
		for idx, n in ipairs(chain) do
			if not root.Parent or hum.Health <= 0 then break end
			if n.hum.Parent and n.hum.Health > 0 and n.root.Parent then
				local tp = n.root.Position
				local dirv = flatDir(flat(tp - last))
				local dest = tp + dirv * 5 + V3(0, 0.5, 0)
				streakBetween(last, dest, 2.2)
				sfx(SFX.dash, 0.5, root, false, rf(1.05, 1.35))
				root.CFrame = CFrame.lookAt(dest, V3(tp.X, dest.Y, tp.Z))
				shockwave(tp - V3(0, 2.5, 0), 10 * sq, 0.4, 0, pal[idx % 3 + 1])
				-- time lock: the NPC is frozen mid-air inside a spinning glass ring
				n.hum.PlatformStand = true
				local ringP = fxPart({
					Shape = Enum.PartType.Cylinder, Material = Enum.Material.Glass, Color = pal[1], Transparency = 0.4,
					Size = V3(0.4, 9 * sq, 9 * sq), CFrame = CFrame.new(tp) * CFrame.Angles(0, 0, math.rad(90)),
				})
				Debris:AddItem(ringP, 4)
				locks[#locks + 1] = ringP
				for h = 1, 3 do
					if not (n.hum.Parent and n.root.Parent) then break end
					local p = n.root.Position + V3(0, 1, 0)
					cut(p, idx + h)
					sfx(SFX.swing, 0.55, anchorPart(p, 3), false, rf(1.0, 1.5))
					hurt(n, HIT)
					n.root.AssemblyLinearVelocity = V3(rf(-10, 10), 38, rf(-10, 10))
					ringP.CFrame = CFrame.new(n.root.Position) * CFrame.Angles(math.rad(rf(-35, 35)), rf(0, TAU), math.rad(90))
					task.wait(gap)
				end
				last = dest
			end
		end
		-- snap back
		if root.Parent then
			streakBetween(last, home.Position, 2.6)
			root.CFrame = home
			shockwave(home.Position - V3(0, 2.5, 0), 16 * sq, 0.5, 0, pal[1])
			sfx(SFX.dash, 0.9, root, false, 0.9)
		end
	end)
	root.Anchored = wasAnchored
	if not ok then warn("[IvoryPeriastron] phantom slash: " .. tostring(err)) end
	if not root.Parent then return end

	-- Azure Cross on everything the chain touched: NPCs are hammered into the ground, owned parts around them burst up
	task.wait(0.25)
	shake(0.5, 1.4 * sq)
	flash(home.Position, 0.5, m)
	for i, n in ipairs(chain) do
		if n.hum.Parent and n.root.Parent then
			local p = n.root.Position
			if n.hum.Health > 0 then
				hurt(n, FIN)
				launch(n, V3(0, -160, 0), 1.2) -- slam down
			end
			if i <= 30 then
				local a = fxPart({ Color = pal[1], Size = V3(2.5 * sq, 70 * sq, 2.5 * sq), CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.rad(45)) })
				local b = fxPart({ Color = WHITE, Size = V3(2.5 * sq, 70 * sq, 2.5 * sq), CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.rad(-45)) })
				tweenKill(a, 0.45, { Size = V3(0.2, 70 * sq, 0.2), Transparency = 1 })
				tweenKill(b, 0.45, { Size = V3(0.2, 70 * sq, 0.2), Transparency = 1 })
				shockwave(p - V3(0, 2.5, 0), 14 * sq, 0.5, 0, pal[2])
				burst(anchorPart(p, 2), { "Stars", "Rays_Thick" })
				physBlast(p, 16 * sq, m.scale * 0.4)
				if i % 3 == 1 then sfx(SFX.impactExp, 0.7, anchorPart(p, 4), false, rf(0.9, 1.2)) end
			end
		end
	end
	for _, r in ipairs(locks) do tweenKill(r, 0.3, { Transparency = 1, Size = V3(0.1, 1, 1) }) end
	physBlast(home.Position, 40 * sq, m.scale * 0.5)
end

-- CHARTREUSE: Green Forcefield. A huge dome that heals you, repels and punishes NPCs and bats owned parts away
NOVAS.chartreuse = function(ctx)
	local m, root, hum = ctx.m, ctx.root, ctx.hum
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local SR = 38 * sq
	local DUR = 12
	sfx(SFX.energyCharge, 1.1, root)
	local shell = ballPart(root.Position, 2, pal[2], 0.45, { Material = Enum.Material.ForceField })
	local glow = ballPart(root.Position, 2, pal[1], 0.93)
	tw(shell, 0.5, { Size = Vector3.one * SR * 2 }, ES.Back)
	tw(glow, 0.5, { Size = Vector3.one * SR * 1.96 }, ES.Back)
	local floorRing = disc(root.Position - V3(0, 2.9, 0), SR * 2, 0.1, pal[2], 0.6)
	local floorCore = disc(root.Position - V3(0, 2.85, 0), SR * 1.2, 0.1, pal[1], 0.75)
	local light = make("PointLight", { Color = pal[1], Brightness = 4, Range = 30, Shadows = false }, glow)
	for _, p in ipairs({ shell, glow, floorRing, floorCore }) do Debris:AddItem(p, DUR + 3) end
	flash(root.Position, 0.4, m)
	shockwave(root.Position - V3(0, 2.5, 0), SR, 0.6, 0, pal[1])
	burst(anchorPart(root.Position), { "Stars", "Stardust" })

	local t0, lastScan, lastOwned = os.clock(), 0, 0
	local cd, ownedList = {}, {}
	while os.clock() - t0 < DUR and root.Parent and hum.Health > 0 do
		local dt = RunService.Heartbeat:Wait()
		local c = root.Position
		shell.CFrame = CFrame.new(c)
		glow.CFrame = CFrame.new(c)
		local fl = CFrame.new(c - V3(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
		floorRing.CFrame = fl
		floorCore.CFrame = fl
		hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.5 * dt) -- rapid heal

		if os.clock() - lastScan > 0.07 then
			lastScan = os.clock()
			for _, n in ipairs(npcsIn(c, SR + 10)) do
				local off = n.root.Position - c
				if off.Magnitude < SR + 3 then
					local away = flatDir(flat(off))
					launch(n, away * 110 + V3(0, 25, 0), 0.5)
					if (cd[n.model] or 0) < os.clock() then
						cd[n.model] = os.clock() + 0.3
						hurt(n, 10)
						local rip = ballPart(c + (off.Magnitude > 0.1 and off.Unit or Vector3.xAxis) * SR, 4, pal[1], 0.3)
						tweenKill(rip, 0.35, { Size = Vector3.one * 14 * sq, Transparency = 1 })
					end
				end
			end
		end
		if os.clock() - lastOwned > 0.25 then
			lastOwned = os.clock()
			ownedList = ownedRoots(c, SR + 8)
		end
		for _, r2 in ipairs(ownedList) do
			if r2.Parent and not r2.Anchored then
				local off = r2.Position - c
				if off.Magnitude < SR + 3 and off.Magnitude > 6 then
					kick(r2, off.Unit * 90 + V3(0, 20, 0), randomSpin(6))
				end
			end
		end
	end

	-- the shield bursts
	local c = root.Position
	tweenKill(shell, 0.4, { Size = Vector3.one * SR * 2.6, Transparency = 1 })
	tweenKill(glow, 0.4, { Transparency = 1 })
	tweenKill(floorRing, 0.4, { Transparency = 1 })
	tweenKill(floorCore, 0.4, { Transparency = 1 })
	for i = 1, 3 do shockwave(c - V3(0, 2.5, 0), SR * (1.9 - i * 0.3), 0.6, (i - 1) * 0.08, pal[i]) end
	burst(anchorPart(c), { "Rays_Thick", "Stars" })
	sfx(SFX.impactExp, 1.1, anchorPart(c, 4), false, 1.1)
	for _, n in ipairs(npcsIn(c, SR * 1.6)) do
		hurt(n, 18)
		launch(n, flatDir(flat(n.root.Position - c)) * 120 + V3(0, 70, 0), 1)
	end
	physBlast(c, SR * 1.6, m.scale * 0.5)
end

-- AMETHYST: the sky goes dark and a colossal amethyst comet slams into the target
NOVAS.amethyst = function(ctx)
	local m, root = ctx.m, ctx.root
	local s, pal = m.scale, m.pal
	local sq = math.sqrt(s)
	local R = BLAST_RADIUS * s * 1.3
	local target = groundTarget(ctx.aim, root, ctx.character)
	skyOn(0.85, pal[3], 1.2)
	local stopOrbs = chargeOrbs(root, m, CHARGE_TIME)
	local tele = telegraph(target, R, m, CHARGE_TIME, CHARGE_TIME + METEOR_TIME)
	local endCharge = chargeUp(ctx.tool, CHARGE_TIME)
	task.wait(CHARGE_TIME)
	endCharge()
	stopOrbs()
	tele.circle.lock()

	task.spawn(function()
		local ok, err = pcall(function()
			meteorFlight(target, root, m, 2.4)
			tele.destroy()
			explode(target, m)
			supernovaDamage(target, R, m, sq)
			-- the comet shatters: fragments rain down on whatever is left
			for i = 1, (m.big and 30 or 14) do
				task.delay(0.15 + i * 0.07, function()
					local npcs = npcsIn(target, R * 1.4)
					local npc = #npcs > 0 and npcs[rand(#npcs)] or nil
					local ang, r = rand() * TAU, R * math.sqrt(rand())
					local fb = target + V3(math.cos(ang) * r, 1, math.sin(ang) * r)
					meteoroid(m, target + V3(rf(-50, 50), 150, rf(-50, 50)), npc, fb, i)
				end)
			end
			task.wait(3)
		end)
		tele.destroy()
		skyOff(1.5)
		if not ok then warn("[IvoryPeriastron] amethyst nova: " .. tostring(err)) end
	end)
end

-- CRIMSON: red spots mark the ground around you, then a ring of huge laser pillars spirals in around you and merges
-- into one column that disintegrates NPCs and owned parts
NOVAS.crimson = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local N = m.big and 14 or 10
	local Rp = 55 * sq
	local PW = 7 * sq
	local WIND, SPIN, HEIGHT = 1.6, 5, 420
	local params = rayParams(character)
	local c0 = root.Position
	local groundY = groundAt(c0, params).Y
	local base = rand() * TAU

	local circle = magicCircle(V3(c0.X, groundY, c0.Z), Rp * 1.1, m, WIND + SPIN)
	local endCharge = chargeUp(ctx.tool, WIND)
	local spots, spotTweens = {}, {}
	for i = 1, N do
		local a = base + i / N * TAU
		local p = groundAt(c0 + V3(math.cos(a) * Rp, 0, math.sin(a) * Rp), params)
		local d = disc(p + V3(0, 0.25, 0), PW * 1.6, 0.1, pal[2], 0.25)
		local tween = TweenService:Create(d, TweenInfo.new(0.25, ES.Sine, ED.InOut, -1, true), { Transparency = 0.8, Size = V3(0.1, PW * 2.2, PW * 2.2) })
		tween:Play()
		spots[i] = d
		spotTweens[i] = tween
		Debris:AddItem(d, WIND + 1)
	end
	task.wait(WIND)
	endCharge()
	circle.lock()
	for i = 1, N do
		spotTweens[i]:Cancel()
		spots[i]:Destroy()
	end

	task.spawn(function()
		local loopSnd, loopSnd2
		local ok, err = pcall(function()
			loopSnd = sfx(SFX.crimsonLoop, 2, nil, true)
			loopSnd2 = sfx(SFX.laserBeam, 1.4, nil, true, 0.85)
			sfx(SFX.thunderBoom, 1.4, root)
			local pillars = {}
			for i = 1, N do
				pillars[i] = {
					outer = fxPart({ Shape = Enum.PartType.Cylinder, Color = pal[2], Transparency = 0.2, Size = V3(1, PW, PW) }),
					core = fxPart({ Shape = Enum.PartType.Cylinder, Color = pal[1]:Lerp(WHITE, 0.5), Transparency = 0.05, Size = V3(1, PW * 0.45, PW * 0.45) }),
					a = base + i / N * TAU,
				}
			end
			local colOuter = fxPart({ Shape = Enum.PartType.Cylinder, Color = pal[1], Transparency = 0.15, Size = V3(1, 0.1, 0.1) })
			local colCore = fxPart({ Shape = Enum.PartType.Cylinder, Color = WHITE, Transparency = 0.02, Size = V3(1, 0.1, 0.1) })
			local rot90 = CFrame.Angles(0, 0, math.rad(90))
			flash(c0, 0.7, m)
			shake(SPIN, 0.5 * sq)

			local t0, spin, lastTick, lastOwned = os.clock(), 0, 0, 0
			local cd, ownedList = {}, {}
			while true do
				local dt = RunService.Heartbeat:Wait()
				local t = os.clock() - t0
				if t >= SPIN or not root.Parent then break end
				local k = t / SPIN
				local c = root.Position
				local h = HEIGHT * math.min(t / 0.5, 1)
				local r = Rp * (1 - k ^ 1.4)
				spin += dt * (1.5 + 4 * k)
				local axes = {}
				for i, p in ipairs(pillars) do
					local x, z = c.X + math.cos(p.a + spin) * r, c.Z + math.sin(p.a + spin) * r
					axes[i] = V3(x, 0, z)
					local cf = CFrame.new(x, groundY + h / 2, z) * rot90
					p.outer.Size = V3(h, PW, PW)
					p.outer.CFrame = cf
					p.core.Size = V3(h, PW * 0.45, PW * 0.45)
					p.core.CFrame = cf
				end
				local Rc = PW * 2.6 * math.clamp((k - 0.3) / 0.7, 0, 1)
				local ccf = CFrame.new(c.X, groundY + h / 2, c.Z) * rot90
				colOuter.Size = V3(h, math.max(Rc * 2, 0.1), math.max(Rc * 2, 0.1))
				colOuter.CFrame = ccf
				colCore.Size = V3(h, math.max(Rc * 1.1, 0.1), math.max(Rc * 1.1, 0.1))
				colCore.CFrame = ccf

				if t - lastTick > 0.1 then
					lastTick = t
					for _, n in ipairs(npcsIn(c, Rp + PW + 12)) do
						local p2 = flat(n.root.Position)
						if Rc > 1 and (p2 - flat(c)).Magnitude < Rc + 1 then
							hurt(n, 12)
							n.hum.PlatformStand = true
							n.root.AssemblyLinearVelocity = V3((flat(c) - p2).X * 2, 70, (flat(c) - p2).Z * 2)
							n.root.AssemblyAngularVelocity = V3(0, 14, 0)
							if n.hum.Health <= 0 then dissolve(n.model, 0.6, pal[1]) end
						else
							for _, ax in ipairs(axes) do
								if (p2 - ax).Magnitude < PW / 2 + 2 and (cd[n.model] or 0) < os.clock() then
									cd[n.model] = os.clock() + 0.35
									hurt(n, 30)
									launch(n, flatDir(p2 - ax) * 80 + V3(0, 40, 0), 0.6)
									break
								end
							end
						end
					end
				end
				if Rc > 1 and os.clock() - lastOwned > 0.2 then
					lastOwned = os.clock()
					for _, r2 in ipairs(ownedRoots(c, Rc + 6)) do
						if (flat(r2.Position) - flat(c)).Magnitude < Rc then
							r2.AssemblyLinearVelocity = V3(0, 60, 0)
							for _, p3 in ipairs(r2:GetConnectedParts(true)) do
								if p3.Parent and p3.Parent ~= debrisFolder then dissolve(p3, 0.5, pal[1]) end
							end
						end
					end
				end
			end

			stopSfx(loopSnd, 0.5)
			stopSfx(loopSnd2, 0.5)
			sfx(SFX.explosion2, 1.4, root, false, 0.9)
			loopSnd = nil
			local c = root.Position
			for _, p in ipairs(pillars) do
				tweenKill(p.outer, 0.5, { Transparency = 1 })
				tweenKill(p.core, 0.5, { Transparency = 1 })
			end
			tweenKill(colOuter, 0.5, { Transparency = 1 })
			tweenKill(colCore, 0.5, { Transparency = 1 })
			circle.destroy()
			for i = 1, 4 do shockwave(V3(c.X, groundY, c.Z), Rp * (1.3 - i * 0.2), 0.7, (i - 1) * 0.08, pal[(i - 1) % 3 + 1]) end
			burst(anchorPart(c), { "Rays_Thick", "Stars", "Supernova" })
			flash(c, 0.6, m)
			physBlast(V3(c.X, groundY, c.Z), Rp, m.scale * 0.5)
		end)
		if loopSnd then stopSfx(loopSnd, 0.3) end
		if loopSnd2 then stopSfx(loopSnd2, 0.3) end
		circle.destroy()
		if not ok then warn("[IvoryPeriastron] crimson nova: " .. tostring(err)) end
	end)
end

-- GRIMGOLD: Sonar. Orange screen, a duplicate sword follows you, and sonar pulses sweep out: they tag NPCs through
-- walls (blue highlight), slow them and damage them
NOVAS.grimgold = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local DUR = 9
	local INTERVAL = m.big and 0.4 or 0.6
	local PR = maxRange()
	local PSPEED = 700
	local BLUE = Color3.fromRGB(70, 160, 255)
	sfx(SFX.magicCast, 1.1, root, false, 1.2)

	local tint = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = pal[2], BackgroundTransparency = 1, BorderSizePixel = 0,
	}, flashGui)
	make("UIGradient", {
		Color = ColorSequence.new(pal[1], pal[3]), Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.9) }),
	}, tint)
	tw(tint, 0.5, { BackgroundTransparency = 0 })

	local dup = handle:Clone()
	for _, d in ipairs(dup:GetChildren()) do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") then d:Destroy() end
	end
	dup.Anchored, dup.CanCollide, dup.CanQuery, dup.CanTouch = true, false, false, false
	dup.Parent = workspace
	Debris:AddItem(dup, DUR + 3)
	make("PointLight", { Color = pal[2], Brightness = 4, Range = 16, Shadows = false }, dup)

	local tagged = {}
	local function tag(n)
		local hl = n.model:FindFirstChild("SonarTag")
		if not hl then
			hl = make("Highlight", {
				Name = "SonarTag", FillColor = BLUE, OutlineColor = WHITE, FillTransparency = 0.5,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			}, n.model)
			tagged[#tagged + 1] = hl
		end
		shockwave(n.root.Position - V3(0, 2.5, 0), 7, 0.5, 0, BLUE)
	end

	local function pulse(origin)
		local ring = disc(origin + V3(0, 0.4, 0), 2, 0.5, pal[1], 0.15)
		tweenKill(ring, PR / PSPEED, { Size = V3(0.4, PR * 2, PR * 2), Transparency = 1 }, ES.Linear)
		local ring2 = disc(origin + V3(0, 0.5, 0), 2, 0.3, WHITE, 0.3)
		tweenKill(ring2, PR / PSPEED, { Size = V3(0.2, PR * 1.9, PR * 1.9), Transparency = 1 }, ES.Linear)
		sfx(SFX.impactExp, 0.3, root, false, 2.2)
		local t0 = os.clock()
		local hitSet = {}
		local list = npcsIn(origin, PR + 12)
		while os.clock() - t0 < PR / PSPEED do
			RunService.Heartbeat:Wait()
			local rad = (os.clock() - t0) * PSPEED
			for _, n in ipairs(list) do
				if not hitSet[n.model] and n.hum.Parent and n.hum.Health > 0 then
					if flat(n.root.Position - origin).Magnitude <= rad + 6 then
						hitSet[n.model] = true
						tag(n)
						hurt(n, 6)
						slowNpc(n, 0.3, 2.5)
					end
				end
			end
		end
	end

	local t0, nextPulse = os.clock(), 0
	while os.clock() - t0 < DUR and root.Parent do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		dup.CFrame = root.CFrame * CFrame.new(3, 1.5 + math.sin(t * 2) * 0.5, 4) * CFrame.Angles(0, t * 2, 0) * CFrame.Angles(math.rad(90), 0, 0)
		if t >= nextPulse then
			nextPulse += INTERVAL
			task.spawn(pulse, root.Position - V3(0, 2.8, 0))
		end
	end

	tweenKill(tint, 0.6, { BackgroundTransparency = 1 })
	dup:Destroy()
	task.delay(1, function()
		for _, hl in ipairs(tagged) do pcall(hl.Destroy, hl) end
	end)
end

local function cast(tool, aim)
	local character, hum, root = liveChar()
	if not character or not aim then return end
	if busy or os.clock() - lastCast < mode().cooldown then return end
	busy = true
	lastCast = os.clock()
	local m = mode()
	local ok, err = pcall(NOVAS[m.id], { tool = tool, character = character, hum = hum, root = root, aim = aim, m = m })
	if not ok then warn("[IvoryPeriastron] nova: " .. tostring(err)) end
	busy = false
end

---------------------------------------------------------------- shared character clone helpers (statue + step ghosts)
local STRIP_CLASSES = {
	"Humanoid", "Animator", "LuaSourceContainer", "BillboardGui", "Decal", "Texture",
	"Clothing", "ShirtGraphic", "BodyColors", "CharacterMesh", "ForceField", "Sound",
	"ParticleEmitter", "Trail", "Beam", "Light", "Sparkles", "Highlight",
	"SurfaceAppearance", "Fire", "Smoke", "Seat", "Explosion",
}

local function shouldStrip(inst)
	for _, class in ipairs(STRIP_CLASSES) do
		if inst:IsA(class) then return true end
	end
	return false
end

-- clone of the character reduced to pure shape; returns model + list of visible parts
local function strippedClone(character)
	character.Archivable = true
	local model = character:Clone()
	if not model then return nil end
	local doomed = {}
	for _, d in ipairs(model:GetDescendants()) do
		if shouldStrip(d) then doomed[#doomed + 1] = d end
	end
	for _, d in ipairs(doomed) do pcall(d.Destroy, d) end
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d:IsA("MeshPart") then d.TextureID = "" end
			for _, c in ipairs(d:GetChildren()) do
				if c:IsA("SpecialMesh") then c.TextureId = "" end
			end
			if d.Transparency < 0.95 then parts[#parts + 1] = d end
		end
	end
	return model, parts
end

---------------------------------------------------------------- Ability 2: Angel's Past + recall
local statue = nil -- { model, cf, tweens, conn }
local lastStatueUse = -math.huge

local function removeStatue(animated)
	if not statue then return end
	local s = statue
	statue = nil
	if s.conn then s.conn:Disconnect() end
	for _, t in ipairs(s.tweens) do pcall(t.Cancel, t) end
	if animated and s.model.Parent then
		for _, d in ipairs(s.model:GetDescendants()) do
			if d:IsA("BasePart") then tw(d, 0.5, { Transparency = 1 })
			elseif d:IsA("Light") then tw(d, 0.5, { Brightness = 0 })
			elseif d:IsA("ParticleEmitter") then d.Enabled = false end
		end
		Debris:AddItem(s.model, 0.7)
	else
		s.model:Destroy()
	end
end

local SINE_LOOP = function(period) return TweenInfo.new(period, ES.Sine, ED.InOut, -1, true) end

local function buildStatue(character, root, m)
	local pal = m.pal
	local model, parts = strippedClone(character)
	if not model then return nil end
	model.Name = STATUE_NAME

	local tweens = {}
	local coreFolder = make("Folder", { Name = "Inner" }, model)

	-- every part becomes a pure-white glass shell with a real VOID inside:
	-- shell (white) > thin colored rim > solid black void, with stars drifting in it
	local function layer(part, scale, name)
		local c = part:Clone()
		for _, ch in ipairs(c:GetChildren()) do
			if not ch:IsA("SpecialMesh") then
				ch:Destroy()
			elseif ch.MeshType == Enum.MeshType.FileMesh then
				ch.Scale = ch.Scale * scale
			end
		end
		c.Name = name
		c.Transparency = 1
		c.Size = part.Size * scale
		c.CFrame = part.CFrame
		c.Anchored = true
		c.Parent = coreFolder
		return c
	end

	local totalVol = 0
	for _, part in ipairs(parts) do
		if part.Name ~= "Handle" then totalVol += part.Size.X * part.Size.Y * part.Size.Z end
	end

	for _, part in ipairs(parts) do
		local rim = layer(part, 0.95, "Rim")
		rim.Material = NEON
		rim.Color = pal[1]
		tw(rim, 0.7, { Transparency = 0.55 })
		local pulse = TweenService:Create(rim, SINE_LOOP(1.8), { Color = pal[2] })
		pulse:Play()
		table.insert(tweens, pulse)

		local void = layer(part, 0.9, "Void") -- solid black, no glow
		void.Material = Enum.Material.SmoothPlastic
		void.Color = Color3.new(0, 0, 0)
		tw(void, 0.7, { Transparency = 0 })

		local vol = part.Size.X * part.Size.Y * part.Size.Z
		if vol > 0.6 and part.Name ~= "Handle" then
			-- slow nebula wisps swirling inside the void
			make("ParticleEmitter", {
				Color = colorSeq(pal, math.floor(vol) % 3), LightEmission = 1,
				Rate = math.clamp(vol * 0.9, 2, 9), Lifetime = NumberRange.new(2, 4),
				Speed = NumberRange.new(0, 0.4), SpreadAngle = Vector2.new(360, 360),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.35), NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.25), NumberSequenceKeypoint.new(1, 1),
				}),
				RotSpeed = NumberRange.new(-40, 40),
			}, void)
		end
		if part.Name ~= "Handle" and totalVol > 0 then
			-- floating dots inside the body (one emitter per part instead of ~120 animated parts)
			local life = 5
			make("ParticleEmitter", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, pal[1]), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, pal[2]),
				}),
				LightEmission = 1, Rate = math.max(0.6, STATUE_DOT_RATE * vol / totalVol),
				Lifetime = NumberRange.new(life - 2, life + 3),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(part.Size.Y * 0.1, part.Size.Y * 0.25),
				SpreadAngle = Vector2.new(20, 20),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.21, 0.09), NumberSequenceKeypoint.new(1, 0.21, 0.09) }),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
				}),
			}, void)
		end

		-- pure white glass shell
		part.Material = NEON
		part.Color = WHITE
		part.Transparency = 1
		tw(part, 0.7, { Transparency = SHELL_TRANSPARENCY })
	end

	-- feet position
	local hit = workspace:Raycast(root.Position, V3(0, -12, 0), rayParams(character, model))
	local feet = hit and hit.Position or (root.Position - V3(0, 3, 0))
	local center = root.Position

	-- ground sigil: stacked colored discs
	disc(feet + V3(0, 0.10, 0), 15, 0.1, pal[1], 0.55, model)
	disc(feet + V3(0, 0.13, 0), 10, 0.1, pal[2], 0.4, model)
	disc(feet + V3(0, 0.16, 0), 5.5, 0.1, WHITE, 0.2, model)

	-- aura: rising motes + light
	local aura = fxPart({ Name = "Aura", Transparency = 1, Size = V3(5, 0.2, 5), Position = feet + V3(0, 0.2, 0) }, model)
	for i = 1, 2 do
		make("ParticleEmitter", {
			Color = colorSeq(pal, i), LightEmission = m.dark and 0.3 or 1, Rate = 16,
			Lifetime = NumberRange.new(2, 3.4), Speed = NumberRange.new(4, 9),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(14, 14),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
			Acceleration = V3(0, 2, 0),
		}, aura)
	end
	local glow = make("PointLight", { Color = m.glow, Brightness = 4, Range = 22, Shadows = false }, aura)
	local glowPulse = TweenService:Create(glow, SINE_LOOP(1.4), { Brightness = 1.5 })
	glowPulse:Play()
	table.insert(tweens, glowPulse)

	-- pillars of light
	local function statuePillar(diam, color, trans, tgtDiam, tgtTrans, period)
		local p = fxPart({
			Shape = Enum.PartType.Cylinder, Color = color, Transparency = trans, Size = V3(100, diam, diam),
			CFrame = CFrame.new(feet + V3(0, 50, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		}, model)
		local t = TweenService:Create(p, SINE_LOOP(period), { Transparency = tgtTrans, Size = V3(100, tgtDiam, tgtDiam) })
		t:Play()
		table.insert(tweens, t)
	end
	statuePillar(6, pal[1], 0.86, 4, 0.93, 1.7)
	statuePillar(3, pal[2], 0.8, 1.8, 0.9, 1.3)

	-- halos (Heaven's second halo is the rare gold)
	local head = model:FindFirstChild("Head")
	if head then
		local hp = head.Position + V3(0, head.Size.Y / 2 + 0.95, 0)
		disc(hp, 3, 0.14, m.dark and pal[1] or WHITE, 0.05, model)
		disc(hp + V3(0, 0.12, 0), 3.8, 0.08, m.accent or pal[2], 0.3, model)
	end

	-- orbiting orbs + ground runes (one BulkMoveTo per frame)
	local moving, orbCount = {}, 6
	for k = 1, orbCount do
		local o = ballPart(center, 0.7, pal[k % 3 + 1], 1)
		o.Parent = model
		local a0 = make("Attachment", { Position = V3(0, 0.35, 0) }, o)
		local a1 = make("Attachment", { Position = V3(0, -0.35, 0) }, o)
		make("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 0.7, FaceCamera = true,
			LightEmission = m.dark and 0.3 or 1, Color = colorSeq(pal, k), Transparency = NumberSequence.new(0.1, 1),
		}, o)
		tw(o, 0.9, { Transparency = 0 }, ES.Linear)
		moving[k] = o
	end
	local runeCount = 12
	for k = 1, runeCount do
		local r = fxPart({ Color = pick(m, k), Size = V3(0.55, 0.55, 0.55), Transparency = 1 }, model)
		tw(r, 0.9, { Transparency = 0.1 }, ES.Linear)
		moving[orbCount + k] = r
	end

	local born = os.clock()
	local cfs = {}
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent then conn:Disconnect() return end
		local t = os.clock() - born
		for k = 1, orbCount do
			local ang = t * 0.9 + k / orbCount * TAU
			cfs[k] = CFrame.new(center + V3(math.cos(ang) * 4.6, 1.2 + math.sin(t * 1.2 + k) * 1.5, math.sin(ang) * 4.6))
		end
		for k = 1, runeCount do
			local ang = -t * 0.5 + k / runeCount * TAU
			cfs[orbCount + k] = CFrame.new(feet + V3(math.cos(ang) * 6.5, 0.7 + math.sin(t * 2 + k) * 0.3, math.sin(ang) * 6.5))
				* CFrame.Angles(t, t * 1.3, 0)
		end
		workspace:BulkMoveTo(moving, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)

	model.Parent = workspace
	return { model = model, tweens = tweens, conn = conn }
end

local function useStatue()
	if os.clock() - lastStatueUse < STATUE_COOLDOWN then return end
	local character, _, root = liveChar()
	if not character then return end
	lastStatueUse = os.clock()

	local m = mode()
	local pal = m.pal

	if not statue then
		-- first press: leave Angel's Past behind
		local ok, result = pcall(buildStatue, character, root, m)
		if ok and result then
			result.cf = root.CFrame
			statue = result
			table.insert(ownedInstances, result.model)
			local ground = root.Position - V3(0, 2.5, 0)
			shockwave(ground, 14, 0.6, 0, pal[1])
			shockwave(ground, 9, 0.5, 0.1, pal[2])
			burst(anchorPart(root.Position), { "Stars", "Stardust" })
			flash(root.Position, 0.35, m)
		else
			warn("[IvoryPeriastron] Angel's Past failed: " .. tostring(result))
		end
	else
		-- second press: teleport back to Angel's Past
		local target = statue.cf
		local from = root.Position

		shockwave(from - V3(0, 2.5, 0), 12, 0.5, 0, pal[1])
		burst(anchorPart(from), { "Stars", "Stardust" })

		root.CFrame = target
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		local arrive = target.Position
		local ground = arrive - V3(0, 2.5, 0)
		shockwave(ground, 20, 0.65, 0, pal[1])
		shockwave(ground, 13, 0.5, 0.1, pal[2])
		shockwave(ground, 7, 0.4, 0.2, pal[3])
		burst(anchorPart(arrive), { "Rays_Thick", "Stars", "Stardust" })
		flash(arrive, 0.5, m)
		shake(0.35, 0.9)

		-- the return slams the area: 80% (right next to you) -> 30% (edge) of every NPC's max health
		local AR = 45 * math.sqrt(m.scale)
		shockwave(ground, AR, 0.6, 0.05, pal[1])
		sfx(SFX.impactExp, 1.2, anchorPart(arrive, 5), false, 0.9)
		for _, n in ipairs(npcsIn(arrive, AR)) do
			local d = (n.root.Position - arrive).Magnitude
			hurtFrac(n, 0.8 - 0.5 * math.clamp(d / AR, 0, 1))
			launch(n, flatDir(flat(n.root.Position - arrive)) * 80 + V3(0, 60, 0), 0.8)
		end
		physBlast(arrive, AR, m.scale * 0.4)

		removeStatue(true)
	end
end

---------------------------------------------------------------- Ability 3: Halo Step / Rift Step
local lastStep = -math.huge

local function useStep()
	if os.clock() - lastStep < STEP_COOLDOWN then return end
	local character, hum, root = liveChar()
	if not character then return end

	local m = mode()
	local pal = m.pal
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
	dir = V3(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then return end
	dir = dir.Unit

	local dist = STEP_DISTANCE
	local hit = workspace:Raycast(root.Position, dir * dist, rayParams(character))
	if hit then dist = math.max(hit.Distance - 3, 0) end
	if dist < 4 then return end
	lastStep = os.clock()
	sfx(SFX.dash, 1, root)

	local pivot = character:GetPivot()
	local startPos = root.Position
	local endPos = startPos + dir * dist

	-- afterimages along the path (character is stripped ONCE, then cloned per image)
	local base = strippedClone(character)
	if base then
		for i = 0, 5 do
			local ghost = base:Clone()
			local color, fade = pal[i % 3 + 1], 0.5 + i * 0.08
			for _, d in ipairs(ghost:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 0.95 then
					d.Material = NEON
					d.Color = color
					d.Transparency = 0.3
					tw(d, fade, { Transparency = 1 })
				end
			end
			ghost.Name = "IvoryGhost"
			ghost:PivotTo(pivot + dir * (dist * i / 6))
			ghost.Parent = workspace
			Debris:AddItem(ghost, 1.2)
		end
		base:Destroy()
	end

	-- light streak between start and end
	local streakCF = CFrame.lookAt((startPos + endPos) / 2, endPos) * CFrame.Angles(0, math.rad(90), 0)
	local function streak(thick, color, trans)
		local st = fxPart({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = trans, Size = V3(dist, thick, thick), CFrame = streakCF })
		tweenKill(st, 0.5, { Size = V3(dist, 0.1, 0.1), Transparency = 1 }, nil, nil, 0.6)
	end
	streak(2.2, pal[1], 0.3)
	streak(1.0, m.dark and m.mid or WHITE, 0.1)

	-- go
	root.CFrame = root.CFrame + dir * dist
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = V3(0, v.Y, 0)

	local lowStart, lowEnd = startPos - V3(0, 2.5, 0), endPos - V3(0, 2.5, 0)
	shockwave(lowStart, 10, 0.5, 0, pal[1])
	shockwave(lowEnd, 14, 0.55, 0, pal[2])
	shockwave(lowEnd, 8, 0.4, 0.08, pal[3])
	burst(anchorPart(startPos), { "Stars", "Stardust" })
	burst(anchorPart(endPos), { "Rays_Thick", "Stars" })
	fovPunch(10, 0.5)

	-- the lunge cuts through every NPC on the path
	local side0 = dir:Cross(Vector3.yAxis)
	for _, n in ipairs(npcsIn((startPos + endPos) / 2, dist / 2 + 12)) do
		if segDist(n.root.Position, startPos, endPos) < 9 then
			hurt(n, 30)
			local side = side0
			if side:Dot(n.root.Position - startPos) < 0 then side = -side end
			launch(n, side * 70 + V3(0, 40, 0), 0.7)
		end
	end
end

---------------------------------------------------------------- Ability 4 (F): the second ability of every Periastron
local judging = false
local lastJudge = -math.huge
local SECOND = {}

-- a standing crescent of light that flies forward. dmg = 0 makes it purely visual (used by the sword swing)
local function crescentWave(origin, dir, m, size, dur, dmg)
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local R = 16 * sq * size
	local H = 9 * sq * size
	local N = 13
	local parts, offs, cfs = {}, {}, {}
	for i = 1, N do
		local a = (i / (N + 1) - 0.5) * math.rad(150)
		local seg = fxPart({
			Color = i % 3 == 0 and WHITE or pal[i % 2 + 1], Size = V3(1.1 * sq, H, R * 0.22), Transparency = 0.1,
		})
		local a0 = make("Attachment", { Position = V3(0, H / 2, 0) }, seg)
		local a1 = make("Attachment", { Position = V3(0, -H / 2, 0) }, seg)
		make("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 0.35, FaceCamera = true, LightEmission = 1,
			Color = colorSeq(pal, i), Transparency = NumberSequence.new(0.2, 1),
		}, seg)
		parts[i] = seg
		offs[i] = CFrame.new(R * math.sin(a), 0, R * (1 - math.cos(a))) * CFrame.Angles(0, -a, 0)
	end
	local start, pos, lastHit = os.clock(), origin + V3(0, 2.5, 0), 0
	local hit = {}
	while os.clock() - start < dur do
		local dt = RunService.Heartbeat:Wait()
		pos += dir * 230 * dt
		local baseCF = CFrame.lookAt(pos, pos + dir)
		for i = 1, N do cfs[i] = baseCF * offs[i] end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		if dmg > 0 and os.clock() - lastHit > 0.05 then
			lastHit = os.clock()
			for _, n in ipairs(npcsIn(pos, R + 4)) do
				if not hit[n.model] and (flat(n.root.Position - pos)):Dot(dir) > -R * 0.3 then
					hit[n.model] = true
					hurt(n, dmg)
					local side = flatDir(flat(n.root.Position - pos))
					launch(n, (dir * 70 + side * 40) + V3(0, 55, 0), 0.8)
					burst(anchorPart(n.root.Position, 2), { "Stars" })
				end
			end
		end
	end
	for _, p in ipairs(parts) do tweenKill(p, 0.25, { Transparency = 1 }) end
end

-- NOIR: Lights Out. The map goes dark, you turn invisible and fast, and shadow spikes impale NPCs around you
SECOND.noir = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local DUR = 12
	local center = root.Position
	local ground = groundTarget(center, root, character)
	sfx(SFX.darkCharge, 1.2, root)
	skyOn(1, pal[2], 0.8)

	-- the small circle that stays lit
	local lit = anchorPart(center + V3(0, 6, 0), DUR + 2)
	make("PointLight", { Brightness = 4, Range = 60, Color = pal[1]:Lerp(WHITE, 0.4), Shadows = false }, lit)
	local ring = disc(ground + V3(0, 0.2, 0), 90 * sq, 0.1, pal[1], 0.75)
	Debris:AddItem(ring, DUR + 2)
	shockwave(ground, 45 * sq, 0.8, 0, pal[1])
	flash(center, 0.4, m)

	-- invisible + fast, sword hidden
	local saved, savedEm = {}, {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			saved[d] = d.Transparency
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			savedEm[d] = d.Enabled
			d.Enabled = false
		end
	end
	local oldSpeed = hum.WalkSpeed
	hum.WalkSpeed = 60
	local smoke = make("ParticleEmitter", {
		Color = ColorSequence.new(pal[3]), Rate = 40, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.2, 1), LightEmission = 0,
	}, root)

	local params = rayParams(character)
	local t0 = os.clock()
	while os.clock() - t0 < DUR and root.Parent and hum.Health > 0 do
		local list = npcsIn(root.Position, maxRange())
		table.sort(list, function(a, b)
			return (a.root.Position - root.Position).Magnitude < (b.root.Position - root.Position).Magnitude
		end)
		for i = 1, math.min(#list, m.big and 12 or 5) do
			local n = list[i]
			spikeAt(groundAt(n.root.Position, params), 4 * sq, 16 * sq, pal[3], m.glow, 0.15, 0.5)
			hurt(n, 18)
			sfx(SFX.impactExp, 0.35, anchorPart(n.root.Position, 3), false, rf(1.2, 1.7))
			launch(n, V3(rf(-20, 20), 80, rf(-20, 20)), 0.8)
			shockwave(n.root.Position - V3(0, 2.5, 0), 8 * sq, 0.4, 0, pal[1])
		end
		task.wait(0.45)
	end

	smoke:Destroy()
	hum.WalkSpeed = oldSpeed
	for d, tr in pairs(saved) do if d.Parent then d.Transparency = tr end end
	for d, en in pairs(savedEm) do if d.Parent then d.Enabled = en end end
	tweenKill(ring, 0.6, { Transparency = 1 })
	skyOff(1.5)
	burst(anchorPart(root.Position), { "Stars", "Stardust" })
end

-- IVORY: Judgement. A magic circle locks on, then a rain of light spears hits the whole area
SECOND.ivory = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local sq = math.sqrt(m.scale)
	local big = m.big
	local R = 40 * sq
	local aim = aimPoint()
	if not aim then return end
	local target = groundTarget(aim, root, character)
	sfx(SFX.magicCast, 1.2, root)
	local circle = magicCircle(target, R, m, 0.9)
	task.wait(0.9)
	circle.lock()

	local count = big and 56 or 26
	local len = 38 * sq
	for i = 1, count do
		local ang, r = rand() * TAU, R * 0.9 * math.sqrt(rand())
		local p = target + V3(math.cos(ang) * r, 0, math.sin(ang) * r)
		task.delay((i - 1) * 0.04, function()
			local spear = fxPart({
				Color = pick(m, i), Size = V3(0.9 * sq, 0.9 * sq, len), CFrame = CFrame.lookAt(p + V3(0, 150, 0), p),
			})
			local fall = tw(spear, 0.28, { CFrame = CFrame.lookAt(p + V3(0, len / 2, 0), p) }, ES.Quad, ED.In)
			fall.Completed:Connect(function()
				shockwave(p - V3(0, 0.2, 0), 7 * sq, 0.4, 0, spear.Color)
				if i % 3 == 0 then burst(anchorPart(p), { "Stars" }) end
				tweenKill(spear, 0.3, { Transparency = 1, Size = V3(0.1, 0.1, len) })
				for _, n in ipairs(npcsIn(p, 7 * sq)) do
					hurt(n, 8)
					launch(n, flatDir(flat(n.root.Position - p)) * 40 + V3(0, 55, 0), 0.7)
				end
			end)
		end)
	end
	task.wait(count * 0.04 + 0.4)

	circle.destroy()
	pillar(target, 10 * sq, m.pal[1], 0.3, 1.2)
	pillar(target, 5 * sq, WHITE, 0.1, 1)
	for i = 1, 3 do shockwave(target, R * (1.3 - i * 0.25), 0.7, (i - 1) * 0.1, m.pal[i]) end
	scorch(target, R, m)
	cracks(target, R, m, big and 22 or 12)
	burst(anchorPart(target), { "Rays_Thick", "Stars", "Stardust" })
	flash(target, 0.5, m)
	shake(0.5, 1.2 * sq)
	for _, n in ipairs(npcsIn(target, R)) do
		hurt(n, 25)
		sfx(SFX.impactExp, 1, anchorPart(target, 4), false, 1)
		launch(n, flatDir(flat(n.root.Position - target)) * 90 + V3(0, 80, 0), 1)
	end
	physBlast(target, R, m.scale * 0.5)
end

-- AZURE: Sword Prison. Giant blue swords rain down in a ring around every NPC (up to 5, or 14 when Destructive),
-- locking each one in a floating cage; the cage squeezes shut and detonates.
SECOND.azure = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local list = npcsIn(root.Position, maxRange())
	table.sort(list, function(a, b)
		return (a.root.Position - root.Position).Magnitude < (b.root.Position - root.Position).Magnitude
	end)
	local cap = m.big and 14 or 5
	while #list > cap do table.remove(list) end
	if #list == 0 then
		showToast("Sword Prison: no target in range", m.hi)
		return
	end
	local params = rayParams(character)
	sfx(SFX.magicCaster, 1.2, root)
	flash(root.Position, 0.3, m)

	local HOLD = m.big and 2.4 or 2.0
	local SWORDS = 8
	local done = 0
	for idx, n in ipairs(list) do
		task.spawn(function()
			local ok, err = pcall(function()
				local ground = groundAt(n.root.Position, params)
				local center = n.root.Position
				local ringR = 10 * sq
				local swords = {}
				for s = 1, SWORDS do
					local a = s / SWORDS * TAU
					local gp = ground + V3(math.cos(a) * ringR, 0, math.sin(a) * ringR)
					local sw = fxPart({ Color = pick(m, s), Size = V3(1.8 * sq, 30 * sq, 0.7 * sq), Position = gp + V3(0, 190, 0) })
					local edge = fxPart({ Color = WHITE, Size = V3(0.5 * sq, 31 * sq, 0.8 * sq), Position = gp + V3(0, 190, 0) })
					swords[s] = { p = sw, e = edge, gp = gp, a = a }
					Debris:AddItem(sw, HOLD + 5)
					Debris:AddItem(edge, HOLD + 5)
				end
				task.wait((idx - 1) * 0.06)
				for s, sw in ipairs(swords) do
					local lean = CFrame.lookAt(sw.gp, V3(ground.X, sw.gp.Y, ground.Z)) * CFrame.Angles(math.rad(8), 0, 0)
					local land = CFrame.new(sw.gp + V3(0, 12 * sq, 0)) * (lean - lean.Position)
					tw(sw.p, 0.3, { CFrame = land }, ES.Quad, ED.In)
					tw(sw.e, 0.3, { CFrame = land }, ES.Quad, ED.In)
					task.delay(0.3, function()
						shockwave(sw.gp, 9 * sq, 0.4, 0, pal[s % 3 + 1])
						if idx <= 2 and s % 3 == 1 then sfx(SFX.swordSlash, 0.5, anchorPart(sw.gp, 3), false, rf(0.8, 1.1)) end
					end)
					task.wait(0.03)
				end
				task.wait(0.4)

				-- the prison: a glass bubble, the NPC floats in it and bleeds
				local bubble = ballPart(center, 4, pal[1], 0.75, { Material = Enum.Material.ForceField })
				tw(bubble, 0.35, { Size = Vector3.one * ringR * 1.7 }, ES.Back)
				local floatY = 8 * sq
				n.hum.PlatformStand = true
				local t0, lastDot = os.clock(), 0
				while os.clock() - t0 < HOLD and n.root.Parent and n.hum.Health > 0 do
					task.wait(0.05)
					local k = (os.clock() - t0) / HOLD
					local tgt = center + V3(0, floatY * math.min(k * 3, 1), 0)
					n.root.CFrame = CFrame.new(tgt) * CFrame.Angles(0, k * 14, 0)
					n.root.AssemblyLinearVelocity = V3(0, 0, 0)
					n.root.AssemblyAngularVelocity = V3(0, 0, 0)
					bubble.Position = tgt
					if os.clock() - lastDot > 0.4 then
						lastDot = os.clock()
						hurt(n, 3)
						burst(anchorPart(tgt, 2), { "Stars" })
					end
				end

				-- squeeze + detonate
				for _, sw in ipairs(swords) do
					local pos = sw.gp:Lerp(ground, 0.85) + V3(0, 12 * sq, 0)
					tw(sw.p, 0.3, { Position = pos }, ES.Quad, ED.In)
					tw(sw.e, 0.3, { Position = pos }, ES.Quad, ED.In)
				end
				tw(bubble, 0.3, { Size = Vector3.one * 3 }, ES.Quad, ED.In)
				task.wait(0.3)
				bubble:Destroy()
				if n.hum.Parent and n.hum.Health > 0 then
					hurtFrac(n, m.big and 0.4 or 0.32)
					launch(n, V3(rf(-40, 40), 150, rf(-40, 40)), 1.3)
				end
				for _, sw in ipairs(swords) do
					tweenKill(sw.p, 0.35, { Transparency = 1 })
					tweenKill(sw.e, 0.35, { Transparency = 1 })
				end
				shockwave(ground, 30 * sq, 0.6, 0, pal[1])
				burst(anchorPart(center + V3(0, floatY, 0), 2), { "Rays_Thick", "Stars", "Stardust" })
				physBlast(center, 22 * sq, m.scale * 0.5)
				if idx <= 3 then
					sfx(SFX.glass, 1.2, anchorPart(center, 4), false, rf(0.9, 1.1))
					sfx(SFX.impactExp, 0.8, anchorPart(center, 4), false, rf(0.9, 1.2))
				end
			end)
			if not ok then warn("[IvoryPeriastron] sword prison: " .. tostring(err)) end
			done += 1
		end)
	end
	local t0 = os.clock()
	while done < #list and os.clock() - t0 < HOLD + 8 do task.wait(0.1) end
	shake(0.4, 1.2)
end

-- CHARTREUSE: Green Laser. A huge piercing beam that follows your aim for 1.8 s and burns everything along it
local function beamEnd(origin, dir, range, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { debrisFolder, character }
	params.FilterDescendantsInstances = ignore
	local pos, remain = origin, range
	for _ = 1, 6 do
		local hit = workspace:Raycast(pos, dir * remain, params)
		if not hit then return pos + dir * remain end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then -- NPCs do not stop the beam
			ignore[#ignore + 1] = model
			params.FilterDescendantsInstances = ignore
			remain -= (hit.Position - pos).Magnitude
			pos = hit.Position
			if remain < 1 then return pos end
		else
			return hit.Position
		end
	end
	return pos + dir * remain
end

SECOND.chartreuse = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local DUR, CHARGE = 1.8, 0.45
	local RANGE = maxRange()
	local W = 3.2 * sq
	local snd = sfx(SFX.energyCharge, 1.2, root, false, 1.2)
	local beamSnd

	local flare = ballPart(tipPos(character, root), 1, pal[1], 0.2)
	tw(flare, CHARGE, { Size = Vector3.one * 5 * sq })
	local t0 = os.clock()
	while os.clock() - t0 < CHARGE and root.Parent do
		RunService.Heartbeat:Wait()
		flare.CFrame = CFrame.new(tipPos(character, root))
	end
	stopSfx(snd, 0.1)
	if not root.Parent then flare:Destroy() return end

	local outer = fxPart({ Shape = Enum.PartType.Cylinder, Color = pal[2], Transparency = 0.25, Size = V3(1, W, W) })
	local inner = fxPart({ Shape = Enum.PartType.Cylinder, Color = WHITE, Transparency = 0.02, Size = V3(1, W * 0.4, W * 0.4) })
	local endBall = ballPart(root.Position, 6 * sq, pal[1], 0.2)
	flash(root.Position, 0.4, m)
	shake(DUR, 0.5 * sq)

	beamSnd = sfx(SFX.laserBeam, 1.3, root, true)
	local lastTick, lastFx = 0, 0
	t0 = os.clock()
	while os.clock() - t0 < DUR and root.Parent do
		RunService.Heartbeat:Wait()
		local origin = tipPos(character, root)
		local aim = aimPoint() or (origin + root.CFrame.LookVector * 100)
		local dir = (aim - origin)
		dir = dir.Magnitude > 0.1 and dir.Unit or root.CFrame.LookVector
		local endPos = beamEnd(origin, dir, RANGE, character)
		local len = (endPos - origin).Magnitude
		local w = W * rf(0.9, 1.15)
		local cf = CFrame.lookAt((origin + endPos) / 2, endPos) * CFrame.Angles(0, math.rad(90), 0)
		outer.Size = V3(len, w, w)
		outer.CFrame = cf
		inner.Size = V3(len, w * 0.4, w * 0.4)
		inner.CFrame = cf
		flare.CFrame = CFrame.new(origin)
		endBall.CFrame = CFrame.new(endPos)

		if os.clock() - lastTick > 0.08 then
			lastTick = os.clock()
			for _, n in ipairs(npcsIn((origin + endPos) / 2, len / 2 + 10)) do
				if segDist(n.root.Position, origin, endPos) < w * 2 + 3 then
					hurt(n, 5)
					launch(n, dir * 70 + V3(0, 30, 0), 0.4)
				end
			end
		end
		if os.clock() - lastFx > 0.15 then
			lastFx = os.clock()
			burst(anchorPart(endPos, 1), { "Stars" })
			shockwave(endPos, 6 * sq, 0.3, 0, pal[1])
			sfx(SFX.impactExp, 0.45, anchorPart(endPos, 3), false, rf(1.1, 1.6))
			for _, r2 in ipairs(ownedRoots(endPos, 30 * sq)) do kick(r2, dir * 120 + V3(0, 70, 0), randomSpin(10)) end
		end
	end
	stopSfx(beamSnd, 0.25)
	for _, p in ipairs({ outer, inner, endBall, flare }) do tweenKill(p, 0.25, { Transparency = 1 }) end
end

-- AMETHYST: Meteoroids. For 8 seconds small meteoroids rain down and seek out NPCs
SECOND.amethyst = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local DUR = 8
	local aim = aimPoint() or root.Position
	local center = groundTarget(aim, root, character)
	sfx(SFX.magicCaster, 1.2, root)
	skyOn(0.5, pal[3], 0.6)
	flash(root.Position, 0.3, m)

	local npcs, lastScan, idx = {}, -1, 0
	local t0 = os.clock()
	while os.clock() - t0 < DUR and root.Parent do
		if os.clock() - lastScan > 0.5 then
			lastScan = os.clock()
			npcs = npcsIn(root.Position, maxRange())
		end
		for _ = 1, (m.big and 3 or 1) do
			idx += 1
			local npc = #npcs > 0 and npcs[rand(#npcs)] or nil
			local ang, r = rand() * TAU, 70 * sq * math.sqrt(rand())
			local fb = center + V3(math.cos(ang) * r, 1, math.sin(ang) * r)
			local anchor = npc and npc.root.Position or fb
			meteoroid(m, anchor + V3(rf(-90, 90), 160, rf(-90, 90)), npc, fb, idx)
		end
		task.wait(0.08)
	end
	task.wait(3)
	skyOff(1.2)
end

-- CRIMSON: Crescent Wave. Piercing crescents of red light cut forward, one after another
SECOND.crimson = function(ctx)
	local m, root = ctx.m, ctx.root
	local origin = root.Position
	local aim = aimPoint() or (origin + root.CFrame.LookVector * 100)
	local dir = flat(aim - origin)
	dir = dir.Magnitude > 1 and dir.Unit or flatDir(flat(root.CFrame.LookVector))
	sfx(SFX.thunderBoom, 0.9, root, false, 1.2)
	local waves = m.big and 5 or 3
	for w = 1, waves do
		sfx(SFX.fireSlash, 1, root, false, rf(0.9, 1.1))
		task.spawn(crescentWave, root.Position, dir, m, 1 + (w - 1) * 0.15, 0.95, 35)
		flash(root.Position, 0.15, m)
		shake(0.2, 0.6)
		task.wait(0.18)
	end
	task.wait(1.1)
end

-- GRIMGOLD: Echo Strike. Every NPC in range is locked on, then a golden lance falls on each one
SECOND.grimgold = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local params = rayParams(character)
	sfx(SFX.thunderStrike, 1.1, root)
	local list = npcsIn(root.Position, maxRange())
	table.sort(list, function(a, b)
		return (a.root.Position - root.Position).Magnitude < (b.root.Position - root.Position).Magnitude
	end)
	local cap = m.big and 120 or 40
	while #list > cap do table.remove(list) end

	local function strike(getPos, i, delayT)
		task.spawn(function()
			local ground = groundAt(getPos(), params)
			local ret = haloRing(ground + V3(0, 0.3, 0), 22 * sq, pal[1])
			tw(ret, 0.8, { Size = V3(5, 0.05, 5) }, ES.Quad, ED.In)
			task.wait(0.8 + delayT)
			ret:Destroy()
			local pos = getPos()
			local lance = fxPart({ Color = pal[1], Size = V3(4 * sq, 260, 4 * sq), Position = pos + V3(0, 130, 0), Transparency = 0.05 })
			local core = fxPart({ Color = WHITE, Size = V3(1.6 * sq, 260, 1.6 * sq), Position = pos + V3(0, 130, 0), Transparency = 0 })
			tweenKill(lance, 0.4, { Size = V3(0.3, 260, 0.3), Transparency = 1 })
			tweenKill(core, 0.3, { Size = V3(0.1, 260, 0.1), Transparency = 1 })
			shockwave(pos - V3(0, 2.5, 0), 14 * sq, 0.5, 0, pal[1])
			sfx(SFX.impactExp, 0.5, anchorPart(pos, 3), false, rf(0.9, 1.3))
			burst(anchorPart(pos, 2), { "Stars", "Rays_Thick" })
			for _, n in ipairs(npcsIn(pos, 12 * sq)) do
				hurt(n, 45)
				launch(n, flatDir(flat(n.root.Position - pos)) * 50 + V3(0, 100, 0), 0.9)
			end
			physBlast(pos, 12 * sq, 0.4)
			if i % 4 == 1 then shake(0.2, 0.8) end
		end)
	end

	if #list == 0 then -- nothing to lock on to: strike the aimed area
		local aim = aimPoint() or root.Position
		local c = groundTarget(aim, root, character)
		for i = 1, 12 do
			local p = c + V3(rf(-40, 40), 0, rf(-40, 40)) * sq
			strike(function() return p end, i, i * 0.05)
		end
	else
		for i, n in ipairs(list) do
			strike(function() return n.root.Position end, i, (i - 1) * 0.03)
		end
	end
	flash(root.Position, 0.3, m)
	task.wait(1.6 + #list * 0.03)
end

local function useJudge()
	if judging or os.clock() - lastJudge < JUDGE_COOLDOWN then return end
	local character, hum, root = liveChar()
	if not character then return end
	judging = true
	lastJudge = os.clock()
	local m = mode()
	local ok, err = pcall(SECOND[m.id], { m = m, character = character, hum = hum, root = root })
	if not ok then warn("[IvoryPeriastron] second ability: " .. tostring(err)) end
	judging = false
	lastJudge = os.clock()
end

---------------------------------------------------------------- Sword swing (click / tap) with a real swing animation
local SWING_COOLDOWN = 0.45
local lastSwing = -math.huge

-- fallback when the game has no default Animate script: swing the right arm by hand
local function manualSwing(character, hum)
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local motor
	if r15 then
		local arm = character:FindFirstChild("RightUpperArm")
		motor = arm and arm:FindFirstChild("RightShoulder")
	else
		local torso = character:FindFirstChild("Torso")
		motor = torso and torso:FindFirstChild("Right Shoulder")
	end
	if not motor then return end
	local c0 = motor.C0
	local function rot(a) return r15 and CFrame.Angles(a, 0, 0) or CFrame.Angles(0, 0, a) end
	task.spawn(function()
		tw(motor, 0.1, { C0 = c0 * rot(math.rad(150)) }, ES.Quad, ED.Out).Completed:Wait()
		tw(motor, 0.09, { C0 = c0 * rot(math.rad(15)) }, ES.Quad, ED.In).Completed:Wait()
		tw(motor, 0.2, { C0 = c0 }, ES.Quad, ED.Out)
	end)
end

local function swing(tool)
	if os.clock() - lastSwing < SWING_COOLDOWN then return end
	local character, hum, root = liveChar()
	if not character or not tool then return end
	lastSwing = os.clock()
	local m = mode()
	local sq = math.sqrt(m.scale)
	sfx(SFX.swing, 0.9, root, false, rf(0.95, 1.1))

	-- the default Animate script plays its slash animation when a "toolanim" value appears in the tool and
	-- deletes the value; if it is still there shortly after, nothing handled it and we animate the arm ourselves
	local tag = Instance.new("StringValue")
	tag.Name = "toolanim"
	tag.Value = "Slash"
	tag.Parent = tool
	task.delay(0.12, function()
		if tag.Parent == tool then
			tag:Destroy()
			manualSwing(character, hum)
		end
	end)

	local h = tool:FindFirstChild("Handle")
	local trail = h and h:FindFirstChild("Trail")
	if trail then
		trail.Enabled = true
		task.delay(0.4, function() if trail.Parent then trail.Enabled = false end end)
	end

	-- the cut: a small crescent + damage in front of you at the moment the arm comes down
	task.delay(0.12, function()
		if not root.Parent then return end
		local look = flatDir(flat(root.CFrame.LookVector))
		crescentWave(root.Position + look * 3, look, m, 0.28, 0.2, 0)
		local c = root.Position
		for _, n in ipairs(npcsIn(c + look * 5, 7 * math.sqrt(sq))) do
			if flat(n.root.Position - c):Dot(look) > -2 then
				hurt(n, 3)
				launch(n, look * 28 + V3(0, 12, 0), 0.3)
			end
		end
		burst(anchorPart(c + look * 6 + V3(0, 1, 0), 2), { "Stars" })
	end)
end

---------------------------------------------------------------- Ability 5 (G): the THIRD ability of every Periastron
local ULT = {}
local ulting = false
local lastUlt = -math.huge

local function ultCooldown() return bigMode and 5 or 14 end

local function nearestFirst(list, pos)
	table.sort(list, function(a, b) return (a.root.Position - pos).Magnitude < (b.root.Position - pos).Magnitude end)
	return list
end

-- NOIR: Shadow Tendrils. Thick black tendrils burst out of the ground under you, snake across the map to every
-- NPC in range, hoist them (and any owned parts around them) high into the air, then slam them down.
ULT.noir = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local list = nearestFirst(npcsIn(root.Position, maxRange()), root.Position)
	local cap = m.big and 16 or 6
	while #list > cap do table.remove(list) end
	if #list == 0 then
		showToast("Shadow Tendrils: no target in range", m.hi)
		return
	end
	local params = rayParams(character)
	sfx(SFX.darkCharge, 1.3, root)
	skyOn(0.5, pal[2], 0.5)
	flash(root.Position, 0.3, m)
	shake(0.6, 0.8 * sq)
	local from = groundAt(root.Position, params)
	shockwave(from, 20 * sq, 0.6, 0, pal[1])
	burst(anchorPart(from + V3(0, 2, 0)), { "Core", "Stardust" })

	local done = 0
	for idx, n in ipairs(list) do
		task.spawn(function()
			local ok, err = pcall(function()
				task.wait((idx - 1) * 0.05)
				local N = 24
				local balls, cfs = {}, {}
				for k = 1, N do
					local size = (4.5 - 2.8 * (k / N)) * sq
					balls[k] = ballPart(from, size, k % 4 == 0 and pal[1] or pal[3], k % 4 == 0 and 0.2 or 0, { Material = k % 4 == 0 and NEON or Enum.Material.SmoothPlastic })
					Debris:AddItem(balls[k], 8)
				end
				local to0 = n.root.Position
				local ground = groundAt(to0, params)
				local EXT, HOIST, HOLD = 0.55, 1.0, 0.25
				local t0 = os.clock()
				local grabbed = false
				local lift = 0
				local sound = false
				while true do
					local dt = RunService.Heartbeat:Wait()
					local t = os.clock() - t0
					if t > EXT + HOIST + HOLD or not n.root.Parent then break end
					local tip
					if t < EXT then
						tip = from:Lerp(to0 + V3(0, 3, 0), t / EXT)
					else
						if not grabbed then
							grabbed = true
							n.hum.PlatformStand = true
							for _, r2 in ipairs(ownedRoots(to0, 18 * sq)) do kick(r2, V3(rf(-10, 10), 70, rf(-10, 10)), randomSpin(8)) end
							shockwave(ground, 14 * sq, 0.4, 0, pal[1])
							if idx <= 3 then sfx(SFX.impactExp, 0.7, anchorPart(to0, 3), false, rf(1.0, 1.3)) end
						end
						lift = math.min((t - EXT) / HOIST, 1)
						local ny = ground.Y + 4 + 48 * sq * lift ^ 0.7
						local cur = n.root.Position
						n.root.CFrame = CFrame.new(V3(to0.X, ny, to0.Z)) * CFrame.Angles(0, t * 6, 0)
						n.root.AssemblyLinearVelocity = V3(0, 0, 0)
						tip = n.root.Position - V3(0, 2, 0)
					end
					local dir = tip - from
					local side = dir:Cross(Vector3.yAxis)
					side = side.Magnitude > 0.01 and side.Unit or V3(1, 0, 0)
					for k = 1, N do
						local f = k / N
						local wob = math.sin(f * 7 + t * 9 + idx) * 5 * sq * math.sin(f * math.pi) * (1 - lift * 0.6)
						local arc = math.sin(f * math.pi) * 6 * sq * (1 - lift)
						local pos = from:Lerp(tip, f) + side * wob + V3(0, arc, 0)
						if t < EXT * f then pos = from end -- the tendril grows out of the ground
						cfs[k] = CFrame.new(pos)
					end
					workspace:BulkMoveTo(balls, cfs, Enum.BulkMoveMode.FireCFrameChanged)
				end

				-- slam
				if n.hum.Parent and n.hum.Health > 0 then
					hurtFrac(n, m.big and 0.42 or 0.33)
					launch(n, V3(rf(-20, 20), -280, rf(-20, 20)), 1.2)
				end
				task.wait(0.15)
				shockwave(ground, 26 * sq, 0.5, 0, pal[1])
				shockwave(ground, 14 * sq, 0.4, 0.05, pal[3])
				burst(anchorPart(ground + V3(0, 2, 0), 2), { "Stars", "Rays_Thick" })
				physBlast(ground, 22 * sq, m.scale * 0.5)
				if idx <= 3 then sfx(SFX.explosion2, 0.8, anchorPart(ground, 3), false, rf(1.0, 1.3)) end
				for _, b in ipairs(balls) do tweenKill(b, 0.3, { Transparency = 1, Size = Vector3.one * 0.5 }) end
			end)
			if not ok then warn("[IvoryPeriastron] tendrils: " .. tostring(err)) end
			done += 1
		end)
	end
	local t0 = os.clock()
	while done < #list and os.clock() - t0 < 8 do task.wait(0.1) end
	skyOff(1.2)
end

-- IVORY: Seraph Wings. Wings of light unfold behind you and beat three times; each beat throws a cone of wind that
-- hurls NPCs back, shreds owned parts forward, and showers feathers. The last beat is huge.
ULT.ivory = function(ctx)
	local m, root, hum = ctx.m, ctx.root, ctx.hum
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local F = 8 -- feathers per wing
	local feathers = {}
	for side = -1, 1, 2 do
		for i = 1, F do
			local L = (15 - i * 1.15) * sq
			local p = fxPart({ Color = i % 2 == 0 and WHITE or pal[1], Transparency = 0.15, Size = V3(L, 0.35, 2.2 * sq) })
			feathers[#feathers + 1] = { p = p, side = side, i = i, L = L }
			Debris:AddItem(p, 9)
		end
	end
	local parts, cfs = {}, {}
	for k, f in ipairs(feathers) do parts[k] = f.p end
	sfx(SFX.magicCast, 1.2, root, false, 1.2)
	flash(root.Position, 0.4, m)

	local BEATS = 3
	local BEAT = 0.8
	local total = BEATS * BEAT + 0.6
	local t0 = os.clock()
	local lastBeat = 0
	local oldJump = hum.JumpPower
	local function gust(power, big)
		local look = flatDir(flat(root.CFrame.LookVector))
		local c = root.Position
		local reach = (big and 190 or 120) * sq
		sfx(SFX.whooshBoom, 1.3, root, false, big and 0.8 or 1)
		sfx(SFX.thunderStrike, 0.7, root, false, big and 0.9 or 1.3)
		shake(0.3, 0.9 * sq)
		for i = 1, 4 do
			shockwave(c + look * (i * reach / 5) - V3(0, 2.5, 0), 18 * sq + i * 5, 0.5, i * 0.04, pal[i % 3 + 1])
		end
		-- feather shower
		for i = 1, big and 40 or 20 do
			local fp = fxPart({ Color = i % 2 == 0 and WHITE or pal[1], Transparency = 0.1, Size = V3(0.6, 0.15, 3 * sq) })
			local a = rf(-0.6, 0.6)
			local dirv = (look * math.cos(a) + look:Cross(Vector3.yAxis) * math.sin(a))
			fp.CFrame = CFrame.lookAt(c + V3(0, 3, 0), c + V3(0, 3, 0) + dirv)
			tweenKill(fp, 0.9, { Position = c + V3(0, rf(0, 14), 0) + dirv * rf(30, reach), Transparency = 1 }, ES.Quad, ED.Out, 1)
		end
		for _, n in ipairs(npcsIn(c + look * reach * 0.5, reach * 0.65)) do
			local off = flat(n.root.Position - c)
			if off.Magnitude > 1 and off.Unit:Dot(look) > 0.35 then
				hurtFrac(n, power)
				launch(n, look * (200 + 140 * (big and 1 or 0)) + V3(0, 90, 0), 1.3)
				burst(anchorPart(n.root.Position, 2), { "Stars" })
			end
		end
		for _, r2 in ipairs(ownedRoots(c + look * reach * 0.5, reach * 0.65)) do
			local off = flat(r2.Position - c)
			if off.Magnitude > 1 and off.Unit:Dot(look) > 0.35 then
				kick(r2, look * (170 + 120 * (big and 1 or 0)) + V3(0, 60, 0), randomSpin(14))
			end
		end
	end

	local beat = 0
	while os.clock() - t0 < total and root.Parent and hum.Health > 0 do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		local unfold = math.min(t / 0.35, 1)
		-- flap angle: raised -> slammed down, once per BEAT
		local ph = (t % BEAT) / BEAT
		local flap = (0.95 - 1.5 * math.sin(math.min(ph / 0.45, 1) * math.pi / 2)) + (ph > 0.45 and (ph - 0.45) * 1.2 or 0)
		flap *= unfold
		local base = root.CFrame * CFrame.new(0, 1.6, 1.3)
		for k, f in ipairs(feathers) do
			local fan = (f.i - 1) * 0.24 * unfold
			local cf = base * CFrame.new(f.side * 0.6, 0, 0) * CFrame.Angles(0, f.side * (-0.4 - fan), f.side * -flap) * CFrame.new(f.side * f.L / 2, 0, 0)
			cfs[k] = cf
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		-- a beat lands when the wing slams down (ph just passed 0.45)
		local idx = math.floor(t / BEAT) + 1
		if idx <= BEATS and idx > beat and ph > 0.45 then
			beat = idx
			gust(idx == BEATS and 0.3 or 0.12, idx == BEATS)
		end
	end
	for _, f in ipairs(feathers) do tweenKill(f.p, 0.4, { Transparency = 1 }) end
	hum.JumpPower = oldJump
end

-- AZURE: Chrono Rupture. Time STOPS: every NPC (and every owned part) in range is frozen in place inside a blue
-- clock field. Your hits keep landing as slash marks; when time resumes everything receives all of it at once.
ULT.azure = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local STOP = m.big and 4.2 or 3.2
	local RANGE = math.min(maxRange(), m.big and 600 or 300)
	local list = npcsIn(root.Position, RANGE)
	sfx(SFX.energyCharge, 1.2, root, false, 1.3)
	flash(root.Position, 0.5, m)
	skyOn(0.6, pal[2], 0.3)
	shake(0.4, 1)

	-- the clock: a big disc with 12 ticks and 2 hands, centred on you
	local c0 = root.Position - V3(0, 2.6, 0)
	local face = disc(c0, 2, 0.3, pal[1], 0.7)
	tw(face, 0.4, { Size = V3(0.3, 90 * sq, 90 * sq) }, ES.Back)
	Debris:AddItem(face, STOP + 3)
	local ticks = {}
	for i = 1, 12 do
		local a = i / 12 * TAU
		local tk = fxPart({ Color = WHITE, Size = V3(1.4 * sq, 0.3, i % 3 == 0 and 7 * sq or 4 * sq), Transparency = 0.1 })
		ticks[i] = { p = tk, a = a }
		Debris:AddItem(tk, STOP + 3)
	end
	local hand1 = fxPart({ Color = pal[1], Size = V3(1.2 * sq, 0.4, 36 * sq), Transparency = 0.1 })
	local hand2 = fxPart({ Color = WHITE, Size = V3(0.8 * sq, 0.4, 24 * sq), Transparency = 0.1 })
	Debris:AddItem(hand1, STOP + 3)
	Debris:AddItem(hand2, STOP + 3)

	-- freeze everything
	local frozen, owned, saved = {}, {}, {}
	for _, n in ipairs(list) do
		frozen[#frozen + 1] = { n = n, hits = 0, v = V3(0, 0, 0) }
		n.hum.PlatformStand = true
		n.root.AssemblyLinearVelocity = V3(0, 0, 0)
	end
	for _, f in ipairs(frozen) do
		for _, p in ipairs(f.n.model:GetDescendants()) do
			if p:IsA("BasePart") and not p.Anchored then
				p.AssemblyLinearVelocity = V3(0, 0, 0)
				p.Anchored = true
				saved[#saved + 1] = p
			end
		end
		local hl = make("Highlight", { FillColor = pal[1], OutlineColor = WHITE, FillTransparency = 0.6, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, f.n.model)
		f.hl = hl
	end
	for _, r2 in ipairs(ownedRoots(root.Position, RANGE)) do
		if not r2.Anchored then
			owned[#owned + 1] = { r = r2, v = r2.AssemblyLinearVelocity }
			r2.Anchored = true
		end
	end
	sfx(SFX.glass, 0.7, root, false, 0.6)

	local t0, lastSlash = os.clock(), 0
	local ok, err = pcall(function()
		while os.clock() - t0 < STOP and root.Parent do
			local dt = RunService.Heartbeat:Wait()
			local t = os.clock() - t0
			local c = root.Position - V3(0, 2.6, 0)
			face.CFrame = CFrame.new(c) * CFrame.Angles(0, 0, math.rad(90))
			for _, tk in ipairs(ticks) do
				tk.p.CFrame = CFrame.new(c) * CFrame.Angles(0, tk.a, 0) * CFrame.new(0, 0.3, -42 * sq)
			end
			hand1.CFrame = CFrame.new(c) * CFrame.Angles(0, -t * 6, 0) * CFrame.new(0, 0.5, -18 * sq)
			hand2.CFrame = CFrame.new(c) * CFrame.Angles(0, -t * 0.5, 0) * CFrame.new(0, 0.5, -12 * sq)
			if os.clock() - lastSlash > (m.big and 0.05 or 0.09) and #frozen > 0 then
				lastSlash = os.clock()
				local f = frozen[rand(#frozen)]
				if f.n.root.Parent then
					local p = f.n.root.Position + V3(rf(-2, 2), rf(-2, 3), rf(-2, 2))
					local dirv = V3(rf(-1, 1), rf(-1, 1), rf(-1, 1))
					if dirv.Magnitude < 0.1 then dirv = V3(1, 0, 0) end
					local sl = fxPart({ Color = rand() < 0.5 and WHITE or pal[1], Size = V3(0.3, 0.3, 14 * sq), CFrame = CFrame.lookAt(p, p + dirv) })
					Debris:AddItem(sl, STOP + 2) -- the cut stays hanging in the air until time resumes
					tw(sl, 0.15, { Size = V3(0.25, 0.25, 22 * sq) })
					f.hits += 1
					f.v += dirv.Unit * 18
					if rand() < 0.3 then sfx(SFX.swordSlash, 0.3, anchorPart(p, 2), false, rf(1.3, 1.8)) end
				end
			end
		end
	end)
	if not ok then warn("[IvoryPeriastron] chrono: " .. tostring(err)) end

	-- time resumes
	for _, p in ipairs(saved) do if p.Parent then p.Anchored = false end end
	skyOff(1)
	sfx(SFX.thunderBoom, 1.3, root, false, 1.2)
	sfx(SFX.explosion2, 1.0, root, false, 1)
	flash(root.Position, 0.8, m)
	shake(0.6, 1.6 * sq)
	for i = 1, 4 do shockwave(root.Position - V3(0, 2.5, 0), 40 * sq * (1 + i * 0.4), 0.7, i * 0.06, pal[i % 3 + 1]) end
	for _, f in ipairs(frozen) do
		local n = f.n
		if f.hl then f.hl:Destroy() end
		if n.hum.Parent and n.root.Parent and n.hum.Health > 0 then
			hurtFrac(n, math.min(0.18 + 0.045 * f.hits, m.big and 0.75 or 0.6))
			launch(n, f.v + V3(0, 60, 0), 1.2)
			burst(anchorPart(n.root.Position, 2), { "Stars", "Rays_Thick" })
		end
	end
	for _, o in ipairs(owned) do
		if o.r.Parent then
			o.r.Anchored = false
			kick(o.r, o.v + V3(rf(-90, 90), rf(40, 130), rf(-90, 90)), randomSpin(14))
		end
	end
	for _, tk in ipairs(ticks) do tweenKill(tk.p, 0.4, { Transparency = 1 }) end
	for _, p in ipairs({ face, hand1, hand2 }) do tweenKill(p, 0.4, { Transparency = 1 }) end
end

-- CHARTREUSE: Gamma Cyclone. A toxic green tornado tears forward along your aim, sucking NPCs and owned parts into
-- its spiral, lifting them high while they orbit, and finally hurling everything out sideways.
ULT.chartreuse = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local R = 34 * sq
	local H = 100 * sq
	local SPEED = m.big and 75 or 45
	local DUR = m.big and 8 or 6
	local look = flatDir(flat((ctx.aim - root.Position)))
	local params = rayParams(character)
	local pos = root.Position + look * (R + 10)

	sfx(SFX.energyCharge, 1.1, root, false, 1.1)
	local wind = sfx(SFX.windLoop, 1.5, anchorPart(pos, DUR + 3), true, 0.9)
	flash(root.Position, 0.4, m)

	local B = m.big and 110 or 80
	local blocks, bs, cfs = {}, {}, {}
	for i = 1, B do
		local h = rand()
		local blk = fxPart({
			Color = pick(m, i), Transparency = rf(0.1, 0.45),
			Size = V3(rf(1.5, 3) * sq, 0.5, rf(5, 11) * sq),
		})
		blocks[i] = blk
		bs[i] = { a = rand() * TAU, h = h, spd = rf(0.8, 1.3) }
		Debris:AddItem(blk, DUR + 3)
	end
	local core = fxPart({ Shape = Enum.PartType.Cylinder, Color = pal[3], Transparency = 0.6, Size = V3(H, R * 0.5, R * 0.5) })
	Debris:AddItem(core, DUR + 3)

	local tracked, ownedMap = {}, {}
	local t0, lastScan, lastDot = os.clock(), 0, 0
	local groundY = groundAt(pos, params).Y
	while os.clock() - t0 < DUR and root.Parent do
		local dt = RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		pos += look * SPEED * dt
		groundY += (groundAt(pos, params).Y - groundY) * math.min(1, dt * 6)
		local c = V3(pos.X, groundY, pos.Z)
		wind.Parent.Position = c + V3(0, 10, 0)

		for i, b in ipairs(bs) do
			b.a += dt * (4.5 - 2.5 * b.h) * b.spd
			local rr = R * (0.2 + 0.85 * b.h)
			local p = c + V3(math.cos(b.a) * rr, b.h * H, math.sin(b.a) * rr)
			local tang = V3(-math.sin(b.a), 0, math.cos(b.a))
			cfs[i] = CFrame.lookAt(p, p + tang)
		end
		workspace:BulkMoveTo(blocks, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		core.CFrame = CFrame.new(c + V3(0, H / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))

		if os.clock() - lastScan > 0.25 then
			lastScan = os.clock()
			for _, n in ipairs(npcsIn(c + V3(0, H * 0.4, 0), R * 1.6 + 8)) do
				if not tracked[n.model] and flat(n.root.Position - c).Magnitude < R * 1.4 then
					local off = flat(n.root.Position - c)
					tracked[n.model] = { n = n, a = math.atan2(off.Z, off.X), r = math.clamp(off.Magnitude, 4, R), y = math.max(n.root.Position.Y - groundY, 0), w = rf(0.8, 1.2) }
					n.hum.PlatformStand = true
					for _, p in ipairs(n.model:GetDescendants()) do
						if p:IsA("BasePart") and p.Anchored then p.Anchored = false end
					end
				end
			end
			local c_ = 0
			for _, r2 in ipairs(ownedRoots(c + V3(0, H * 0.4, 0), R * 1.6 + 8)) do
				if not ownedMap[r2] and flat(r2.Position - c).Magnitude < R * 1.4 and c_ < 60 then
					c_ += 1
					local off = flat(r2.Position - c)
					ownedMap[r2] = { a = math.atan2(off.Z, off.X), r = math.clamp(off.Magnitude, 4, R), y = math.max(r2.Position.Y - groundY, 0), w = rf(0.8, 1.4) }
				end
			end
		end

		local function swirl(r2, s)
			s.a += dt * (3.2 + s.y / H * 2.5) * s.w
			s.y = math.min(s.y + dt * (H * 0.3) * (0.7 + 0.5 * s.w), H * 0.9)
			s.r += (R * (0.3 + 0.6 * s.y / H) - s.r) * math.min(1, dt * 2)
			r2.CFrame = CFrame.new(c + V3(math.cos(s.a) * s.r, s.y, math.sin(s.a) * s.r)) * CFrame.Angles(s.a * 2, s.a, 0)
			r2.AssemblyLinearVelocity = V3(0, 0, 0)
			r2.AssemblyAngularVelocity = V3(0, 0, 0)
		end
		for model, s in pairs(tracked) do
			if model.Parent and s.n.root.Parent and s.n.hum.Health > 0 then swirl(s.n.root, s) end
		end
		for r2, s in pairs(ownedMap) do
			if r2.Parent and not r2.Anchored then swirl(r2, s) end
		end
		if os.clock() - lastDot > 0.4 then
			lastDot = os.clock()
			for _, s in pairs(tracked) do hurt(s.n, 3) end
			burst(anchorPart(c + V3(0, rf(0, H), 0), 2), { "Stars" })
		end
	end

	-- release: everything is thrown outward along its orbit tangent
	stopSfx(wind, 0.5)
	sfx(SFX.thunderHuge, 1.2, anchorPart(pos, 5), false, 1.1)
	sfx(SFX.impactExp, 1, anchorPart(pos, 5), false, 0.9)
	local c = V3(pos.X, groundY, pos.Z)
	for i = 1, 3 do shockwave(c, R * (1 + i * 0.7), 0.6, i * 0.06, pal[i]) end
	burst(anchorPart(c + V3(0, 10, 0), 2), { "Rays_Thick", "Stars", "Stardust" })
	shake(0.6, 1.5 * sq)
	for _, s in pairs(tracked) do
		local n = s.n
		if n.hum.Parent and n.root.Parent and n.hum.Health > 0 then
			local tang = V3(-math.sin(s.a), 0, math.cos(s.a))
			hurtFrac(n, m.big and 0.38 or 0.28)
			launch(n, (tang + flatDir(flat(n.root.Position - c)) * 0.8) * 190 + V3(0, 60, 0), 1.5)
		end
	end
	for r2, s in pairs(ownedMap) do
		if r2.Parent and not r2.Anchored then
			local tang = V3(-math.sin(s.a), 0, math.cos(s.a))
			kick(r2, tang * 200 + V3(0, 60, 0), randomSpin(16))
		end
	end
	for _, b in ipairs(blocks) do tweenKill(b, 0.4, { Transparency = 1 }) end
	tweenKill(core, 0.4, { Transparency = 1 })
end

-- AMETHYST: Crystal Prism. A colossal crystal hangs over the target, charges, then fires rainbow prism beams that
-- sweep the ground like lighthouse lamps. Anything touched is scorched; owned parts are flung up. It shatters at the end.
ULT.amethyst = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local target = groundTarget(ctx.aim, root, character)
	local HC = 75 * sq
	local center = target + V3(0, HC, 0)
	local BEAMS = m.big and 10 or 6
	local DUR = m.big and 5 or 4
	local params = rayParams(character)

	sfx(SFX.energyCharge, 1.2, root, false, 0.9)
	local crystal = {}
	for i = 1, 3 do
		crystal[i] = fxPart({
			Color = i == 1 and pal[2] or (i == 2 and pal[1] or WHITE), Transparency = i == 3 and 0.2 or 0.35,
			Size = V3(1, 1, 1) * (i == 3 and 6 or (24 - i * 3)) * sq, CFrame = CFrame.new(center),
		})
		Debris:AddItem(crystal[i], DUR + 5)
	end
	local tele = telegraph(target, 60 * sq, m, 0.9, 1.9)
	skyOn(0.45, pal[3], 0.5)
	local t0 = os.clock()
	while os.clock() - t0 < 0.9 and root.Parent do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		local s = math.min(t / 0.5, 1)
		crystal[1].CFrame = CFrame.new(center) * CFrame.Angles(t * 2, t * 3, math.rad(35)) * CFrame.new(0, 0, 0)
		crystal[2].CFrame = CFrame.new(center) * CFrame.Angles(-t * 2, t * 2, math.rad(55))
		crystal[3].CFrame = CFrame.new(center) * CFrame.Angles(t * 4, 0, t * 4)
	end
	tele.circle.lock()
	tele.destroy()
	flash(center, 0.6, m)
	sfx(SFX.magicCaster, 1.3, anchorPart(center, 6), false, 0.8)

	local beams, cores, cfs = {}, {}, {}
	for i = 1, BEAMS do
		beams[i] = fxPart({ Shape = Enum.PartType.Cylinder, Color = Color3.fromHSV(i / BEAMS, 0.6, 1), Transparency = 0.2, Size = V3(1, 3 * sq, 3 * sq) })
		Debris:AddItem(beams[i], DUR + 3)
	end
	local beamSnd = sfx(SFX.laserBeam, 1.2, anchorPart(center, DUR + 3), true, 1.2)
	local cd, lastOwned = {}, 0
	t0 = os.clock()
	while os.clock() - t0 < DUR and root.Parent do
		local dt = RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		crystal[1].CFrame = CFrame.new(center) * CFrame.Angles(t * 2, t * 3, math.rad(35))
		crystal[2].CFrame = CFrame.new(center) * CFrame.Angles(-t * 2, t * 2, math.rad(55))
		crystal[3].CFrame = CFrame.new(center) * CFrame.Angles(t * 4, 0, t * 4)
		local reach = (45 + 55 * (0.5 + 0.5 * math.sin(t * 1.7))) * sq
		local ends = {}
		for i, b in ipairs(beams) do
			local a = i / BEAMS * TAU + t * 1.8
			local ep = V3(target.X + math.cos(a) * reach, target.Y, target.Z + math.sin(a) * reach)
			local hit = workspace:Raycast(center, (ep - center) * 1.2, params)
			if hit then ep = hit.Position end
			ends[i] = ep
			local len = (ep - center).Magnitude
			b.Color = Color3.fromHSV((i / BEAMS + t * 0.25) % 1, 0.55, 1)
			b.Size = V3(len, 3 * sq, 3 * sq)
			cfs[i] = CFrame.lookAt((center + ep) / 2, ep) * CFrame.Angles(0, math.rad(90), 0)
			if rand() < 0.25 then burst(anchorPart(ep + V3(0, 1, 0), 1), { "Stars" }) end
		end
		workspace:BulkMoveTo(beams, cfs, Enum.BulkMoveMode.FireCFrameChanged)

		for _, n in ipairs(npcsIn(target, 130 * sq)) do
			for i = 1, BEAMS do
				if segDist(n.root.Position, center, ends[i]) < 7 * sq and (cd[n.model] or 0) < os.clock() then
					cd[n.model] = os.clock() + 0.3
					hurt(n, m.big and 5 or 4)
					launch(n, V3(rf(-20, 20), 65, rf(-20, 20)), 0.5)
					break
				end
			end
		end
		if os.clock() - lastOwned > 0.2 then
			lastOwned = os.clock()
			for i = 1, BEAMS, 2 do
				for _, r2 in ipairs(ownedRoots(ends[i], 14 * sq)) do kick(r2, V3(rf(-30, 30), 90, rf(-30, 30)), randomSpin(12)) end
			end
		end
	end

	-- shatter
	stopSfx(beamSnd, 0.3)
	skyOff(1.2)
	sfx(SFX.glass, 1.5, anchorPart(center, 5), false, 0.9)
	sfx(SFX.explosion2, 1.3, anchorPart(center, 5), false, 1)
	flash(center, 1, m)
	for _, b in ipairs(beams) do tweenKill(b, 0.25, { Transparency = 1 }) end
	for _, c in ipairs(crystal) do c:Destroy() end
	for i = 1, 36 do
		local sh = fxPart({ Color = Color3.fromHSV(rand(), 0.55, 1), Size = V3(rf(1, 3), rf(1, 3), rf(3, 8)) * sq, CFrame = CFrame.new(center) * CFrame.Angles(rand() * TAU, rand() * TAU, 0) })
		local a = rand() * TAU
		tweenKill(sh, 1.1, { Position = target + V3(math.cos(a) * rf(5, 70) * sq, rf(0, 3), math.sin(a) * rf(5, 70) * sq), Transparency = 1 }, ES.Quad, ED.In, 1.2)
	end
	shockwave(target, 70 * sq, 0.8, 0, pal[1])
	pillar(target, 12 * sq, WHITE, 0.2, 1)
	shake(0.8, 2 * sq)
	for _, n in ipairs(npcsIn(target, 70 * sq)) do
		hurtFrac(n, m.big and 0.4 or 0.28)
		launch(n, flatDir(flat(n.root.Position - target)) * 110 + V3(0, 100, 0), 1.2)
	end
	physBlast(target, 70 * sq, m.scale * 0.7)
end

-- CRIMSON: Blood Moon. A red moon rises over the target and locks a beam onto every NPC near it: they are slowed,
-- lifted and drained (the blood flows back to you), then the moon pulses and slams them into the ground.
ULT.crimson = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local target = groundTarget(ctx.aim, root, character)
	local MR = 110 * sq -- mark radius
	local DUR = m.big and 7 or 5.5
	local moonPos = target + V3(0, 300 * sq, 0)

	sfx(SFX.thunderHuge, 1.5, root, false, 0.8)
	skyOn(0.8, pal[3], 1)
	local moon = ballPart(moonPos, 4, pal[2], 0.05)
	local halo = ballPart(moonPos, 4, pal[1], 0.7, { Material = Enum.Material.ForceField })
	tw(moon, 1.2, { Size = Vector3.one * 110 * sq }, ES.Quad)
	tw(halo, 1.2, { Size = Vector3.one * 135 * sq }, ES.Quad)
	Debris:AddItem(moon, DUR + 4)
	Debris:AddItem(halo, DUR + 4)
	local ring = disc(target + V3(0, 0.3, 0), MR * 2, 0.2, pal[2], 0.55)
	Debris:AddItem(ring, DUR + 3)
	flash(moonPos, 0.6, m)
	task.wait(1.2)

	local marks = {}
	local list = nearestFirst(npcsIn(target, MR), target)
	local cap = m.big and 24 or 10
	for i = 1, math.min(#list, cap) do
		local n = list[i]
		local beam = fxPart({ Color = pal[1], Transparency = 0.35, Size = V3(1.2 * sq, 1.2 * sq, 10) })
		Debris:AddItem(beam, DUR + 3)
		marks[#marks + 1] = { n = n, beam = beam }
	end
	local snd = sfx(SFX.darkCharge, 1, anchorPart(moonPos, DUR + 3), true, 0.8)

	local t0, lastTick = os.clock(), 0
	while os.clock() - t0 < DUR and root.Parent do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		moon.Size = Vector3.one * (110 + math.sin(t * 4) * 4) * sq
		for _, mk in ipairs(marks) do
			local n = mk.n
			if n.hum.Parent and n.root.Parent and n.hum.Health > 0 then
				local p = n.root.Position
				local len = (p - moonPos).Magnitude
				mk.beam.Size = V3(1.2 * sq, 1.2 * sq, len)
				mk.beam.CFrame = CFrame.lookAt((moonPos + p) / 2, p)
				n.hum.PlatformStand = true
				local v = n.root.AssemblyLinearVelocity
				n.root.AssemblyLinearVelocity = V3(v.X * 0.9, 14 + math.sin(t * 3) * 4, v.Z * 0.9)
			else
				mk.beam.Transparency = 1
			end
		end
		if t - lastTick > 0.5 then
			lastTick = t
			local healed = 0
			for _, mk in ipairs(marks) do
				local n = mk.n
				if n.hum.Parent and n.hum.Health > 0 and n.root.Parent then
					hurt(n, 5)
					healed += 1
					-- a blood orb flies from the NPC to you
					local orb = ballPart(n.root.Position, 1.6 * sq, pal[1], 0.1)
					tweenKill(orb, 0.55, { Position = root.Position + V3(0, 2, 0), Size = Vector3.one * 0.3 }, ES.Quad, ED.In, 0.7)
					if healed <= 3 then burst(anchorPart(n.root.Position, 2), { "Stars" }) end
				end
			end
			if healed > 0 and hum.Parent then hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.01 * math.min(healed, 8)) end
		end
	end

	-- the moon collapses on them
	stopSfx(snd, 0.4)
	skyOff(1.5)
	sfx(SFX.explosion2, 1.5, anchorPart(target, 6), false, 0.9)
	sfx(SFX.thunderBoom, 1.3, anchorPart(target, 6), false, 1)
	flash(moonPos, 1, m)
	shake(0.8, 2 * sq)
	tweenKill(moon, 0.5, { Size = Vector3.one * 10, Transparency = 1 })
	tweenKill(halo, 0.5, { Size = Vector3.one * 10, Transparency = 1 })
	for i = 1, 4 do shockwave(target, MR * (1.1 - i * 0.15), 0.7, i * 0.07, pal[i % 3 + 1]) end
	pillar(target, 14 * sq, pal[2], 0.2, 1.2)
	for _, mk in ipairs(marks) do
		local n = mk.n
		tweenKill(mk.beam, 0.3, { Transparency = 1 })
		if n.hum.Parent and n.root.Parent and n.hum.Health > 0 then
			hurtFrac(n, m.big and 0.35 or 0.25)
			launch(n, V3(rf(-20, 20), -260, rf(-20, 20)), 1.2)
		end
	end
	physBlast(target, MR, m.scale * 0.6)
	task.wait(0.3)
end

-- GRIMGOLD: Midas Shatter. A wave of gold spreads from the target: every NPC (and owned part) it touches is turned
-- to solid frozen gold while gold coins rain down; then all of it shatters into gold shards.
ULT.grimgold = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local target = groundTarget(ctx.aim, root, character)
	local R = 140 * sq
	local HOLD = m.big and 3 or 2.4
	local GOLD_C = Color3.fromRGB(255, 200, 40)

	sfx(SFX.magicCast, 1.2, root, false, 0.9)
	sfx(SFX.thunderStrike, 0.9, anchorPart(target, 6), false, 0.9)
	flash(target, 0.6, m)
	local wave = disc(target + V3(0, 0.6, 0), 2, 0.5, GOLD_C, 0.2)
	tweenKill(wave, 0.9, { Size = V3(0.5, R * 2, R * 2), Transparency = 0.8 }, ES.Quad, ED.Out)
	shockwave(target, R, 0.9, 0.05, pal[1])

	local list = nearestFirst(npcsIn(target, R), target)
	local cap = m.big and 40 or 14
	while #list > cap do table.remove(list) end
	local owned = ownedRoots(target, R)

	local statues = {}
	local function goldify(model, delay)
		task.wait(delay)
		local saved = {}
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				saved[#saved + 1] = { p = p, c = p.Color, mat = p.Material, refl = p.Reflectance }
				p.Color = GOLD_C
				p.Material = Enum.Material.Metal
				p.Reflectance = 0.3
			end
		end
		return saved
	end
	for _, n in ipairs(list) do
		local d = (n.root.Position - target).Magnitude
		task.spawn(function()
			local saved = goldify(n.model, d / (R / 0.9))
			n.hum.PlatformStand = true
			n.root.AssemblyLinearVelocity = V3(0, 0, 0)
			for _, p in ipairs(n.model:GetDescendants()) do
				if p:IsA("BasePart") and not p.Anchored then p.Anchored = true end
			end
			local hl = make("Highlight", { FillColor = GOLD_C, OutlineColor = WHITE, FillTransparency = 0.5, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, n.model)
			statues[#statues + 1] = { n = n, saved = saved, hl = hl }
			burst(anchorPart(n.root.Position, 2), { "Stars", "Rays_Thick" })
			shockwave(n.root.Position - V3(0, 2.5, 0), 10 * sq, 0.4, 0, GOLD_C)
		end)
	end
	local gparts = {}
	for i = 1, math.min(#owned, 60) do
		local r2 = owned[i]
		local d = (r2.Position - target).Magnitude
		task.spawn(function()
			task.wait(d / (R / 0.9))
			if r2.Parent then
				gparts[#gparts + 1] = { p = r2, c = r2.Color, mat = r2.Material }
				r2.Color = GOLD_C
				r2.Material = Enum.Material.Metal
				kick(r2, V3(0, 40, 0), randomSpin(4))
			end
		end)
	end

	-- coins rain down over the whole area while everything is gold
	local t0 = os.clock()
	while os.clock() - t0 < HOLD and root.Parent do
		task.wait(0.05)
		for _ = 1, m.big and 5 or 3 do
			local a, rr = rand() * TAU, R * math.sqrt(rand())
			local pos = target + V3(math.cos(a) * rr, rf(70, 130), math.sin(a) * rr)
			local coin = fxPart({ Shape = Enum.PartType.Cylinder, Color = GOLD_C, Size = V3(0.4, 3 * sq, 3 * sq), CFrame = CFrame.new(pos) * CFrame.Angles(rand() * TAU, 0, rand() * TAU) })
			tweenKill(coin, 0.9, { Position = V3(pos.X, target.Y + 1, pos.Z), Orientation = V3(rand() * 720, 0, rand() * 720) }, ES.Quad, ED.In, 1)
		end
	end

	-- SHATTER
	sfx(SFX.glass, 1.5, anchorPart(target, 6), false, 0.8)
	sfx(SFX.explosion2, 1.2, anchorPart(target, 6), false, 1.1)
	shake(0.8, 2 * sq)
	for _, s in ipairs(statues) do
		local n = s.n
		if s.hl then s.hl:Destroy() end
		for _, r in ipairs(s.saved) do
			if r.p.Parent then
				r.p.Color, r.p.Material, r.p.Reflectance = r.c, r.mat, r.refl
				if r.p.Anchored then r.p.Anchored = false end
			end
		end
		if n.root.Parent then
			local p = n.root.Position
			for i = 1, 12 do
				local sh = fxPart({ Color = GOLD_C, Size = V3(rf(0.8, 2), rf(0.8, 2), rf(0.8, 2)) * sq, CFrame = CFrame.new(p) * CFrame.Angles(rand() * TAU, rand() * TAU, 0) })
				local dirv = V3(rf(-1, 1), rf(0.2, 1.2), rf(-1, 1)).Unit
				tweenKill(sh, 0.9, { Position = p + dirv * rf(15, 45) * sq, Transparency = 1 }, ES.Quad, ED.Out, 1)
			end
			shockwave(p - V3(0, 2.5, 0), 16 * sq, 0.5, 0, GOLD_C)
			burst(anchorPart(p, 2), { "Rays_Thick", "Stars" })
			if n.hum.Parent and n.hum.Health > 0 then
				hurtFrac(n, m.big and 0.5 or 0.4)
				launch(n, flatDir(flat(p - target)) * 90 + V3(0, 130, 0), 1.3)
			end
		end
	end
	for _, g in ipairs(gparts) do
		if g.p.Parent then
			g.p.Color, g.p.Material = g.c, g.mat
			kick(g.p, flatDir(flat(g.p.Position - target)) * rf(60, 170) + V3(0, 110, 0), randomSpin(14))
		end
	end
	shockwave(target, R * 0.7, 0.8, 0, GOLD_C)
end

local function useUlt()
	if ulting or os.clock() - lastUlt < ultCooldown() then return end
	local character, hum, root = liveChar()
	if not character then return end
	ulting = true
	lastUlt = os.clock()
	local m = mode()
	local aim = aimPoint() or (root.Position + root.CFrame.LookVector * 60)
	local ok, err = pcall(ULT[m.id], { m = m, character = character, hum = hum, root = root, aim = aim })
	if not ok then warn("[IvoryPeriastron] third ability: " .. tostring(err)) end
	ulting = false
	lastUlt = os.clock()
end

---------------------------------------------------------------- simulation radius
local SIM_STEPS = { 50, 500, 1000, 5000, 10000 }
local simIdx = 0
local function applySim()
	if simIdx == 0 then return end
	local v = SIM_STEPS[simIdx]
	if sethiddenproperty then
		pcall(sethiddenproperty, player, "SimulationRadius", v)
		pcall(sethiddenproperty, player, "MaximumSimulationRadius", v)
	else
		pcall(function() player.SimulationRadius = v end)
		pcall(function() player.MaximumSimulationRadius = v end)
	end
end
local function cycleSim()
	simIdx = simIdx % #SIM_STEPS + 1
	applySim()
	showToast("Simulation radius: " .. SIM_STEPS[simIdx], WHITE)
end

---------------------------------------------------------------- mode / style switching
local function refreshMode(label)
	buildFx()
	local m = mode()
	for _, holder in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		local tool = holder and holder:FindFirstChild(TOOL_NAME)
		if tool then applyModeToTool(tool) end
	end
	showToast(label, m.accent or m.hi)

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local ground = root.Position - V3(0, 2.5, 0)
		local sq = math.sqrt(m.scale)
		shockwave(ground, 9 * sq, 0.5, 0, m.pal[1])
		shockwave(ground, 6 * sq, 0.4, 0.08, m.pal[2])
		burst(anchorPart(root.Position), { "Stars" })
	end
end

local function cycleStyle()
	styleIdx = styleIdx % #STYLES + 1
	refreshMode("Style: " .. STYLES[styleIdx].name)
end

local function toggleDestructive()
	bigMode = not bigMode
	refreshMode("Destructive: " .. (bigMode and "ON" or "OFF"))
end

---------------------------------------------------------------- ability buttons
local equipped = false
local uiToken = 0
local currentTool = nil
local desktopGui
local desktopButtons = {}
local labelCache = {}

local function aimedCast()
	if currentTool then cast(currentTool, aimPoint()) end
end

-- touch: ang/rad place the button around the jump button; `above` puts it right above another button.
-- desktop: col/row place it in the bottom-right grid.
local BUTTONS = {
	{ act = ACT.nova,   key = Enum.KeyCode.Z, fn = aimedCast,         ang = 176, rad = TOUCH_BUTTON_DISTANCE,       col = 1 },
	{ act = ACT.statue, key = Enum.KeyCode.X, fn = useStatue,         ang = 153, rad = TOUCH_BUTTON_DISTANCE,       col = 2 },
	{ act = ACT.step,   key = Enum.KeyCode.V, fn = useStep,           ang = 107, rad = TOUCH_BUTTON_DISTANCE,       col = 3 },
	{ act = ACT.judge,  key = Enum.KeyCode.F, fn = useJudge,          ang = 108, rad = TOUCH_BUTTON_DISTANCE * 1.6, col = 4 },
	{ act = ACT.theme,  key = Enum.KeyCode.B, fn = cycleStyle,        ang = 166, rad = TOUCH_BUTTON_DISTANCE * 1.6, col = 5 },
	{ act = ACT.mode,   key = Enum.KeyCode.C, fn = toggleDestructive, above = 5,                                    col = 5, row = 1 },
	{ act = ACT.third,  key = Enum.KeyCode.G, fn = useUlt,            ang = 137, rad = TOUCH_BUTTON_DISTANCE * 1.6, col = 6 },
	{ act = ACT.sim,    key = Enum.KeyCode.T, fn = cycleSim,          above = 4,                                    col = 4, row = 1 },
}

local function setLabel(i, text)
	if labelCache[i] == text then return end
	labelCache[i] = text
	local b = BUTTONS[i]
	if desktopButtons[i] then
		desktopButtons[i].Text = text .. "\n[" .. b.key.Name .. "]"
	else
		pcall(CAS.SetTitle, CAS, b.act, text)
	end
end

local function styleButton(b, x, y)
	b.AnchorPoint = Vector2.new(1, 1)
	b.Size = UDim2.fromOffset(92, 92)
	b.Position = UDim2.new(1, x, 1, y)
	b.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	b.BackgroundTransparency = 0.15
	b.TextColor3 = WHITE
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextWrapped = true
	b.AutoButtonColor = true
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	make("UIStroke", { Color = Color3.fromRGB(255, 214, 60), Thickness = 2.5 }, b)
end

-- places the Roblox touch buttons in two arcs, well away from the jump button
local function placeTouchButtons()
	task.wait(0.25)
	local ok = pcall(function()
		local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
		local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
		local first = CAS:GetButton(ACT.nova)
		assert(jump and first and first.Parent and jump.AbsoluteSize.X > 0)
		local frame = first.Parent
		local jc = jump.AbsolutePosition + jump.AbsoluteSize / 2
		local centers = {}
		for i, b in ipairs(BUTTONS) do
			if not b.above then
				local a = math.rad(b.ang)
				local radius = jump.AbsoluteSize.X * b.rad
				centers[i] = jc + Vector2.new(math.cos(a) * radius, -math.sin(a) * radius)
			end
		end
		for i, b in ipairs(BUTTONS) do
			local btn = CAS:GetButton(b.act)
			local center = centers[i]
			if b.above then center = centers[b.above] - Vector2.new(0, btn.AbsoluteSize.Y * 1.15) end
			btn.Position = UDim2.fromOffset(
				center.X - frame.AbsolutePosition.X - btn.AbsoluteSize.X / 2,
				center.Y - frame.AbsolutePosition.Y - btn.AbsoluteSize.Y / 2
			)
		end
	end)
	if not ok then
		local fallback = { { 0.1, 0.3 }, { 0.1, 0.6 }, { 0.6, 0.1 }, { 0.8, 0.1 }, { 0.3, 0.6 }, { 0.3, 0.38 }, { 0.45, 0.1 }, { 0.8, 0.3 } }
		for i, b in ipairs(BUTTONS) do
			CAS:SetPosition(b.act, UDim2.new(fallback[i][1], 0, fallback[i][2], 0))
		end
	end
end

local function showButtons()
	equipped = true
	for _, b in ipairs(BUTTONS) do
		CAS:BindAction(b.act, function(_, state)
			if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			b.fn()
			return Enum.ContextActionResult.Sink
		end, true, b.key)
	end

	if UserInputService.TouchEnabled then
		task.spawn(placeTouchButtons)
	else
		desktopGui = make("ScreenGui", { Name = "IvoryButtons", ResetOnSpawn = false, DisplayOrder = 9 }, guiParent)
		table.insert(ownedInstances, desktopGui)
		for i, b in ipairs(BUTTONS) do
			local btn = make("TextButton", { Name = b.act }, desktopGui)
			styleButton(btn, -24 - 112 * (b.col - 1), -150 - (b.row or 0) * 102)
			btn.MouseButton1Click:Connect(b.fn)
			desktopButtons[i] = btn
		end
	end

	uiToken += 1
	local my = uiToken
	local function cd(last, total, ready)
		local left = total - (os.clock() - last)
		return left > 0 and tostring(math.ceil(left)) or ready
	end
	local simTick = 0
	task.spawn(function()
		while uiToken == my do
			local m = mode()
			local st = STYLES[styleIdx]
			setLabel(1, cd(lastCast, m.cooldown, st.q))
			setLabel(2, statue and "Return" or "Angel's Past")
			setLabel(3, cd(lastStep, STEP_COOLDOWN, st.step))
			setLabel(4, cd(lastJudge, JUDGE_COOLDOWN, st.e))
			setLabel(5, st.short)
			setLabel(6, bigMode and "Destructive: ON" or "Destructive: OFF")
			setLabel(7, cd(lastUlt, ultCooldown(), st.u))
			setLabel(8, simIdx == 0 and "Sim Radius" or ("Sim: " .. SIM_STEPS[simIdx]))
			simTick += 1
			if simTick % 10 == 0 then applySim() end
			task.wait(0.1)
		end
	end)
end

local function hideButtons()
	equipped = false
	uiToken += 1
	for _, name in pairs(ACT) do pcall(CAS.UnbindAction, CAS, name) end
	if desktopGui then desktopGui:Destroy() end
	desktopGui = nil
	table.clear(desktopButtons)
	table.clear(labelCache)
end

---------------------------------------------------------------- give via clone
local function setup(tool)
	table.insert(connections, tool.Equipped:Connect(function()
		currentTool = tool
		applyModeToTool(tool)
		if not equipped then showButtons() end
	end))
	table.insert(connections, tool.Unequipped:Connect(function()
		if equipped then hideButtons() end
	end))
	-- clicking / tapping the screen swings the sword (with the swing animation); abilities are only on the buttons
	table.insert(connections, tool.Activated:Connect(function() swing(tool) end))
end

local function give()
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
	if backpack:FindFirstChild(TOOL_NAME) then return end
	if player.Character and player.Character:FindFirstChild(TOOL_NAME) then return end
	local clone = template:Clone()
	setup(clone)
	applyModeToTool(clone)
	clone.Parent = backpack
end

give()

table.insert(connections, player.CharacterAdded:Connect(function()
	if equipped then hideButtons() end
	removeStatue(false)
	task.wait(0.6)
	give()
end))

print("Rip-off Rainbow Pariastron OMEGA v6 given. Click = swing  [Z] Nova  [X] Angel's Past  [C] Destructive on/off  [V] Lunge  [B] Periastron style  [F] second ability.")
