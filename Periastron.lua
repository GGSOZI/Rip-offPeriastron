--[[
	Rip-off Rainbow Pariastron OMEGA v10 - CLIENT-SIDE
	Execute once. Gives "Rip-off Rainbow Pariastron OMEGA" to your Backpack (re-given every respawn).
	Equip it and the buttons appear. Click / tap the screen = swing the sword (swing animation + small slash).

	  [Nova]         (Z)  the style's main ability (see below)
	  [Angel's Past] (X)  1st press: leave a statue / 2nd press: teleport back + shockwave, 80% -> 30% of NPC max health by distance
	  [Lunge]        (V)  dash forward, cutting through NPCs on the way
	  [Second]       (F)  the style's second ability
	  [Third]        (G)  the style's third ability: Shadow Tendrils / Angelic Pinwheel / Chrono Rupture / Spore Garden / Crystal Prism / Blood Moon / Midas Shatter / Chroma Serpent
	  SimulationRadius is set to 1000 automatically (and kept there) when you execute (needs sethiddenproperty).
	  [Style]        (B)  cycles the Periastron: Noir Psi > Ivory > Azure Alpha > Chartreuse Gamma > Amethyst Kappa > Crimson Mu > Grimgold Beta
	  [Destructive]  (C)  right above the Style button: bigger, faster, deadlier version of whichever style is picked

	  Style             Nova (Z)            Second (F)
	  Noir Psi          Black Hole          Lights Out
	  Ivory             Toll of Heaven      Lance of Dawn
	  Azure Alpha       Phantom Slash       Sword Prison
	  Chartreuse Gamma  Gamma Mutation      Gamma Smash
	  Amethyst Kappa    Amethyst Comet      Meteoroids
	  Crimson Mu        Crimson Pillars     Crescent Wave
	  Grimgold Beta     Sonar               Echo Strike
	  Rainbow           Chroma Tentacles    Prism Ricochet      (strongest style, unique abilities)

	NPC DAMAGE: every ability hurts NPCs (any Humanoid model that is not a player). Damage = % of the NPC's max health per hit (kept low so abilities don't one-shot; Noir destructive is the exception). EXECUTE: any attack on an NPC at or under 10% health kills it instantly.
	Noir Black Hole: NPCs + owned parts are dragged up into an End-portal style void, then it explodes: 100% (center) -> 10% (edge) of max health,
	everything is launched away. Destructive Noir = instant kill for everything in range.
	Unanchored parts you have NETWORK OWNERSHIP of are pushed / pulled / launched by the abilities too.
	Your own character and other players are never damaged or pushed.

	Sounds: charge-ups, dash, black hole and crimson laser use the Roblox audio IDs in the SFX table.
	Run again to replace the old copy.
]]
local __ivOk, __ivErr = pcall(function()

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
	step = "IvoryStep", theme = "IvoryTheme", judge = "IvoryJudge", third = "IvoryThird",
		fourth = "IvoryFourth", song = "IvorySong", music = "IvoryMusic",
}

local TAU = math.pi * 2
local rand = math.random
local ES, ED = Enum.EasingStyle, Enum.EasingDirection
local NEON = Enum.Material.Neon
local V3 = Vector3.new

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

local function hex(h) return Color3.fromHex(h) end

local STYLES = {
	{ id = "noir", name = "Noir Periastron Psi", short = "Noir Psi", q = "Black Hole", e = "Lights Out", u = "Shadow Tendrils", step = "Shadow Lunge",
		dark = true, pal = { hex("B4B4C8"), hex("55556A"), hex("08080C") }, glow = hex("9A9AB8") },
	{ id = "ivory", name = "Ivory Periastron", short = "Ivory", q = "Toll of Heaven", e = "Lance of Dawn", u = "Angelic Pinwheel", step = "Halo Step",
		pal = { hex("87CEEB"), hex("6495ED"), WHITE }, glow = hex("EAFBFF"), accent = GOLD, flash = WHITE },
	{ id = "azure", name = "Azure Periastron Alpha", short = "Azure Alpha", q = "Phantom Slash", e = "Sword Prison", u = "Chrono Rupture", step = "Azure Lunge",
		pal = { hex("8FD8FF"), hex("2F7BFF"), hex("0A2C8C") }, glow = hex("A5E4FF") },
	{ id = "chartreuse", name = "Chartreuse Periastron Gamma", short = "Chartreuse Gamma", q = "Gamma Mutation", e = "Gamma Smash", u = "Spore Garden", step = "Green Lunge",
		pal = { hex("CCFF66"), hex("5BD63B"), hex("0B6B22") }, glow = hex("DFFF8F") },
	{ id = "amethyst", name = "Amethyst Periastron Kappa", short = "Amethyst Kappa", q = "Amethyst Comet", e = "Meteoroids", u = "Crystal Prism", step = "Amethyst Dash",
		pal = { hex("E0B0FF"), hex("9B4DFF"), hex("3B0B7C") }, glow = hex("E8C0FF") },
	{ id = "crimson", name = "Crimson Periastron Mu", short = "Crimson Mu", q = "Crimson Pillars", e = "Crescent Wave", u = "Blood Moon", step = "Crimson Lunge",
		pal = { hex("FF8080"), hex("E0132D"), hex("640010") }, glow = hex("FF5050") },
	{ id = "grimgold", name = "Grimgold Periastron Beta", short = "Grimgold Beta", q = "Sonar", e = "Echo Strike", u = "Midas Shatter", step = "Gold Lunge",
		pal = { hex("FFE070"), hex("FF9A1F"), hex("8A4A00") }, glow = hex("FFB62E") },
	{ id = "rainbow", name = "Rainbow Periastron", short = "Rainbow", q = "Chroma Tentacles", e = "Prism Ricochet", u = "Prismatic Dimension", v = "Periastron Legion", step = "Prism Step",
		pal = { hex("FFC8F4"), hex("8A63FF"), hex("00C8FF") }, glow = WHITE, flash = WHITE },
}

local MODES = {}
for i, st in ipairs(STYLES) do
	for d = 1, 2 do
		local big = d == 2
		local p = st.pal
		local m = {
			id = st.id, style = i, big = big, name = st.short .. (big and " Destructive" or ""),
			scale = st.id == "rainbow" and (big and 9.5 or 2.2) or (big and 5.4 or 1), cooldown = big and 2 or 10, dark = st.dark or false,
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

local template = Instance.new("Tool")
template.Name = TOOL_NAME
template.ToolTip = "Click = swing  |  Nova [Z]  |  Angel's Past [X]  |  Destructive [C]  |  Lunge [V]  |  Style [B]  |  Second ability [F]  |  Third ability [G]  |  Legion [H] (Rainbow)  |  Next song [N]  |  Music on/off [M]"
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
	toastToken = toastToken + (1)
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

local cc = make("ColorCorrectionEffect", { Enabled = false }, Lighting)
local bloom = make("BloomEffect", { Enabled = false, Intensity = 0, Size = 40, Threshold = 0.7 }, Lighting)
local blur = make("BlurEffect", { Enabled = false, Size = 0 }, Lighting)
table.insert(ownedInstances, cc)
table.insert(ownedInstances, bloom)
table.insert(ownedInstances, blur)

local skyCC = make("ColorCorrectionEffect", { Enabled = false }, Lighting)
table.insert(ownedInstances, skyCC)
local skyBase, skyToken = nil, 0

local function skyOn(strength, tint, dur)
	skyToken = skyToken + (1)
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
	flashToken = flashToken + (1)
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
				n = n + (1)
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

	local outerStroke = stroke(frame(root, 1), th(1.1), c1, 0.05, true)
	stroke(frame(root, 0.965), th(0.35), c2, 0.35, true)

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

	local star1 = frame(root, 0.54, 0)
	stroke(star1, th(0.35), c1, 0.1)
	local star2 = frame(root, 0.54, 45)
	stroke(star2, th(0.35), c3, 0.1)

	local innerStroke = stroke(frame(root, 0.34), th(0.5), c1, 0.1, true)
	stroke(frame(root, 0.2), th(0.3), c3, 0.2, true)
	stroke(frame(root, 0.07, 45), th(0.6), c3, 0)

	local sweep = frame(root, 1)
	local line = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, th(0.5), 0.5, 0), BackgroundColor3 = c3, BorderSizePixel = 0,
	}, sweep)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }),
	}, line)

	local d = 1.2 * sq
	local column = disc(pos + V3(0, 0.1, 0), d, 0.1, c3, 0.35)
	column.CFrame = CFrame.new(pos + V3(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Size = V3(0.1, d, d)
	tw(column, dur, { Size = V3(160, d, d), CFrame = CFrame.new(pos + V3(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, ES.Quad, ED.In)
	Debris:AddItem(column, dur + 8)

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
		aT = aT + (dt * 40 * boost)
		aM = aM + (dt * 55 * boost)
		aS = aS + (dt * 70 * boost)
		aW = aW + (dt * 180 * boost)
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

local function explode(position, m)
	local s, pal = m.scale, m.pal
	local big, dark = s > 1, m.dark
	local R = BLAST_RADIUS * s
	local sq = math.sqrt(s)
	local HOLD, FADE = 3, 2.5 -- the explosion bubble holds ~3s, then fades out slowly

	burst(anchorPart(position))

	local lt = make("PointLight", {
		Color = m.glow, Brightness = dark and 12 or 25, Range = math.min(R * 2, 60), Shadows = false,
	}, anchorPart(position + V3(0, 4, 0), 0.9 + HOLD + FADE + 0.5))
	tw(lt, 0.9 + HOLD + FADE, { Brightness = 0 }, ES.Sine, ED.InOut)

	for i = 1, 3 do
		local ball = ballPart(position, 2, pal[i], 0.1)
		tweenKill(ball, 0.6 + i * 0.15, { Size = Vector3.one * R * (1.9 - i * 0.35), Transparency = 1 }, nil, nil, 1.2)
	end

	if dark then
		local void = ballPart(position + V3(0, R * 0.15, 0), 2, pal[3], 0, { Material = Enum.Material.SmoothPlastic })
		tw(void, 0.45, { Size = Vector3.one * R * 1.1 }).Completed:Connect(function()
			tw(void, 0.55, { Size = Vector3.one * 0.5, Transparency = 1 }, ES.Quad, ED.In)
		end)
		Debris:AddItem(void, 1.3)
	end

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

	local rings = big and 6 or 4
	for i = 1, rings do
		shockwave(position, R * (1.6 - (i - 1) * (1.1 / rings)), 0.7 + i * 0.05, (i - 1) * 0.1, pal[(i - 1) % 3 + 1])
	end

	pillar(position, 18 * s, pal[1], 0.3, 1.5)
	pillar(position, 13 * s, m.mid, 0.35, 1.3)
	pillar(position, 8 * s, dark and m.mid or WHITE, 0.1, 1.1)

	scorch(position, R, m)
	cracks(position, R, m, big and 30 or 18)

	local thick = 0.5 * sq
	for i = 1, (big and 30 or 16) do
		local start = CFrame.new(position + V3(0, 1.5, 0)) * CFrame.Angles(0, (i / (big and 30 or 16)) * TAU, 0)
			* CFrame.Angles(math.rad(rf(10, 45)), 0, 0)
		local sp = fxPart({ Color = pick(m, i), Size = V3(thick, thick, rf(5, 10) * s), CFrame = start })
		tweenKill(sp, rf(0.9, 1.3), { CFrame = start * CFrame.new(0, 0, -R * rf(0.9, 1.7)), Transparency = 1 }, nil, nil, 1.5)
	end

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

local function meteorFlight(targetPos, root, m, sizeMul)
	local s, pal, dark = m.scale, m.pal, m.dark
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
			flightCFs[4] = look * CFrame.new(0, 0, tailLen / 2) * rot90
			flightCFs[5] = look * CFrame.new(0, 0, tailLen * 0.35) * rot90
		end
		workspace:BulkMoveTo(flight, flightCFs, Enum.BulkMoveMode.FireCFrameChanged)
		if raw >= 1 then break end
		RunService.Heartbeat:Wait()
	end

	for _, p in ipairs(flight) do p:Destroy() end
end

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
	bling = 4612374393,            -- bling_diamond_pickup (thienbao2109): sparkle / chime
	stormBolt = 168586586,         -- storm_bolt (SuperEvilAzmil): lightning crack
	psionic = 5272307532,          -- Psionic Storm Impact (SuperEvilAzmil): heavy magic impact
	gong = 9125585925,             -- Gong single hit (ProSoundEffects)
	explosion = 5349302454,        -- Explosion (auroruszs)
	synthStart = 9126070959,       -- Synth Power Start Up (ProSoundEffects): rainbow charge-ups
	synthTone = 9112884584,        -- Synth Tone (ProSoundEffects): rainbow hum / rush
}

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

local function ensureBar(hum)
	pcall(function()
		if hum.HealthDisplayType ~= Enum.HumanoidHealthDisplayType.AlwaysOn then
			hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
		end
		if hum.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
		if hum.HealthDisplayDistance < 1000 then hum.HealthDisplayDistance = 1000 end
	end)
end

local function hurt(n, pct) -- pct = percent of the NPC's MAX health
	local hum = n.hum
	if not hum.Parent or hum.Health <= 0 then return end
	ensureBar(hum)
	if executeCheck(n) then return end
	hum.Health = math.max(0, hum.Health - hum.MaxHealth * pct / 100)
end

local function hurtFrac(n, frac) -- frac of the NPC's MAX health (1 = dead)
	local hum = n.hum
	if not hum.Parent or hum.Health <= 0 then return end
	ensureBar(hum)
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
				b.speed = b.speed + (b.accel * dt)
				b.pos = b.pos + (b.dir * b.speed * dt)
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

local busy = false
local lastCast = -math.huge
local NOVAS = {}

local function supernovaDamage(target, ER, m, sq)
	sfx(SFX.impactExp, 1.5, anchorPart(target, 6), false, 0.85)
	sfx(SFX.explosion, 1.2, anchorPart(target, 6), false, 0.9)
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

NOVAS.ivory = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local R = 95 * sq
	local target = groundTarget(ctx.aim, root, character)
	local HB = 110 * sq -- height of the bell's rim above the ground

	sfx(SFX.magicCast, 1.3, root) -- instant
	local stopOrbs = chargeOrbs(root, m, 0.7)
	local tele = telegraph(target, R * 0.8, m, 0.7, 2)
	task.wait(0.7)
	stopOrbs()
	tele.circle.lock()

	task.spawn(function()
		local bellParts = {}
		local ok, err = pcall(function()
			task.wait(0.2)
			tele.destroy()
			skyOn(0.35, pal[1], 0.6)

			local GOLDC = Color3.fromRGB(255, 205, 70)
			local layers = { { 12, 6 }, { 22, 7 }, { 32, 7 }, { 42, 7 }, { 50, 6 }, { 54, 3 } } -- { diameter, height }
			local offs, parts = {}, {}
			local y = 0
			for i, L in ipairs(layers) do
				local d, h = L[1] * sq, L[2] * sq
				local p = fxPart({
					Shape = Enum.PartType.Cylinder, Color = i == 6 and WHITE or GOLDC, Transparency = 0.05,
					Size = V3(h, d, d), Position = target + V3(0, 400, 0),
				})
				parts[#parts + 1] = p
				offs[#offs + 1] = CFrame.new(0, -(y + h / 2), 0) * CFrame.Angles(0, 0, math.rad(90))
				y = y + (h)
			end
			local clapper = ballPart(target + V3(0, 400, 0), 9 * sq, WHITE, 0)
			parts[#parts + 1] = clapper
			offs[#offs + 1] = CFrame.new(0, -(y - 1 * sq), 0)
			local halo = disc(target + V3(0, 400, 0), 60 * sq, 0.8 * sq, pal[1], 0.3)
			parts[#parts + 1] = halo
			offs[#offs + 1] = CFrame.new(0, -y - 2 * sq, 0) * CFrame.Angles(0, 0, math.rad(90))
			for _, p in ipairs(parts) do Debris:AddItem(p, 16) end
			bellParts = parts
			local totalH = y
			local cfs = {}
			local function place(pivot)
				for i, off in ipairs(offs) do cfs[i] = pivot * off end
				workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			end
			local pivotPos = target + V3(0, HB + totalH, 0)

			sfx(SFX.whooshBoom, 1.1, anchorPart(target, 6), false, 0.8)
			local t0 = os.clock()
			while os.clock() - t0 < 0.9 do
				RunService.Heartbeat:Wait()
				local k = math.min((os.clock() - t0) / 0.9, 1)
				k = 1 - (1 - k) ^ 3
				place(CFrame.new(pivotPos + V3(0, 300 * (1 - k), 0)))
			end
			flash(target + V3(0, HB, 0), 0.5, m)

			local mouth = target + V3(0, HB, 0)
			local tracked = {}
			local function toll(n)
				local sway = (n % 2 == 0) and -0.28 or 0.28
				local ts = os.clock()
				while os.clock() - ts < 0.45 do
					RunService.Heartbeat:Wait()
					local k = (os.clock() - ts) / 0.45
					place(CFrame.new(pivotPos) * CFrame.Angles(0, 0, sway * math.sin(k * math.pi)))
				end
				sfx(SFX.gong, 1.6, anchorPart(mouth, 8), false, 1.05 - n * 0.12)
				if n == 3 then sfx(SFX.thunderHuge, 1.2, anchorPart(mouth, 8), false, 1) end
				flash(mouth, 0.5, m)
				shake(0.5, (1 + n * 0.5) * sq)
				local reach = R * (0.55 + 0.25 * n)
				local wave = ballPart(mouth, 4, pal[1], 0.6, { Material = Enum.Material.ForceField })
				tweenKill(wave, 0.7, { Size = Vector3.one * reach * 2, Transparency = 1 }, ES.Quad, ED.Out)
				local ring = disc(target + V3(0, 0.5, 0), 4, 0.5, WHITE, 0.2)
				tweenKill(ring, 0.7, { Size = V3(0.3, reach * 2, reach * 2), Transparency = 1 }, ES.Quad, ED.Out)
				for i = 1, 3 do shockwave(target, reach * (1.1 - i * 0.2), 0.7, i * 0.06, pal[i % 3 + 1]) end

				for _, npc in ipairs(npcsIn(target + V3(0, HB * 0.3, 0), reach)) do
					if flat(npc.root.Position - target).Magnitude <= reach then
						tracked[npc.model] = npc
						if n == 1 then
							hurt(npc, 6)
							launch(npc, V3(0, 105, 0), 2.2)
						elseif n == 2 then
							hurt(npc, 8)
							npc.hum.PlatformStand = true
							npc.root.AssemblyLinearVelocity = V3(0, 6, 0)
							npc.root.AssemblyAngularVelocity = V3(0, 22, 0)
						else
							hurtFrac(npc, m.big and 0.4 or 0.28)
							launch(npc, V3(rf(-20, 20), -300, rf(-20, 20)), 1.4)
						end
						burst(anchorPart(npc.root.Position, 2), { "Stars" })
					end
				end
				for _, r2 in ipairs(ownedRoots(target + V3(0, HB * 0.3, 0), reach)) do
					if flat(r2.Position - target).Magnitude <= reach then
						if n == 1 then kick(r2, V3(rf(-10, 10), 100, rf(-10, 10)), randomSpin(6))
						elseif n == 2 then kick(r2, V3(0, 4, 0), V3(0, 24, 0))
						else kick(r2, V3(rf(-70, 70), -240, rf(-70, 70)), randomSpin(12)) end
					end
				end
			end
			for n = 1, 3 do toll(n) end

			local fs = os.clock()
			while os.clock() - fs < 0.3 do
				RunService.Heartbeat:Wait()
				local k = math.min((os.clock() - fs) / 0.3, 1) ^ 2
				place(CFrame.new(pivotPos - V3(0, HB * k, 0)))
			end
			sfx(SFX.explosion, 1.6, anchorPart(target, 8), false, 0.9)
			sfx(SFX.glass, 1.5, anchorPart(target, 8), false, 0.7)
			sfx(SFX.impactExp, 1.4, anchorPart(target, 8), false, 0.8)
			skyOff(1.5)
			flash(target, 1, m)
			pillar(target, 16 * sq, pal[1], 0.2, 1.2)
			scorch(target, R * 0.7, m)
			cracks(target, R * 0.7, m, m.big and 30 or 20)
			flingGround(target, R * 0.5, m.scale * 0.8)
			shake(1, 2.4 * sq)
			fovPunch(9, 0.7)
			for _, p in ipairs(parts) do tweenKill(p, 0.4, { Transparency = 1 }) end
			for i = 1, 30 do
				local sh = fxPart({ Color = i % 2 == 0 and GOLDC or WHITE, Size = V3(rf(1, 3), rf(1, 3), rf(3, 8)) * sq, CFrame = CFrame.new(target + V3(0, 6, 0)) * CFrame.Angles(rand() * TAU, rand() * TAU, 0) })
				local a = rand() * TAU
				tweenKill(sh, 1, { Position = target + V3(math.cos(a) * rf(10, R), rf(0, 10), math.sin(a) * rf(10, R)), Transparency = 1 }, ES.Quad, ED.Out, 1.1)
			end
			for _, npc in ipairs(npcsIn(target, R * 0.8)) do
				hurtFrac(npc, m.big and 0.3 or 0.2)
				launch(npc, flatDir(flat(npc.root.Position - target)) * 130 + V3(0, 150, 0), 1.3)
			end
			for model, npc in pairs(tracked) do
				if model.Parent and npc.hum.Parent and npc.hum.Health > 0 then npc.hum.PlatformStand = false end
			end
			physBlast(target, R * 0.8, m.scale)
		end)
		for _, p in ipairs(bellParts) do tweenKill(p, 0.3, { Transparency = 1 }) end
		tele.destroy()
		skyOff(1)
		if not ok then warn("[IvoryPeriastron] toll of heaven: " .. tostring(err)) end
	end)
end

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
	local vig = make("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0,
	}, clip)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, vig)
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.78, 1), NumberSequenceKeypoint.new(1, 0.25) }),
	}, vig)

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
			local col = fxPart({ Color = pal[3], Transparency = 0.6, Size = V3(D * 0.12, hole.Y - target.Y, D * 0.12), Position = (hole + target) / 2 })
			Debris:AddItem(col, 9)
			skyOn(0.6, pal[2], 1.2)
			flash(hole, 0.5, m)
			burst(anchorPart(hole), { "Core", "Stardust" })
			loopSnd = sfx(SFX.bhLoop, 1.4, anchorPart(hole, 12), true)

			local coreD = D
			local starCount = m.big and 150 or 90
			local stars, sp, cfs = {}, {}, {}
			for i = 1, starCount do
				local star = ballPart(hole, rf(0.4, 1.3) * sq, pick(m, i), 1)
				tw(star, 1, { Transparency = 0.05 })
				stars[i] = star
				sp[i] = { r = rf(coreD * 0.6, PR * 0.85), a = rand() * TAU, y = rf(-0.3, 0.3), spd = rf(0.8, 1.2) }
			end

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
					st.r = st.r - ((14 + 60 * (1 - math.min(st.r / (PR * 0.85), 1))) * st.spd * dt)
					st.a = st.a + (dt * (300 / (st.r + 14)) * st.spd * 3)
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

			sfx(SFX.bhLaunch, 1.6, anchorPart(hole, 8))
			sfx(SFX.impactExp, 1.6, anchorPart(hole, 8), false, 0.8)
			sfx(SFX.psionic, 1.5, anchorPart(hole, 8), false, 0.7)
			sfx(SFX.gong, 1.2, anchorPart(hole, 8), false, 0.6)
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

NOVAS.chartreuse = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local R = 80 * sq
	local GROW = m.big and 3 or 2.4
	local MAXSCALE = m.big and 3.2 or 2.6
	local target = groundTarget(ctx.aim, root, character)

	sfx(SFX.energyCharge, 1.3, root, false, 0.9) -- instant
	local stopOrbs = chargeOrbs(root, m, 0.7)
	local tele = telegraph(target, R, m, 0.7, 1.7)
	task.wait(0.7)
	stopOrbs()
	tele.circle.lock()

	task.spawn(function()
		local victims, partsV = {}, {}
		local ok, err = pcall(function()
			task.wait(0.2)
			tele.destroy()
			skyOn(0.3, pal[2], 0.5)
			flash(target, 0.6, m)
			sfx(SFX.psionic, 1.2, anchorPart(target, 6), false, 0.8)
			sfx(SFX.whooshBoom, 1, anchorPart(target, 6), false, 0.7)
			local pulse = disc(target + V3(0, 0.6, 0), 4, 0.6, pal[1], 0.3)
			tweenKill(pulse, 0.7, { Size = V3(0.4, R * 2, R * 2), Transparency = 1 }, ES.Quad, ED.Out)
			local dome = ballPart(target, 4, pal[2], 0.7, { Material = Enum.Material.ForceField })
			tweenKill(dome, 0.8, { Size = Vector3.one * R * 2.2, Transparency = 1 }, ES.Quad, ED.Out)
			for i = 1, 3 do shockwave(target, R * (0.5 + i * 0.25), 0.7, i * 0.07, pal[i % 3 + 1]) end

			local cap = m.big and 50 or 18
			local list = npcsIn(target, R)
			while #list > cap do table.remove(list) end
			for _, n in ipairs(list) do
				local okS, base = pcall(function() return n.model:GetScale() end)
				victims[#victims + 1] = {
					n = n, base = okS and base or 1, canScale = okS,
					hl = make("Highlight", { FillColor = pal[1], OutlineColor = pal[2], FillTransparency = 0.45, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, n.model),
					y0 = n.root.Position.Y,
				}
				n.hum.PlatformStand = true
				for _, p in ipairs(n.model:GetDescendants()) do
					if p:IsA("BasePart") and p.Anchored then p.Anchored = false end
				end
			end
			local owned = ownedRoots(target, R)
			for i = 1, math.min(#owned, 50) do
				local r2 = owned[i]
				partsV[#partsV + 1] = { r = r2, size = r2.Size, color = r2.Color }
			end

			local t0, lastTick = os.clock(), 0
			while os.clock() - t0 < GROW do
				local dt = RunService.Heartbeat:Wait()
				local k = (os.clock() - t0) / GROW
				local sc = 1 + (MAXSCALE - 1) * k ^ 1.6
				for _, v in ipairs(victims) do
					local n = v.n
					if n.hum.Parent and n.root.Parent and n.hum.Health > 0 then
						if v.canScale then pcall(n.model.ScaleTo, n.model, v.base * sc) end
						local p = n.root.Position
						n.root.CFrame = CFrame.new(V3(p.X + rf(-0.4, 0.4) * k * 2, v.y0 + 6 * k * sq + (sc - 1) * 3, p.Z + rf(-0.4, 0.4) * k * 2)) * CFrame.Angles(0, k * 8 + t0, 0)
						n.root.AssemblyLinearVelocity = V3(0, 0, 0)
						n.root.AssemblyAngularVelocity = V3(0, 0, 0)
						v.hl.FillColor = pal[1]:Lerp(Color3.fromRGB(255, 255, 255), math.sin(k * 30) * 0.3 + 0.3)
					end
				end
				for _, pv in ipairs(partsV) do
					if pv.r.Parent and not pv.r.Anchored then
						pcall(function() pv.r.Size = pv.size * sc end)
						pv.r.Color = pv.color:Lerp(pal[1], k)
						pv.r.AssemblyLinearVelocity = pv.r.AssemblyLinearVelocity * 0.9 + V3(0, 2, 0)
					end
				end
				if os.clock() - lastTick > 0.4 then
					lastTick = os.clock()
					for _, v in ipairs(victims) do
						if v.n.hum.Parent and v.n.hum.Health > 0 then
							hurt(v.n, 2)
							burst(anchorPart(v.n.root.Position, 2), { "Stars" })
						end
					end
					sfx(SFX.bling, 0.4, anchorPart(target + V3(rf(-20, 20), rf(2, 25), rf(-20, 20)), 2), false, rf(0.5, 0.9))
				end
			end

			skyOff(1.2)
			sfx(SFX.explosion, 1.6, anchorPart(target, 8), false, 0.9)
			sfx(SFX.impactExp, 1.3, anchorPart(target, 8), false, 0.8)
			shake(0.9, 2 * sq)
			fovPunch(8, 0.6)
			local popped = 0
			for _, v in ipairs(victims) do
				local n = v.n
				if v.hl then v.hl:Destroy() end
				if v.canScale then pcall(n.model.ScaleTo, n.model, v.base) end
				if n.hum.Parent and n.root.Parent then
					popped = popped + (1)
					local p = n.root.Position
					shockwave(p - V3(0, 2.5, 0), 16 * sq, 0.5, 0, pal[1])
					burst(anchorPart(p, 2), { "Rays_Thick", "Stars", "Stardust" })
					for i = 1, 6 do
						local blob = ballPart(p, rf(1.5, 4) * sq, pick(m, i), 0.1)
						tweenKill(blob, 0.8, { Position = p + V3(rf(-30, 30), rf(5, 35), rf(-30, 30)) * sq, Transparency = 1, Size = Vector3.one * 0.3 }, ES.Quad, ED.Out, 0.9)
					end
					if popped <= 4 then sfx(SFX.bling, 0.9, anchorPart(p, 3), false, rf(0.4, 0.7)) end
					if n.hum.Health > 0 then
						hurtFrac(n, m.big and 0.55 or 0.4)
						launch(n, V3(rf(-100, 100), rf(120, 200), rf(-100, 100)), 1.4)
					end
				end
			end
			for _, pv in ipairs(partsV) do
				if pv.r.Parent then
					pcall(function() pv.r.Size = pv.size end)
					pv.r.Color = pv.color
					kick(pv.r, V3(rf(-1, 1), rf(0.3, 1), rf(-1, 1)).Unit * rf(150, 260), randomSpin(16))
				end
			end
			scorch(target, R * 0.5, m)
			physBlast(target, R, m.scale * 0.6)
		end)
		for _, v in ipairs(victims) do
			if v.canScale then pcall(v.n.model.ScaleTo, v.n.model, v.base) end
			if v.hl then v.hl:Destroy() end
		end
		for _, pv in ipairs(partsV) do
			if pv.r.Parent then pcall(function() pv.r.Size = pv.size end) end
		end
		tele.destroy()
		skyOff(1)
		if not ok then warn("[IvoryPeriastron] gamma mutation: " .. tostring(err)) end
	end)
end

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
			sfx(SFX.stormBolt, 1.1, root, false, 0.8)
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
				spin = spin + (dt * (1.5 + 4 * k))
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
			nextPulse = nextPulse + (INTERVAL)
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
		if part.Name ~= "Handle" then totalVol = totalVol + (part.Size.X * part.Size.Y * part.Size.Z) end
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

		part.Material = NEON
		part.Color = WHITE
		part.Transparency = 1
		tw(part, 0.7, { Transparency = SHELL_TRANSPARENCY })
	end

	local hit = workspace:Raycast(root.Position, V3(0, -12, 0), rayParams(character, model))
	local feet = hit and hit.Position or (root.Position - V3(0, 3, 0))
	local center = root.Position

	disc(feet + V3(0, 0.10, 0), 15, 0.1, pal[1], 0.55, model)
	disc(feet + V3(0, 0.13, 0), 10, 0.1, pal[2], 0.4, model)
	disc(feet + V3(0, 0.16, 0), 5.5, 0.1, WHITE, 0.2, model)

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

	local head = model:FindFirstChild("Head")
	if head then
		local hp = head.Position + V3(0, head.Size.Y / 2 + 0.95, 0)
		disc(hp, 3, 0.14, m.dark and pal[1] or WHITE, 0.05, model)
		disc(hp + V3(0, 0.12, 0), 3.8, 0.08, m.accent or pal[2], 0.3, model)
	end

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

	local streakCF = CFrame.lookAt((startPos + endPos) / 2, endPos) * CFrame.Angles(0, math.rad(90), 0)
	local function streak(thick, color, trans)
		local st = fxPart({ Shape = Enum.PartType.Cylinder, Color = color, Transparency = trans, Size = V3(dist, thick, thick), CFrame = streakCF })
		tweenKill(st, 0.5, { Size = V3(dist, 0.1, 0.1), Transparency = 1 }, nil, nil, 0.6)
	end
	streak(2.2, pal[1], 0.3)
	streak(1.0, m.dark and m.mid or WHITE, 0.1)

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

local judging = false
local lastJudge = -math.huge
local SECOND = {}

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
		pos = pos + (dir * 230 * dt)
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

SECOND.noir = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local DUR = 12
	local center = root.Position
	local ground = groundTarget(center, root, character)
	sfx(SFX.darkCharge, 1.2, root)
	skyOn(1, pal[2], 0.8)

	local lit = anchorPart(center + V3(0, 6, 0), DUR + 2)
	make("PointLight", { Brightness = 4, Range = 60, Color = pal[1]:Lerp(WHITE, 0.4), Shadows = false }, lit)
	local ring = disc(ground + V3(0, 0.2, 0), 90 * sq, 0.1, pal[1], 0.75)
	Debris:AddItem(ring, DUR + 2)
	shockwave(ground, 45 * sq, 0.8, 0, pal[1])
	flash(center, 0.4, m)

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

SECOND.ivory = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local LEN = m.big and 1100 or 520
	local SPEED = 380
	local aim = aimPoint() or (root.Position + root.CFrame.LookVector * 200)
	local origin = root.Position + V3(0, 3, 0)
	local dir = (aim - origin)
	dir = dir.Magnitude > 1 and dir.Unit or root.CFrame.LookVector
	local params = rayParams(character)

	sfx(SFX.magicCast, 1.3, root, false, 1.1)
	sfx(SFX.thunderStrike, 1.2, root, false, 0.8)
	flash(origin, 0.5, m)
	shake(0.4, 1)

	local GOLDC = Color3.fromRGB(255, 220, 110)
	local shaft = fxPart({ Color = WHITE, Size = V3(2.4 * sq, 2.4 * sq, 70 * sq) })
	local glow = fxPart({ Color = pal[1], Transparency = 0.5, Size = V3(6 * sq, 6 * sq, 74 * sq) })
	local head = fxPart({ Color = GOLDC, Size = V3(5 * sq, 5 * sq, 14 * sq) })
	local wingL = fxPart({ Color = WHITE, Transparency = 0.2, Size = V3(26 * sq, 0.6 * sq, 16 * sq) })
	local parts = { shaft, glow, head, wingL }
	local trail = make("Trail", {
		Attachment0 = make("Attachment", { Position = V3(0, 0, 30 * sq) }, shaft), Attachment1 = make("Attachment", { Position = V3(0, 0, 30 * sq) + V3(0, 6 * sq, 0) }, shaft),
		Lifetime = 0.5, LightEmission = 1, FaceCamera = true, Color = ColorSequence.new(pal[1], WHITE), Transparency = NumberSequence.new(0.2, 1),
	}, shaft)
	for _, p in ipairs(parts) do Debris:AddItem(p, LEN / SPEED + 4) end
	local lightP = make("PointLight", { Color = pal[1], Brightness = 4, Range = 50, Shadows = false }, shaft)
	local snd = sfx(SFX.whooshBoom, 1.2, shaft, true, 1.2)

	local impaled, ownedImp = {}, {}
	local pos, travelled = origin, 0
	local cfs = {}
	local lastScan, lastOwned = 0, 0
	local count = 0
	while travelled < LEN and root.Parent do
		local dt = RunService.Heartbeat:Wait()
		local step = SPEED * dt
		local hit = workspace:Raycast(pos, dir * (step + 6 * sq), params)
		if hit and not (hit.Instance:FindFirstAncestorOfClass("Model") and hit.Instance:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")) then
			pos = hit.Position
			break
		end
		pos = pos + (dir * step)
		travelled = travelled + (step)
		local cf = CFrame.lookAt(pos, pos + dir)
		cfs[1] = cf * CFrame.new(0, 0, 8 * sq)
		cfs[2] = cf * CFrame.new(0, 0, 8 * sq)
		cfs[3] = cf * CFrame.new(0, 0, -30 * sq)
		cfs[4] = cf * CFrame.new(0, 0, -22 * sq)
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)

		if os.clock() - lastScan > 0.05 then
			lastScan = os.clock()
			for _, n in ipairs(npcsIn(pos, 16 * sq)) do
				if not impaled[n.model] and count < 40 then
					count = count + (1)
					impaled[n.model] = { n = n, off = CFrame.new(rf(-2, 2) * sq, rf(-2, 2) * sq, rf(-12, 4) * sq) * CFrame.Angles(rf(-1, 1), rf(-1, 1), rf(-1, 1)) }
					n.hum.PlatformStand = true
					hurt(n, 10)
					burst(anchorPart(n.root.Position, 2), { "Stars", "Rays_Thick" })
					if count <= 4 then sfx(SFX.swordSlash, 0.8, anchorPart(n.root.Position, 3), false, rf(0.8, 1.1)) end
				end
			end
		end
		if os.clock() - lastOwned > 0.15 then
			lastOwned = os.clock()
			for _, r2 in ipairs(ownedRoots(pos, 16 * sq)) do
				if not ownedImp[r2] and not r2.Anchored then
					ownedImp[r2] = CFrame.new(rf(-3, 3) * sq, rf(-3, 3) * sq, rf(-12, 4) * sq) * CFrame.Angles(rf(-1, 1), rf(-1, 1), rf(-1, 1))
				end
			end
		end
		for model, s in pairs(impaled) do
			if model.Parent and s.n.root.Parent and s.n.hum.Health > 0 then
				s.n.root.CFrame = cf * s.off
				s.n.root.AssemblyLinearVelocity = V3(0, 0, 0)
				s.n.root.AssemblyAngularVelocity = V3(0, 0, 0)
			end
		end
		for r2, off in pairs(ownedImp) do
			if r2.Parent and not r2.Anchored then
				r2.CFrame = cf * off
				r2.AssemblyLinearVelocity = V3(0, 0, 0)
			end
		end
	end

	stopSfx(snd, 0.2)
	sfx(SFX.explosion, 1.6, anchorPart(pos, 8), false, 0.9)
	sfx(SFX.gong, 1.4, anchorPart(pos, 8), false, 0.8)
	sfx(SFX.impactExp, 1.3, anchorPart(pos, 8), false, 1)
	flash(pos, 1, m)
	shake(0.7, 2 * sq)
	for _, p in ipairs(parts) do tweenKill(p, 0.3, { Transparency = 1 }) end
	local dome = ballPart(pos, 4, WHITE, 0.2)
	tweenKill(dome, 0.7, { Size = Vector3.one * 130 * sq, Transparency = 1 }, ES.Quad, ED.Out)
	local dome2 = ballPart(pos, 4, pal[1], 0.5, { Material = Enum.Material.ForceField })
	tweenKill(dome2, 0.9, { Size = Vector3.one * 170 * sq, Transparency = 1 }, ES.Quad, ED.Out)
	local gpos = groundAt(pos, params)
	for i = 1, 4 do shockwave(gpos, 60 * sq * (1 + i * 0.3), 0.7, i * 0.06, pal[i % 3 + 1]) end
	for i = 1, 24 do
		local ray = fxPart({ Color = i % 2 == 0 and WHITE or pal[1], Size = V3(0.8 * sq, 0.8 * sq, 60 * sq), CFrame = CFrame.lookAt(pos, pos + V3(rf(-1, 1), rf(-1, 1), rf(-1, 1))) })
		tweenKill(ray, 0.5, { Size = V3(0.1, 0.1, 140 * sq), Transparency = 1 })
	end
	for model, s in pairs(impaled) do
		local n = s.n
		if model.Parent and n.hum.Parent and n.hum.Health > 0 then
			hurtFrac(n, m.big and 0.4 or 0.28)
			launch(n, flatDir(flat(n.root.Position - pos)) * 170 + V3(0, 140, 0), 1.4)
		end
	end
	for r2 in pairs(ownedImp) do
		if r2.Parent and not r2.Anchored then
			kick(r2, (r2.Position - pos).Unit * 190 + V3(0, 80, 0), randomSpin(16))
		end
	end
	for _, n in ipairs(npcsIn(pos, 60 * sq)) do
		if not impaled[n.model] then
			hurtFrac(n, 0.15)
			launch(n, flatDir(flat(n.root.Position - pos)) * 110 + V3(0, 100, 0), 1)
		end
	end
	physBlast(pos, 70 * sq, m.scale)
end

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
			done = done + (1)
		end)
	end
	local t0 = os.clock()
	while done < #list and os.clock() - t0 < HOLD + 8 do task.wait(0.1) end
	shake(0.4, 1.2)
end

SECOND.chartreuse = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local params = rayParams(character)
	local aim = aimPoint() or (root.Position + root.CFrame.LookVector * 80)
	local fwd = flat(aim - root.Position)
	fwd = fwd.Magnitude > 3 and fwd.Unit or flatDir(flat(root.CFrame.LookVector))
	local reach = math.min(flat(aim - root.Position).Magnitude, m.big and 160 or 90)

	sfx(SFX.energyCharge, 1.2, root, false, 1.4)
	sfx(SFX.whooshBoom, 1.2, root, false, 1)
	flash(root.Position, 0.4, m)
	shockwave(root.Position - V3(0, 2.5, 0), 20 * sq, 0.5, 0, pal[1])
	local orb = ballPart(root.Position, 14 * sq, pal[1], 0.5)
	local orb2 = ballPart(root.Position, 8 * sq, WHITE, 0.2)
	local a0 = make("Attachment", { Position = V3(0, 6 * sq, 0) }, orb)
	local a1 = make("Attachment", { Position = V3(0, -6 * sq, 0) }, orb)
	make("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 0.7, LightEmission = 1, FaceCamera = true, Color = ColorSequence.new(pal[1], pal[3]), Transparency = NumberSequence.new(0.1, 1) }, orb)
	Debris:AddItem(orb, 8)
	Debris:AddItem(orb2, 8)

	local ok, err = pcall(function()
		root.AssemblyLinearVelocity = fwd * (reach / 1.4) + V3(0, 175, 0)
		local t0, falling, landed = os.clock(), false, false
		while os.clock() - t0 < 3 and root.Parent do
			RunService.Heartbeat:Wait()
			orb.CFrame = CFrame.new(root.Position)
			orb2.CFrame = CFrame.new(root.Position)
			local v = root.AssemblyLinearVelocity
			if not falling and v.Y < 10 and os.clock() - t0 > 0.25 then
				falling = true
				sfx(SFX.psionic, 1, root, false, 1.3)
			end
			if falling then
				root.AssemblyLinearVelocity = V3(v.X * 0.9, math.min(v.Y, -30) - 280 * 0.016 * 3, v.Z * 0.9) -- dive
				local hit = workspace:Raycast(root.Position, V3(0, -6, 0), params)
				if hit then landed = true break end
			end
		end
	end)
	if not ok then warn("[IvoryPeriastron] gamma smash leap: " .. tostring(err)) end
	tweenKill(orb, 0.3, { Transparency = 1 })
	tweenKill(orb2, 0.3, { Transparency = 1 })

	local c = groundAt(root.Position, params)
	sfx(SFX.explosion, 1.7, anchorPart(c, 8), false, 0.8)
	sfx(SFX.thunderBoom, 1.4, anchorPart(c, 8), false, 0.9)
	sfx(SFX.impactExp, 1.4, anchorPart(c, 8), false, 0.7)
	flash(c, 1, m)
	shake(1.1, 3 * sq)
	fovPunch(12, 0.8)
	local R = 85 * sq
	for i = 1, 5 do shockwave(c, R * (0.3 + i * 0.2), 0.8, (i - 1) * 0.07, pal[i % 3 + 1]) end
	pillar(c, 18 * sq, pal[1], 0.2, 1.3)
	pillar(c, 8 * sq, WHITE, 0.05, 1)
	scorch(c, R * 0.7, m)
	cracks(c, R, m, m.big and 40 or 28)
	flingGround(c, R * 0.7, m.scale * 1.2)
	burst(anchorPart(c + V3(0, 3, 0)), { "Rays_Thick", "Supernova", "Stars", "Stardust" })

	for _, n in ipairs(npcsIn(c, R)) do
		local d = flat(n.root.Position - c).Magnitude
		local near = 1 - math.clamp(d / R, 0, 1)
		hurtFrac(n, 0.15 + 0.35 * near)
		if d < R * 0.3 then
			launch(n, V3(rf(-20, 20), 260, rf(-20, 20)), 1.6) -- straight up out of the crater
		else
			launch(n, flatDir(flat(n.root.Position - c)) * (160 + 100 * near) + V3(0, 90 + 80 * near, 0), 1.2)
		end
	end
	physBlast(c, R, m.scale * 1.4)

	for w = 1, 3 do
		task.wait(0.35)
		local rr = R * (0.8 + w * 0.5)
		sfx(SFX.psionic, 0.9, anchorPart(c, 5), false, 0.7 + w * 0.15)
		shake(0.35, 1.2 * sq)
		for i = 1, 2 do shockwave(c, rr, 0.6, i * 0.06, pal[(w + i) % 3 + 1]) end
		cracks(c, rr * 0.8, m, 14)
		for _, n in ipairs(npcsIn(c, rr)) do
			if flat(n.root.Position - c).Magnitude > rr * 0.55 then
				hurt(n, m.big and 9 or 7)
				launch(n, V3(rf(-30, 30), 120, rf(-30, 30)), 0.8)
			end
		end
		for _, r2 in ipairs(ownedRoots(c, rr)) do
			if flat(r2.Position - c).Magnitude > rr * 0.55 then kick(r2, V3(rf(-40, 40), 110, rf(-40, 40)), randomSpin(12)) end
		end
	end
end

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
			idx = idx + (1)
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

local SWING_COOLDOWN = 0.45
local lastSwing = -math.huge

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

local ULT = {}
local ulting = false
local lastUlt = -math.huge

local function ultCooldown() return bigMode and 5 or 14 end

local function nearestFirst(list, pos)
	table.sort(list, function(a, b) return (a.root.Position - pos).Magnitude < (b.root.Position - pos).Magnitude end)
	return list
end

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

				if n.hum.Parent and n.hum.Health > 0 then
					hurtFrac(n, m.big and 0.42 or 0.33)
					launch(n, V3(rf(-20, 20), -280, rf(-20, 20)), 1.2)
				end
				task.wait(0.15)
				shockwave(ground, 26 * sq, 0.5, 0, pal[1])
				if idx <= 3 then sfx(SFX.psionic, 0.8, anchorPart(ground, 3), false, rf(0.9, 1.2)) end
				shockwave(ground, 14 * sq, 0.4, 0.05, pal[3])
				burst(anchorPart(ground + V3(0, 2, 0), 2), { "Stars", "Rays_Thick" })
				physBlast(ground, 22 * sq, m.scale * 0.5)
				if idx <= 3 then sfx(SFX.explosion2, 0.8, anchorPart(ground, 3), false, rf(1.0, 1.3)) end
				for _, b in ipairs(balls) do tweenKill(b, 0.3, { Transparency = 1, Size = Vector3.one * 0.5 }) end
			end)
			if not ok then warn("[IvoryPeriastron] tendrils: " .. tostring(err)) end
			done = done + (1)
		end)
	end
	local t0 = os.clock()
	while done < #list and os.clock() - t0 < 8 do task.wait(0.1) end
	skyOff(1.2)
end

ULT.ivory = function(ctx)
	local m, root, hum = ctx.m, ctx.root, ctx.hum
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local ARMS = m.big and 9 or 5
	local DUR = m.big and 6.5 or 5
	local MAXR = (m.big and 260 or 150) * sq
	local FSPEED = 150
	local center0 = root.Position
	local GOLDC = Color3.fromRGB(255, 220, 120)

	sfx(SFX.magicCast, 1.4, root, false, 0.9)
	sfx(SFX.gong, 1.2, root, false, 0.9)
	flash(center0, 0.6, m)
	shake(0.6, 1 * sq)
	local halo = {}
	for i = 1, 3 do
		halo[i] = disc(center0, 2, 0.8, i == 2 and WHITE or pal[1], 0.15)
		tw(halo[i], 0.6, { Size = V3(0.8, (14 + i * 7) * sq, (14 + i * 7) * sq) }, ES.Back)
		Debris:AddItem(halo[i], DUR + 4)
	end
	local windSnd = sfx(SFX.windLoop, 1.1, root, true, 1.1)

	local feathers, fpos, fcf = {}, {}, {}
	local parts = {}
	local nextEmit, emitAngle = 0, 0
	local npcList, ownedList = {}, {}
	local cd = {}
	local t0, lastScan, lastHit, lastBling = os.clock(), -1, 0, 0
	while os.clock() - t0 < DUR and root.Parent do
		local dt = RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		local c = root.Position
		for i, h in ipairs(halo) do
			h.CFrame = CFrame.new(c + V3(0, 1 + i * 1.2, 0)) * CFrame.Angles(0, t * (i % 2 == 0 and 3 or -3), math.rad(90))
		end

		nextEmit = nextEmit - (dt)
		local spinRate = 3 + 2 * (t / DUR)
		emitAngle = emitAngle + (dt * spinRate)
		while nextEmit <= 0 do
			nextEmit = nextEmit + (0.055)
			for a = 1, ARMS do
				local ang = emitAngle + a / ARMS * TAU
				local dirv = V3(math.cos(ang), 0, math.sin(ang))
				local p = fxPart({ Color = (a + #feathers) % 2 == 0 and WHITE or GOLDC, Transparency = 0.1, Size = V3(0.9 * sq, 0.3 * sq, 7 * sq) })
				feathers[#feathers + 1] = { p = p, pos = c + V3(0, 2, 0) + dirv * 6, dir = dirv, dist = 0, c = c }
				parts[#parts + 1] = p
			end
		end

		local alive = {}
		local ps, cs = {}, {}
		for _, f in ipairs(feathers) do
			f.dist = f.dist + (FSPEED * dt)
			if f.dist >= MAXR then
				tweenKill(f.p, 0.15, { Transparency = 1 })
			else
				f.pos = f.pos + (f.dir * FSPEED * dt)
				alive[#alive + 1] = f
				ps[#ps + 1] = f.p
				cs[#cs + 1] = CFrame.lookAt(f.pos, f.pos + f.dir)
			end
		end
		feathers = alive
		if #ps > 0 then workspace:BulkMoveTo(ps, cs, Enum.BulkMoveMode.FireCFrameChanged) end

		if os.clock() - lastScan > 0.4 then
			lastScan = os.clock()
			npcList = npcsIn(c, MAXR)
			ownedList = ownedRoots(c, MAXR)
		end
		if os.clock() - lastBling > 0.35 then
			lastBling = os.clock()
			sfx(SFX.bling, 0.45, anchorPart(c + V3(rf(-30, 30), rf(2, 20), rf(-30, 30)), 2), false, rf(0.8, 1.7))
		end
		if os.clock() - lastHit > 0.1 then
			lastHit = os.clock()
			for _, n in ipairs(npcList) do
				if n.hum.Parent and n.hum.Health > 0 and n.root.Parent and (cd[n.model] or 0) < os.clock() then
					local np = n.root.Position
					for _, f in ipairs(feathers) do
						if (f.pos - np).Magnitude < 8 * sq then
							cd[n.model] = os.clock() + 0.22
							local off = flat(np - c)
							local tang = off.Magnitude > 1 and V3(-off.Unit.Z, 0, off.Unit.X) or f.dir
							hurt(n, m.big and 4 or 3)
							launch(n, tang * 85 + f.dir * 60 + V3(0, 35, 0), 0.5)
							burst(anchorPart(np, 2), { "Stars" })
							break
						end
					end
				end
			end
			for _, r2 in ipairs(ownedList) do
				if r2.Parent and not r2.Anchored and (cd[r2] or 0) < os.clock() then
					local rp = r2.Position
					for _, f in ipairs(feathers) do
						if (f.pos - rp).Magnitude < 9 * sq then
							cd[r2] = os.clock() + 0.25
							local off = flat(rp - c)
							local tang = off.Magnitude > 1 and V3(-off.Unit.Z, 0, off.Unit.X) or f.dir
							kick(r2, tang * 110 + f.dir * 70 + V3(0, 40, 0), randomSpin(10))
							break
						end
					end
				end
			end
		end
	end

	stopSfx(windSnd, 0.4)
	local c = root.Position
	sfx(SFX.explosion, 1.3, root, false, 1.1)
	sfx(SFX.thunderBoom, 1.1, root, false, 1)
	flash(c, 0.9, m)
	shake(0.7, 1.8 * sq)
	for i = 1, 6 do shockwave(c - V3(0, 2.5, 0), MAXR * 0.5 * (0.4 + i * 0.2), 0.8, i * 0.05, pal[i % 3 + 1]) end
	for _, h in ipairs(halo) do tweenKill(h, 0.5, { Size = V3(0.8, MAXR * 0.6, MAXR * 0.6), Transparency = 1 }) end
	for _, p in ipairs(parts) do if p.Parent then tweenKill(p, 0.3, { Transparency = 1 }) end end
	for _, n in ipairs(npcsIn(c, MAXR * 0.6)) do
		hurtFrac(n, m.big and 0.3 or 0.2)
		launch(n, flatDir(flat(n.root.Position - c)) * 190 + V3(0, 110, 0), 1.4)
	end
	physBlast(c, MAXR * 0.6, m.scale)
end

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
					f.hits = f.hits + (1)
					f.v = f.v + (dirv.Unit * 18)
					if rand() < 0.3 then sfx(SFX.swordSlash, 0.3, anchorPart(p, 2), false, rf(1.3, 1.8)) end
				end
			end
		end
	end)
	if not ok then warn("[IvoryPeriastron] chrono: " .. tostring(err)) end

	for _, p in ipairs(saved) do if p.Parent then p.Anchored = false end end
	skyOff(1)
	sfx(SFX.thunderBoom, 1.3, root, false, 1.2)
	sfx(SFX.explosion2, 1.0, root, false, 1)
	sfx(SFX.gong, 1.2, root, false, 0.9)
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

ULT.chartreuse = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local target = groundTarget(ctx.aim, root, character)
	local params = rayParams(character)
	local COUNT = m.big and 10 or 6
	local DUR = m.big and 7 or 5.5
	local CAPR = 17 * sq -- cap radius
	local STEM = 15 * sq

	sfx(SFX.energyCharge, 1.1, root, false, 1.2)
	sfx(SFX.magicCaster, 1.2, anchorPart(target, 6), false, 1.2)
	skyOn(0.25, pal[3], 0.5)
	flash(target, 0.5, m)

	local shrooms = {}
	for i = 1, COUNT do
		local a = i / COUNT * TAU + rf(-0.2, 0.2)
		local rr = (i == 1) and 0 or rf(28, 62) * sq
		local gp = groundAt(target + V3(math.cos(a) * rr, 0, math.sin(a) * rr), params)
		local size = (i == 1) and 1.5 or rf(0.8, 1.2)
		local stem = fxPart({
			Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(235, 245, 200), Material = Enum.Material.SmoothPlastic,
			Size = V3(1, 1, 1), CFrame = CFrame.new(gp) * CFrame.Angles(0, 0, math.rad(90)),
		})
		local cap = fxPart({
			Shape = Enum.PartType.Ball, Color = pick(m, i), Material = NEON, Transparency = 0.1, Size = V3(1, 1, 1), CFrame = CFrame.new(gp),
		})
		local spots = {}
		for s = 1, 5 do
			spots[s] = fxPart({ Shape = Enum.PartType.Ball, Color = WHITE, Size = V3(1, 1, 1), CFrame = CFrame.new(gp), Transparency = 0.1 })
		end
		make("ParticleEmitter", {
			Color = ColorSequence.new(pal[1], pal[2]), Rate = 25, Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(4, 10),
			SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * sq), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.3, 1),
		}, cap)
		local sh = { stem = stem, cap = cap, spots = spots, gp = gp, size = size, a = a, cd = {} }
		shrooms[i] = sh
		for _, p in ipairs({ stem, cap, table.unpack(spots) }) do Debris:AddItem(p, DUR + 5) end
		task.delay(i * 0.07, function()
			shockwave(gp, 20 * sq * size, 0.5, 0, pick(m, i))
			burst(anchorPart(gp + V3(0, 2, 0), 2), { "Stars", "Rays_Thick" })
			if i <= 3 then sfx(SFX.bling, 0.8, anchorPart(gp, 3), false, rf(0.5, 0.8)) end
			tw(stem, 0.4, { Size = V3(STEM * size, 4.5 * sq * size, 4.5 * sq * size), CFrame = CFrame.new(gp + V3(0, STEM * size / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, ES.Back)
			tw(cap, 0.4, { Size = V3(CAPR * 2 * size, CAPR * 1.1 * size, CAPR * 2 * size), CFrame = CFrame.new(gp + V3(0, STEM * size, 0)) }, ES.Back)
			for s, sp in ipairs(spots) do
				local ang = s / #spots * TAU
				tw(sp, 0.4, { Size = Vector3.one * 3.2 * sq * size, Position = gp + V3(math.cos(ang) * CAPR * 0.6 * size, STEM * size + CAPR * 0.45 * size, math.sin(ang) * CAPR * 0.6 * size) }, ES.Back)
			end
		end)
	end
	task.wait(0.8)

	local t0, lastPoison = os.clock(), 0
	local npcList, ownedList, lastScan = {}, {}, -1
	while os.clock() - t0 < DUR and root.Parent do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		if os.clock() - lastScan > 0.2 then
			lastScan = os.clock()
			npcList = npcsIn(target, 110 * sq)
			ownedList = ownedRoots(target, 110 * sq)
		end
		for _, sh in ipairs(shrooms) do
			local top = sh.gp + V3(0, STEM * sh.size + CAPR * 0.55 * sh.size, 0)
			local bob = 1 + 0.05 * math.sin(t * 6 + sh.a)
			sh.cap.Size = V3(CAPR * 2 * sh.size * bob, CAPR * 1.1 * sh.size / bob, CAPR * 2 * sh.size * bob)
			for _, n in ipairs(npcList) do
				if n.hum.Parent and n.hum.Health > 0 and (sh.cd[n.model] or 0) < os.clock() then
					local off = n.root.Position - top
					if flat(off).Magnitude < CAPR * sh.size and off.Y > -10 and off.Y < 14 then
						sh.cd[n.model] = os.clock() + 0.75
						launch(n, V3(rf(-25, 25), 170, rf(-25, 25)), 1)
						hurt(n, 3)
						shockwave(top - V3(0, CAPR * 0.5, 0), 14 * sq, 0.35, 0, pick(m, 2))
						sfx(SFX.bling, 0.55, anchorPart(top, 2), false, rf(0.7, 1.3))
						tw(sh.cap, 0.08, { Size = V3(CAPR * 2.3 * sh.size, CAPR * 0.7 * sh.size, CAPR * 2.3 * sh.size) })
					end
				end
			end
			for _, r2 in ipairs(ownedList) do
				if r2.Parent and not r2.Anchored and (sh.cd[r2] or 0) < os.clock() then
					local off = r2.Position - top
					if flat(off).Magnitude < CAPR * sh.size and off.Y > -10 and off.Y < 14 then
						sh.cd[r2] = os.clock() + 0.6
						kick(r2, V3(rf(-25, 25), 190, rf(-25, 25)), randomSpin(10))
					end
				end
			end
		end
		if os.clock() - lastPoison > 0.5 then
			lastPoison = os.clock()
			for _, n in ipairs(npcList) do
				if n.hum.Parent and n.hum.Health > 0 then
					local near = false
					for _, sh in ipairs(shrooms) do
						if (n.root.Position - sh.gp).Magnitude < 32 * sq then near = true break end
					end
					if near then
						hurt(n, 2)
						slowNpc(n, 0.45, 0.8)
					end
				end
			end
		end
	end

	skyOff(1.2)
	for i, sh in ipairs(shrooms) do
		task.spawn(function()
			task.wait((i - 1) * 0.12)
			local top = sh.gp + V3(0, STEM * sh.size + CAPR * 0.4 * sh.size, 0)
			tw(sh.cap, 0.25, { Size = Vector3.one * CAPR * 3 * sh.size }, ES.Quad, ED.Out)
			task.wait(0.25)
			sfx(SFX.explosion, i <= 3 and 1.1 or 0.5, anchorPart(top, 5), false, rf(0.9, 1.2))
			sfx(SFX.bling, 0.8, anchorPart(top, 5), false, rf(0.4, 0.6))
			shockwave(sh.gp, 34 * sq, 0.6, 0, pick(m, i))
			burst(anchorPart(top, 2), { "Rays_Thick", "Supernova", "Stars", "Stardust" })
			for k = 1, 8 do
				local blob = ballPart(top, rf(2, 5) * sq, pick(m, k), 0.1)
				tweenKill(blob, 0.8, { Position = top + V3(rf(-35, 35), rf(0, 30), rf(-35, 35)) * sq, Transparency = 1, Size = Vector3.one * 0.3 }, ES.Quad, ED.Out, 0.9)
			end
			for _, p in ipairs({ sh.stem, sh.cap, table.unpack(sh.spots) }) do tweenKill(p, 0.15, { Transparency = 1 }) end
			for _, n in ipairs(npcsIn(top, 36 * sq)) do
				hurtFrac(n, m.big and 0.22 or 0.15)
				launch(n, flatDir(flat(n.root.Position - top)) * 90 + V3(0, 210, 0), 1.2)
			end
			physBlast(top, 36 * sq, m.scale * 0.7)
			shake(0.3, 1 * sq)
		end)
	end
	task.wait(#shrooms * 0.12 + 0.6)
end

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

	stopSfx(beamSnd, 0.3)
	skyOff(1.2)
	sfx(SFX.glass, 1.5, anchorPart(center, 5), false, 0.9)
	sfx(SFX.bling, 1.2, anchorPart(center, 5), false, 0.9)
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

ULT.crimson = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local pal = m.pal
	local sq = math.sqrt(m.scale)
	local target = groundTarget(ctx.aim, root, character)
	local MR = 110 * sq -- mark radius
	local DUR = m.big and 7 or 5.5
	local moonPos = target + V3(0, 300 * sq, 0)

	sfx(SFX.thunderHuge, 1.5, root, false, 0.8)
	sfx(SFX.gong, 1.4, root, false, 0.5)
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
					healed = healed + (1)
					local orb = ballPart(n.root.Position, 1.6 * sq, pal[1], 0.1)
					tweenKill(orb, 0.55, { Position = root.Position + V3(0, 2, 0), Size = Vector3.one * 0.3 }, ES.Quad, ED.In, 0.7)
					if healed <= 3 then burst(anchorPart(n.root.Position, 2), { "Stars" }) end
				end
			end
			if healed > 0 and hum.Parent then hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.01 * math.min(healed, 8)) end
		end
	end

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

	local t0 = os.clock()
	while os.clock() - t0 < HOLD and root.Parent do
		task.wait(0.05)
		for _ = 1, m.big and 5 or 3 do
			local a, rr = rand() * TAU, R * math.sqrt(rand())
			local pos = target + V3(math.cos(a) * rr, rf(70, 130), math.sin(a) * rr)
			if rand() < 0.15 then sfx(SFX.bling, 0.35, anchorPart(pos, 2), false, rf(0.9, 1.8)) end
			local coin = fxPart({ Shape = Enum.PartType.Cylinder, Color = GOLD_C, Size = V3(0.4, 3 * sq, 3 * sq), CFrame = CFrame.new(pos) * CFrame.Angles(rand() * TAU, 0, rand() * TAU) })
			tweenKill(coin, 0.9, { Position = V3(pos.X, target.Y + 1, pos.Z), Orientation = V3(rand() * 720, 0, rand() * 720) }, ES.Quad, ED.In, 1)
		end
	end

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

local RB = {}
function RB.hue(t, s, v) return Color3.fromHSV(t % 1, s or 0.7, v or 1) end
RB.last = -math.huge
RB.busy = false

function RB.drawT(balls, cfs, from, tip, t, phase, lift, idx, N, sq, ext)
	local dir = tip - from
	local side = dir:Cross(Vector3.yAxis)
	side = side.Magnitude > 0.01 and side.Unit or V3(1, 0, 0)
	local up2 = dir.Magnitude > 0.01 and side:Cross(dir.Unit) or V3(0, 1, 0)
	for k = 1, N do
		local f = k / N
		local env = math.sin(f * math.pi)
		local damp = 1 - lift * 0.5
		local w1 = math.sin(f * 8 + t * 10 + phase) * 4 * sq * env * damp
		local w2 = math.cos(f * 8 + t * 10 + phase) * 4 * sq * env * damp
		local arc = math.sin(f * math.pi) * 5 * sq * (1 - lift)
		local pos = from:Lerp(tip, f) + side * w1 + up2 * w2 + V3(0, arc, 0)
		if ext and t < ext * f then pos = from end
		cfs[k] = CFrame.new(pos)
		balls[k].Color = RB.hue(f * 0.9 - t * 0.7 + idx * 0.13, 0.85, 1)
	end
	workspace:BulkMoveTo(balls, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

NOVAS.rainbow = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local sq = math.sqrt(m.scale)
	local params = rayParams(character)
	local range = maxRange()
	local origin = root.Position
	local ents = {}
	local npcL = nearestFirst(npcsIn(origin, range), origin)
	local ncap = m.big and 30 or 12
	for i = 1, math.min(#npcL, ncap) do
		ents[#ents + 1] = { n = npcL[i], root = npcL[i].root }
	end
	local partL = ownedRoots(origin, math.min(range, 450))
	table.sort(partL, function(a, b) return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude end)
	local pcap = m.big and 36 or 14
	for i = 1, math.min(#partL, pcap) do
		ents[#ents + 1] = { root = partL[i] }
	end
	if #ents == 0 then
		showToast("Chroma Tentacles: nothing in range", m.hi)
		return
	end

	local from = groundAt(origin, params)
	sfx(SFX.synthStart, 1.5, root)
	sfx(SFX.darkCharge, 1.1, root, false, 1.3)
	skyOn(0.5, RB.hue(0.8, 0.6, 0.45), 0.5)
	flash(origin, 0.5, m)
	shake(0.6, 0.9 * sq)
	for i = 1, 5 do shockwave(from, (14 + i * 7) * sq, 0.6, i * 0.06, RB.hue(i / 5, 0.85, 1)) end
	burst(anchorPart(from + V3(0, 2, 0)), { "Core", "Stardust" })

	local remaining = #ents
	for idx, e in ipairs(ents) do
		task.spawn(function()
			local ok, err = pcall(function()
				task.wait((idx - 1) * 0.05)
				local er = e.root
				local N = 22
				local NT = idx <= 5 and 2 or 1
				local sets = {}
				for ti = 1, NT do
					local balls = {}
					for k = 1, N do
						local f = k / N
						local size = (5.2 - 3.2 * f) * sq * (ti == 1 and 1 or 0.7)
						balls[k] = ballPart(from, size, RB.hue(f + idx * 0.13, 0.85, 1), 0.05)
						Debris:AddItem(balls[k], 14)
					end
					sets[ti] = { balls = balls, cfs = {} }
				end
				local pos0 = er.Position
				local ground = groundAt(pos0, params)
				local EXT, HOIST, WHIP, SL, NS = 0.45, 0.8, 1.1, 0.5, 3
				local t1 = EXT
				local t2 = EXT + HOIST
				local t3 = t2 + WHIP
				local total = t3 + NS * SL
				local HI = 46 * sq
				local R = 16 * sq
				local gY = ground.Y + 4
				local dmg = m.big and { 25, 35, 60 } or { 14, 18, 24 }
				local grabbed = false
				local slamDone = { false, false, false }
				local t0 = os.clock()
				while true do
					RunService.Heartbeat:Wait()
					local t = os.clock() - t0
					if t >= total or not er.Parent then break end
					local tip
					if t < t1 then
						tip = from:Lerp(pos0 + V3(0, 3, 0), t / EXT)
					else
						if not grabbed then
							grabbed = true
							if e.n then e.n.hum.PlatformStand = true end
							shockwave(ground, 16 * sq, 0.4, 0, RB.hue(idx * 0.17, 0.85, 1))
							if idx <= 3 then sfx(SFX.impactExp, 0.7, anchorPart(pos0, 3), false, rf(1.0, 1.3)) end
						end
						local x, y, z = pos0.X, gY, pos0.Z
						if t < t2 then
							local p = (t - t1) / HOIST
							y = gY + HI * (1 - (1 - p) ^ 2)
						elseif t < t3 then
							local p = (t - t2) / WHIP
							local rr = R * math.sin(p * math.pi)
							local a = p * TAU * 2.5 + idx
							x = pos0.X + math.cos(a) * rr
							z = pos0.Z + math.sin(a) * rr
							y = gY + HI + math.sin(p * 9) * 5 * sq
						else
							local s = t - t3
							local si = math.min(math.floor(s / SL) + 1, NS)
							local ls = s - (si - 1) * SL
							local startY = si == 1 and (gY + HI) or (gY + HI * 0.6)
							if ls < 0.16 then
								local q = ls / 0.16
								y = startY + (gY - startY) * q * q
							else
								local q = (ls - 0.16) / (SL - 0.16)
								y = gY + HI * 0.6 * (1 - (1 - q) ^ 2)
								if not slamDone[si] then
									slamDone[si] = true
									shockwave(ground, 24 * sq, 0.45, 0, RB.hue(si / 3 + idx * 0.1, 0.85, 1))
									shockwave(ground, 13 * sq, 0.4, 0.05, WHITE)
									burst(anchorPart(ground + V3(0, 2, 0), 2), { "Stars", "Rays_Thick" })
									physBlast(ground, 34 * sq, m.scale * 0.8)
									pillar(ground, 12 * sq, RB.hue(si / 3 + idx * 0.1, 0.9, 1), 0.3, 0.7)
									if si == NS then
										for _, v in ipairs(npcsIn(ground, 26 * sq)) do
											if not (e.n and v.model == e.n.model) then hurt(v, m.big and 12 or 6) end
										end
									end
									if e.n and e.n.hum.Parent and e.n.hum.Health > 0 then hurt(e.n, dmg[si]) end
									if idx <= 3 then sfx(si == NS and SFX.explosion2 or SFX.psionic, 0.8, anchorPart(ground, 3), false, rf(0.9, 1.3)) end
									if idx == 1 then shake(0.35, 1.2 * sq) end
								end
							end
						end
						er.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, (t - t1) * 6, 0)
						er.AssemblyLinearVelocity = V3(0, 0, 0)
						er.AssemblyAngularVelocity = V3(0, 0, 0)
						tip = er.Position - V3(0, 2, 0)
					end
					local lift = math.clamp((t - t1) / HOIST, 0, 1) * (t < t3 and 1 or 0.3)
					for ti, set in ipairs(sets) do
						RB.drawT(set.balls, set.cfs, from, tip, t, ti * 2.1, lift, idx + ti, N, sq, t < t1 and EXT or nil)
					end
				end

				if er.Parent then
					if e.n then
						if e.n.hum.Parent and e.n.hum.Health > 0 then
							hurtFrac(e.n, m.big and 1 or 0.4)
							launch(e.n, flatDir(flat(er.Position - origin)) * 150 + V3(0, 100, 0), 1.3)
						end
					else
						kick(er, V3(rf(-150, 150), 110, rf(-150, 150)), randomSpin(14))
					end
				end
				for _, set in ipairs(sets) do
					for _, b in ipairs(set.balls) do tweenKill(b, 0.35, { Transparency = 1, Size = Vector3.one * 0.5 }) end
				end
			end)
			if not ok then warn("[IvoryPeriastron] chroma tentacles: " .. tostring(err)) end
			remaining = remaining - 1
		end)
	end
	local tw0 = os.clock()
	while remaining > 0 and os.clock() - tw0 < 9 do task.wait(0.1) end
	skyOff(0.8)
end

SECOND.rainbow = function(ctx)
	local m, root, hum, character = ctx.m, ctx.root, ctx.hum, ctx.character
	local sq = math.sqrt(m.scale)
	local COUNT = m.big and 52 or 26
	local BOUNCES = m.big and 9 or 7
	local SPEED = 420
	local aim = aimPoint() or (root.Position + root.CFrame.LookVector * 100)
	local origin = root.Position + V3(0, 2.5, 0)
	local base = (aim - origin)
	base = base.Magnitude > 1 and base.Unit or root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { debrisFolder, character }

	sfx(SFX.synthStart, 1.4, root, false, 1.2)
	sfx(SFX.stormBolt, 1.1, root, false, 1)
	flash(origin, 0.5, m)
	shake(0.4, 1)

	local shards, parts, cfs = {}, {}, {}
	for i = 1, COUNT do
		local yaw = (i / (COUNT + 1) - 0.5) * math.rad(m.big and 150 or 110)
		local pitch = rf(-0.12, 0.2)
		local dirv = (CFrame.lookAt(origin, origin + base) * CFrame.Angles(pitch, yaw, 0)).LookVector
		local col = RB.hue(i / COUNT, 0.8, 1)
		local p = fxPart({ Color = col, Size = V3(1.6 * sq, 1.6 * sq, 9 * sq) })
		local a0 = make("Attachment", { Position = V3(0, 0.8 * sq, 0) }, p)
		local a1 = make("Attachment", { Position = V3(0, -0.8 * sq, 0) }, p)
		make("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 1.1, LightEmission = 1, FaceCamera = true,
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, col), ColorSequenceKeypoint.new(0.5, RB.hue(i / COUNT + 0.25, 0.8, 1)), ColorSequenceKeypoint.new(1, RB.hue(i / COUNT + 0.5, 0.8, 1)) }),
			Transparency = NumberSequence.new(0.1, 1), WidthScale = NumberSequence.new(1, 0.2),
		}, p)
		Debris:AddItem(p, 9)
		shards[i] = { p = p, pos = origin, dir = dirv, bounces = 0, life = 0, alive = true, cd = {}, col = col }
		parts[i] = p
	end

	local frame, lastOwned = 0, 0
	local t0 = os.clock()
	while os.clock() - t0 < 6 and root.Parent do
		local dt = RunService.Heartbeat:Wait()
		frame = frame + (1)
		local anyAlive = false
		for i, s in ipairs(shards) do
			if s.alive then
				anyAlive = true
				s.life = s.life + (dt)
				local dist = SPEED * dt
				local hit = workspace:Raycast(s.pos, s.dir * (dist + 3), params)
				if hit then
					local model = hit.Instance:FindFirstAncestorOfClass("Model")
					if not (model and model:FindFirstChildOfClass("Humanoid")) then
						s.pos = hit.Position + hit.Normal * 1.2
						s.dir = (s.dir - 2 * s.dir:Dot(hit.Normal) * hit.Normal).Unit
						s.bounces = s.bounces + (1)
						shockwave(hit.Position + hit.Normal * 0.3, 10 * sq, 0.35, 0, s.col)
						if i % 3 == 0 then
							local bp = hit.Position
							for _, v in ipairs(npcsIn(bp, 16 * sq)) do
								hurt(v, m.big and 12 or 6)
								launch(v, flatDir(flat(v.root.Position - bp)) * 140 + V3(0, 90, 0), 0.6)
							end
							physBlast(bp, 16 * sq, m.scale * 0.4)
						end
						burst(anchorPart(hit.Position + hit.Normal * 2, 2), { "Stars" })
						if i <= 5 or i % 4 == 0 then sfx(SFX.bling, 0.6, anchorPart(hit.Position, 2), false, 0.7 + 0.18 * s.bounces + rf(0, 0.15)) end
						if s.bounces % 2 == 1 and i % 3 == 0 then sfx(SFX.stormBolt, 0.5, anchorPart(hit.Position, 2), false, rf(1, 1.6)) end
						if s.bounces > BOUNCES then
							s.alive = false
							tweenKill(s.p, 0.25, { Transparency = 1 })
						end
					else
						s.pos = s.pos + (s.dir * dist)
					end
				else
					s.pos = s.pos + (s.dir * dist)
				end
				if s.alive then
					s.p.CFrame = CFrame.lookAt(s.pos, s.pos + s.dir)
					if (frame + i) % 4 == 0 then
						for _, n in ipairs(npcsIn(s.pos, 14 * sq)) do
							if (s.cd[n.model] or 0) < os.clock() then
								s.cd[n.model] = os.clock() + 0.5
								hurt(n, m.big and 30 or 16)
								launch(n, s.dir * 160 + V3(0, 90, 0), 0.5)
								burst(anchorPart(n.root.Position, 2), { "Stars", "Rays_Thick" })
								sfx(SFX.psionic, 0.35, anchorPart(n.root.Position, 2), false, rf(1.3, 1.9))
							end
						end
					end
					if (frame + i) % 12 == 0 then
						for _, r2 in ipairs(ownedRoots(s.pos, 14 * sq)) do
							kick(r2, s.dir * 130 + V3(0, 70, 0), randomSpin(12))
						end
					end
				end
			end
		end
		if not anyAlive then break end
	end
	for _, s in ipairs(shards) do
		if s.alive and s.p.Parent then
			burst(anchorPart(s.pos, 2), { "Stars", "Rays_Thick" })
			tweenKill(s.p, 0.25, { Transparency = 1 })
		end
	end
	sfx(SFX.explosion, 0.8, root, false, 1.3)
end



ULT.rainbow = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local sq = math.sqrt(m.scale)
	local R = m.big and 900 or 420
	local center = root.Position
	local params = rayParams(character)
	local ground = groundAt(center, params)
	sfx(SFX.synthStart, 1.6, root)
	sfx(SFX.charge, 1.2, root)
	skyOn(0.6, RB.hue(0.8, 0.7, 0.45), 0.6)
	flash(center, 0.8, m)
	shake(0.6, 1 * sq)
	local dome = ballPart(center, 4, WHITE, 0.4, { Material = Enum.Material.ForceField })
	tw(dome, 2.2, { Size = Vector3.one * R * 0.45, Transparency = 0.8 }, ES.Quad)
	Debris:AddItem(dome, 14)

	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { character, fxFolder, debrisFolder, dome }
	op.MaxParts = m.big and 700 or 420
	local painted = {}
	for _, p in ipairs(workspace:GetPartBoundsInRadius(center, R, op)) do
		if p.Transparency < 0.95 then
			painted[#painted + 1] = { p = p, c = p.Color, d = (p.Position - center).Magnitude }
		end
	end
	table.sort(painted, function(a, b) return a.d < b.d end)

	local DUR_A = 2.0
	local DUR_B = m.big and 6.4 or 4.8
	local BEAT = 0.6
	local beatN = 0
	local t0 = os.clock()
	local lastUp = 0
	local ok, err = pcall(function()
		while os.clock() - t0 < DUR_A + DUR_B and root.Parent do
			RunService.Heartbeat:Wait()
			local t = os.clock() - t0
			local waveR = R * math.min(t / DUR_A, 1) ^ 0.8
			if os.clock() - lastUp > 0.1 then
				lastUp = os.clock()
				for _, e in ipairs(painted) do
					if e.d > waveR then break end
					if e.p.Parent then e.p.Color = RB.hue(e.d / 140 - t * 0.55 + beatN * 0.12, 0.85, 1) end
				end
				dome.Color = RB.hue(t * 0.4, 0.5, 1)
			end
			if t > DUR_A and (t - DUR_A) >= beatN * BEAT then
				beatN = beatN + 1
				local col = RB.hue(beatN * 0.137, 0.85, 1)
				shockwave(ground, 40 * sq + beatN * 8, 0.55, 0, col)
				shockwave(ground, 24 * sq, 0.45, 0.05, WHITE)
				shake(0.25, 0.7 * sq)
				sfx(SFX.bling, 0.7, root, false, 0.8 + beatN * 0.06)
				if beatN % 2 == 1 then sfx(SFX.synthTone, 0.6, root, false, 0.9 + beatN * 0.05) end
				for i = 1, (m.big and 10 or 6) do
					local a = rf(0, TAU)
					local rr = rf(30, R * 0.5)
					local pp = groundAt(center + V3(math.cos(a) * rr, 0, math.sin(a) * rr), params)
					pillar(pp, rf(6, 12) * sq, RB.hue(rf(0, 1), 0.85, 1), 0.3, 0.6)
					for _, v in ipairs(npcsIn(pp, 18 * sq)) do hurt(v, m.big and 6 or 3) end
				end
				for _, n in ipairs(npcsIn(center, R)) do
					hurt(n, m.big and 16 or 8)
					launch(n, V3(rf(-30, 30), 85 + beatN * 4, rf(-30, 30)), 0.5)
				end
				for _, r2 in ipairs(ownedRoots(center, R)) do
					kick(r2, V3(rf(-25, 25), 65 + beatN * 3, rf(-25, 25)), randomSpin(8))
				end
			end
		end
	end)
	if not ok then warn("[IvoryPeriastron] prismatic dimension: " .. tostring(err)) end

	for _, e in ipairs(painted) do if e.p.Parent then e.p.Color = WHITE end end
	local c = root.Parent and root.Position or center
	flash(c, 1, m)
	shake(0.8, 2 * sq)
	sfx(SFX.explosion, 1.4, root, false, 1)
	sfx(SFX.thunderBoom, 1.2, root, false, 0.9)
	for i = 1, 7 do shockwave(ground, R * 0.12 * (1 + i * 0.45), 0.8, i * 0.05, RB.hue(i / 7, 0.9, 1)) end
	pillar(ground, 30 * sq, WHITE, 0.2, 1.2)
	for _, n in ipairs(npcsIn(c, R)) do
		hurtFrac(n, m.big and 1 or 0.5)
		launch(n, flatDir(flat(n.root.Position - c)) * 170 + V3(0, 120, 0), 1.4)
	end
	physBlast(c, R * 0.5, m.scale)
	task.wait(0.35)
	for _, e in ipairs(painted) do
		if e.p.Parent then pcall(function() e.p.Color = e.c end) end
	end
	tweenKill(dome, 0.6, { Transparency = 1 })
	skyOff(1.2)
end

RB.defs = {
	{ sid = "noir", asset = 120307951 }, { sid = "ivory", asset = 108158379 }, { sid = "azure", asset = 69499437 },
	{ sid = "chartreuse", asset = 80661504 }, { sid = "amethyst", asset = 93136802 }, { sid = "crimson", asset = 99119240 },
	{ sid = "grimgold", asset = 73829193 }, { sid = "rainbow", asset = 159229806 },
}
RB.ROT = {
	X = CFrame.Angles(0, math.rad(90), 0),
	Y = CFrame.Angles(math.rad(-90), 0, 0),
	Z = CFrame.new(),
}
RB.cache = {}

function RB.loadSword(asset)
	if RB.cache[asset] ~= nil then return RB.cache[asset] end
	local ok, obj = pcall(function() return game:GetService("InsertService"):LoadAsset(asset) end)
	if not (ok and obj) then
		ok, obj = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(asset))[1] end)
	end
	local found = false
	if ok and obj then
		local model = Instance.new("Model")
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then
				local c = d:Clone()
				for _, ch in ipairs(c:GetChildren()) do
					if not (ch:IsA("DataModelMesh") or ch:IsA("Decal") or ch:IsA("Texture") or ch:IsA("SurfaceAppearance")) then ch:Destroy() end
				end
				c.Anchored = true
				c.CanCollide = false
				c.CanTouch = false
				c.CanQuery = false
				c.Massless = true
				c.Parent = model
				if d.Name == "Handle" then model.PrimaryPart = c end
			end
		end
		pcall(function() obj:Destroy() end)
		if not model.PrimaryPart then
			local first = model:FindFirstChildWhichIsA("BasePart")
			if first then model.PrimaryPart = first end
		end
		if model.PrimaryPart then found = model else model:Destroy() end
	end
	RB.cache[asset] = found
	return found
end

function RB.fallback()
	local model = Instance.new("Model")
	local c = template.Handle:Clone()
	for _, ch in ipairs(c:GetChildren()) do
		if not ch:IsA("SpecialMesh") then ch:Destroy() end
	end
	c.Anchored = true
	c.CanCollide = false
	c.CanTouch = false
	c.CanQuery = false
	c.Parent = model
	model.PrimaryPart = c
	return model
end

function RB.makeSword(def, len, col)
	local src = RB.loadSword(def.asset)
	local model = (src and src:Clone()) or RB.fallback()
	local hp = model.PrimaryPart
	local sz = hp.Size
	local axis, longest = "Z", sz.Z
	if sz.X > longest then axis, longest = "X", sz.X end
	if sz.Y > longest then axis, longest = "Y", sz.Y end
	local factor = len / math.max(longest, 0.5)
	local scaled = pcall(function() model:ScaleTo(factor) end)
	model.Parent = workspace
	Debris:AddItem(model, 40)
	make("Highlight", { FillColor = col, OutlineColor = WHITE, FillTransparency = 0.65, OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.Occluded }, model)
	local axv = axis == "X" and V3(1, 0, 0) or (axis == "Y" and V3(0, 1, 0) or V3(0, 0, 1))
	local half = len * 0.5
	local a0 = make("Attachment", { Position = axv * half }, hp)
	local a1 = make("Attachment", { Position = axv * (half * 0.1) }, hp)
	local trail = make("Trail", {
		Attachment0 = a0, Attachment1 = a1, Lifetime = 0.45, Color = ColorSequence.new(col, WHITE),
		Transparency = NumberSequence.new(0.2, 1), LightEmission = 1, FaceCamera = true, Enabled = false,
	}, hp)
	return model, RB.ROT[axis], trail, scaled and factor or 1
end

function RB.dirTo(a, b)
	local d = b - a
	if d.Magnitude > 0.05 then return d.Unit end
	return V3(0, 1, 0)
end

RB.imp = {}
function RB.dm(m, base) return base * (m.big and 4 or 2.5) end
RB.imp.noir = function(p, n, m, sq, s)
	sfx(SFX.psionic, 0.9, anchorPart(p, 3), false, rf(0.8, 1))
	local ball = ballPart(p, 3, Color3.new(0.02, 0, 0.05), 0, { Material = Enum.Material.SmoothPlastic })
	local rim = ballPart(p, 4, s.pal[2], 0.5)
	tw(ball, 0.5, { Size = Vector3.one * 22 * sq }, ES.Back)
	tw(rim, 0.5, { Size = Vector3.one * 26 * sq }, ES.Back)
	task.delay(0.9, function()
		tweenKill(ball, 0.25, { Size = Vector3.one, Transparency = 1 })
		tweenKill(rim, 0.25, { Size = Vector3.one, Transparency = 1 })
	end)
	for _, v in ipairs(npcsIn(p, 40 * sq)) do
		hurt(v, RB.dm(m, 6))
		launch(v, RB.dirTo(v.root.Position, p) * 110 + V3(0, 25, 0), 0.7)
	end
	for _, r2 in ipairs(ownedRoots(p, 40 * sq)) do kick(r2, RB.dirTo(r2.Position, p) * 120, randomSpin(10)) end
end
RB.imp.ivory = function(p, n, m, sq, s)
	sfx(SFX.magicCast, 1, anchorPart(p, 3), false, 1.2)
	pillar(p, 14 * sq, WHITE, 0.25, 0.8)
	shockwave(p, 26 * sq, 0.5, 0, s.pal[1])
	burst(anchorPart(p, 2), { "Stars" })
	for _, v in ipairs(npcsIn(p, 30 * sq)) do
		hurt(v, RB.dm(m, 6))
		launch(v, V3(0, 120, 0), 0.9)
	end
	physBlast(p, 24 * sq, m.scale * 0.4)
end
RB.imp.azure = function(p, n, m, sq, s)
	sfx(SFX.glass, 1, anchorPart(p, 3), false, 1)
	for i = 1, 8 do
		local a = i / 8 * TAU
		local sp = fxPart({
			Color = i % 2 == 0 and s.pal[1] or WHITE, Size = V3(2.2 * sq, 12 * sq, 2.2 * sq), Transparency = 0.1,
			CFrame = CFrame.new(p) * CFrame.Angles(0, a, 0) * CFrame.new(0, 4 * sq, -5 * sq) * CFrame.Angles(math.rad(40), 0, 0),
		})
		tweenKill(sp, 1.1, { Transparency = 1 }, ES.Quad, ED.In)
	end
	shockwave(p, 28 * sq, 0.5, 0, s.pal[1])
	for _, v in ipairs(npcsIn(p, 30 * sq)) do
		hurt(v, RB.dm(m, 5))
		launch(v, V3(0, 0, 0), 2.2)
	end
end
RB.imp.chartreuse = function(p, n, m, sq, s)
	sfx(SFX.explosion2, 0.8, anchorPart(p, 3), false, 1.5)
	local cloud = ballPart(p, 4, s.pal[1], 0.55)
	tw(cloud, 0.5, { Size = Vector3.one * 28 * sq }, ES.Quad)
	task.delay(2.2, function() tweenKill(cloud, 0.4, { Transparency = 1 }) end)
	task.spawn(function()
		for _ = 1, 3 do
			for _, v in ipairs(npcsIn(p, 16 * sq)) do
				hurt(v, RB.dm(m, 1.5))
				launch(v, V3(rf(-10, 10), 35, rf(-10, 10)), 0.5)
			end
			task.wait(0.7)
		end
	end)
end
RB.imp.amethyst = function(p, n, m, sq, s)
	sfx(SFX.glass, 1, anchorPart(p, 3), false, 0.8)
	for i = 1, 6 do
		local a = rf(0, TAU)
		local rr = rf(2, 14) * sq
		local base = p + V3(math.cos(a) * rr, 0, math.sin(a) * rr)
		local sp = fxPart({ Color = s.pal[i % 3 + 1], Size = V3(3 * sq, 1, 3 * sq), Position = base })
		tw(sp, 0.25, { Size = V3(3 * sq, rf(12, 20) * sq, 3 * sq), Position = base + V3(0, 7 * sq, 0) }, ES.Back)
		tweenKill(sp, 0.6, { Transparency = 1 }, ES.Quad, ED.In, 1.4)
	end
	for _, v in ipairs(npcsIn(p, 22 * sq)) do
		hurt(v, RB.dm(m, 6))
		launch(v, V3(rf(-20, 20), 100, rf(-20, 20)), 0.9)
	end
	physBlast(p, 20 * sq, m.scale * 0.4)
end
RB.imp.crimson = function(p, n, m, sq, s)
	sfx(SFX.explosion2, 1, anchorPart(p, 3), false, 1)
	flash(p, 0.5, m)
	shockwave(p, 34 * sq, 0.5, 0, s.pal[1])
	shockwave(p, 20 * sq, 0.4, 0.05, WHITE)
	burst(anchorPart(p, 2), { "Supernova" })
	for _, v in ipairs(npcsIn(p, 32 * sq)) do
		hurt(v, RB.dm(m, 7))
		launch(v, flatDir(flat(v.root.Position - p)) * 150 + V3(0, 90, 0), 1)
	end
	physBlast(p, 28 * sq, m.scale * 0.6)
end
RB.imp.grimgold = function(p, n, m, sq, s)
	sfx(SFX.glass, 1, anchorPart(p, 3), false, 1.3)
	for i = 1, 12 do
		local coin = ballPart(p + V3(0, 2, 0), 1.6 * sq, i % 2 == 0 and s.pal[1] or s.pal[2], 0)
		local a = rf(0, TAU)
		local rr = rf(10, 28) * sq
		tw(coin, 0.7, { Position = p + V3(math.cos(a) * rr, rf(4, 20) * sq, math.sin(a) * rr) }, ES.Quad)
		tweenKill(coin, 0.7, { Transparency = 1 }, ES.Quad, ED.In, 1.5)
	end
	shockwave(p, 26 * sq, 0.5, 0, s.pal[1])
	for _, v in ipairs(npcsIn(p, 28 * sq)) do
		hurt(v, RB.dm(m, 7))
		launch(v, flatDir(flat(v.root.Position - p)) * 90 + V3(0, 100, 0), 1)
	end
	physBlast(p, 22 * sq, m.scale * 0.5)
end
RB.imp.rainbow = function(p, n, m, sq, s)
	sfx(SFX.explosion2, 1, anchorPart(p, 3), false, 1)
	flash(p, 0.6, m)
	for i = 1, 6 do shockwave(p, (16 + i * 8) * sq, 0.6, i * 0.05, RB.hue(i / 6, 0.9, 1)) end
	pillar(p, 14 * sq, WHITE, 0.2, 0.9)
	burst(anchorPart(p, 2), { "Supernova", "Stars" })
	for _, v in ipairs(npcsIn(p, 44 * sq)) do
		hurt(v, RB.dm(m, 7))
		launch(v, flatDir(flat(v.root.Position - p)) * 170 + V3(0, 120, 0), 1)
	end
	physBlast(p, 40 * sq, m.scale * 0.7)
end

RB.legion = function(ctx)
	local m, root, character = ctx.m, ctx.root, ctx.character
	local sq = math.sqrt(m.scale)
	local params = rayParams(character)
	local LEN = 20 * sq

	local pending = 0
	for _, d in ipairs(RB.defs) do
		if RB.cache[d.asset] == nil then
			pending = pending + 1
			task.spawn(function()
				pcall(RB.loadSword, d.asset)
				pending = pending - 1
			end)
		end
	end
	local tl = os.clock()
	while pending > 0 and os.clock() - tl < 5 do task.wait(0.1) end

	local sw = {}
	for i, d in ipairs(RB.defs) do
		local pal
		for _, st in ipairs(STYLES) do if st.id == d.sid then pal = st.pal end end
		pal = pal or STYLES[1].pal
		local model, rot, trail, factor = RB.makeSword(d, i == 8 and LEN * 1.5 or LEN, pal[1])
		sw[i] = { d = d, model = model, rot = rot, trail = trail, scale = factor, col = pal[1], pal = pal, state = "hold" }
	end

	local function rcfNow()
		local p = root.Position
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.05 then look = V3(0, 0, -1) end
		return CFrame.lookAt(p, p + look)
	end
	local function slot(i, t)
		local rcf = rcfNow()
		if i == 8 then
			return rcf:PointToWorldSpace(V3(0, 24 * sq + math.sin(t * 1.6) * 1.5 * sq, 12 * sq)), rcf:VectorToWorldSpace(V3(0, 1, 0.1)).Unit
		end
		local A = math.rad(-78 + (i - 1) * 26)
		local pos = rcf:PointToWorldSpace(V3(math.sin(A) * 20 * sq, 7 * sq + math.cos(A) * 9 * sq + math.sin(t * 1.9 + i) * 1.2 * sq, 9 * sq + (1 - math.cos(A)) * 4 * sq))
		return pos, rcf:VectorToWorldSpace(V3(math.sin(A) * 0.9, math.cos(A), 0.2)).Unit
	end
	local function place(s, pos, dir)
		s.model:PivotTo(CFrame.lookAt(pos, pos + dir) * s.rot)
	end

	sfx(SFX.gong, 1.4, root)
	sfx(SFX.synthStart, 1.4, root)
	skyOn(0.5, RB.hue(0.8, 0.6, 0.45), 0.55)
	flash(root.Position, 0.7, m)
	shake(0.5, 0.8 * sq)
	local halo = disc(root.Position, 2, 1, WHITE, 0.45)
	local halo2 = disc(root.Position, 2, 1, RB.hue(0.6), 0.55)
	Debris:AddItem(halo, 40)
	Debris:AddItem(halo2, 40)
	tw(halo, 1.2, { Size = V3(1.5, 74 * sq, 74 * sq) }, ES.Back)
	tw(halo2, 1.4, { Size = V3(1.5, 50 * sq, 50 * sq) }, ES.Back)
	local function haloUpdate(t)
		local rcf = rcfNow()
		halo.CFrame = rcf * CFrame.new(0, 22 * sq, 15 * sq) * CFrame.Angles(0, math.rad(90), 0)
		halo2.CFrame = rcf * CFrame.new(0, 22 * sq, 14 * sq) * CFrame.Angles(0, math.rad(90), 0)
		halo.Color = RB.hue(t * 0.5, 0.6, 1)
		halo2.Color = RB.hue(t * 0.5 + 0.5, 0.8, 1)
	end

	local APP, GAP = 0.5, 0.22
	local total1 = 7 * GAP + 0.4 + APP + 0.3
	local announced = {}
	local t0 = os.clock()
	while os.clock() - t0 < total1 and root.Parent do
		RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		haloUpdate(t)
		for i, s in ipairs(sw) do
			local start = (i - 1) * GAP + (i == 8 and 0.4 or 0)
			local p = math.clamp((t - start) / APP, 0, 1)
			local pos, dir = slot(i, t)
			if p > 0 then
				local e = 1 - (1 - p) ^ 3
				place(s, pos - V3(0, (1 - e) * 26 * sq, 0), dir)
				if p >= 1 and not announced[i] then
					announced[i] = true
					shockwave(groundAt(pos, params), (i == 8 and 28 or 14) * sq, 0.5, 0, s.col)
					burst(anchorPart(pos, 2), { "Stars" })
					sfx(i == 8 and SFX.thunderBoom or SFX.bling, 0.8, anchorPart(pos, 3), false, 0.8 + i * 0.08)
				end
			else
				place(s, pos - V3(0, 80, 0), dir)
			end
		end
	end

	local keeping = true
	task.spawn(function()
		while keeping and root.Parent do
			RunService.Heartbeat:Wait()
			local t = os.clock() - t0
			haloUpdate(t)
			for i, s in ipairs(sw) do
				if s.state == "hold" and s.model.Parent then
					local pos, dir = slot(i, t)
					place(s, pos, dir)
				end
			end
		end
	end)

	sfx(SFX.charge, 1.2, root)
	task.wait(0.9)

	local origin = root.Position
	local list = nearestFirst(npcsIn(origin, maxRange()), origin)
	local aim = ctx.aim
	local cpos = aim
	if #list > 0 then
		local sum = V3(0, 0, 0)
		for _, n in ipairs(list) do sum = sum + n.root.Position end
		cpos = sum / #list
	end
	cpos = groundAt(cpos, params)
	local top = cpos + V3(0, 105 * sq, 0)

	local targets = {}
	for i = 1, 8 do
		if #list > 0 then
			targets[i] = { n = list[(i - 1) % #list + 1] }
		else
			local a = rf(0, TAU)
			local rr = rf(5, 35)
			targets[i] = { pos = groundAt(aim + V3(math.cos(a) * rr, 0, math.sin(a) * rr), params) }
		end
	end
	local function tgtPos(tg)
		if tg.n and tg.n.root.Parent then return tg.n.root.Position end
		return tg.pos or aim
	end

	-- the giant Rainbow sword rises above the battlefield and GROWS as every other Periastron fuses into it
	local big = sw[8]
	big.state = "fly"
	big.hover = true
	big.grow, big.cur = 1, 1
	big.trail.Enabled = true
	tweenKill(halo, 1, { Transparency = 1 })
	tweenKill(halo2, 1, { Transparency = 1 })
	sfx(SFX.charge, 1.4, root, false, 0.9)
	sfx(SFX.energyCharge, 1.2, root)
	task.spawn(function()
		local startPos = big.model:GetPivot().Position
		local hl = big.model:FindFirstChildOfClass("Highlight")
		local rt0 = os.clock()
		while big.hover and big.model.Parent do
			RunService.Heartbeat:Wait()
			local t = os.clock() - rt0
			local e = 1 - (1 - math.min(t / 1.2, 1)) ^ 2
			local pos = startPos:Lerp(top, e)
			if t > 1.2 then pos = top + V3(0, math.sin(t * 2.2) * 2.5 * sq, 0) end
			place(big, pos, V3(0, 1, 0))
			if math.abs(big.grow - big.cur) > 0.01 then
				big.cur = big.cur + (big.grow - big.cur) * 0.18
				pcall(function() big.model:ScaleTo(big.scale * big.cur) end)
			end
			if hl then hl.FillColor = RB.hue(t * 0.6, 0.8, 1) end
		end
	end)

	-- STAGE 1: 7 Periastron swords each strike with their own signature blast, then fly up and fuse into the big sword
	local flying, fused = 0, 0
	for i = 1, 7 do
		local s = sw[i]
		local tg = targets[i]
		flying = flying + 1
		task.spawn(function()
			local ok, err = pcall(function()
				task.wait((i - 1) * 0.2)
				s.state = "fly"
				local startPos = s.model:GetPivot().Position
				local dist = (tgtPos(tg) - startPos).Magnitude
				local dur = math.max(dist / 380, 0.3)
				local tt0 = os.clock()
				s.trail.Enabled = true
				sfx(SFX.swordSlash, 0.8, anchorPart(startPos, 3), false, rf(1.1, 1.5))
				local pos = startPos
				while true do
					RunService.Heartbeat:Wait()
					local p = (os.clock() - tt0) / dur
					if p >= 1 then break end
					local npos = startPos:Lerp(tgtPos(tg), p) + V3(0, math.sin(p * math.pi) * 8 * sq, 0)
					local d = npos - pos
					if d.Magnitude > 0.01 then place(s, npos, d.Unit) end
					pos = npos
				end
				local ip = tgtPos(tg)
				if tg.n then ip = groundAt(ip, params) end
				RB.imp[s.d.sid](ip, tg.n, m, sq * 1.6, s)
				place(s, ip + V3(0, LEN * 0.3, 0), V3(0, -1, 0))
				task.wait(0.55)
				local fromP = s.model:GetPivot().Position
				local fdir = (top - fromP)
				fdir = fdir.Magnitude > 0.05 and fdir.Unit or V3(0, 1, 0)
				local side = (i % 2 == 0 and 1 or -1) * 14 * sq
				local ft0 = os.clock()
				while true do
					RunService.Heartbeat:Wait()
					local p = (os.clock() - ft0) / 0.8
					if p >= 1 then break end
					place(s, fromP:Lerp(top, p * p) + V3(math.sin(p * math.pi) * side, 0, 0), fdir)
				end
				fused = fused + 1
				big.grow = 1 + fused * 0.4
				shockwave(top - V3(0, 60 * sq, 0), 20 * sq, 0.5, 0, s.col)
				burst(anchorPart(top, 3), { "Stars" })
				sfx(SFX.bling, 0.9, anchorPart(top, 3), false, 0.8 + fused * 0.1)
				s.trail.Enabled = false
				s.model:Destroy()
			end)
			if not ok then warn("[IvoryPeriastron] legion sword: " .. tostring(err)) end
			flying = flying - 1
		end)
	end
	local fw, lastPull = os.clock(), 0
	while flying > 0 and os.clock() - fw < 12 do
		task.wait(0.1)
		if os.clock() - lastPull > 0.35 then -- Noir pull: drag everything toward the centre while the swords strike
			lastPull = os.clock()
			for _, v in ipairs(npcsIn(cpos, 150 * sq)) do
				launch(v, RB.dirTo(v.root.Position, cpos + V3(0, 12 * sq, 0)) * 70 + V3(0, 20, 0), 0.4)
			end
			for _, r2 in ipairs(ownedRoots(cpos, 150 * sq)) do kick(r2, RB.dirTo(r2.Position, cpos) * 110, randomSpin(8)) end
		end
	end
	keeping = false

	-- STAGE 2: fully fused. All 8 colours charge, everything is dragged in
	big.grow = 3.4
	sfx(SFX.charge, 1.5, root, false, 0.8)
	sfx(SFX.gong, 1.4, root, false, 0.7)
	flash(cpos, 1, m)
	shake(0.8, 1.4 * sq)
	for i = 1, 5 do shockwave(cpos, (40 + i * 22) * sq, 0.8, i * 0.1, RB.hue(i / 5, 0.9, 1)) end
	local cw = os.clock()
	while os.clock() - cw < 0.9 do
		task.wait(0.1)
		for _, v in ipairs(npcsIn(cpos, 150 * sq)) do
			launch(v, RB.dirTo(v.root.Position, cpos + V3(0, 10 * sq, 0)) * 110 + V3(0, 30, 0), 0.3)
		end
		for _, r2 in ipairs(ownedRoots(cpos, 150 * sq)) do kick(r2, RB.dirTo(r2.Position, cpos) * 140, randomSpin(10)) end
	end
	big.hover = false
	task.wait(0.05)

	-- STAGE 3: the fused sword slams down
	local dt0 = os.clock()
	while os.clock() - dt0 < 0.3 do
		RunService.Heartbeat:Wait()
		local p = (os.clock() - dt0) / 0.3
		place(big, top:Lerp(cpos + V3(0, 24 * sq, 0), p * p), V3(0, -1, 0))
	end
	sfx(SFX.explosion2, 1.4, anchorPart(cpos, 4), false, 0.9)
	sfx(SFX.thunderBoom, 1.3, anchorPart(cpos, 4), false, 1)
	sfx(SFX.impactExp, 1.2, anchorPart(cpos, 4), false, 0.8)
	flash(cpos, 1, m)
	shake(1.2, 2.6 * sq)
	for i = 1, 8 do shockwave(cpos, (36 + i * 20) * sq, 0.9, i * 0.05, RB.hue(i / 8, 0.9, 1)) end
	pillar(cpos, 44 * sq, WHITE, 0.15, 1.6)
	burst(anchorPart(cpos + V3(0, 5, 0), 3), { "Supernova", "Stars", "Core" })
	for _, n in ipairs(npcsIn(cpos, 150 * sq)) do
		hurtFrac(n, m.big and 0.6 or 0.4)
		launch(n, V3(rf(-30, 30), 150, rf(-30, 30)), 1.6)
	end
	physBlast(cpos, 150 * sq, m.scale)

	-- STAGE 4: Periastron Cascade, all 8 Periastron detonate in turn (7 around the ring, Rainbow in the centre)
	local ringR = 56 * sq
	for k = 1, 8 do
		task.delay(0.15 + (k - 1) * 0.13, function()
			local sk = sw[k]
			local bp = cpos
			if k < 8 then
				local a = (k - 1) / 7 * TAU
				bp = groundAt(cpos + V3(math.cos(a) * ringR, 0, math.sin(a) * ringR), params)
			end
			pillar(bp, 12 * sq, sk.col, 0.2, 1)
			local ok2, err2 = pcall(RB.imp[sk.d.sid], bp, nil, m, sq * 1.7, sk)
			if not ok2 then warn("[IvoryPeriastron] legion cascade: " .. tostring(err2)) end
		end)
	end
	task.wait(0.15 + 8 * 0.13 + 0.4)

	-- STAGE 5: final Chroma Nova
	sfx(SFX.explosion2, 1.5, anchorPart(cpos, 4), false, 0.7)
	sfx(SFX.thunderBoom, 1.4, anchorPart(cpos, 4), false, 0.8)
	flash(cpos, 1, m)
	shake(1.4, 3 * sq)
	for i = 1, 10 do shockwave(cpos, (30 + i * 24) * sq, 1, i * 0.04, RB.hue(i / 10, 0.9, 1)) end
	pillar(cpos, 60 * sq, WHITE, 0.1, 1.8)
	for _, n in ipairs(npcsIn(cpos, 170 * sq)) do
		hurtFrac(n, m.big and 1 or 0.35)
		launch(n, flatDir(flat(n.root.Position - cpos)) * 260 + V3(0, 140, 0), 1.6)
	end
	physBlast(cpos, 170 * sq, m.scale * 1.4)
	task.wait(0.9)
	big.trail.Enabled = false
	big.model:Destroy()
	for _, s in ipairs(sw) do if s.model.Parent then s.model:Destroy() end end
	skyOff(1.2)
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

local function useFourth()
	local st = STYLES[styleIdx]
	if st.id ~= "rainbow" then
		showToast("Periastron Legion is Rainbow Periastron only", mode().hi)
		return
	end
	if RB.busy or os.clock() - RB.last < (bigMode and 8 or 22) then return end
	local character, hum, root = liveChar()
	if not character then return end
	RB.busy = true
	RB.last = os.clock()
	local m = mode()
	local aim = aimPoint() or (root.Position + root.CFrame.LookVector * 60)
	local ok, err = pcall(RB.legion, { m = m, character = character, hum = hum, root = root, aim = aim })
	if not ok then warn("[IvoryPeriastron] legion: " .. tostring(err)) end
	RB.busy = false
	RB.last = os.clock()
end

local SIM_RADIUS = 1000
local simAlive = true
table.insert(connections, { Disconnect = function() simAlive = false end })
task.spawn(function()
	while simAlive do
		if sethiddenproperty then
			pcall(sethiddenproperty, player, "SimulationRadius", SIM_RADIUS)
			pcall(sethiddenproperty, player, "MaximumSimulationRadius", SIM_RADIUS)
		else
			pcall(function() player.SimulationRadius = SIM_RADIUS end)
			pcall(function() player.MaximumSimulationRadius = SIM_RADIUS end)
		end
		task.wait(1)
	end
end)

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

local equipped = false
local uiToken = 0
local currentTool = nil
local desktopGui
local desktopButtons = {}
local labelCache = {}
local MU = { idx = 0, on = false, sound = nil, token = 0, vol = 0.55 }
MU.LIST = {
	{ name = "leaveamsg - sped up + bass boosted", url = "https://www.dropbox.com/scl/fi/9yhe3n5xjv6wmnxoixwmd/leaveamsg-sped-up-bass-boosted.mp3?rlkey=88ucxzihhodmsl0h78lquj3r3&st=rmzv7jp6&dl=0" },
	{ name = "Hide n Seek - Sped Up", url = "https://www.dropbox.com/scl/fi/3iqhmps7i71ep7tpngvp7/Hide-n-Seek-Sped-Up-1.mp3?rlkey=kjjwjbseuzhp5lusufsgr21r0&st=l7bokfi7&dl=0" },
	{ name = "fly day chinatown (hoodtrap)", url = "https://www.dropbox.com/scl/fi/yiubdfxdnyrlljkb1pr3o/fly-day-chinatown-hoodtrap.mp3?rlkey=aqckpzja03ve8waaw256po7o8&st=meygy5o7&dl=0" },
	{ name = "a new kind of love - Enkei Remix", url = "https://www.dropbox.com/scl/fi/twu984r0mj5s8oak4trjf/a-new-kind-of-love-Enkei-Remix.mp3?rlkey=ra5ngnt8ixfa2f2yawjyhvlph&st=sl2izd4k&dl=0" },
	{ name = "1 Thing", url = "https://www.dropbox.com/scl/fi/a3jzashbapndfz28ktz4a/1-Thing.mp3?rlkey=9274s4ndh6h6g63e01raa5swz&st=5gx9q40q&dl=0" },
}

MU.PLAYLIST_URL = ""

function MU.fixUrl(u)
	u = u:gsub("dl=0", "dl=1")
	if u:find("dropbox.com") and not u:find("dl=1") and not u:find("raw=1") then
		u = u .. (u:find("?", 1, true) and "&dl=1" or "?dl=1")
	end
	return u
end

function MU.say(text) showToast(text, mode().hi) end

function MU.content(e)
	if e.id then return "rbxassetid://" .. tostring(e.id) end
	if e.url and writefile and getcustomasset and isfile then
		local folder = "IvoryPeriastronMusic"
		pcall(function()
			if isfolder and makefolder and not isfolder(folder) then makefolder(folder) end
		end)
		local file = folder .. "/" .. (tostring(e.name):gsub("[^%w]", "_")) .. ".mp3"
		if not isfile(file) then writefile(file, game:HttpGet(MU.fixUrl(e.url))) end
		return getcustomasset(file)
	end
	return nil
end

function MU.stop()
	MU.token = MU.token + 1
	MU.on = false
	if MU.sound then
		pcall(function()
			MU.sound:Stop()
			MU.sound:Destroy()
		end)
		MU.sound = nil
	end
end

function MU.play(i, tries)
	tries = tries or 0
	local list = MU.LIST
	if #list == 0 then
		MU.say("No songs in MU.LIST")
		return
	end
	MU.stop()
	MU.idx = ((i - 1) % #list) + 1
	local e = list[MU.idx]
	local my = MU.token
	MU.on = true
	MU.say("Loading: " .. e.name)
	task.spawn(function()
		local ok, content = pcall(MU.content, e)
		if my ~= MU.token then return end
		if not (ok and content) then
			MU.on = false
			MU.say("Song failed: " .. e.name)
			return
		end
		local s = Instance.new("Sound")
		s.Name = "PeriastronMusic"
		s.SoundId = content
		s.Volume = MU.vol
		s.Looped = false
		s.Parent = flashGui
		MU.sound = s
		local w0 = os.clock()
		while not s.IsLoaded and os.clock() - w0 < 8 and my == MU.token do task.wait(0.1) end
		if my ~= MU.token then return end
		if not s.IsLoaded then
			MU.say("Can't play: " .. e.name .. " (skipping)")
			if tries + 1 < #list then MU.play(MU.idx + 1, tries + 1) else MU.stop() end
			return
		end
		s:Play()
		MU.say("Now playing: " .. e.name)
		s.Ended:Connect(function()
			if my == MU.token then MU.play(MU.idx + 1) end
		end)
	end)
end

function MU.next() MU.play(MU.idx + 1) end

function MU.toggle()
	if MU.on then
		MU.stop()
		MU.say("Music stopped")
	else
		MU.play(MU.idx == 0 and 1 or MU.idx)
	end
end

table.insert(connections, { Disconnect = function() MU.stop() end })

if MU.PLAYLIST_URL ~= "" then
	task.spawn(function()
		local ok, body = pcall(function() return game:HttpGet(MU.fixUrl(MU.PLAYLIST_URL)) end)
		if not ok or type(body) ~= "string" then return end
		local list = {}
		for line in body:gmatch("[^\r\n]+") do
			local name, url = line:match("^%s*(.-)%s*|%s*(.-)%s*$")
			if name and name ~= "" and url and url:sub(1, 4) == "http" then list[#list + 1] = { name = name, url = url } end
		end
		if #list > 0 then MU.LIST = list end
	end)
end


local function aimedCast()
	if currentTool then cast(currentTool, aimPoint()) end
end

local BUTTONS = {
	{ act = ACT.nova,   key = Enum.KeyCode.Z, fn = aimedCast,         ang = 176, rad = TOUCH_BUTTON_DISTANCE,       col = 1 },
	{ act = ACT.statue, key = Enum.KeyCode.X, fn = useStatue,         ang = 153, rad = TOUCH_BUTTON_DISTANCE,       col = 2 },
	{ act = ACT.step,   key = Enum.KeyCode.V, fn = useStep,           ang = 107, rad = TOUCH_BUTTON_DISTANCE,       col = 3 },
	{ act = ACT.judge,  key = Enum.KeyCode.F, fn = useJudge,          ang = 108, rad = TOUCH_BUTTON_DISTANCE * 1.6, col = 4 },
	{ act = ACT.theme,  key = Enum.KeyCode.B, fn = cycleStyle,        ang = 166, rad = TOUCH_BUTTON_DISTANCE * 1.6, col = 5 },
	{ act = ACT.mode,   key = Enum.KeyCode.C, fn = toggleDestructive, above = 5,                                    col = 5, row = 1 },
	{ act = ACT.third,  key = Enum.KeyCode.G, fn = useUlt,            ang = 137, rad = TOUCH_BUTTON_DISTANCE * 1.6, col = 6 },
	{ act = ACT.fourth, key = Enum.KeyCode.H, fn = useFourth,         ang = 118, rad = TOUCH_BUTTON_DISTANCE * 2.2, col = 6, row = 1, ui = true },
	{ act = ACT.song,   key = Enum.KeyCode.N, fn = MU.next,           ang = 143, rad = TOUCH_BUTTON_DISTANCE * 2.2, col = 1, row = 1, ui = true },
	{ act = ACT.music,  key = Enum.KeyCode.M, fn = MU.toggle,         ang = 168, rad = TOUCH_BUTTON_DISTANCE * 2.2, col = 2, row = 1, ui = true },
}

local function setLabel(i, text)
	if labelCache[i] == text then return end
	labelCache[i] = text
	local b = BUTTONS[i]
	if desktopButtons[i] then
		desktopButtons[i].Text = UserInputService.TouchEnabled and text or (text .. "\n[" .. b.key.Name .. "]")
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
			local btn = (not b.ui) and CAS:GetButton(b.act)
			local center = centers[i]
			if not btn then continue end
			if b.above then center = centers[b.above] - Vector2.new(0, btn.AbsoluteSize.Y * 1.15) end
			centers[i] = center
			btn.Position = UDim2.fromOffset(
				center.X - frame.AbsolutePosition.X - btn.AbsoluteSize.X / 2,
				center.Y - frame.AbsolutePosition.Y - btn.AbsoluteSize.Y / 2
			)
		end
	end)
	if not ok then
		local fallback = { { 0.1, 0.3 }, { 0.1, 0.6 }, { 0.6, 0.1 }, { 0.8, 0.1 }, { 0.3, 0.6 }, { 0.3, 0.38 }, { 0.45, 0.1 }, { 0.6, 0.35 }, { 0.1, 0.12 }, { 0.28, 0.12 } }
		for i, b in ipairs(BUTTONS) do
			if not b.ui then CAS:SetPosition(b.act, UDim2.new(fallback[i][1], 0, fallback[i][2], 0)) end
		end
	end
end

local SPK = "rbxasset://textures/particles/sparkles_main.dds"
local SMK = "rbxasset://textures/particles/smoke_main.dds"
local FIR = "rbxasset://textures/particles/fire_main.dds"
RB.AURA = {
	noir = { shape = "Ball", n = 5, spd = 1.4, rad = 6, h = 1.2, size = 2, tex = SMK, rate = 12, psize = 3, speed = 1.5, acc = V3(0, -6, 0), life = 1.6, trans = 0.55 },
	ivory = { shape = "Block", n = 6, spd = 1.1, rad = 6, h = 1.8, size = 1.3, tex = SPK, rate = 16, psize = 1, speed = 3, acc = V3(0, -3, 0), life = 1.6, trans = 0.2 },
	azure = { shape = "Block", n = 6, spd = 1.8, rad = 5.5, h = 1.4, size = 1.2, tex = SPK, rate = 10, psize = 1.1, speed = 2, acc = V3(0, 2, 0), life = 1.5, trans = 0.2 },
	chartreuse = { shape = "Ball", n = 6, spd = 1.2, rad = 5, h = 2.2, size = 1.1, tex = SPK, rate = 18, psize = 0.9, speed = 2, acc = V3(0, 6, 0), life = 1.4, trans = 0.25 },
	amethyst = { shape = "Block", n = 5, spd = 1.0, rad = 6.5, h = 1.6, size = 1.6, tex = SPK, rate = 10, psize = 1.2, speed = 1.5, acc = V3(0, 1, 0), life = 1.6, trans = 0.2 },
	crimson = { shape = "Ball", n = 6, spd = 2.0, rad = 5, h = 1.5, size = 1.1, tex = FIR, rate = 14, psize = 1.6, speed = 2, acc = V3(0, 9, 0), life = 1.2, trans = 0.3 },
	grimgold = { shape = "Cylinder", n = 6, spd = 1.6, rad = 5.5, h = 1.3, size = 1.4, tex = SPK, rate = 14, psize = 1, speed = 2, acc = V3(0, 3, 0), life = 1.4, trans = 0.2 },
	rainbow = { shape = "Ball", n = 8, spd = 1.9, rad = 6, h = 1.8, size = 1.3, tex = SPK, rate = 28, psize = 1.2, speed = 3, acc = V3(0, 4, 0), life = 1.5, trans = 0.15 },
}

function RB.auraLoop(my)
	local key, parts, cfs, anchor, ring = nil, {}, {}, nil, nil
	local function clear()
		for _, p in ipairs(parts) do p:Destroy() end
		parts, cfs = {}, {}
		if anchor then anchor:Destroy() end
		anchor = nil
		if ring then ring:Destroy() end
		ring = nil
	end
	while uiToken == my do
		RunService.Heartbeat:Wait()
		local ok, err = pcall(function()
			local st = STYLES[styleIdx]
			local k = st.id .. (bigMode and "B" or "N")
			local A = RB.AURA[st.id]
			if k ~= key then
				key = k
				clear()
				if A then
					local sz = A.size * (bigMode and 1.5 or 1)
					for i = 1, A.n do
						local c1, c2 = st.pal[i % 3 + 1], st.pal[(i + 1) % 3 + 1]
						local p = fxPart({
							Shape = Enum.PartType[A.shape], Color = c1, Transparency = 0.15,
							Size = A.shape == "Cylinder" and V3(sz * 0.3, sz, sz) or V3(sz, sz, sz),
						})
						local a0 = make("Attachment", { Position = V3(0, sz * 0.8, 0) }, p)
						local a1 = make("Attachment", { Position = V3(0, -sz * 0.8, 0) }, p)
						make("Trail", {
							Attachment0 = a0, Attachment1 = a1, Lifetime = 0.55, Color = ColorSequence.new(c1, c2),
							Transparency = NumberSequence.new(0.2, 1), LightEmission = 1, FaceCamera = true,
						}, p)
						parts[i] = p
					end
					anchor = fxPart({ Transparency = 1, Size = V3(3, 0.2, 3) })
					make("ParticleEmitter", {
						Texture = A.tex, Rate = A.rate * (bigMode and 2 or 1), Lifetime = NumberRange.new(A.life * 0.7, A.life),
						Speed = NumberRange.new(A.speed * 0.5, A.speed), SpreadAngle = Vector2.new(180, 180), Acceleration = A.acc,
						Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, A.psize * (bigMode and 1.5 or 1)), NumberSequenceKeypoint.new(1, 0) }),
						Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, A.trans), NumberSequenceKeypoint.new(1, 1) }),
						Color = colorSeq(st.pal, 0), LightEmission = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
					}, anchor)
					ring = disc(Vector3.zero, 9, 0.2, st.pal[1], 0.7)
				end
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not (A and root and anchor) then return end
			local mul = bigMode and 1.7 or 1
			local t = os.clock()
			local base = root.Position
			local rainbow = st.id == "rainbow"
			for i, p in ipairs(parts) do
				local a = t * A.spd + i / A.n * TAU
				local r = A.rad * mul * (1 + 0.15 * math.sin(t * 2 + i))
				local y = -1 + (i % 3) * 1.6 + math.sin(t * 1.7 + i) * A.h
				cfs[i] = CFrame.new(base + V3(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(t + i, t * 1.3, i)
				if rainbow then p.Color = RB.hue(t * 0.3 + i / A.n, 0.8, 1) end
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			local foot = base - V3(0, 2.8, 0)
			anchor.CFrame = CFrame.new(foot)
			local d = (9 + math.sin(t * 3) * 1.2) * mul
			ring.Size = V3(0.2, d, d)
			ring.CFrame = CFrame.new(foot) * CFrame.Angles(0, 0, math.rad(90))
			if rainbow then ring.Color = RB.hue(t * 0.4, 0.8, 1) end
		end)
		if not ok then
			warn("[IvoryPeriastron] aura: " .. tostring(err))
			key = nil
			task.wait(1)
		end
	end
	clear()
end
table.insert(connections, { Disconnect = function() uiToken = uiToken + 1 end })

local function showButtons()
	equipped = true
	for _, b in ipairs(BUTTONS) do
		CAS:BindAction(b.act, function(_, state)
			if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
			b.fn()
			return Enum.ContextActionResult.Sink
		end, not b.ui, b.key)
	end

	if UserInputService.TouchEnabled then
		task.spawn(placeTouchButtons)
		-- Own on-screen buttons for Legion / Next Song / Play Music (always visible, no Roblox action-button limit)
		desktopGui = make("ScreenGui", { Name = "IvoryTouchButtons", ResetOnSpawn = false, DisplayOrder = 9, IgnoreGuiInset = true }, guiParent)
		table.insert(ownedInstances, desktopGui)
		local n = 0
		for i, b in ipairs(BUTTONS) do
			if b.ui then
				n = n + 1
				local btn = make("TextButton", { Name = b.act }, desktopGui)
				styleButton(btn, 0, 0)
				btn.AnchorPoint = Vector2.new(1, 0)
				btn.Size = UDim2.fromOffset(66, 66)
				btn.TextSize = 11
				btn.Position = UDim2.new(1, -14, 0.22, (n - 1) * 74)
				btn.Activated:Connect(b.fn)
				desktopButtons[i] = btn
			end
		end
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

	uiToken = uiToken + (1)
	local my = uiToken
	task.spawn(RB.auraLoop, my)
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
			setLabel(7, cd(lastUlt, ultCooldown(), st.u))
			setLabel(8, st.id == "rainbow" and cd(RB.last, bigMode and 8 or 22, "Legion") or "Legion (Rainbow)")
			setLabel(9, "Next Song")
			setLabel(10, MU.on and "Stop Music" or "Play Music")
			task.wait(0.1)
		end
	end)
end

local function hideButtons()
	equipped = false
	uiToken = uiToken + (1)
	for _, name in pairs(ACT) do pcall(CAS.UnbindAction, CAS, name) end
	if desktopGui then desktopGui:Destroy() end
	desktopGui = nil
	table.clear(desktopButtons)
	table.clear(labelCache)
end

local function setup(tool)
	table.insert(connections, tool.Equipped:Connect(function()
		currentTool = tool
		applyModeToTool(tool)
		if not equipped then showButtons() end
	end))
	table.insert(connections, tool.Unequipped:Connect(function()
		if equipped then hideButtons() end
	end))
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

task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	local function notify(title, text, icon, dur)
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCore("SendNotification", { Title = title, Text = text, Icon = icon, Duration = dur })
			end)
			if ok then return end
			task.wait(0.5)
		end
	end
	local icon
	pcall(function()
		local id = Players:GetUserIdFromNameAsync("DuaKNo")
		icon = Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	notify("Rip-off Rainbow Periastron OMEGA", "By DuaKNo", icon, 7)
	task.wait(1.2)
	notify("Follow on Instagram", "me_duakno", nil, 7)
	task.wait(1.2)
	notify("Join Discord server for more", "discord.gg/empgqd5qpq", nil, 9)
end)

print("Rip-off Rainbow Pariastron OMEGA v10 given. Click = swing  [Z] Nova  [X] Angel's Past  [C] Destructive on/off  [V] Lunge  [B] Periastron style  [F] second ability  [G] third ability.")

end)
if not __ivOk then
	warn("[IvoryPeriastron] failed to start: " .. tostring(__ivErr))
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Periastron error", Text = tostring(__ivErr):sub(1, 180), Duration = 15 })
	end)
end
