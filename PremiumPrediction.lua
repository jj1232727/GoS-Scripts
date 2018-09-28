--[[
	   ___                _            ___             ___     __  _         
	  / _ \_______ __ _  (_)_ ____ _  / _ \_______ ___/ (_)___/ /_(_)__  ___ 
	 / ___/ __/ -_)  ' \/ / // /  ' \/ ___/ __/ -_) _  / / __/ __/ / _ \/ _ \
	/_/  /_/  \__/_/_/_/_/\_,_/_/_/_/_/  /_/  \__/\_,_/_/\__/\__/_/\___/_//_/

	>> Generic prediction callbacks

	* GetPrediction(source, unit, speed, range, delay, radius, angle, collision)
	* GetDashPrediction(source, unit, speed, delay)
	* GetImmobilePrediction(source, unit, speed, range, delay, radius, collision)
	* GetStandardPrediction(source, unit, speed, range, delay, radius, angle, collision)
	> return: CastPos, HitChance, TimeToHit

	>> AOE prediction callbacks

	* GetLinearAOEPrediction(source, unit, speed, range, delay, radius, angle, collision)
	* GetCircularAOEPrediction(source, unit, speed, range, delay, radius, angle, collision)
	* GetConicAOEPrediction(source, unit, speed, range, delay, radius, angle, collision)
	> return: CastPos, HitChance

	>> Hitchances

	-1      Minion or hero collision
	0       Unit is out of range
	1-2     Low accuracy
	3-4     Medium accuracy
	5-6     High accuracy
	7-8     Very high accuracy
	9-10    Unit is immobile or dashing

--]]

local a = Game.Latency
local b = Game.Timer
local c = Game.HeroCount
local d = Game.Hero
local e = Game.MinionCount
local f = Game.Minion
local g = math.abs
local h = math.acos
local i = math.ceil
local j = math.cos
local k = math.deg
local l = math.floor
local m = math.huge
local n = math.max
local o = math.min
local p = math.sqrt
local q = table.insert
local r = table.remove

function OnLoad()
	require("MapPositionGOS")
	PremiumPrediction()
end

function gds(s, t)
	local t = t or myHero.pos
	local u = s.x - t.x
	local v = (s.z or s.y) - (t.z or t.y)
	return u * u + v * v
end

function gd(s, t)
	return p(gds(s, t))
end

function geh()
	EnemyHeroes = {}
	for w = 1, c() do
		local x = d(w)
		if x.isEnemy then
			q(EnemyHeroes, x)
		end
	end
	return EnemyHeroes
end

function vt(y, range)
	if not range or not range then
		range = m
	end
	return y ~= nil and y.valid and y.visible and not y.dead and range >= y.distance
end

function vp(z, A, B)
	local C, D, E, F, G, H = A.z or B.x, B.z or B.y, z.x, z.z or z.y, A.x, A.y
	local I = ((C - E) * (G - E) + (D - F) * (H - F)) / ((G - E) ^ 2 + (H - F) ^ 2)
	local J = {
		x = E + I * (G - E),
		y = F + I * (H - F)
	}
	local K = I < 0 and 0 or I > 1 and 1 or I
	local L = K == I
	local M = L and J or {
		x = E + K * (G - E),
		y = F + K * (H - F)
	}
	return M, J, L
end

class("PremiumPrediction")

function PremiumPrediction:__init()
	ActiveWaypoints = {}
	Callback.Add("Tick", function()
		self:Tick()
	end)
	Callback.Add("Draw", function()
		self:Draw(geh())
	end)
end

--[[
-- Ryze Q Example
function PremiumPrediction:Draw(N)
	for w = 1, #N do
		local O = N[w]
		local CastPos, HitChance, P = self:GetLinearAOEPrediction(myHero, O, 1700, 1000, 0.25, 55, 0, true)
		if CastPos then
			Draw.Circle(CastPos, 100, 1, Draw.Color(255, 255, 255, 255))
			if HitChance >= 1 and vt(O) and 1000 > gd(myHero.pos, O.pos) and Game.CanUseSpell(_Q) == 0 then
				Control.CastSpell(HK_Q, CastPos)
			end
		end
	end
end
--]]

function PremiumPrediction:Tick()
	self:ProcessWaypoint(geh())
end

function PremiumPrediction:GetPrediction(Q, O, R, range, S, radius, T, collision)
	local unitPos = Vector(O.pos)
	if unitPos then
		local R = R or m
		local range = range or 12500
		local S = S + a() / 2000 + 0.07
		local U = O.networkID
		if self:IsMoving(O) then
			if self:IsDashing(O) then
				local CastPos, HitChance, time = self:GetDashPrediction(Q, O, R, S)
				return CastPos, HitChance, time
			else
				local CastPos, HitChance, time = self:GetStandardPrediction(Q, O, R, range, S, radius, T, collision)
				return CastPos, HitChance, time
			end
		else
			local CastPos, HitChance, time = self:GetImmobilePrediction(Q, O, R, range, S, radius, collision)
			return CastPos, HitChance, time
		end
	end
end

function PremiumPrediction:GetDashPrediction(Q, O, R, S)
	if self:IsDashing(O) then
		local Q = Vector(Q.pos)
		local unitPos = O.pos
		local S = S + a() / 1000
		local V = O.pathing.dashSpeed
		local CastPos = unitPos
		local W = Vector(O:GetPath(0))
		local X = Vector(O:GetPath(1))
		local Y, Z, _ = X.x - W.x, X.y - W.y, X.z - W.z
		local a0 = p(Y * Y + _ * _)
		Y = Y / a0 * V
		Z = Z / a0
		_ = _ / a0 * V
		local a1 = Y * Y + _ * _ - R * R
		local a2 = 2 * (W.x * Y + W.z * _ - Q.x * Y - Q.z * _)
		local a3 = W.x * W.x + W.z * W.z + Q.x * Q.x + Q.z * Q.z - 2 * Q.x * W.x - 2 * Q.z * W.z
		local a4 = a2 * a2 - 4 * a1 * a3
		local a5 = (-a2 - p(a4)) / (2 * a1)
		local a6 = (-a2 + p(a4)) / (2 * a1)
		local a7 = S + n(a5, a6)
		local a8 = gd(unitPos, X) / R
		if a7 <= a8 then
			CastPos = unitPos + Vector(unitPos, X):Normalized() * V * a7
		else
			CastPos = X
		end
		local HitChance = 10
		local time = S + gd(CastPos, Q) / R
	end
	if collision and self:Collision(Q, CastPos, radius / 1.5) or MapPosition:inWall(CastPos) then
		HitChance = -1
	elseif gds(unitPos, Q) > range * range then
		HitChance = 0
	end
	return CastPos, HitChance, time
end

function PremiumPrediction:GetImmobilePrediction(Q, O, R, range, S, radius, collision, V)
	local Q = Vector(Q.pos)
	local unitPos = Vector(O.pos)
	local V = O.ms
	local CastPos = unitPos
	local HitChance = 0
	local time = S + a() / 1000 + gd(CastPos, Q) / R
	local a9, aa = self:IsAttacking(O)
	local ab, ac = self:IsImmobile(O)
	if a9 then
		HitChance = o(10, i(radius / V * 1.1 / (time - aa) * 10))
	elseif ab then
		if time < ac then
			HitChance = 10
		else
			HitChance = o(10, i(radius / V * 1.1 / (time - ac) * 10))
		end
	else
		HitChance = o(10, i(radius / V * 1.1 / time * 10))
	end
	if not O.visible then
		HitChance = l(HitChance / 2)
	end
	if collision and self:Collision(Q, CastPos, radius / 1.5) or MapPosition:inWall(CastPos) then
		HitChance = -1
	elseif gds(unitPos, Q) > range * range then
		HitChance = 0
	end
	return CastPos, HitChance, time
end

function PremiumPrediction:GetStandardPrediction(Q, O, R, range, S, radius, T, collision, V)
	local Q = Vector(Q.pos)
	local unitPos = O.pos
	local S = S + a() / 1000
	local V = O.ms
	local CastPos = unitPos
	local HitChance = 0
	local time = 0
	local U = O.networkID
	local ad = self:GetWaypoints(O)
	if ad and #ad > 0 then
		local W = ActiveWaypoints[U][#ad].startPos
		local X = ActiveWaypoints[U][#ad].endPos
		if #ad >= 2 then
			for w = 1, #ad - 1 do
				local ae = ad[w]
				local af = ad[w + 1]
				X = Vector((ae + af) / 2)
			end
		end
		local Y, Z, _ = X.x - W.x, X.y - W.y, X.z - W.z
		local a0 = p(Y * Y + _ * _)
		Y = Y / a0 * V
		Z = Z / a0
		_ = _ / a0 * V
		local ag = o(S * V, a0)
		if T and T > 0 then
			radius = p(2 * ag * ag - 2 * ag * ag * j(T))
		end
		local ah = W.x + ag * Y / V
		local ai = W.y + ag * Z
		local aj = W.z + ag * _ / V
		CastPos = Vector(ah, ai, aj)
		time = S + gd(CastPos, Q) / R
		if R ~= m then
			local a1 = Y * Y + _ * _ - R * R
			local a2 = 2 * (W.x * Y + W.z * _ - Q.x * Y - Q.z * _)
			local a3 = W.x * W.x + W.z * W.z + Q.x * Q.x + Q.z * Q.z - 2 * Q.x * W.x - 2 * Q.z * W.z
			local a4 = a2 * a2 - 4 * a1 * a3
			local a5 = (-a2 - p(a4)) / (2 * a1)
			local a6 = (-a2 + p(a4)) / (2 * a1)
			time = time + n(a5, a6)
		end
	else
		if R ~= m then
			CastPos = unitPos + Vector(O:GetPath(1) - unitPos):Normalized() * V * (S + gd(unitPos, myHero.pos) / R)
		else
			CastPos = unitPos + Vector(O:GetPath(1) - unitPos):Normalized() * V * S
		end
		time = S + gd(CastPos, Q) / R
	end
	radius = radius * 2
	HitChance = o(10, i(radius / V * 1.1 / time * 10))
	local ak = Q:AngleBetween(unitPos, O.posTo)
	if ak and ak > 0 then
		HitChance = i(g(HitChance * (1 - ak / 180)))
	end
	if self:IsSlowed(O) then
		HitChance = o(10, i(HitChance * 1.5))
	end
	if not O.visible then
		HitChance = l(HitChance / 2)
	end
	if collision and self:Collision(Q, CastPos, radius / 1.5) or MapPosition:inWall(CastPos) then
		HitChance = -1
	elseif gds(unitPos, Q) > range * range then
		HitChance = 0
	end
	return CastPos, HitChance, time
end

function PremiumPrediction:GetLinearAOEPrediction(Q, O, R, range, S, radius, T, collision)
	local CastPos, HitChance, time = self:GetPrediction(Q, O, R, range, S, radius, T, collision)
	local Q = Vector(Q.pos)
	local al = 2 * radius * 2 * radius
	local am = CastPos
	local an, ao = CastPos.x, CastPos.z
	do
		local Y, _ = an - Q.x, ao - Q.z
		local a0 = p(Y * _ + _ * _)
		an = an + Y / a0 * range
		ao = ao + _ / a0 * range
	end
	for w, ap in pairs(geh()) do
		if vt(ap) and ap ~= O then
			local aq, ar, as = self:GetPrediction(Q, ap, R, range, S, radius, T, collision)
			local a3 = (aq.x - Q.x) * (an - Q.x) + (aq.z - Q.z) * (ao - Q.z)
			if range > gd(aq, Q) then
				local at = a3 / (range * range)
				if at > 0 and at < 1 then
					local au = Vector(Q.x + at * (an - Q.x), 0, Q.z + at * (ao - Q.z))
					local av = (aq.x - au.x) * (aq.x - au.x) + (aq.z - au.z) * (aq.z - au.z)
					if al > av then
						am = Vector(0.5 * (am.x + aq.x), am.y, 0.5 * (am.z + aq.z))
						al = al - 0.5 * av
					end
				end
			end
		end
	end
	return CastPos, HitChance
end

function PremiumPrediction:GetCircularAOEPrediction(Q, O, R, range, S, radius, T, collision)
	local CastPos, HitChance, time = self:GetPrediction(Q, O, R, range, S, radius, T, collision)
	local Q = Vector(Q.pos)
	local al = 2 * radius * 2 * radius
	local am = CastPos
	local an, ao = CastPos.x, CastPos.z
	for w, ap in pairs(geh()) do
		if vt(ap) and ap ~= O then
			local aq, ar, as = self:GetPrediction(Q, ap, R, range, S, radius, T, collision)
			local aw = (aq.x - an) * (aq.x - an) + (aq.z - ao) * (aq.z - ao)
			if al > aw then
				am = Vector(0.5 * (am.x + aq.x), am.y, 0.5 * (am.z + aq.z))
				al = al - 0.5 * aw
			end
		end
	end
	CastPos = am
	return CastPos, HitChance
end

function PremiumPrediction:GetConicAOEPrediction(Q, O, R, range, S, radius, T, collision)
	if T and T > 0 then
		local CastPos, HitChance, time = self:GetPrediction(Q, O, R, range, S, radius, T, collision)
		local Q = Vector(Q.pos)
		local al = 2 * T
		local am = CastPos
		local an, ao = CastPos.x, CastPos.z
		local Y, _ = an - Q.x, ao - Q.z
		do
			local a0 = p(Y * _ + _ * _)
			an = an + Y / a0 * range
			ao = ao + _ / a0 * range
		end
		for w, ap in pairs(geh()) do
			if vt(ap) and ap ~= O then
				local aq, ar, as = self:GetPrediction(Q, ap, R, range, S, radius, T, collision)
				local ax = gd(aq, Q)
				if range > ax then
					local ay = gd(am, Q)
					local az = (am.x - Q.x) * (aq.x - Q.x) + (am.z - Q.z) * (aq.z - Q.z)
					local aA = k(h(az / (ax * ay)))
					if al > aA then
						am = Vector(0.5 * (am.x + aq.x), am.y, 0.5 * (am.z + aq.z))
						al = aA
					end
				end
			end
		end
		CastPos = am
		return CastPos, HitChance
	end
end

function PremiumPrediction:WaypointCutter(ad, range)
	local aB = {}
	local aC = range
	if range > 0 then
		for w = 1, #ad - 1 do
			local aD, aE = ad[w], ad[w + 1]
			local aF = gd(aD, aE)
			if aC <= aF then
				aB[1] = Vector(aD) + aC * (Vector(aE) - Vector(aD)):Normalized()
				for aG = w + 1, #ad do
					aB[aG - w + 1] = ad[aG]
				end
				aC = 0
				break
			else
				aC = aC - aF
			end
		end
	else
		local aD, aE = ad[1], ad[2]
		aB = ad
		aB[1] = Vector(aD) - range * (Vector(aE) - Vector(aD)):Normalized()
	end
	return aB
end

function PremiumPrediction:GetWaypoints(O)
	local ad = {}
	local U = O.networkID
	if ActiveWaypoints[U] and #ActiveWaypoints[U] > 0 then
		for w, aH in pairs(ActiveWaypoints[U]) do
			local aI = aH.endPos
			q(ad, aI)
		end
	end
	return ad or nil
end

function PremiumPrediction:ProcessWaypoint(N)
	for w = 1, #N do
		local O = N[w]
		local U = O.networkID
		if ActiveWaypoints[U] and #ActiveWaypoints[U] > 0 then
			local aJ = #ActiveWaypoints[U]
			if GetTickCount() > ActiveWaypoints[U][aJ].ticker + 300 then
				for w = aJ, 1, -1 do
					ActiveWaypoints[U][w] = nil
				end
			end
		end
		if self:IsMoving(O) then
			if not ActiveWaypoints[U] then
				ActiveWaypoints[U] = {}
			end
			for w, aH in pairs(ActiveWaypoints[U]) do
				if aH.endPos ~= Vector(O.pathing.endPos) then
					q(ActiveWaypoints[U], {
						startPos = Vector(O.pathing.startPos),
						endPos = Vector(O.pathing.endPos),
						dashSpeed = O.pathing.dashSpeed,
						ticker = GetTickCount()
					})
					for w, aH in pairs(ActiveWaypoints[U]) do
						if w > 3 then
							r(ActiveWaypoints[U], 1)
						end
					end
				end
			end
		elseif ActiveWaypoints[U] and #ActiveWaypoints[U] > 0 then
			local aJ = #ActiveWaypoints[U]
			for w = aJ, 1, -1 do
				ActiveWaypoints[U][w] = nil
			end
		end
	end
end

function PremiumPrediction:Collision(W, X, radius)
	for w = 1, e() do
		local aK = f(w)
		if aK and aK.isEnemy then
			local M, J, L = vp(W, X, aK.pos)
			if L and gds(M, aK.pos) < (aK.boundingRadius * 2 + radius) ^ 2 then
				return true
			end
		end
	end
	return false
end

function PremiumPrediction:IsAttacking(O)
	if O.activeSpell then
		return b() < O.activeSpell.startTime + O.activeSpell.windup, O.activeSpell.startTime + O.activeSpell.windup - b()
	end
end

function PremiumPrediction:IsImmobile(O)
	for w = 0, O.buffCount do
		local aL = O:GetBuff(w)
		if aL and (aL.type == 5 or aL.type == 11 or aL.type == 18 or aL.type == 22 or aL.type == 24 or aL.type == 28 or aL.type == 29) and 0 < aL.duration then
			return b() < aL.expireTime, aL.expireTime - b()
		end
	end
	return false
end

function PremiumPrediction:IsSlowed(O)
	for w = 0, O.buffCount do
		local aL = O:GetBuff(w)
		if aL and aL.type == 10 and 0 < aL.duration then
			return b() < aL.expireTime
		end
	end
	return false
end

function PremiumPrediction:IsDashing(O)
	return O.pathing.isDashing
end

function PremiumPrediction:IsMoving(O)
	return O.pathing.hasMovePath
end
