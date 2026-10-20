--[[
	Ivory Periastron v4 - CLIENT-SIDE
	Execute once. Gives "Rip-off Ivory Pariastron" to your Backpack (re-given every respawn).
	Equip it and the buttons appear. Click / tap the screen = swing the sword (swing animation + small slash).

	  [Nova]         (Z)  the style's main ability (see below)
	  [Angel's Past] (X)  1st press: leave a statue / 2nd press: teleport back + shockwave, 80% -> 30% of NPC max health by distance
	  [Lunge]        (V)  dash forward, cutting through NPCs on the way
	  [Second]       (F)  the style's second ability
	  [Style]        (B)  cycles the Periastron: Noir Psi > Ivory > Azure Alpha > Chartreuse Gamma > Amethyst Kappa > Crimson Mu > Grimgold Beta
	  [Destructive]  (C)  right above the Style button: bigger, faster, deadlier version of whichever style is picked

	  Style             Nova (Z)            Second (F)
	  Noir Psi          Black Hole          Lights Out
	  Ivory             Star Rain           Judgement
	  Azure Alpha       Sword Twirl         Sword Stance
	  Chartreuse Gamma  Green Forcefield    Green Laser
	  Amethyst Kappa    Amethyst Comet      Meteoroids
	  Crimson Mu        Crimson Pillars     Crescent Wave
	  Grimgold Beta     Sonar               Echo Strike

	NPC DAMAGE: every ability hurts NPCs (any Humanoid model that is not a player). Damage = original game number x POWER (10, see config).
	Noir Black Hole: NPCs + owned parts are slowly pulled in, then it explodes: 100% (center) -> 10% (edge) of max health,
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

local TOOL_NAME = "Rip-off Ivory Pariastron"
local STATUE_NAME = "Angel's Past"
local ACT = {
	nova = "IvoryNova", statue = "IvoryStatue", mode = "IvoryMode",
	step = "IvoryStep", theme = "IvoryTheme", judge = "IvoryJudge",
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
		local old = holder and holder:FindFirstChild(TOOL_NAME)
		if old then old:Destroy() end
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
local MAX_RANGE = 180
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
local POWER = 10 -- every ability's damage = the original game's damage x POWER (set to 1 for stock numbers)
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
	{ id = "noir", name = "Noir Periastron Psi", short = "Noir Psi", q = "Black Hole", e = "Lights Out", step = "Shadow Lunge",
		dark = true, pal = { hex("B4B4C8"), hex("55556A"), hex("08080C") }, glow = hex("9A9AB8") },
	{ id = "ivory", name = "Ivory Periastron", short = "Ivory", q = "Star Rain", e = "Judgement", step = "Halo Step",
		pal = { hex("87CEEB"), hex("6495ED"), WHITE }, glow = hex("EAFBFF"), accent = GOLD, flash = WHITE },
	{ id = "azure", name = "Azure Periastron Alpha", short = "Azure Alpha", q = "Sword Twirl", e = "Sword Stance", step = "Azure Lunge",
		pal = { hex("8FD8FF"), hex("2F7BFF"), hex("0A2C8C") }, glow = hex("A5E4FF") },
	{ id = "chartreuse", name = "Chartreuse Periastron Gamma", short = "Chartreuse Gamma", q = "Green Forcefield", e = "Green Laser", step = "Green Lunge",
		pal = { hex("CCFF66"), hex("5BD63B"), hex("0B6B22") }, glow = hex("DFFF8F") },
	{ id = "amethyst", name = "Amethyst Periastron Kappa", short = "Amethyst Kappa", q = "Amethyst Comet", e = "Meteoroids", step = "Amethyst Dash",
		pal = { hex("E0B0FF"), hex("9B4DFF"), hex("3B0B7C") }, glow = hex("E8C0FF") },
	{ id = "crimson", name = "Crimson Periastron Mu", short = "Crimson Mu", q = "Crimson Pillars", e = "Crescent Wave", step = "Crimson Lunge",
		pal = { hex("FF8080"), hex("E0132D"), hex("640010") }, glow = hex("FF5050") },
	{ id = "grimgold", name = "Grimgold Periastron Beta", short = "Grimgold Beta", q = "Sonar", e = "Echo Strike", step = "Gold Lunge",
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
template.ToolTip = "Click = swing  |  Nova [Z]  |  Angel's Past [X]  |  Destructive [C]  |  Lunge [V]  |  Style [B]  |  Second ability [F]"
template.TextureId = "rbxassetid://108137249"
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
	local hit = workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, rayParams(char))
	return hit and hit.Position or (ray.Origin + ray.Direction * MAX_RANGE)
end

local function groundTarget(targetPos, root, character)
	local offset = targetPos - root.Position
	if offset.Magnitude > MAX_RANGE then targetPos = root.Position + offset.Unit * MAX_RANGE end
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
}

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
-- Damage numbers are "original game damage" x POWER (10x). Health is changed on this client; for NPCs your
-- client spawned (like the DuaKNo spawner) that is the real thing.
local function npcsIn(position, radius)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { debrisFolder, player.Character }
	params.MaxParts = 3000
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

local function hurt(n, base) -- base = original damage, multiplied by POWER
	local hum = n.hum
	if hum.Parent and hum.Health > 0 then hum.Health = math.max(0, hum.Health - base * POWER) end
end

local function hurtFrac(n, frac) -- frac of the NPC's MAX health (1 = dead)
	local hum = n.hum
	if not hum.Parent or hum.Health <= 0 then return end
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
	for _, n in ipairs(npcsIn(target, ER)) do
		local d = (n.root.Position - target).Magnitude
		if m.big then kill(n) else hurtFrac(n, 1 - 0.65 * math.clamp(d / ER, 0, 1)) end
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
			burst(anchorPart(pos, 2), { "Stars", "Rays_Thick" })
			for _, n in ipairs(npcsIn(pos, 14 * sq)) do
				hurt(n, 25)
				launch(n, flatDir(flat(n.root.Position - pos)) * 90 + V3(0, 80, 0), 0.9)
			end
			physBlast(pos, 14 * sq, 0.5)
			shake(0.15, 0.4)
		end,
	})
end

-- IVORY: a bright star rises over the target, rains homing light spears on every NPC, then crashes down as a supernova
NOVAS.ivory = function(ctx)
	local m, root = ctx.m, ctx.root
	local s, pal = m.scale, m.pal
	local sq = math.sqrt(s)
	local R = BLAST_RADIUS * s
	local target = groundTarget(ctx.aim, root, ctx.character)
	local stopOrbs = chargeOrbs(root, m, CHARGE_TIME)
	local tele = telegraph(target, R, m, CHARGE_TIME, CHARGE_TIME + 10)
	local endCharge = chargeUp(ctx.tool, CHARGE_TIME)
	task.wait(CHARGE_TIME)
	endCharge()
	stopOrbs()
	tele.circle.lock()

	task.spawn(function()
		local ok, err = pcall(function()
			local sunPos = target + V3(0, 110 * sq, 0)
			local from0 = target + V3(0, 3, 0)
			local sun = ballPart(from0, 3, WHITE, 0)
			local shell = ballPart(from0, 5, pal[1], 0.5)
			local halo = ballPart(from0, 8, pal[2], 0.8)
			make("PointLight", { Brightness = 12, Range = 60, Color = m.glow, Shadows = false }, sun)
			local d = 15 * sq
			tw(sun, 0.9, { Position = sunPos, Size = Vector3.one * d }, ES.Quad, ED.Out)
			tw(shell, 0.9, { Position = sunPos, Size = Vector3.one * d * 1.5 }, ES.Quad, ED.Out)
			tw(halo, 0.9, { Position = sunPos, Size = Vector3.one * d * 2.4 }, ES.Quad, ED.Out)
			pillar(target, 8 * sq, pal[1], 0.4, 0.9)
			burst(anchorPart(sunPos), { "Core", "Rays_Thick" })
			flash(sunPos, 0.4, m)
			task.wait(0.9)

			-- the rain: homing spears at every NPC around the target
			local npcs, lastScan = {}, -1
			local t0, idx = os.clock(), 0
			while os.clock() - t0 < 7 do
				if os.clock() - lastScan > 0.5 then
					lastScan = os.clock()
					npcs = npcsIn(target, R * 1.4)
				end
				for _ = 1, (m.big and 2 or 1) do
					idx += 1
					local my = idx
					local npc = #npcs > 0 and npcs[rand(#npcs)] or nil
					local from = sunPos + V3(rf(-1, 1), rf(-0.4, 0.4), rf(-1, 1)) * 8 * sq
					local ang, r = rand() * TAU, R * math.sqrt(rand())
					local fb = target + V3(math.cos(ang) * r, 1, math.sin(ang) * r)
					local goal = npc and npc.root.Position or fb
					launchBolt({
						pos = from, dir = (goal - from).Unit, npc = npc, fallback = fb, speed = 110, accel = 120, turn = 7,
						life = 3, hitRadius = 3.5 * sq, size = V3(0.8 * sq, 0.8 * sq, 6 * sq), color = pick(m, my), color2 = WHITE,
						onHit = function(pos, hitNpc)
							shockwave(pos + V3(0, 0.3, 0), 7 * sq, 0.4, 0, WHITE)
							if my % 3 == 0 then burst(anchorPart(pos, 2), { "Stars" }) end
							for _, n in ipairs(npcsIn(pos, 7 * sq)) do
								hurt(n, (hitNpc and n.model == hitNpc.model) and 10 or 5)
								launch(n, V3(rf(-20, 20), 45, rf(-20, 20)), 0.6)
							end
						end,
					})
				end
				task.wait(m.big and 0.035 or 0.09)
			end

			-- the star falls
			local land = target + V3(0, 6, 0)
			tw(sun, 0.4, { Position = land, Size = Vector3.one * d * 1.4 }, ES.Quad, ED.In)
			tw(shell, 0.4, { Position = land, Size = Vector3.one * d * 2.2 }, ES.Quad, ED.In)
			tw(halo, 0.4, { Position = land, Size = Vector3.one * d * 3 }, ES.Quad, ED.In)
			task.wait(0.4)
			sun:Destroy()
			shell:Destroy()
			halo:Destroy()
			tele.destroy()
			explode(target, m)
			supernovaDamage(target, R * 1.1, m, sq)
		end)
		tele.destroy()
		if not ok then warn("[IvoryPeriastron] ivory nova: " .. tostring(err)) end
	end)
end

-- NOIR: a black hole. Everything (NPCs + owned parts) is slowly dragged in, then it detonates and throws it all away.
-- Normal: damage 100% at the center -> 10% at the edge of the pull. Destructive: instant kill for everything.
NOVAS.noir = function(ctx)
	local m, root = ctx.m, ctx.root
	local s, pal = m.scale, m.pal
	local sq = math.sqrt(s)
	local PR = 90 * sq -- pull + blast radius
	local target = groundTarget(ctx.aim, root, ctx.character)
	local hole = target + V3(0, 18 * sq, 0)
	local CH = 1
	local stopOrbs = chargeOrbs(root, m, CH)
	local tele = telegraph(target, PR * 0.5, m, CH, CH + 1)
	local endCharge = chargeUp(ctx.tool, CH)
	task.wait(CH)
	endCharge()
	stopOrbs()
	tele.circle.lock()

	task.spawn(function()
		local loopSnd
		local ok, err = pcall(function()
			task.wait(0.25)
			tele.destroy()
			local coreD = 16 * sq
			local core = ballPart(hole, 1, pal[3], 0, { Material = Enum.Material.SmoothPlastic })
			local lens = ballPart(hole, 1, m.glow, 0.82, { Material = Enum.Material.ForceField })
			local rim = ballPart(hole, 1, pal[1], 0.9)
			tw(core, 1.4, { Size = Vector3.one * coreD }, ES.Back)
			tw(lens, 1.4, { Size = Vector3.one * coreD * 1.45 })
			tw(rim, 1.4, { Size = Vector3.one * coreD * 1.12 })
			local field = disc(target + V3(0, 0.2, 0), PR * 2, 0.1, pal[3], 0.55)
			Debris:AddItem(field, 12)
			skyOn(0.6, pal[2], 1.2)
			flash(hole, 0.5, m)
			burst(anchorPart(hole), { "Core", "Stardust" })
			loopSnd = sfx(SFX.bhLoop, 1.2, anchorPart(hole, 12), true)

			-- accretion: stars spiralling into the hole
			local starCount = m.big and 150 or 90
			local stars, sp, cfs = {}, {}, {}
			for i = 1, starCount do
				local star = ballPart(hole, rf(0.4, 1.3) * sq, pick(m, i), 1)
				tw(star, 1, { Transparency = 0.05 })
				stars[i] = star
				sp[i] = { r = rf(coreD * 0.7, PR * 0.8), a = rand() * TAU, y = rf(-0.18, 0.18), spd = rf(0.8, 1.2) }
			end

			-- the slow pull
			local PULL = 6
			local t0, lastScan, lastRing = os.clock(), -1, 0
			local tracked, ownedList = {}, {}
			while true do
				local dt = RunService.Heartbeat:Wait()
				local t = os.clock() - t0
				if t >= PULL then break end
				local k = t / PULL

				for i, st in ipairs(sp) do
					st.r -= (10 + 34 * (1 - math.min(st.r / (PR * 0.8), 1))) * st.spd * dt
					st.a += dt * (260 / (st.r + 14)) * st.spd * 3
					if st.r < coreD * 0.55 then
						st.r = PR * rf(0.5, 0.8)
						st.a = rand() * TAU
					end
					cfs[i] = CFrame.new(hole + V3(math.cos(st.a) * st.r, st.y * st.r, math.sin(st.a) * st.r))
				end
				workspace:BulkMoveTo(stars, cfs, Enum.BulkMoveMode.FireCFrameChanged)

				if t - lastRing > 0.5 then
					lastRing = t
					local ring = disc(target + V3(0, 0.3, 0), PR * 2, 0.15, pal[1], 0.5)
					tweenKill(ring, 1.2, { Size = V3(0.15, coreD, coreD), Transparency = 1 }, ES.Quad, ED.In)
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

				for model, n in pairs(tracked) do
					local r2 = n.root
					if model.Parent and r2.Parent and n.hum.Health > 0 then
						local off = hole - r2.Position
						local dist = off.Magnitude
						if dist > 3 then
							local speed = (12 + 30 * k) * (0.4 + 0.9 * (1 - math.min(dist / PR, 1)))
							r2.AssemblyLinearVelocity = r2.AssemblyLinearVelocity:Lerp(off.Unit * speed, math.min(1, dt * 4))
						else
							r2.AssemblyLinearVelocity = r2.AssemblyLinearVelocity * 0.8
						end
						r2.AssemblyAngularVelocity = V3(0, 5 + 5 * k, 0)
					end
				end
				for _, r2 in ipairs(ownedList) do
					if r2.Parent and not r2.Anchored then
						local off = hole - r2.Position
						local dist = off.Magnitude
						if dist > 3 then
							local speed = (10 + 28 * k) * (0.4 + 0.9 * (1 - math.min(dist / PR, 1)))
							r2.AssemblyLinearVelocity = r2.AssemblyLinearVelocity:Lerp(off.Unit * speed, math.min(1, dt * 3))
						end
						r2.AssemblyAngularVelocity = V3(rf(-1, 1), 4 + 4 * k, rf(-1, 1))
					end
				end
			end

			-- collapse
			stopSfx(loopSnd, 0.4)
			tw(core, 0.4, { Size = Vector3.one * 2 }, ES.Quad, ED.In)
			tw(lens, 0.4, { Size = Vector3.one * 2, Transparency = 1 }, ES.Quad, ED.In)
			tw(rim, 0.4, { Size = Vector3.one * 2, Transparency = 1 }, ES.Quad, ED.In)
			for _, st in ipairs(stars) do tweenKill(st, 0.4, { Position = hole, Transparency = 1 }, ES.Quad, ED.In) end
			task.wait(0.4)
			core:Destroy()
			lens:Destroy()
			rim:Destroy()
			skyOff(2)

			-- BOOM
			sfx(SFX.bhLaunch, 1.6, anchorPart(hole, 8))
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
			scorch(target, PR * 0.6, m)
			cracks(target, PR * 0.6, m, m.big and 30 or 20)
			flingGround(target, PR * 0.5, s * 0.9)
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
				launch(n, away * (180 + 260 * near) * (m.big and 1.5 or 1) + V3(0, 80 + 120 * near, 0), 1.5)
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
		tele.destroy()
		skyOff(1.5)
		if not ok then warn("[IvoryPeriastron] noir nova: " .. tostring(err)) end
	end)
end

-- AZURE: Sword Twirl. You spin at high speed inside rings of blue blades that shred everything in reach
NOVAS.azure = function(ctx)
	local m, root, hum = ctx.m, ctx.root, ctx.hum
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local R = 16 * sq
	local DUR = 5
	sfx(SFX.smallCharge, 0.9, root)
	flash(root.Position, 0.3, m)
	local oldSpeed, oldRot = hum.WalkSpeed, hum.AutoRotate
	hum.WalkSpeed = 75
	hum.AutoRotate = false

	local blades, ps, cs = {}, {}, {}
	local function addBlade(i, y, dir)
		local p = fxPart({ Color = pick(m, i), Size = V3(0.7, 0.35, R), Transparency = 0.1 })
		local a0 = make("Attachment", { Position = V3(0, 1.2, -R / 2) }, p)
		local a1 = make("Attachment", { Position = V3(0, -1.2, -R / 2) }, p)
		make("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 0.45, FaceCamera = true, LightEmission = 1,
			Color = colorSeq(pal, i), Transparency = NumberSequence.new(0.1, 1),
		}, p)
		blades[#blades + 1] = { base = i / 4 * TAU, y = y, dir = dir }
		ps[#ps + 1] = p
		Debris:AddItem(p, DUR + 2)
	end
	for i = 1, 4 do addBlade(i, -0.5, 1) end
	for i = 1, 4 do addBlade(i + 4, 3.5, -1) end

	local t0, spin, lastTick, lastRing = os.clock(), 0, 0, 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		if t >= DUR or not root.Parent or hum.Health <= 0 then break end
		spin += dt * TAU * 3.5
		root.CFrame = root.CFrame * CFrame.Angles(0, dt * TAU * 3.5, 0)
		local c = root.Position
		for i, b in ipairs(blades) do
			cs[i] = CFrame.new(c + V3(0, b.y, 0)) * CFrame.Angles(0, b.base + b.dir * spin * (b.dir == 1 and 1 or 1.3), 0) * CFrame.new(0, 0, -R / 2)
		end
		workspace:BulkMoveTo(ps, cs, Enum.BulkMoveMode.FireCFrameChanged)

		if t - lastRing > 0.12 then -- wind layers rising off the ground
			lastRing = t
			local ring = disc(c - V3(0, 2.6, 0), R * 1.4, 0.15, pick(m, math.floor(t * 10)), 0.5)
			tweenKill(ring, 0.5, { Size = V3(0.15, R * 2.2, R * 2.2), Position = ring.Position + V3(0, 9, 0), Transparency = 1 })
		end
		if t - lastTick > 0.1 then
			lastTick = t
			for _, n in ipairs(npcsIn(c, R * 2.4)) do
				local off = flat(n.root.Position - c)
				local d = off.Magnitude
				if d <= R + 4 and math.abs(n.root.Position.Y - c.Y) < 12 then
					hurt(n, 30)
					launch(n, flatDir(off) * 40 + V3(0, 35, 0), 0.5)
				elseif d > R then
					local r2 = n.root
					r2.AssemblyLinearVelocity = r2.AssemblyLinearVelocity:Lerp(-flatDir(off) * 45, 0.4)
				end
			end
		end
	end

	hum.WalkSpeed, hum.AutoRotate = oldSpeed, oldRot
	for _, p in ipairs(ps) do tweenKill(p, 0.3, { Transparency = 1 }) end
	local c = root.Position
	-- finisher
	for i = 1, 3 do shockwave(c - V3(0, 2.5, 0), R * (3.4 - i * 0.7), 0.6, (i - 1) * 0.08, pal[i]) end
	burst(anchorPart(c), { "Rays_Thick", "Stars", "Stardust" })
	flash(c, 0.5, m)
	shake(0.5, 1.4 * sq)
	for _, n in ipairs(npcsIn(c, R * 3)) do
		hurt(n, 40)
		launch(n, flatDir(flat(n.root.Position - c)) * 150 + V3(0, 90, 0), 1.2)
	end
	physBlast(c, R * 3, m.scale * 0.6)
end

-- CHARTREUSE: Green Forcefield. A huge dome that heals you, repels and punishes NPCs and bats owned parts away
NOVAS.chartreuse = function(ctx)
	local m, root, hum = ctx.m, ctx.root, ctx.hum
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local SR = 38 * sq
	local DUR = 12
	sfx(SFX.smallCharge, 0.9, root)
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
						hurt(n, 15)
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
	for _, n in ipairs(npcsIn(c, SR * 1.6)) do
		hurt(n, 20)
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
		local loopSnd
		local ok, err = pcall(function()
			loopSnd = sfx(SFX.crimsonLoop, 1.3, root, true)
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
							kill(n)
							dissolve(n.model, 0.6, pal[1])
						else
							for _, ax in ipairs(axes) do
								if (p2 - ax).Magnitude < PW / 2 + 2 and (cd[n.model] or 0) < os.clock() then
									cd[n.model] = os.clock() + 0.25
									hurt(n, 70)
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
	local PR = 150 * sq
	local BLUE = Color3.fromRGB(70, 160, 255)
	sfx(SFX.smallCharge, 0.9, root)

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
		tweenKill(ring, 0.9, { Size = V3(0.4, PR * 2, PR * 2), Transparency = 1 }, ES.Linear)
		local ring2 = disc(origin + V3(0, 0.5, 0), 2, 0.3, WHITE, 0.3)
		tweenKill(ring2, 0.9, { Size = V3(0.2, PR * 1.9, PR * 1.9), Transparency = 1 }, ES.Linear)
		local t0 = os.clock()
		local hitSet = {}
		local list = npcsIn(origin, PR + 12)
		while os.clock() - t0 < 0.9 do
			RunService.Heartbeat:Wait()
			local rad = (os.clock() - t0) / 0.9 * PR
			for _, n in ipairs(list) do
				if not hitSet[n.model] and n.hum.Parent and n.hum.Health > 0 then
					if flat(n.root.Position - origin).Magnitude <= rad + 6 then
						hitSet[n.model] = true
						tag(n)
						hurt(n, 5)
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
			hurt(n, 25)
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
	sfx(SFX.smallCharge, 0.9, root)
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
		local list = npcsIn(root.Position, 150 * sq)
		table.sort(list, function(a, b)
			return (a.root.Position - root.Position).Magnitude < (b.root.Position - root.Position).Magnitude
		end)
		for i = 1, math.min(#list, m.big and 12 or 5) do
			local n = list[i]
			spikeAt(groundAt(n.root.Position, params), 4 * sq, 16 * sq, pal[3], m.glow, 0.15, 0.5)
			hurt(n, 12)
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
	sfx(SFX.smallCharge, 0.9, root)
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
					hurt(n, 12)
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
		hurt(n, 30)
		launch(n, flatDir(flat(n.root.Position - target)) * 90 + V3(0, 80, 0), 1)
	end
	physBlast(target, R, m.scale * 0.5)
end

-- AZURE: Sword Stance. A parry shield: every NPC that comes close is countered (damage + knockback); when the
-- stance ends all the parries are released in one blast
SECOND.azure = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local DUR, SR = 7, 18 * sq
	sfx(SFX.smallCharge, 0.9, root)
	local shield = ballPart(root.Position, 2, pal[1], 0.55, { Material = Enum.Material.ForceField })
	local inner = ballPart(root.Position, 2, pal[2], 0.93)
	tw(shield, 0.25, { Size = Vector3.one * SR * 2 }, ES.Back)
	tw(inner, 0.25, { Size = Vector3.one * SR * 1.9 }, ES.Back)
	Debris:AddItem(shield, DUR + 2)
	Debris:AddItem(inner, DUR + 2)
	local ff = make("ForceField", { Visible = false }, character)
	shockwave(root.Position - V3(0, 2.5, 0), SR, 0.5, 0, pal[1])
	flash(root.Position, 0.3, m)

	local cds, parries, lastScan = {}, 0, 0
	local t0 = os.clock()
	while os.clock() - t0 < DUR and root.Parent and hum.Health > 0 do
		RunService.Heartbeat:Wait()
		local c = root.Position
		shield.CFrame = CFrame.new(c)
		inner.CFrame = CFrame.new(c)
		hum.Health = hum.MaxHealth -- invulnerable while parrying (this client)
		if os.clock() - lastScan > 0.08 then
			lastScan = os.clock()
			for _, n in ipairs(npcsIn(c, SR + 4)) do
				if (cds[n.model] or 0) < os.clock() then
					cds[n.model] = os.clock() + 0.6
					parries += 1
					local p = n.root.Position
					local away = flatDir(flat(p - c))
					local slash = fxPart({
						Color = WHITE, Size = V3(0.5, 0.5, 14 * sq),
						CFrame = CFrame.lookAt(p, p + V3(rf(-1, 1), rf(-1, 1), rf(-1, 1))),
					})
					tweenKill(slash, 0.25, { Size = V3(0.05, 0.05, 14 * sq), Transparency = 1 })
					shockwave(c - V3(0, 2.5, 0), SR * 0.8, 0.35, 0, WHITE)
					burst(anchorPart(p, 2), { "Stars" })
					hurt(n, 25)
					launch(n, away * 140 + V3(0, 70, 0), 1)
					flash(c, 0.15, m)
					shake(0.2, 0.6)
				end
			end
		end
	end

	ff:Destroy()
	local c = root.Position
	tweenKill(shield, 0.3, { Size = Vector3.one * SR * 3, Transparency = 1 })
	tweenKill(inner, 0.3, { Transparency = 1 })
	-- release: stronger the more parries you landed
	local power = 1 + parries
	for i = 1, 3 do shockwave(c - V3(0, 2.5, 0), SR * (3.4 - i * 0.7), 0.6, (i - 1) * 0.08, pal[i]) end
	burst(anchorPart(c), { "Rays_Thick", "Stars", "Stardust" })
	flash(c, 0.6, m)
	shake(0.5, 1.5)
	for _, n in ipairs(npcsIn(c, SR * 3)) do
		hurt(n, 10 * power)
		launch(n, flatDir(flat(n.root.Position - c)) * (120 + 15 * power) + V3(0, 80, 0), 1.2)
	end
	physBlast(c, SR * 3, m.scale * 0.5)
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
	local RANGE = m.big and 1200 or 450
	local W = 3.2 * sq
	local snd = sfx(SFX.smallCharge, 1, root)

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
					hurt(n, 40)
					launch(n, dir * 70 + V3(0, 30, 0), 0.4)
				end
			end
		end
		if os.clock() - lastFx > 0.15 then
			lastFx = os.clock()
			burst(anchorPart(endPos, 1), { "Stars" })
			shockwave(endPos, 6 * sq, 0.3, 0, pal[1])
		end
	end
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
	sfx(SFX.smallCharge, 0.9, root)
	skyOn(0.5, pal[3], 0.6)
	flash(root.Position, 0.3, m)

	local npcs, lastScan, idx = {}, -1, 0
	local t0 = os.clock()
	while os.clock() - t0 < DUR and root.Parent do
		if os.clock() - lastScan > 0.5 then
			lastScan = os.clock()
			npcs = npcsIn(root.Position, 260 * sq)
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
	sfx(SFX.smallCharge, 0.9, root)
	local waves = m.big and 5 or 3
	for w = 1, waves do
		task.spawn(crescentWave, root.Position, dir, m, 1 + (w - 1) * 0.15, 0.95, 20)
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
	sfx(SFX.smallCharge, 0.9, root)
	local list = npcsIn(root.Position, 220 * sq)
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
			burst(anchorPart(pos, 2), { "Stars", "Rays_Thick" })
			for _, n in ipairs(npcsIn(pos, 12 * sq)) do
				hurt(n, 30)
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
		crescentWave(root.Position + look * 3, look, m, 0.6, 0.35, 0)
		local c = root.Position
		for _, n in ipairs(npcsIn(c + look * 6 * sq, 12 * sq)) do
			if flat(n.root.Position - c):Dot(look) > -2 then
				hurt(n, 10)
				launch(n, look * 55 + V3(0, 25, 0), 0.5)
			end
		end
		burst(anchorPart(c + look * 6 + V3(0, 1, 0), 2), { "Stars" })
	end)
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
		local fallback = { { 0.1, 0.3 }, { 0.1, 0.6 }, { 0.6, 0.1 }, { 0.8, 0.1 }, { 0.3, 0.6 }, { 0.3, 0.38 } }
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

print("Ivory Periastron v4 given. Click = swing  [Z] Nova  [X] Angel's Past  [C] Destructive on/off  [V] Lunge  [B] Periastron style  [F] second ability.")
