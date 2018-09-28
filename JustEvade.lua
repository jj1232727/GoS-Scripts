-- ==================
-- == Introduction ==
-- ==================
-- Current version: 1.0.8 BETA
-- Intermediate GoS script which draws and attempts to dodge enemy spells.
-- ===============
-- == Changelog ==
-- ===============
-- 1.0.8 BETA
-- + Updated spell data for Aatrox
-- 1.0.7 BETA
-- + Added threeway drawings
-- 1.0.6.1 BETA
-- + Experimental Update
-- 1.0.6 BETA
-- + Rebuilt Pathfinding
-- + Added menu options (Danger Level, Fast Evade & %HP To Dodge)
-- 1.0.5.2 BETA
-- + Added 'Recalculate Path'
-- + Fixed dodging
-- 1.0.5.1 BETA
-- + Fixed drawings
-- + Optimized code
-- 1.0.5 BETA
-- + Added Pyke Q detection
-- + Added Pyke E to evade spells
-- 1.0.4 BETA
-- + Added 'stop dodging' keybinds
-- 1.0.3 BETA
-- + Imported 2 more Pathfindings
-- 1.0.2.2 BETA
-- + Minor changes in Menu
-- 1.0.2.1 BETA
-- + Fixed minor bug
-- 1.0.2 BETA
-- + Added conic spells evading
-- + Improved spell usage
-- + Extended menu settings
-- 1.0.1 BETA
-- + Improved Pathfinding
-- + Added rectangular spells evading
-- 1.0 BETA
-- + Initial release

local TableInsert = table.insert
local TableRemove = table.remove
local MathHuge, MathCeil, MathPi, MathRad, MathSin, MathCos = math.huge, math.ceil, math.pi, math.rad, math.sin, math.cos

class 'JustEvade'

OnLoad(function()
	EMenu = Menu("JustEvade", "JustEvade")
	JustEvade()
	require 'MapPositionGOS'
	require 'Collision'
end)

function JustEvade:__init()
	_G.JustEvade = false
	self.ReCalc = false
	self.Flash = (GetCastName(myHero,SUMMONER_1):lower():find("summonerflash") and SUMMONER_1 or (GetCastName(myHero,SUMMONER_2):lower():find("summonerflash") and SUMMONER_2 or nil))
	self.SpSlot = {[_Q]="Q",[_W]="W",[_E]="E",[_R]="R"}
	self.DetectedSpells = {}
	EMenu:SubMenu("Main", "Main Settings")
	EMenu.Main:Boolean("Evade", "Enable Evade", true)
	EMenu.Main:Boolean("Status", "Draw Evade Status", true)
	EMenu.Main:Boolean("SafePos", "Draw Safe Position", true)
	EMenu.Main:Boolean("RP", "Recalculate Path", true)
	EMenu:SubMenu("Misc", "Misc Settings")
	EMenu.Misc:Key("SD", "Stop Dodging", string.byte("A"))
	EMenu.Misc:Key("DD", "Dodge Only Dangerous", string.byte("N"))
	EMenu.Misc:Slider("DE","Delay Before Enabling OW", 0.25, 0, 1, 0.01)
	EMenu.Misc:Slider("TE","Extended Timer On Evade", 0, 0, 1, 0.01)
	EMenu.Misc:Slider("ER","Extra Spell Radius", 20, 0, 100, 5)
	EMenu:SubMenu("Spells", "Spell Settings")
	EMenu:SubMenu("EvadeSpells", "Evade Spells")
	DelayAction(function()
		for _,spell in pairs(self.Spells) do
			for l,k in pairs(GetEnemyHeroes()) do
				if not self.Spells[_] then return end
				if spell.charName == k.charName then
					if not EMenu.Spells[_] then EMenu.Spells:Menu(_,""..spell.charName.." "..self.SpSlot[spell.slot].." | "..spell.displayName) end
					EMenu.Spells[_]:Boolean("Dodge".._, "Dodge Spell", true)
					EMenu.Spells[_]:Boolean("Draw".._, "Draw Spell", true)
					if spell.danger >= 2 then
						EMenu.Spells[_]:Boolean("FE".._, "Fast Evade", true)
					else
						EMenu.Spells[_]:Boolean("FE".._, "Fast Evade", false)
					end
					EMenu.Spells[_]:Slider("HP".._, "%HP To Dodge", 100, 0, 100, 5)
					EMenu.Spells[_]:Slider("Danger".._, "Danger Level", (spell.danger or 1), 1, 3, 1)
				end
			end
		end
		if self.EvadeSpells[GetObjectName(myHero)] then
			for i = 0,3 do
				if self.EvadeSpells[GetObjectName(myHero)][i] and self.EvadeSpells[GetObjectName(myHero)][i].name then
					if not EMenu.EvadeSpells[self.EvadeSpells[GetObjectName(myHero)][i].name] then
						EMenu.EvadeSpells:Menu(self.EvadeSpells[GetObjectName(myHero)][i].name,""..myHero.charName.." "..(self.SpSlot[i] or "?").." | "..self.EvadeSpells[GetObjectName(myHero)][i].displayName)
						EMenu.EvadeSpells[self.EvadeSpells[GetObjectName(myHero)][i].name]:Boolean("US"..self.EvadeSpells[GetObjectName(myHero)][i].name, "Use Spell", true)
						EMenu.EvadeSpells[self.EvadeSpells[GetObjectName(myHero)][i].name]:Slider("Danger"..self.EvadeSpells[GetObjectName(myHero)][i].name, "Danger Level", (self.EvadeSpells[GetObjectName(myHero)][i].danger or 1), 1, 3, 1)
					end
				end
			end
		end
		if self.Flash then
			EMenu.EvadeSpells:Menu("Flash",""..myHero.charName.." | Summoner Flash")
			EMenu.EvadeSpells.Flash:Boolean("Use", "Use Flash", true)
		end
		if GetItemSlot(myHero, 3157) > 0 then
			EMenu.EvadeSpells:Menu("Stopwatch",""..myHero.charName.." | Stopwatch")
			EMenu.EvadeSpells.Stopwatch:Boolean("Use", "Use Stopwatch", true)
		end
		if GetItemSlot(myHero, 3157) > 0 then
			EMenu.EvadeSpells:Menu("Zhonya",""..myHero.charName.." | Zhonya's Hourglass")
			EMenu.EvadeSpells.Zhonya:Boolean("Use", "Use Zhonya's Hourglass", true)
		end
	end,.1)
	Callback.Add("Tick", function() self:Dodge() end)
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("ProcessSpell", function(unit, spell) self:Detect(unit, spell) end)

self.Spells = {
	["AatroxQ"]={charName="Aatrox",slot=_Q,type="linear",displayName="The Darkin Blade",danger=2,speed=MathHuge,range=650,delay=0.6,radius=130,collision=false},
	["AatroxQ2"]={charName="Aatrox",slot=_Q,type="linear",displayName="The Darkin Blade",danger=2,speed=MathHuge,range=500,delay=0.6,radius=300,collision=false},
	["AatroxQ3"]={charName="Aatrox",slot=_Q,type="circular",displayName="The Darkin Blade",danger=2,speed=MathHuge,range=200,delay=0.6,radius=300,collision=false},
	["AatroxW"]={charName="Aatrox",slot=_W,type="linear",displayName="Infernal Chains",danger=2,speed=1800,range=825,delay=0.25,radius=80,collision=true},
	["AhriOrbofDeception"]={charName="Ahri",slot=_Q,type="linear",displayName="Orb of Deception",danger=1,speed=2500,range=880,delay=0.25,radius=100,collision=false},
	["AhriSeduce"]={charName="Ahri",slot=_E,type="linear",displayName="Charm",danger=1,speed=1550,range=975,delay=0.25,radius=60,collision=true},
	["Pulverize"]={charName="Alistar",slot=_Q,type="circular",displayName="Pulverize",danger=1,speed=MathHuge,range=0,delay=0.25,radius=365,collision=false},
	["BandageToss"]={charName="Amumu",slot=_Q,type="linear",displayName="Bandage Toss",danger=1,speed=2000,range=1100,delay=0.25,radius=80,collision=true},
	["Tantrum"]={charName="Amumu",slot=_E,type="circular",displayName="Tantrum",danger=2,speed=MathHuge,range=0,delay=0.25,radius=350,collision=false},
	["CurseoftheSadMummy"]={charName="Amumu",slot=_R,type="circular",displayName="Curse of the Sad Mummy",danger=3,speed=MathHuge,range=0,delay=0.25,radius=550,collision=false},
	["FlashFrost"]={charName="Anivia",slot=_Q,type="linear",displayName="Flash Frost",danger=1,speed=850,range=1075,delay=0.25,radius=110,collision=false},
	["Incinerate"]={charName="Annie",slot=_W,type="conic",displayName="Incinerate",danger=2,speed=MathHuge,range=600,delay=0.25,radius=50,angle=50,collision=false},
	["InfernalGuardian"]={charName="Annie",slot=_R,type="circular",displayName="Summon Tibbers",danger=3,speed=MathHuge,range=600,delay=0.25,radius=290,collision=false},
	["Volley"]={charName="Ashe",slot=_W,type="conic",displayName="Volley",danger=2,speed=2000,range=1200,delay=0.25,radius=20,angle=57.5,collision=true},
	["EnchantedCrystalArrow"]={charName="Ashe",slot=_R,type="linear",displayName="Enchanted Crystal Arrow",danger=2,speed=1600,range=25000,delay=0.25,radius=130,collision=false},
	["AurelionSolQ"]={charName="AurelionSol",slot=_Q,type="linear",displayName="Starsurge",danger=1,speed=850,range=1075,delay=0.25,radius=210,collision=false},
	["AurelionSolR"]={charName="AurelionSol",slot=_R,type="linear",displayName="Voice of Light",danger=2,speed=4500,range=1500,delay=0.35,radius=120,collision=false},
	["BardQ"]={charName="Bard",slot=_Q,type="linear",displayName="Cosmic Binding",danger=1,speed=1500,range=950,delay=0.25,radius=60,collision=true},
	["BardR"]={charName="Bard",slot=_R,type="circular",displayName="Tempered Fate",danger=2,speed=2100,range=3400,delay=0.5,radius=350,collision=false},
	["RocketGrab"]={charName="Blitzcrank",slot=_Q,type="linear",displayName="Rocket Grab",danger=1,speed=1800,range=925,delay=0.25,radius=70,collision=true},
	["StaticField"]={charName="Blitzcrank",slot=_R,type="circular",displayName="Static Field",danger=2,speed=MathHuge,range=0,delay=0.25,radius=600,collision=false},
	["BrandQ"]={charName="Brand",slot=_Q,type="linear",displayName="Sear",danger=1,speed=1600,range=1050,delay=0.25,radius=60,collision=true},
	["BrandW"]={charName="Brand",slot=_W,type="circular",displayName="Pillar of Flame",danger=2,speed=MathHuge,range=900,delay=0.85,radius=250,collision=false},
	["BraumQ"]={charName="Braum",slot=_Q,type="linear",displayName="Winter's Bite",danger=1,speed=1700,range=1000,delay=0.25,radius=60,collision=true},
	["BraumRWrapper"]={charName="Braum",slot=_R,type="linear",displayName="Glacial Fissure",danger=1,speed=1400,range=1250,delay=0.5,radius=115,collision=false},
	["CaitlynPiltoverPeacemaker"]={charName="Caitlyn",slot=_Q,type="linear",displayName="Piltover Peacemaker",danger=1,speed=2200,range=1250,delay=0.625,radius=90,collision=false},
	["CaitlynYordleTrap"]={charName="Caitlyn",slot=_W,type="circular",displayName="Yordle Snap Trap",danger=2,speed=MathHuge,range=800,delay=0.25,radius=75,collision=false},
	["CaitlynEntrapmentMissile"]={charName="Caitlyn",slot=_E,type="linear",displayName="90 Caliber Net",danger=1,speed=1600,range=750,delay=0.25,radius=70,collision=true},
	["CamilleW"]={charName="Camille",slot=_W,type="conic",displayName="Tactical Sweep",danger=2,speed=MathHuge,range=610,delay=0.75,radius=80,angle=80,collision=false},
	["CamilleE"]={charName="Camille",slot=_E,type="linear",displayName="Hookshot",danger=1,speed=1900,range=800,delay=0,radius=60,collision=false},
	["CamilleEDash2"]={charName="Camille",slot=_E,type="linear",displayName="Hookshot",danger=1,speed=1900,range=400,delay=0,radius=60,collision=false},
	["CassiopeiaQ"]={charName="Cassiopeia",slot=_Q,type="circular",displayName="Noxious Blast",danger=1,speed=MathHuge,range=850,delay=0.4,radius=150,collision=false},
	["CassiopeiaW"]={charName="Cassiopeia",slot=_W,type="circular",displayName="Miasma",danger=1,speed=2500,range=800,delay=0.25,radius=160,collision=false},
	["CassiopeiaR"]={charName="Cassiopeia",slot=_R,type="conic",displayName="Petrifying Gaze",danger=2,speed=MathHuge,range=825,delay=0.5,radius=80,angle=80,collision=false},
	["Rupture"]={charName="Chogath",slot=_Q,type="circular",displayName="Rupture",danger=1,speed=MathHuge,range=950,delay=0.5,radius=250,collision=false},
	["FeralScream"]={charName="Chogath",slot=_W,type="conic",displayName="Feral Scream",danger=1,speed=MathHuge,range=650,delay=0.5,radius=60,angle=60,collision=false},
	["PhosphorusBomb"]={charName="Corki",slot=_Q,type="circular",displayName="Phosphorus Bomb",danger=1,speed=1000,range=825,delay=0.25,radius=250,collision=false},
	["CarpetBomb"]={charName="Corki",slot=_W,type="linear",displayName="Valkyrie",danger=1,speed=650,range=600,delay=0,radius=100,collision=false},
	["CarpetBombMega"]={charName="Corki",slot=_W,type="linear",displayName="Special Delivery",danger=1,speed=1500,range=1800,delay=0,radius=100,collision=false},
	["MissileBarrageMissile"]={charName="Corki",slot=_R,type="linear",displayName="Missile Barrage",danger=1,speed=2000,range=1225,delay=0.175,radius=40,collision=true},
	["MissileBarrageMissile2"]={charName="Corki",slot=_R,type="linear",displayName="Missile Barrage",danger=1,speed=2000,range=1225,delay=0.175,radius=40,collision=true},
	["DariusAxeGrabCone"]={charName="Darius",slot=_E,type="conic",displayName="Apprehend",danger=2,speed=MathHuge,range=535,delay=0.25,radius=50,angle=50,collision=false},
	["DianaArc"]={charName="Diana",slot=_Q,type="circular",displayName="Crescent Strike",danger=2,speed=1400,range=900,delay=0.25,radius=205,collision=false},
	["InfectedCleaverMissileCast"]={charName="DrMundo",slot=_Q,type="linear",displayName="Infected Cleaver",danger=1,speed=2000,range=975,delay=0.25,radius=60,collision=true},
	["DravenDoubleShot"]={charName="Draven",slot=_E,type="linear",displayName="Stand Aside",danger=2,speed=1400,range=1050,delay=0.25,radius=130,collision=false},
	["DravenRCast"]={charName="Draven",slot=_R,type="linear",displayName="Whirling Death",danger=2,speed=2000,range=25000,delay=0.5,radius=160,collision=false},
	["EkkoQ"]={charName="Ekko",slot=_Q,type="linear",displayName="Timewinder",danger=1,speed=1650,range=1075,delay=0.25,radius=120,collision=false},
	["EkkoW"]={charName="Ekko",slot=_W,type="circular",displayName="Parallel Convergence",danger=1,speed=1650,range=1600,delay=3.75,radius=400,collision=false},
	["EkkoR"]={charName="Ekko",slot=_R,type="circular",displayName="Chronobreak",danger=3,speed=1650,range=1600,delay=0.25,radius=375,collision=false},
	["EliseHumanE"]={charName="Elise",slot=_E,type="linear",displayName="Cocoon",danger=1,speed=1600,range=1075,delay=0.25,radius=55,collision=true},
	["EvelynnQ"]={charName="Evelynn",slot=_Q,type="linear",displayName="Hate Spike",danger=1,speed=2200,range=800,delay=0.25,radius=35,collision=true},
	["EvelynnR"]={charName="Evelynn",slot=_R,type="conic",displayName="Last Caress",danger=2,speed=MathHuge,range=450,delay=0.35,radius=180,angle=180,collision=false},
	["EzrealMysticShot"]={charName="Ezreal",slot=_Q,type="linear",displayName="Mystic Shot",danger=1,speed=2000,range=1150,delay=0.25,radius=60,collision=true},
	["EzrealEssenceFlux"]={charName="Ezreal",slot=_W,type="linear",displayName="Essence Flux",danger=1,speed=1600,range=1000,delay=0.25,radius=80,collision=false},
	["EzrealTrueshotBarrage"]={charName="Ezreal",slot=_R,type="linear",displayName="Trueshot Barrage",danger=2,speed=2000,range=25000,delay=1,radius=160,collision=false},
	["FioraW"]={charName="Fiora",slot=_W,type="linear",displayName="Riposte",danger=1,speed=3200,range=750,delay=0.75,radius=70,collision=false},
	["FizzR"]={charName="Fizz",slot=_R,type="linear",displayName="Chum the Waters",danger=2,speed=1300,range=1300,delay=0.25,radius=80,collision=false},
	["GalioQ"]={charName="Galio",slot=_Q,type="circular",displayName="Winds of War",danger=1,speed=1150,range=825,delay=0.25,radius=250,collision=false},
	["GalioE"]={charName="Galio",slot=_E,type="linear",displayName="Justice Punch",danger=2,speed=1800,range=650,delay=0.45,radius=160,collision=false},
	["GalioR"]={charName="Galio",slot=_R,type="circular",displayName="Hero's Entrance",danger=2,speed=MathHuge,range=5500,delay=2.75,radius=650,collision=false},
	["GangplankR"]={charName="Gangplank",slot=_R,type="circular",displayName="Cannon Barrage",danger=2,speed=MathHuge,range=25000,delay=0.25,radius=600,collision=false},
	["GnarQ"]={charName="Gnar",slot=_Q,type="linear",displayName="Boomerang Throw",danger=1,speed=2500,range=1100,delay=0.25,radius=55,collision=false},
	["GnarE"]={charName="Gnar",slot=_E,type="circular",displayName="Hop",danger=2,speed=900,range=475,delay=0.25,radius=160,collision=false},
	["GnarBigQ"]={charName="Gnar",slot=_Q,type="linear",displayName="Boulder Toss",danger=1,speed=2100,range=1100,delay=0.5,radius=90,collision=true},
	["GnarBigW"]={charName="Gnar",slot=_W,type="linear",displayName="Wallop",danger=1,speed=MathHuge,range=550,delay=0.6,radius=100,collision=false},
	["GnarBigE"]={charName="Gnar",slot=_E,type="circular",displayName="Crunch",danger=2,speed=800,range=600,delay=0.25,radius=375,collision=false},
	["GnarR"]={charName="Gnar",slot=_R,type="circular",displayName="GNAR!",danger=3,speed=MathHuge,range=0,delay=0.25,radius=475,collision=false},
	["GragasQ"]={charName="Gragas",slot=_Q,type="circular",displayName="Barrel Roll",danger=1,speed=1000,range=850,delay=0.25,radius=250,collision=false},
	["GragasE"]={charName="Gragas",slot=_E,type="linear",displayName="Body Slam",danger=2,speed=900,range=600,delay=0.25,radius=170,collision=true},
	["GragasR"]={charName="Gragas",slot=_R,type="circular",displayName="Explosive Cask",danger=3,speed=1800,range=1000,delay=0.25,radius=400,collision=false},
	["GravesQLineSpell"]={charName="Graves",slot=_Q,type="linear",displayName="End of the Line",danger=1,speed=2000,range=925,delay=0.25,radius=20,collision=false},
	["GravesSmokeGrenade"]={charName="Graves",slot=_W,type="circular",displayName="Smoke Screen",danger=1,speed=1450,range=950,delay=0.15,radius=250,collision=false},
	["GravesChargeShot"]={charName="Graves",slot=_R,type="linear",displayName="Collateral Damage",danger=2,speed=2100,range=1000,delay=0.25,radius=100,collision=false},
	["HecarimRapidSlash"]={charName="Hecarim",slot=_Q,type="circular",displayName="Collateral Damage",danger=1,speed=MathHuge,range=0,delay=0,radius=350,collision=false},
	["HecarimUlt"]={charName="Hecarim",slot=_R,type="linear",displayName="Onslaught of Shadows",danger=2,speed=1100,range=1000,delay=0.01,radius=230,collision=false},
	["HeimerdingerW"]={charName="Heimerdinger",slot=_W,type="linear",displayName="Hextech Micro-Rockets",danger=1,speed=2050,range=1325,delay=0.25,radius=60,collision=true},
	["HeimerdingerE"]={charName="Heimerdinger",slot=_E,type="circular",displayName="CH-2 Electron Storm Grenade",danger=1,speed=1200,range=970,delay=0.25,radius=250,collision=false},
	["HeimerdingerEUlt"]={charName="Heimerdinger",slot=_E,type="circular",displayName="CH-3X Lightning Grenade",danger=2,speed=1200,range=970,delay=0.25,radius=250,collision=false},
	["IllaoiQ"]={charName="Illaoi",slot=_Q,type="linear",displayName="Tentacle Smash",danger=1,speed=MathHuge,range=850,delay=0.75,radius=100,collision=false},
	["IllaoiE"]={charName="Illaoi",slot=_E,type="linear",displayName="Test of Spirit",danger=1,speed=1900,range=900,delay=0.25,radius=50,collision=true},
	["IllaoiR"]={charName="Illaoi",slot=_R,type="circular",displayName="Leap of Faith",danger=3,speed=MathHuge,range=0,delay=0.5,radius=450,collision=false},
	["IreliaW2"]={charName="Irelia",slot=_W,type="circular",displayName="Defiant Dance",danger=1,speed=MathHuge,range=0,delay=0,radius=275,collision=false},
	["IreliaW2"]={charName="Irelia",slot=_W,type="linear",displayName="Defiant Dance",danger=1,speed=MathHuge,range=825,delay=0.25,radius=90,collision=false},
	["IreliaE"]={charName="Irelia",slot=_E,type="circular",displayName="Flawless Duet",danger=1,speed=2000,range=900,delay=0,radius=90,collision=false},
	["IreliaE2"]={charName="Irelia",slot=_E,type="circular",displayName="Flawless Duet",danger=1,speed=2000,range=900,delay=0,radius=90,collision=false},
	["IreliaR"]={charName="Irelia",slot=_R,type="linear",displayName="Vanguard's Edge",danger=2,speed=2000,range=1000,delay=0.4,radius=160,collision=false},
	["IvernQ"]={charName="Ivern",slot=_Q,type="linear",displayName="Rootcaller",danger=1,speed=1300,range=1075,delay=0.25,radius=80,collision=true},
	["HowlingGale"]={charName="Janna",slot=_Q,type="linear",displayName="Howling Gale",danger=1,speed=667,range=1750,delay=0,radius=100,collision=false},
	["JarvanIVDragonStrike"]={charName="JarvanIV",slot=_Q,type="linear",displayName="Dragon Strike",danger=1,speed=MathHuge,range=770,delay=0.4,radius=60,collision=false},
	["JarvanIVDemacianStandard"]={charName="JarvanIV",slot=_E,type="circular",displayName="Demacian Standard",danger=1,speed=3440,range=860,delay=0,radius=175,collision=false},
	["JayceShockBlast"]={charName="Jayce",slot=_Q,type="linear",displayName="Shock Blast",danger=1,speed=1450,range=1175,delay=0.214,radius=70,collision=true},
	["JayceShockBlastWallMis"]={charName="Jayce",slot=_Q,type="linear",displayName="Shock Blast",danger=2,speed=2350,range=1900,delay=0.214,radius=115,collision=true},
	["JhinW"]={charName="Jhin",slot=_W,type="linear",displayName="Deadly Flourish",danger=1,speed=5000,range=3000,delay=0.75,radius=40,collision=false},
	["JhinE"]={charName="Jhin",slot=_E,type="circular",displayName="Captive Audience",danger=1,speed=1600,range=750,delay=0.25,radius=120,collision=false},
	["JhinRShot"]={charName="Jhin",slot=_R,type="linear",displayName="Curtain Call",danger=2,speed=5000,range=3500,delay=0.25,radius=80,collision=false},
	["JinxW"]={charName="Jinx",slot=_W,type="linear",displayName="Zap!",danger=1,speed=3300,range=1450,delay=0.6,radius=60,collision=true},
	["JinxE"]={charName="Jinx",slot=_E,type="circular",displayName="Flame Chompers!",danger=1,speed=1100,range=900,delay=1.5,radius=120,collision=false},
	["JinxR"]={charName="Jinx",slot=_R,type="linear",displayName="Mega Death Rocket!",danger=2,speed=1700,range=25000,delay=0.6,radius=140,collision=false},
	["KaisaW"]={charName="Kaisa",slot=_W,type="linear",displayName="Void Seeker",danger=1,speed=1750,range=3000,delay=0.4,radius=100,collision=true},
	["KalistaMysticShot"]={charName="Kalista",slot=_Q,type="linear",displayName="Pierce",danger=1,speed=2400,range=1150,delay=0.35,radius=40,collision=true},
	["KarmaQ"]={charName="Karma",slot=_Q,type="linear",displayName="Inner Flame",danger=1,speed=1700,range=950,delay=0.25,radius=60,collision=true},
	["KarmaQMantra"]={charName="Karma",slot=_Q,type="linear",displayName="Inner Flame",danger=2,speed=1700,range=950,delay=0.25,radius=80,collision=true},
	["KarthusLayWasteA1"]={charName="Karthus",slot=_Q,type="circular",displayName="Lay Waste",danger=1,speed=MathHuge,range=875,delay=0.625,radius=200,collision=false},
	["KarthusLayWasteA2"]={charName="Karthus",slot=_Q,type="circular",displayName="Lay Waste",danger=1,speed=MathHuge,range=875,delay=0.625,radius=200,collision=false},
	["KarthusLayWasteA3"]={charName="Karthus",slot=_Q,type="circular",displayName="Lay Waste",danger=1,speed=MathHuge,range=875,delay=0.625,radius=200,collision=false},
	["ForcePulse"]={charName="Kassadin",slot=_E,type="conic",displayName="Force Pulse",danger=2,speed=MathHuge,range=600,delay=0.25,radius=80,angle=80,collision=false},
	["Riftwalk"]={charName="Kassadin",slot=_R,type="circular",displayName="Riftwalk",danger=2,speed=MathHuge,range=500,delay=0.25,radius=300,collision=false},
	["KatarinaE"]={charName="Katarina",slot=_E,type="circular",displayName="Shunpo",danger=2,speed=MathHuge,range=725,delay=0.15,radius=150,collision=false},
	["KatarinaR"]={charName="Katarina",slot=_R,type="circular",displayName="Death Lotus",danger=2,speed=MathHuge,range=0,delay=0,radius=550,collision=false},
	["KaynQ"]={charName="Kayn",slot=_Q,type="circular",displayName="Reaping Slash",danger=2,speed=MathHuge,range=0,delay=0.15,radius=350,collision=false},
	["KaynW"]={charName="Kayn",slot=_W,type="linear",displayName="Blade's Reach",danger=1,speed=MathHuge,range=700,delay=0.55,radius=90,collision=false},
	["KennenShurikenHurlMissile1"]={charName="Kennen",slot=_Q,type="linear",displayName="Thundering Shuriken",danger=1,speed=1700,range=1050,delay=0.175,radius=50,collision=true},
	["KhazixW"]={charName="Khazix",slot=_W,type="linear",displayName="Void Spike",danger=1,speed=1700,range=1000,delay=0.25,radius=70,collision=true},
	["KhazixWLong"]={charName="Khazix",slot=_W,type="threeway",displayName="Void Spike",danger=2,speed=1700,range=1000,delay=0.25,radius=70,angle=50,collision=true},
	["KhazixE"]={charName="Khazix",slot=_E,type="circular",displayName="Leap",danger=2,speed=1000,range=700,delay=0.25,radius=320,collision=false},
	["KhazixELong"]={charName="Khazix",slot=_E,type="circular",displayName="Leap",danger=2,speed=1000,range=900,delay=0.25,radius=320,collision=false},
	["KledQ"]={charName="Kled",slot=_Q,type="linear",displayName="Beartrap on a Rope",danger=1,speed=1600,range=800,delay=0.25,radius=45,collision=true},
	["KledRiderQ"]={charName="Kled",slot=_Q,type="conic",displayName="Pocket Pistol",danger=2,speed=3000,range=700,delay=0.25,angle=25,collision=false},
	["KledEDash"]={charName="Kled",slot=_E,type="linear",displayName="Jousting",danger=2,speed=1100,range=550,delay=0,radius=90,collision=false},
	["KogMawQ"]={charName="KogMaw",slot=_Q,type="linear",displayName="Caustic Spittle",danger=1,speed=1650,range=1175,delay=0.25,radius=70,collision=true},
	["KogMawVoidOoze"]={charName="KogMaw",slot=_E,type="linear",displayName="Void Ooze",danger=1,speed=1400,range=1280,delay=0.25,radius=120,collision=false},
	["KogMawLivingArtillery"]={charName="KogMaw",slot=_R,type="circular",displayName="Living Artillery",danger=1,speed=MathHuge,range=1800,delay=0.85,radius=200,collision=false},
	["LeBlancW"]={charName="Leblanc",slot=_W,type="circular",displayName="Distortion",danger=2,speed=1450,range=600,delay=0.25,radius=260,collision=false},
	["LeBlancE"]={charName="Leblanc",slot=_E,type="linear",displayName="Ethereal Chains",danger=1,speed=1750,range=925,delay=0.25,radius=55,collision=true},
	["LeBlancRW"]={charName="Leblanc",slot=_W,type="circular",displayName="Distortion",danger=2,speed=1450,range=600,delay=0.25,radius=260,collision=false},
	["LeBlancRE"]={charName="Leblanc",slot=_E,type="linear",displayName="Ethereal Chains",danger=1,speed=1750,range=925,delay=0.25,radius=55,collision=true},
	["BlindMonkQOne"]={charName="LeeSin",slot=_Q,type="linear",displayName="Sonic Wave",danger=1,speed=1800,range=1200,delay=0.25,radius=60,collision=true},
	["BlindMonkEOne"]={charName="LeeSin",slot=_E,type="circular",displayName="Tempest",danger=2,speed=MathHuge,range=0,delay=0.25,radius=350,collision=false},
	["LeonaZenithBlade"]={charName="Leona",slot=_E,type="linear",displayName="Zenith Blade",danger=1,speed=2000,range=875,delay=0.25,radius=70,collision=false},
	["LeonaSolarFlare"]={charName="Leona",slot=_R,type="circular",displayName="Solar Flare",danger=3,speed=MathHuge,range=1200,delay=0.625,radius=250,collision=false},
	["LissandraQ"]={charName="Lissandra",slot=_Q,type="linear",displayName="Ice Shard",danger=1,speed=2200,range=825,delay=0.251,radius=75,collision=false},
	["LissandraW"]={charName="Lissandra",slot=_W,type="circular",displayName="Ring of Frost",danger=2,speed=MathHuge,range=0,delay=0.25,radius=450,collision=false},
	["LissandraE"]={charName="Lissandra",slot=_E,type="linear",displayName="Glacial Path",danger=1,speed=850,range=1050,delay=0.25,radius=125,collision=false},
	["LucianQ"]={charName="Lucian",slot=_Q,type="linear",displayName="Piercing Light",danger=1,speed=MathHuge,range=900,delay=0.5,radius=65,collision=false},
	["LucianW"]={charName="Lucian",slot=_W,type="linear",displayName="Ardent Blaze",danger=1,speed=1600,range=900,delay=0.25,radius=55,collision=false},
	["LucianR"]={charName="Lucian",slot=_R,type="linear",displayName="The Culling",danger=2,speed=2800,range=1200,delay=0.01,radius=110,collision=true},
	["LuluQ"]={charName="Lulu",slot=_Q,type="linear",displayName="Glitterlance",danger=1,speed=1450,range=925,delay=0.25,radius=60,collision=false},
	["LuxLightBinding"]={charName="Lux",slot=_Q,type="linear",displayName="Light Binding",danger=1,speed=1200,range=1175,delay=0.25,radius=50,collision=true},
	["LuxLightStrikeKugel"]={charName="Lux",slot=_E,type="circular",displayName="Lucent Singularity",danger=2,speed=1200,range=1000,delay=0.25,radius=310,collision=false},
	["LuxMaliceCannon"]={charName="Lux",slot=_R,type="linear",displayName="Final Spark",danger=2,speed=MathHuge,range=3340,delay=1.375,radius=120,collision=false},
	["Landslide"]={charName="Malphite",slot=_E,type="circular",displayName="Ground Slam",danger=2,speed=MathHuge,range=0,delay=0.242,radius=200,collision=false},
	["UFSlash"]={charName="Malphite",slot=_R,type="circular",displayName="Unstoppable Force",danger=3,speed=1835,range=1000,delay=0,radius=300,collision=false},
	["MalzaharQ"]={charName="Malzahar",slot=_Q,type="rectangular",displayName="Call of the Void",danger=2,speed=MathHuge,range=900,delay=0.25,radius2=400,radius=100,collision=false},
	["MaokaiQ"]={charName="Maokai",slot=_Q,type="linear",displayName="Bramble Smash",danger=1,speed=1600,range=600,delay=0.375,radius=110,collision=false},
	["MissFortuneScattershot"]={charName="MissFortune",slot=_E,type="circular",displayName="Make It Rain",danger=2,speed=MathHuge,range=1000,delay=0.5,radius=400,collision=false},
	["MissFortuneBulletTime"]={charName="MissFortune",slot=_R,type="conic",displayName="Bullet Time",danger=2,speed=MathHuge,range=1400,delay=0.001,radius=40,angle=40,collision=false},
	["MordekaiserSiphonOfDestruction"]={charName="Mordekaiser",slot=_E,type="conic",displayName="Siphon of Destruction",danger=2,speed=MathHuge,range=675,delay=0.25,radius=50,angle=50,collision=false},
	["DarkBindingMissile"]={charName="Morgana",slot=_Q,type="linear",displayName="Dark Binding",danger=1,speed=1200,range=1175,delay=0.25,radius=70,collision=true},
	["TormentedSoil"]={charName="Morgana",slot=_W,type="circular",displayName="Tormented Soil",danger=2,speed=MathHuge,range=900,delay=0.25,radius=325,collision=false},
	["NamiQ"]={charName="Nami",slot=_Q,type="circular",displayName="Aqua Prison",danger=1,speed=MathHuge,range=875,delay=0.95,radius=200,collision=false},
	["NamiR"]={charName="Nami",slot=_R,type="linear",displayName="Tidal Wave",danger=2,speed=850,range=2750,delay=0.5,radius=250,collision=false},
	["NasusE"]={charName="Nasus",slot=_E,type="circular",displayName="Spirit Fire",danger=2,speed=MathHuge,range=650,delay=0.25,radius=400,collision=false},
	["NautilusAnchorDrag"]={charName="Nautilus",slot=_Q,type="linear",displayName="Dredge Line",danger=2,speed=2000,range=1100,delay=0.25,radius=90,collision=true},
	["JavelinToss"]={charName="Nidalee",slot=_Q,type="linear",displayName="Javelin Toss",danger=1,speed=1300,range=1500,delay=0.25,radius=40,collision=true},
	["Bushwhack"]={charName="Nidalee",slot=_W,type="circular",displayName="Bushwhack",danger=1,speed=MathHuge,range=900,delay=0.25,radius=85,collision=true},
	["Pounce"]={charName="Nidalee",slot=_W,type="circular",displayName="Pounce",danger=2,speed=1750,range=750,delay=0.25,radius=200,collision=false},
	["Swipe"]={charName="Nidalee",slot=_E,type="conic",displayName="Swipe",danger=2,speed=MathHuge,range=300,delay=0.25,radius=180,angle=180,collision=false},
	["NocturneDuskbringer"]={charName="Nocturne",slot=_Q,type="linear",displayName="Duskbringer",danger=1,speed=1600,range=1200,delay=0.25,radius=60,collision=false},
	["AbsoluteZero"]={charName="Nunu",slot=_R,type="circular",displayName="Absolute Zero",danger=3,speed=MathHuge,range=0,delay=0.01,radius=650,collision=false},
	["OlafAxeThrowCast"]={charName="Olaf",slot=_Q,type="linear",displayName="Undertow",danger=1,speed=1600,range=1000,delay=0.25,radius=90,collision=false},
	["OrianaIzunaCommand"]={charName="Orianna",slot=_Q,type="hybrid",displayName="Command Attack",danger=1,speed=1400,range=825,delay=0.25,radius=80,collision=false},
	["OrianaDissonanceCommand"]={charName="Orianna",slot=_W,type="hybrid",displayName="Command Dissonance",proj="OrianaDissonanceCommand-",danger=2,speed=MathHuge,range=0,delay=0.25,radius=250,collision=false},
	["OrianaRedactCommand"]={charName="Orianna",slot=_E,type="hybrid",displayName="Command Protect",proj="orianaredact",danger=1,speed=1400,range=1100,delay=0.25,radius=80,collision=false},
	["OrianaDetonateCommand"]={charName="Orianna",slot=_R,type="hybrid",displayName="Command Shockwave",proj="OrianaDetonateCommand-",danger=3,speed=MathHuge,range=0,delay=0.5,radius=325,collision=false},
	["OrnnQ"]={charName="Ornn",slot=_Q,type="linear",displayName="Volcanic Rupture",danger=1,speed=1800,range=800,delay=0.3,radius=65,collision=false},
	["OrnnE"]={charName="Ornn",slot=_E,type="linear",displayName="Searing Charge",danger=2,speed=1800,range=800,delay=0.35,radius=150,collision=false},
	["OrnnR"]={charName="Ornn",slot=_R,type="linear",displayName="Call of the Forge God",danger=2,speed=1650,range=2500,delay=0.5,radius=250,collision=false},
	["OrnnRCharge"]={charName="Ornn",slot=_R,type="linear",displayName="Call of the Forge God",danger=2,speed=1650,range=2500,delay=0.25,radius=200,collision=true},
	["PantheonE"]={charName="Pantheon",slot=_E,type="conic",displayName="Heartseeker Strike",danger=2,speed=MathHuge,range=0,delay=0.389,radius=80,angle=80,collision=false},
	["PantheonRFall"]={charName="Pantheon",slot=_R,type="circular",displayName="Grand Skyfall",danger=2,speed=MathHuge,range=5500,delay=2.25,radius=700,collision=false},
	["PoppyQSpell"]={charName="Poppy",slot=_Q,type="linear",displayName="Hammer Shock",danger=1,speed=MathHuge,range=430,delay=1.32,radius=85,collision=false},
	["PoppyRSpell"]={charName="Poppy",slot=_R,type="linear",displayName="Keeper's Verdict",danger=2,speed=2000,range=1900,delay=0.333,radius=100,collision=false},
	["PykeQMelee"]={charName="Pyke",slot=_Q,type="linear",displayName="Bone Skewer",danger=2,speed=MathHuge,range=400,delay=0.25,radius=70,collision=false},
	["PykeQRange"]={charName="Pyke",slot=_Q,type="linear",displayName="Bone Skewer",danger=2,speed=2000,range=1100,delay=0.2,radius=70,collision=true},
	["QuinnQ"]={charName="Quinn",slot=_Q,type="linear",displayName="Blinding Assault",danger=1,speed=1550,range=1025,delay=0.25,radius=60,collision=true},
	["RakanQ"]={charName="Rakan",slot=_Q,type="linear",displayName="Gleaming Quill",danger=1,speed=1850,range=900,delay=0.25,radius=65,collision=true},
	["RakanW"]={charName="Rakan",slot=_W,type="circular",displayName="Grand Entrance",danger=2,speed=2050,range=600,delay=0,radius=250,collision=false},
	["RekSaiQBurrowed"]={charName="Reksai",slot=_Q,type="linear",displayName="Prey Seeker",danger=1,speed=1950,range=1650,delay=0.125,radius=65,collision=true},
	["RenektonCleave"]={charName="Renekton",slot=_Q,type="circular",displayName="Cull the Meek",danger=2,speed=MathHuge,range=0,delay=0.25,radius=325,collision=false},
	["RenektonSliceAndDice"]={charName="Renekton",slot=_E,type="linear",displayName="Slice and Dice",danger=2,speed=1125,range=450,delay=0.25,radius=45,collision=false},
	["RengarW"]={charName="Rengar",slot=_W,type="circular",displayName="Battle Roar",danger=2,speed=MathHuge,range=0,delay=0.25,radius=450,collision=false},
	["RengarE"]={charName="Rengar",slot=_E,type="linear",displayName="Bola Strike",danger=1,speed=1500,range=1000,delay=0.25,radius=70,collision=true},
	["RivenMartyr"]={charName="Riven",slot=_W,type="circular",displayName="Ki Burst",danger=2,speed=MathHuge,range=0,delay=0.267,radius=135,collision=false},
	["RivenIzunaBlade"]={charName="Riven",slot=_R,type="conic",displayName="Blade of the Exile",danger=3,speed=1600,range=900,delay=0.25,radius=50,angle=50,collision=false},
	["RumbleGrenade"]={charName="Rumble",slot=_E,type="linear",displayName="Electro Harpoon",danger=1,speed=2000,range=850,delay=0.25,radius=60,collision=true},
	["RumbleCarpetBombDummy"]={charName="Rumble",slot=_R,type="rectangular",displayName="The Equalizer",danger=2,speed=1600,range=1700,delay=0.583,radius1=600,radius2=200,collision=false},
	["RyzeQ"]={charName="Ryze",slot=_Q,type="linear",displayName="Overload",danger=1,speed=1700,range=1000,delay=0.25,radius=55,collision=true},
	["SejuaniW"]={charName="Sejuani",slot=_W,type="conic",displayName="Winter's Wrath",danger=1,speed=MathHuge,range=600,delay=0.25,radius=75,angle=75,collision=false},
	["SejuaniWDummy"]={charName="Sejuani",slot=_W,type="linear",displayName="Winter's Wrath",danger=1,speed=MathHuge,range=600,delay=1,radius=65,collision=false},
	["SejuaniR"]={charName="Sejuani",slot=_R,type="linear",displayName="Glacial Prison",danger=3,speed=1600,range=1300,delay=0.25,radius=120,collision=false},
	["ShenE"]={charName="Shen",slot=_E,type="linear",displayName="Shadow Dash",danger=2,speed=1200,range=600,delay=0,radius=60,collision=false},
	["ShyvanaFireball"]={charName="Shyvana",slot=_E,type="linear",displayName="Flame Breath",danger=1,speed=1575,range=925,delay=0.25,radius=60,collision=false},
	["ShyvanaTransformLeap"]={charName="Shyvana",slot=_R,type="linear",displayName="Dragon's Descent",danger=2,speed=1130,range=850,delay=0.25,radius=160,collision=false},
	["ShyvanaFireballDragon2"]={charName="Shyvana",slot=_E,type="linear",displayName="Flame Breath",danger=1,speed=1575,range=925,delay=0.333,radius=60,collision=false},
	["MegaAdhesive"]={charName="Singed",slot=_W,type="circular",displayName="Mega Adhesive",danger=2,speed=MathHuge,range=1000,delay=0.25,radius=265,collision=false},
	["SionQ"]={charName="Sion",slot=_Q,type="linear",displayName="Decimating Smash",danger=2,speed=MathHuge,range=600,delay=0,radius=300,collision=false},
	["SionE"]={charName="Sion",slot=_E,type="linear",displayName="Roar of the Slayer",danger=1,speed=1800,range=725,delay=0.25,radius=80,collision=false},
	["SivirQ"]={charName="Sivir",slot=_Q,type="linear",displayName="Boomerang Blade",danger=1,speed=1350,range=1250,delay=0.25,radius=90,collision=false},
	["SkarnerVirulentSlash"]={charName="Skarner",slot=_Q,type="circular",displayName="Crystal Slash",danger=2,speed=MathHuge,range=0,delay=0.25,radius=350,collision=false},
	["SkarnerFracture"]={charName="Skarner",slot=_E,type="linear",displayName="Fracture",danger=1,speed=1500,range=1000,delay=0.25,radius=70,collision=false},
	["SonaR"]={charName="Sona",slot=_R,type="linear",displayName="Crescendo",danger=2,speed=2400,range=900,delay=0.25,radius=140,collision=false},
	["SorakaQ"]={charName="Soraka",slot=_Q,type="circular",displayName="Crescendo",danger=1,speed=1150,range=800,delay=0.25,radius=235,collision=false},
	["SorakaE"]={charName="Soraka",slot=_E,type="circular",displayName="Equinox",danger=1,speed=MathHuge,range=925,delay=0.25,radius=300,collision=false},
	["SwainQ"]={charName="Swain",slot=_Q,type="conic",displayName="Death's Hand",danger=2,speed=MathHuge,range=725,delay=0.25,radius=45,angle=45,collision=false},
	["SwainW"]={charName="Swain",slot=_W,type="circular",displayName="Vision of Empire",danger=1,speed=MathHuge,range=3500,delay=0.25,radius=325,collision=false},
	["SwainE"]={charName="Swain",slot=_E,type="linear",displayName="Nevermove",danger=1,speed=935,range=850,delay=0.25,radius=85,collision=false},
	["SyndraQ"]={charName="Syndra",slot=_Q,type="circular",displayName="Dark Sphere",danger=1,speed=MathHuge,range=800,delay=0.625,radius=200,collision=false},
	["SyndraWCast"]={charName="Syndra",slot=_W,type="circular",displayName="Force of Will",danger=1,speed=1450,range=950,delay=0.25,radius=225,collision=false},
	["SyndraE"]={charName="Syndra",slot=_E,type="conic",displayName="Scatter the Weak",danger=2,speed=2500,range=700,delay=0.25,radius=40,angle=40,collision=false},
	["SyndraEMissile"]={charName="Syndra",slot=_E,type="linear",displayName="Scatter the Weak",danger=2,speed=1600,range=1250,delay=0.25,radius=60,collision=false},
	["TahmKenchQ"]={charName="TahmKench",slot=_Q,type="linear",displayName="Tongue Lash",danger=1,speed=2800,range=800,delay=0.25,radius=70,collision=true},
	["TaliyahQ"]={charName="Taliyah",slot=_Q,type="linear",displayName="Threaded Volley",danger=1,speed=3600,range=1000,delay=0.25,radius=100,collision=true},
	["TaliyahWVC"]={charName="Taliyah",slot=_W,type="circular",displayName="Seismic Shove",danger=2,speed=MathHuge,range=900,delay=0.6,radius=150,collision=false},
	["TaliyahE"]={charName="Taliyah",slot=_E,type="conic",displayName="Unraveled Earth",danger=2,speed=2000,range=800,delay=0.25,radius=80,angle=80,collision=false},
	["TalonW"]={charName="Talon",slot=_W,type="conic",displayName="Rake",danger=2,speed=1850,range=650,delay=0.25,radius=35,angle=35,collision=false},
	["TalonR"]={charName="Talon",slot=_R,type="circular",displayName="Shadow Assault",danger=2,speed=MathHuge,range=0,delay=0.25,radius=550,collision=false},
	["TeemoRCast"]={charName="Teemo",slot=_R,type="circular",displayName="Noxious Trap",danger=1,speed=MathHuge,range=900,delay=1.25,radius=200,collision=false},
	["ThreshQ"]={charName="Thresh",slot=_Q,type="linear",displayName="Death Sentence",danger=1,speed=1900,range=1100,delay=0.5,radius=70,collision=true},
	["ThreshEFlay"]={charName="Thresh",slot=_E,type="linear",displayName="Flay",proj="ThreshEMissile1",danger=2,speed=MathHuge,range=400,delay=0.389,radius=110,collision=false},
	["TristanaW"]={charName="Tristana",slot=_W,type="circular",displayName="Rocket Jump",danger=2,speed=1100,range=900,delay=0.25,radius=250,collision=false},
	["TrundleCircle"]={charName="Trundle",slot=_E,type="circular",displayName="Pillar of Ice",danger=2,speed=MathHuge,range=1000,delay=0.25,radius=375,collision=false},
	["TryndamereE"]={charName="Tryndamere",slot=_E,type="linear",displayName="Spinning Slash",danger=2,speed=1300,range=660,delay=0,radius=225,collision=false},
	["WildCards"]={charName="TwistedFate",slot=_Q,type="threeway",displayName="Wild Cards",danger=1,speed=1000,range=1450,delay=0.25,radius=40,angle=27.5,collision=false},
	["TwitchVenomCask"]={charName="Twitch",slot=_W,type="circular",displayName="Venom Cask",danger=2,speed=1400,range=950,delay=0.25,radius=340,collision=false},
	["UrgotQ"]={charName="Urgot",slot=_Q,type="circular",displayName="Corrosive Charge",danger=1,speed=MathHuge,range=800,delay=0.6,radius=215,collision=false},
	["UrgotE"]={charName="Urgot",slot=_E,type="linear",displayName="Disdain",danger=2,speed=1050,range=475,delay=0.45,radius=100,collision=false},
	["UrgotR"]={charName="Urgot",slot=_R,type="linear",displayName="Fear Beyond Death",danger=2,speed=3200,range=1600,delay=0.4,radius=80,collision=false},
	["VarusQ"]={charName="Varus",slot=_Q,type="linear",displayName="Piercing Arrow",danger=1,speed=1900,range=1625,delay=0,radius=70,collision=false},
	["VarusE"]={charName="Varus",slot=_E,type="circular",displayName="Hail of Arrows",danger=2,speed=1500,range=925,delay=0.242,radius=280,collision=false},
	["VarusR"]={charName="Varus",slot=_R,type="linear",displayName="Chain of Corruption",danger=2,speed=1950,range=1075,delay=0.242,radius=120,collision=false},
	["VeigarBalefulStrike"]={charName="Veigar",slot=_Q,type="linear",displayName="Baleful Strike",danger=1,speed=2200,range=950,delay=0.25,radius=70,collision=true},
	["VeigarDarkMatter"]={charName="Veigar",slot=_W,type="circular",displayName="Dark Matter",danger=1,speed=MathHuge,range=900,delay=1.25,radius=225,collision=false},
	["VeigarEventHorizon"]={charName="Veigar",slot=_E,type="annular",displayName="Event Horizon",danger=2,speed=MathHuge,range=700,delay=0.75,radius=375,collision=false},
	["VelKozQ"]={charName="VelKoz",slot=_Q,type="linear",displayName="Plasma Fission",danger=1,speed=1300,range=1050,delay=0.251,radius=50,collision=true},
	["VelkozQMissileSplit"]={charName="VelKoz",slot=_Q,type="linear",displayName="Plasma Fission",proj="VelkozQMissileSplit",danger=1,speed=2100,range=1050,delay=0.251,radius=45,collision=true},
	["VelKozW"]={charName="VelKoz",slot=_W,type="linear",displayName="Void Rift",danger=1,speed=1700,range=1050,delay=0.25,radius=87.5,collision=false},
	["VelKozE"]={charName="VelKoz",slot=_E,type="circular",displayName="Tectonic Disruption",danger=2,speed=MathHuge,range=850,delay=0.75,radius=235,collision=false},
	["ViQ"]={charName="Vi",slot=_Q,type="linear",displayName="Vault Breaker",danger=2,speed=1500,range=725,delay=0,radius=90,collision=false},
	["ViktorGravitonField"]={charName="Viktor",slot=_W,type="circular",displayName="Gravity Field",danger=1,speed=MathHuge,range=700,delay=1.333,radius=290,collision=false},
	["ViktorDeathRay"]={charName="Viktor",slot=_E,type="linear",displayName="Death Ray",danger=1,speed=1050,range=1025,delay=0,radius=80,collision=false},
	["VladimirHemoplague"]={charName="Vladimir",slot=_R,type="circular",displayName="Hemoplague",danger=3,speed=MathHuge,range=700,delay=0.389,radius=350,collision=true},
	["WarwickR"]={charName="Warwick",slot=_R,type="linear",displayName="Infinite Duress",danger=2,speed=1800,range=3000,delay=0.1,radius=45,collision=false},
	["XayahQ"]={charName="Xayah",slot=_Q,type="linear",displayName="Double Daggers",danger=1,speed=2075,range=1100,delay=0.5,radius=45,collision=false},
	["XayahR"]={charName="Xayah",slot=_R,type="conic",displayName="Featherstorm",danger=2,speed=4000,range=1100,delay=1.5,radius=20,angle=40,collision=false},
	["XerathArcanopulse2"]={charName="Xerath",slot=_Q,type="linear",displayName="Arcanopulse",danger=1,speed=MathHuge,range=1400,delay=0.5,radius=90,collision=false},
	["XerathArcaneBarrage2"]={charName="Xerath",slot=_W,type="circular",displayName="Eye of Destruction",danger=2,speed=MathHuge,range=1100,delay=0.7,radius=235,collision=false},
	["XerathMageSpear"]={charName="Xerath",slot=_E,type="linear",displayName="Shocking Orb",danger=1,speed=1350,range=1050,delay=0.2,radius=60,collision=true},
	["XerathRMissileWrapper"]={charName="Xerath",slot=_R,type="circular",displayName="Rite of the Arcane",danger=2,speed=MathHuge,range=6160,delay=0.7,radius=200,collision=false},
	["XinZhaoW"]={charName="XinZhao",slot=_W,type="conic",displayName="Wind Becomes Lightning",danger=2,speed=MathHuge,range=125,delay=0,radius=180,angle=180,collision=false},
	["XinZhaoW"]={charName="XinZhao",slot=_W,type="linear",displayName="Wind Becomes Lightning",danger=2,speed=MathHuge,range=900,delay=0.5,radius=45,collision=false},
	["XinZhaoR"]={charName="XinZhao",slot=_R,type="circular",displayName="Crescent Guard",danger=2,speed=MathHuge,range=0,delay=0.325,radius=550,collision=false},
	["YasuoQW"]={charName="Yasuo",slot=_Q,type="linear",displayName="Steel Tempest",danger=1,speed=MathHuge,range=475,delay=0.339,radius=40,collision=false},
	["YasuoQ2W"]={charName="Yasuo",slot=_Q,type="linear",displayName="Steel Wind Rising",danger=1,speed=MathHuge,range=475,delay=0.339,radius=40,collision=false},
	["YasuoQ3W"]={charName="Yasuo",slot=_Q,type="linear",displayName="Gathering Storm",danger=1,speed=1200,range=1000,delay=0.339,radius=90,collision=false},
	["YorickW"]={charName="Yorick",slot=_W,type="annular",displayName="Dark Procession",danger=2,speed=MathHuge,range=600,delay=0.25,radius=300,collision=false},
	["ZacQ"]={charName="Zac",slot=_Q,type="linear",displayName="Stretching Strikes",danger=1,speed=2800,range=800,delay=0.33,radius=80,collision=true},
	["ZacW"]={charName="Zac",slot=_W,type="circular",displayName="Unstable Matter",danger=2,speed=MathHuge,range=0,delay=0.25,radius=350,collision=false},
	["ZacE"]={charName="Zac",slot=_E,type="circular",displayName="Elastic Slingshot",danger=2,speed=1330,range=1800,delay=0,radius=300,collision=false},
	["ZacR"]={charName="Zac",slot=_R,type="circular",displayName="Let's Bounce!",danger=3,speed=MathHuge,range=1000,delay=0,radius=300,collision=false},
	["ZedQ"]={charName="Zed",slot=_Q,type="linear",displayName="Razor Shuriken",danger=1,speed=1700,range=900,delay=0.25,radius=50,collision=false},
	["ZedW"]={charName="Zed",slot=_W,type="linear",displayName="Living Shadow",danger=2,speed=1750,range=650,delay=0.25,radius=60,collision=false},
	["ZedE"]={charName="Zed",slot=_E,type="circular",displayName="Shadow Slash",danger=2,speed=MathHuge,range=0,delay=0.25,radius=290,collision=false},
	["ZiggsQ"]={charName="Ziggs",slot=_Q,type="circular",displayName="Bouncing Bomb",danger=1,speed=3000,range=1400,delay=0.25,radius=130,collision=false},
	["ZiggsW"]={charName="Ziggs",slot=_W,type="circular",displayName="Satchel Charge",danger=1,speed=2000,range=1000,delay=0.25,radius=280,collision=false},
	["ZiggsE"]={charName="Ziggs",slot=_E,type="circular",displayName="Hexplosive Minefield",danger=2,speed=1800,range=900,delay=0.25,radius=250,collision=false},
	["ZiggsR"]={charName="Ziggs",slot=_R,type="circular",displayName="Mega Inferno Bomb",danger=3,speed=1600,range=5300,delay=0.375,radius=550,collision=false},
	["ZileanQ"]={charName="Zilean",slot=_Q,type="circular",displayName="Time Bomb",danger=2,speed=MathHuge,range=900,delay=0.8,radius=180,collision=false},
	["ZileanQAttachAudio"]={charName="Zilean",slot=_Q,type="circular",displayName="Time Bomb",danger=2,speed=MathHuge,range=900,delay=0.8,radius=180,collision=false},
	["ZoeQ"]={charName="Zoe",slot=_Q,type="linear",displayName="Paddle Star",danger=1,speed=1200,range=800,delay=0.25,radius=50,collision=true},
	["ZoeQRecast"]={charName="Zoe",slot=_Q,type="hybrid",displayName="Paddle Star",danger=1,speed=2500,range=1600,delay=0,radius=70,collision=true},
	["ZoeE"]={charName="Zoe",slot=_E,type="linear",displayName="Sleepy Trouble Bubble",danger=2,speed=1700,range=800,delay=0.3,radius=50,collision=true},
	["ZyraQ"]={charName="Zyra",slot=_Q,type="rectangular",displayName="Deadly Spines",danger=2,speed=MathHuge,range=800,delay=0.625,radius2=400,radius=100,collision=false},
	["ZyraE"]={charName="Zyra",slot=_E,type="linear",displayName="Grasping Roots",danger=1,speed=1150,range=1100,delay=0.25,radius=70,collision=false},
	["ZyraR"]={charName="Zyra",slot=_R,type="circular",displayName="Stranglethorns",danger=3,speed=MathHuge,range=700,delay=1.775,radius=575,collision=false},
}

self.EvadeSpells = {
	["Ahri"] = {
		[3] = {type=1,displayName="Spirit Rush",name="AhriR",danger=3,range=450,slot=3},
	},
	["Blitzcrank"] = {
		[1] = {type=2,displayName="Overdrive",name="BlitzcrankW",danger=2,slot=1},
	},
	["Braum"] = {
		[2] = {type=2,displayName="Unbreakable",name="BraumE",danger=1,slot=2},
	},
	["Corki"] = {
		[1] = {type=1,displayName="Valkyrie",name="CorkiW",danger=2,range=600,slot=1},
	},
	["Draven"] = {
		[1] = {type=2,displayName="Blood Rush",name="DravenW",danger=2,slot=1},
	},
	["Ekko"] = {
		[2] = {type=1,displayName="Phase Dive",name="EkkoE",danger=1,range=325,slot=2},
	},
	["Evelynn"] = {
		[3] = {type=1,displayName="Last Caress",name="EvelynnR",danger=3,range=450,slot=3},
	},
	["Ezreal"] = {
		[2] = {type=1,displayName="Arcane Shift",name="EzrealQ",danger=2,range=475,slot=2},
	},
	["Fiora"] = {
		[0] = {type=1,displayName="Lunge",name="FioraQ",danger=1,range=400,slot=0},
	},
	["Fizz"] = {
		[2] = {type=2,displayName="Playful",name="FizzE",danger=2,slot=2},
	},
	["Garen"] = {
		[0] = {type=2,displayName="Decisive Strike",name="GarenQ",danger=1,slot=0},
	},
	["Gnar"] = {
		[2] = {type=1,displayName="Hop/Crunch",name="GnarE",range=475,danger=2,slot=2},
	},
	["Gragas"] = {
		[2] = {type=1,displayName="Body Slam",name="GragasE",range=600,danger=2,slot=2},
	},
	["Graves"] = {
		[2] = {type=1,displayName="Quickdraw",name="GravesE",range=425,danger=1,slot=2},
	},
	["Hecarim"] = {
		[2] = {type=2,displayName="Devastating Charge",name="HecarimE",danger=2,slot=2},
		[3] = {type=1,displayName="Onslaught of Shadows",name="HecarimR",range=1000,danger=3,slot=3},
	},
	["Jayce"] = {
		[3] = {type=2,displayName="Transform Mercury Cannon",name="JayceR",danger=1,slot=3},
	},
	["Kaisa"] = {
		[2] = {type=2,displayName="Supercharge",name="KaisaE",danger=1,slot=2},
	},
	["Karma"] = {
		[2] = {type=3,displayName="Inspire",name="KarmaE",danger=1,slot=2},
	},
	["Kassadin"] = {
		[3] = {type=1,displayName="Riftwalk",name="KassadinR",range=500,danger=1,slot=3},
	},
	["Katarina"] = {
		[1] = {type=2,displayName="Preparation",name="KatarinaW",danger=2,slot=1},
	},
	["Kayle"] = {
		[1] = {type=3,displayName="Divine Blessing",name="KayleW",danger=2,slot=1},
	},
	["Kayn"] = {
		[0] = {type=1,displayName="Reaping Slash",name="KaynQ",danger=1,slot=0},
	},
	["Kennen"] = {
		[2] = {type=2,displayName="Lightning Rush",name="KennenE",danger=2,slot=2},
	},
	["Khazix"] = {
		[2] = {type=1,displayName="Leap",name="KhazixW",range=700,danger=2,slot=2},
	},
	["Kindred"] = {
		[0] = {type=1,displayName="Dance of Arrows",name="KindredQ",range=340,danger=1,slot=0},
	},
	["Kled"] = {
		[2] = {type=1,displayName="Jousting",name="KledE",range=550,danger=2,slot=2},
	},
	["Leblanc"] = {
		[1] = {type=1,displayName="Distortion",name="LeblancW",range=600,danger=2,slot=1},
	},
	["Lucian"] = {
		[2] = {type=1,displayName="Relentless Pursuit",name="LucianE",range=425,danger=2,slot=2},
	},
	["MasterYi"] = {
		[0] = {type=4,displayName="Alpha Strike",name="MasterYiQ",range=600,danger=2,slot=0},
	},
	["Poppy"] = {
		[1] = {type=2,displayName="Steadfast Presence",name="PoppyW",danger=2,slot=1},
	},
	["Pyke"] = {
		[2] = {type=1,displayName="Phantom Undertow",name="PykeE",range=550,danger=2,slot=2},
	},
	["Rakan"] = {
		[1] = {type=1,displayName="Grand Entrance",name="RakanW",range=600,danger=2,slot=1},
	},
	["Renekton"] = {
		[2] = {type=1,displayName="Slice and Dice",name="RenektonE",range=450,danger=2,slot=2},
	},
	["Riven"] = {
		[2] = {type=1,displayName="Valor",name="RivenE",range=325,danger=1,slot=2},
	},
	["Rumble"] = {
		[1] = {type=2,displayName="Scrap Shield",name="RumbleW",danger=1,slot=1},
	},
	["Sejuani"] = {
		[0] = {type=1,displayName="Arctic Assault",name="SejuaniQ",danger=2,slot=0},
	},
	["Shaco"] = {
		[0] = {type=1,displayName="Deceive",name="ShacoQ",range=400,danger=2,slot=0},
		[3] = {type=2,displayName="Hallucinate",name="ShacoR",danger=3,slot=3},
	},
	["Shen"] = {
		[2] = {type=1,displayName="Shadow Dash",name="ShenE",range=600,danger=2,slot=2},
	},
	["Shyvana"] = {
		[1] = {type=2,displayName="Burnout",name="ShyvanaW",danger=2,slot=1},
	},
	["Skarner"] = {
		[1] = {type=2,displayName="Crystalline Exoskeleton",name="SkarnerW",danger=2,slot=1},
	},
	["Sona"] = {
		[2] = {type=2,displayName="Song of Celerity",name="SonaE",danger=2,slot=2},
	},
	["Teemo"] = {
		[1] = {type=2,displayName="Move Quick",name="TeemoW",danger=2,slot=1},
	},
	["Tryndamere"] = {
		[2] = {type=1,displayName="Spinning Slash",name="TryndamereE",range=660,danger=2,slot=2},
	},
	["Udyr"] = {
		[2] = {type=2,displayName="Bear Stance",name="UdyrE",danger=1,slot=2},
	},
	["Vayne"] = {
		[0] = {type=1,displayName="Tumble",name="VayneQ",range=300,danger=1,slot=0},
	},
	["Vi"] = {
		[0] = {type=1,displayName="Vault Breaker",name="ViQ",range=250,danger=1,slot=0},
	},
	["Vladimir"] = {
		[1] = {type=2,displayName="Sanguine Pool",name="VladimirW",danger=2,slot=1},
	},
	["Volibear"] = {
		[0] = {type=2,displayName="Rolling Thunder",name="VolibearQ",danger=1,slot=0},
	},
	["Wukong"] = {
		[2] = {type=1,displayName="Nimbus Strike",name="WukongE",range=625,danger=1,slot=2},
	},
	["Xayah"] = {
		[3] = {type=2,displayName="Featherstorm",name="XayahR",danger=3,slot=3},
	},
	["Zed"] = {
		[3] = {type=4,displayName="Death Mark",name="ZedR",range=625,danger=3,slot=3},
	},
	["Zilean"] = {
		[2] = {type=3,displayName="Time Warp",name="ZileanE",danger=2,slot=2},
	},
}
end

function JustEvade:Dodge()
	if myHero.dead then return end
	for _,spell in pairs(self.DetectedSpells) do
		if EMenu.Main.Evade:Value() then
			if _G.JustEvade and self.SafePos ~= nil then
				if GetDistance(self.SafePos,myHero) > myHero.boundingRadius and self.Timer+EMenu.Misc.TE:Value() > GetGameTimer() then
					if EMenu.Misc.DD:Value() and self.DangerLvl <= 2 or EMenu.Misc.SD:Value() or EMenu.Spells[spell.name]["HP"..spell.name]:Value() < GetPercentHP(myHero) then return end
					if _G.DAC_Loaded then
						DAC:MovementEnabled(false)
						DAC:AttacksEnabled(false)
					elseif _G.AutoCarry_Loaded then
						DACR.movementEnabled = false
						DACR.attacksEnabled = false
					elseif _G.GoSWalkLoaded then
						_G.GoSWalk:EnableMovement(false)
						_G.GoSWalk:EnableAttack(false)
					elseif _G.IOW then
						IOW.movementEnabled = false
						IOW.attacksEnabled = false
					end
					BlockF7OrbWalk(true)
					BlockF7Dodge(true)
					BlockInput(true)
					MoveToXYZ(self.SafePos.x,self.SafePos.y,self.SafePos.z)
					if self.EvadeSpells[GetObjectName(myHero)] then
						for op = 0,3 do
							if self.EvadeSpells[GetObjectName(myHero)][op] then
								if EMenu.EvadeSpells[self.EvadeSpells[GetObjectName(myHero)][op].name]["US"..self.EvadeSpells[GetObjectName(myHero)][op].name]:Value() then
									if CanUseSpell(myHero, self.EvadeSpells[GetObjectName(myHero)][op].slot) == READY and self.DangerLvl >= EMenu.EvadeSpells[self.EvadeSpells[GetObjectName(myHero)][op].name]["Danger"..self.EvadeSpells[GetObjectName(myHero)][op].name]:Value() then
										if self.EvadeSpells[GetObjectName(myHero)][op].type == 1 then
											CastSkillShot(self.EvadeSpells[GetObjectName(myHero)][op].slot, self.SafePos)
										elseif self.EvadeSpells[GetObjectName(myHero)][op].type == 2 then
											CastSpell(self.EvadeSpells[GetObjectName(myHero)][op].slot)
										elseif self.EvadeSpells[GetObjectName(myHero)][op].type == 3 then
											CastTargetSpell(myHero, self.EvadeSpells[GetObjectName(myHero)][op].slot)
										elseif self.EvadeSpells[GetObjectName(myHero)][op].type == 4 then
											for _, enemy in pairs(GetEnemyHeroes()) do
												if ValidTarget(enemy, self.EvadeSpells[GetObjectName(myHero)][op].range) then
													CastTargetSpell(enemy, self.EvadeSpells[GetObjectName(myHero)][op].slot)
												end
											end
										end
									end
								end
							end
						end
					end
				end
				if self.DangerLvl == 3 then
					if GetItemSlot(myHero, 2420) > 0 and CanUseSpell(myHero, GetItemSlot(myHero, 2420)) == READY then
						if EMenu.EvadeSpells.Stopwatch.Use:Value() then
							CastSpell(GetItemSlot(myHero, 2420))
						end
					elseif GetItemSlot(myHero, 3157) > 0 and CanUseSpell(myHero, GetItemSlot(myHero, 3157)) == READY then
						if EMenu.EvadeSpells.Zhonya.Use:Value() then
							CastSpell(GetItemSlot(myHero, 3157))
						end
					elseif self.Flash and EMenu.EvadeSpells.Flash.Use:Value() then
						CastSkillShot(self.Flash, self.SafePos.x, self.SafePos.y, self.SafePos.z)
					end
				end
				return
			else
				DelayAction(function()
					_G.JustEvade = false
					if _G.DAC_Loaded then
						DAC:MovementEnabled(true)
						DAC:AttacksEnabled(true)
					elseif _G.AutoCarry_Loaded then
						DACR.movementEnabled = true
						DACR.attacksEnabled = true
					elseif _G.GoSWalkLoaded then
						_G.GoSWalk:EnableMovement(true)
						_G.GoSWalk:EnableAttack(true)
					elseif _G.IOW then
						IOW.movementEnabled = true
						IOW.attacksEnabled = true
					end
					BlockF7OrbWalk(false)
					BlockF7Dodge(false)
					BlockInput(false)
				end, EMenu.Misc.DE:Value())
			end
		end
		if EMenu.Spells[spell.name]["Dodge"..spell.name]:Value() then
			local FE = EMenu.Spells[spell.name]["FE"..spell.name]:Value()
			local speed = self.Spells[spell.name].speed
			local range = self.Spells[spell.name].range
			local delay = self.Spells[spell.name].delay
			local radius = self.Spells[spell.name].radius
			local type = self.Spells[spell.name].type
			local danger = EMenu.Spells[spell.name]["Danger"..spell.name]:Value()
			local collision = self.Spells[spell.name].collision
			local b = myHero.boundingRadius
			if type == "linear" or type == "threeway" then
				if speed and speed ~= MathHuge then
					if spell.startTime+range/speed+delay+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						local p = spell.startPos+Vector(Vector(spell.endPos)-spell.startPos):normalized()*(speed*(GetGameTimer()-delay-spell.startTime)-radius)
						local BPos = VectorPointProjectionOnLineSegment(Vector(p),spell.endPos,Vector(myHero))
						if BPos and GetDistance(myHero,BPos) < (radius+b+10+EMenu.Misc.ER:Value())then
							_G.JustEvade = true
							if self.ReCalc then
								self.SafePos = self:Pathfinding(spell.startPos,spell.endPos,radius,radius2,b,BPos,FE,type)
								if not EMenu.Main.RP:Value() then
									self.ReCalc = false
								end
							end
							self.Timer = spell.startTime+range/speed+delay+self:AdditionalTime(spell.source, spell.slot)
							self.DangerLvl = danger
						end
					else
						self.SafePos = nil
						TableRemove(self.DetectedSpells, _)
					end
				elseif speed and speed == MathHuge then
					if spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						if GetDistance(myHero,spell.endPos) < radius+b+EMenu.Misc.ER:Value() then
							_G.JustEvade = true
							if self.ReCalc then
								self.SafePos = self:Pathfinding(spell.startPos,spell.endPos,radius,radius2,b,BPos,FE,type)
								if not EMenu.Main.RP:Value() then
									self.ReCalc = false
								end
							end
							self.Timer = spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot)
							self.DangerLvl = danger
						end
					else
						self.SafePos = nil
						TableRemove(self.DetectedSpells, _)
					end
				end
			end
			if type == "circular" then
				if speed and speed ~= MathHuge then
					if spell.startTime+range/speed+delay+0.5+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						if GetDistance(myHero,spell.endPos) < (radius+b+EMenu.Misc.ER:Value()) then
							_G.JustEvade = true
							if self.ReCalc then
								self.SafePos = self:Pathfinding(spell.startPos,spell.endPos,radius,radius2,b,BPos,FE,type)
								if not EMenu.Main.RP:Value() then
									self.ReCalc = false
								end
							end
							self.Timer = spell.startTime+range/speed+delay+self:AdditionalTime(spell.source, spell.slot)
							self.DangerLvl = danger
						end
					else
						self.SafePos = nil
						TableRemove(self.DetectedSpells, _)
					end
				elseif speed and speed == MathHuge then
					if spell.startTime+delay+0.5+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						if GetDistance(myHero,spell.endPos) < (radius+b+EMenu.Misc.ER:Value()) then
							_G.JustEvade = true
							if self.ReCalc then
								self.SafePos = self:Pathfinding(spell.startPos,spell.endPos,radius,radius2,b,BPos,FE,type)
								if not EMenu.Main.RP:Value() then
									self.ReCalc = false
								end
							end
							self.Timer = spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot)
							self.DangerLvl = danger
						end
					else
						self.SafePos = nil
						TableRemove(self.DetectedSpells, _)
					end
				end
			end
			if type == "rectangular" then
				local radius2 = self.Spells[spell.name].radius2
				if speed then
					if spell.startTime+delay+0.5+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						local StartPosition = Vector(spell.endPos)-(Vector(spell.endPos)-Vector(spell.startPos)):normalized():perpendicular()*(radius2 or 400)
						local EndPosition = Vector(spell.endPos)+(Vector(spell.endPos)-Vector(spell.startPos)):normalized():perpendicular()*(radius2 or 400)
						if GetDistance(StartPosition) < (range+b+EMenu.Misc.ER:Value()) and GetDistance(EndPosition) < (range+b+EMenu.Misc.ER:Value()) then
							local BPos = VectorPointProjectionOnLineSegment(StartPosition,EndPosition,Vector(myHero))
							if BPos and GetDistance(myHero,BPos) < (radius+b+EMenu.Misc.ER:Value()) then
								_G.JustEvade = true
								if self.ReCalc then
									self.SafePos = self:Pathfinding(spell.startPos,spell.endPos,radius,radius2,b,BPos,FE,type)
									if not EMenu.Main.RP:Value() then
										self.ReCalc = false
									end
								end
								self.Timer = spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot)
								self.DangerLvl = danger
							end
						end
					else
						self.SafePos = nil
						TableRemove(self.DetectedSpells, _)
					end
				end
			end
			if type == "conic" then
				local angle = self.Spells[spell.name].angle
				if speed and speed ~= MathHuge then
					if spell.startTime+range/speed+delay+0.25+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						if GetDistance(spell.startPos) < (range+b) and GetDistance(spell.endPos) < (range+b) then
							local BPos = VectorPointProjectionOnLineSegment(spell.startPos,spell.endPos,Vector(myHero))
							if BPos and GetDistance(myHero,BPos) < (radius+b+EMenu.Misc.ER:Value()) then
								_G.JustEvade = true
								if self.ReCalc then
									self.SafePos = self:Pathfinding(spell.startPos,spell.endPos,radius,radius2,b,BPos,FE,type)
									if not EMenu.Main.RP:Value() then
										self.ReCalc = false
									end
								end
								self.Timer = spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot)
								self.DangerLvl = danger
							end
						end
					else
						self.SafePos = nil
						TableRemove(self.DetectedSpells, _)
					end
				elseif speed and speed == MathHuge then
					if spell.startTime+delay+0.5+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						if GetDistance(spell.startPos) < (range+b) and GetDistance(spell.endPos) < (range+b) then
							local BPos = VectorPointProjectionOnLineSegment(spell.startPos,spell.endPos,Vector(myHero))
							if BPos and GetDistance(myHero,BPos) < (radius+b+EMenu.Misc.ER:Value()) then
								_G.JustEvade = true
								if self.ReCalc then
									self.SafePos = self:Pathfinding(spell.startPos,spell.endPos,radius,radius2,b,BPos,FE,type)
									if not EMenu.Main.RP:Value() then
										self.ReCalc = false
									end
								end
								self.Timer = spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot)
								self.DangerLvl = danger
							end
						end
					else
						self.SafePos = nil
						TableRemove(self.DetectedSpells, _)
					end
				end
			end
		end
	end
end

function JustEvade:Pathfinding(startPos, endPos, radius, radius2, boundingRadius, bPos, FE, type)
	if myHero.dead then return end
	if FE then
		if type == "linear" or type == "threeway" then
			local DPos = Vector(VectorIntersection(startPos,endPos,myHero.pos+(Vector(startPos)-Vector(endPos)):perpendicular(),myHero.pos).x,endPos.y,VectorIntersection(startPos,endPos,myHero.pos+(Vector(startPos)-Vector(endPos)):perpendicular(),myHero.pos).y)
			if GetDistance(GetOrigin(myHero)+Vector(startPos-endPos):perpendicular(),DPos) >= GetDistance(GetOrigin(myHero)+Vector(startPos-endPos):perpendicular2(),DPos) then
				local Path = DPos+Vector(startPos-endPos):perpendicular():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
				if not MapPosition:inWall(Path) then
					local Pos1 = DPos+Vector(startPos-endPos):perpendicular():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos1
				else
					local Pos2 = DPos+Vector(startPos-endPos):perpendicular2():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos2
				end
			else
				local Path = DPos+Vector(startPos-endPos):perpendicular2():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
				if not MapPosition:inWall(Path) then
					local Pos3 = DPos+Vector(startPos-endPos):perpendicular2():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos3
				else
					local Pos4 = DPos+Vector(startPos-endPos):perpendicular():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos4
				end
			end
		elseif type == "circular" then
			local Path = Vector(endPos)+(GetOrigin(myHero)-Vector(endPos)):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			if not MapPosition:inWall(Path) then
				local Pos1 = Vector(endPos)+(GetOrigin(myHero)-Vector(endPos)):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
				return Pos1
			else
				local Pos2 = endPos+Vector(Path-endPos):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
				return Pos2
			end
		elseif type == "rectangular" then
			local MPos = Vector(myHero)+Vector(Vector(GetMousePos())-myHero.pos):normalized()*(radius+boundingRadius)
			local StartPosition = Vector(endPos)-(Vector(endPos)-Vector(startPos)):normalized():perpendicular()*(radius2 or 400)
			local EndPosition = Vector(endPos)+(Vector(endPos)-Vector(startPos)):normalized():perpendicular()*(radius2 or 400)
			local Path = Vector(MPos)+Vector(StartPosition-EndPosition):normalized():perpendicular()*(radius+boundingRadius)
			if not MapPosition:inWall(Path) then
				local Pos1 = Vector(myHero)+Vector(StartPosition-EndPosition):normalized():perpendicular()*(radius+boundingRadius)
				return Pos1
			else
				local Pos2 = Vector(myHero)+Vector(StartPosition-EndPosition):normalized():perpendicular2()*(radius+boundingRadius)
				return Pos2
			end
		elseif type == "conic" then
			local DPos = Vector(VectorIntersection(startPos,endPos,myHero.pos+(Vector(startPos)-Vector(endPos)):perpendicular(),myHero.pos).x,endPos.y,VectorIntersection(startPos,endPos,myHero.pos+(Vector(startPos)-Vector(endPos)):perpendicular(),myHero.pos).y)
			if GetDistance(GetOrigin(myHero)+Vector(startPos-endPos):perpendicular(),DPos) >= GetDistance(GetOrigin(myHero)+Vector(startPos-endPos):perpendicular2(),DPos) then
				local Path = DPos+Vector(startPos-endPos):perpendicular():normalized()*(radius+boundingRadius)
				if not MapPosition:inWall(Path) then
					local Pos1 = DPos+Vector(startPos-endPos):perpendicular():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos1
				else
					local Pos2 = DPos+Vector(startPos-endPos):perpendicular2():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos2
				end
			else
				local Path = DPos+Vector(startPos-endPos):perpendicular2():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
				if not MapPosition:inWall(Path) then
					local Pos3 = DPos+Vector(startPos-endPos):perpendicular2():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos3
				else
					local Pos4 = DPos+Vector(startPos-endPos):perpendicular():normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos4
				end
			end
		end
	else
		local MPos = Vector(myHero)+Vector(Vector(GetMousePos())-myHero.pos):normalized()
		if type == "linear" or type == "threeway" then
			local Path1 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			local Path2 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			if GetDistance(Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2(),bPos) > GetDistance(Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular(),bPos) then
				if not MapPosition:inWall(Path2) then
					local Pos1 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos1
				else
					local Pos2 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos2
				end
			else
				if not MapPosition:inWall(Path1) then
					local Pos3 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos3
				else
					local Pos4 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos4
				end
			end
		elseif type == "circular" then
			local Path1 = Vector(endPos)+(GetOrigin(myHero)-Vector(endPos)):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			local Path2 = Vector(endPos)+(Vector(MPos)-Vector(endPos)):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			if MPos and GetDistance(MPos, Path1) > GetDistance(MPos, Path2) then
				if not MapPosition:inWall(Path2) then
					local Pos1 = Vector(endPos)+(Vector(MPos)-Vector(endPos)):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos1
				else
					local Pos2 = endPos+Vector(Path2-endPos):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos2
				end
			else
				if not MapPosition:inWall(Path1) then
					local Pos3 = Vector(endPos)+(GetOrigin(myHero)-Vector(endPos)):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos3
				else
					local Pos4 = endPos+Vector(Path1-endPos):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos4
				end
			end
		elseif type == "rectangular" then
			local StartPosition = Vector(endPos)-(Vector(endPos)-Vector(startPos)):normalized():perpendicular()*(radius2 or 400)
			local EndPosition = Vector(endPos)+(Vector(endPos)-Vector(startPos)):normalized():perpendicular()*(radius2 or 400)
			local Path1 = Vector(MPos)+Vector(StartPosition-EndPosition):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			local Path2 = Vector(MPos)+Vector(StartPosition-EndPosition):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			if GetDistance(Vector(MPos)+Vector(StartPosition-EndPosition):normalized():perpendicular2(),bPos) > GetDistance(Vector(MPos)+Vector(StartPosition-EndPosition):normalized():perpendicular(),bPos) then
				if not MapPosition:inWall(Path2) then
					local Pos1 = Vector(MPos)+Vector(StartPosition-EndPosition):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos1
				else
					local Pos2 = endPos+Vector(Path1-endPos):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos2
				end
			else
				if not MapPosition:inWall(Path1) then
					local Pos3 = Vector(MPos)+Vector(StartPosition-EndPosition):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos3
				else
					local Pos4 = endPos+Vector(Path1-endPos):normalized()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos4
				end
			end
		elseif type == "conic" then
			local Path1 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			local Path2 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
			if GetDistance(Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2(),bPos) > GetDistance(Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular(),bPos) then
				if not MapPosition:inWall(Path2) then
					local Pos1 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos1
				else
					local Pos2 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos2
				end
			else
				if not MapPosition:inWall(Path1) then
					local Pos3 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos3
				else
					local Pos4 = Vector(MPos)+Vector(Vector(MPos)-endPos):normalized():perpendicular2()*(radius+boundingRadius+EMenu.Misc.ER:Value())
					return Pos4
				end
			end
		end
	end
end

function JustEvade:Draw()
	if EMenu.Main.Status:Value() then
		if EMenu.Main.Evade:Value() then
			DrawText("Evade: ON", 15, myHero.pos2D.x-30, myHero.pos2D.y+30, ARGB(255,255,255,255))
		else
			DrawText("Evade: OFF", 15, myHero.pos2D.x-30, myHero.pos2D.y+30, ARGB(255,255,255,255))
		end
	end
	if EMenu.Main.Evade:Value() then
		if _G.JustEvade and self.SafePos and EMenu.Main.SafePos:Value() then
			DrawCircle(self.SafePos.x,self.SafePos.y,self.SafePos.z,myHero.boundingRadius,2,32,ARGB(255,255,255,255))
		end
		for _,spell in pairs(self.DetectedSpells) do
			if EMenu.Spells[spell.name]["Draw"..spell.name]:Value() then
				local speed = self.Spells[spell.name].speed
				local range = self.Spells[spell.name].range
				local delay = self.Spells[spell.name].delay
				local radius = self.Spells[spell.name].radius
				local type = self.Spells[spell.name].type
				local collision = self.Spells[spell.name].collision
				if type == "linear" then
					if speed ~= MathHuge then
						if spell.startTime+range/speed+delay+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
							local pos = spell.startPos+Vector(Vector(spell.endPos)-spell.startPos):normalized()*(speed*(GetGameTimer()-delay-spell.startTime)-radius)
							self:DrawRectangleOutline(spell.startPos, spell.endPos, (spell.startTime+delay < GetGameTimer() and pos or nil), radius)
						else
							TableRemove(self.DetectedSpells, _)
						end
					elseif speed == MathHuge then
						if spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
							self:DrawRectangleOutline(spell.startPos, spell.endPos, nil, radius)
						else
							TableRemove(self.DetectedSpells, _)
						end
					end
				end
				if type == "threeway" then
					local angle = self.Spells[spell.name].angle
					local endPos1 = self:RotateVector2D(spell.endPos, spell.startPos, MathRad(angle))
					local endPos2 = self:RotateVector2D(spell.endPos, spell.startPos, MathRad(-angle))
					if spell.startTime+range/speed+delay+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						local pos = spell.startPos+Vector(Vector(spell.endPos)-spell.startPos):normalized()*(speed*(GetGameTimer()-delay-spell.startTime)-radius)
						local pos1 = spell.startPos+Vector(endPos1-spell.startPos):normalized()*(speed*(GetGameTimer()-delay-spell.startTime)-radius)
						local pos2 = spell.startPos+Vector(endPos2-spell.startPos):normalized()*(speed*(GetGameTimer()-delay-spell.startTime)-radius)
						self:DrawRectangleOutline(spell.startPos, spell.endPos, (spell.startTime+delay < GetGameTimer() and pos or nil), radius)
						self:DrawRectangleOutline(spell.startPos, endPos1, (spell.startTime+delay < GetGameTimer() and pos1 or nil), radius)
						self:DrawRectangleOutline(spell.startPos, endPos2, (spell.startTime+delay < GetGameTimer() and pos2 or nil), radius)
					else
						TableRemove(self.DetectedSpells, _)
					end
				end
				if type == "circular" then
					if speed ~= MathHuge then
						if spell.startTime+range/speed+delay+0.5+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
							DrawCircle(spell.endPos.x,spell.endPos.y,spell.endPos.z,radius+EMenu.Misc.ER:Value(),2,32,ARGB(255,255,255,255))
							DrawCircle(spell.endPos.x,spell.endPos.y,spell.endPos.z,radius,2,32,ARGB(255,255,255,255))
						else
							TableRemove(self.DetectedSpells, _)
						end
					elseif speed == MathHuge then
						if spell.startTime+delay+0.5+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
							DrawCircle(spell.endPos.x,spell.endPos.y,spell.endPos.z,radius+EMenu.Misc.ER:Value(),2,32,ARGB(255,255,255,255))
							DrawCircle(spell.endPos.x,spell.endPos.y,spell.endPos.z,radius,2,32,ARGB(255,255,255,255))
						else
							TableRemove(self.DetectedSpells, _)
						end
					end
				end
				if type == "conic" then
					local angle = self.Spells[spell.name].angle
					local EndPosition = Vector(spell.startPos)+Vector(Vector(spell.endPos)-spell.startPos):normalized()*range
					if speed ~= MathHuge then
						if spell.startTime+range/speed+delay+0.25+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
							self:DrawCone(spell.startPos, Vector(EndPosition), angle or 40,1,ARGB(255,255,255,255))
						else
							TableRemove(self.DetectedSpells, _)
						end
					elseif speed == MathHuge then
						if spell.startTime+delay+0.25+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
							self:DrawCone(spell.startPos, Vector(EndPosition), angle or 40,1,ARGB(255,255,255,255))
						else
							TableRemove(self.DetectedSpells, _)
						end
					end
				end
				if type == "rectangular" then
					local radius2 = self.Spells[spell.name].radius2
					if spell.startTime+delay+0.5+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						self:DrawRectangle(spell.startPos, spell.endPos, radius+myHero.boundingRadius, radius2, 1, ARGB(255,255,255,255))
						self:DrawRectangle(spell.startPos, spell.endPos, radius+myHero.boundingRadius+EMenu.Misc.ER:Value(), radius2+EMenu.Misc.ER:Value(), 1, ARGB(255,255,255,255))
					else
						TableRemove(self.DetectedSpells, _)
					end
				end
				if type == "annular" then
					if spell.startTime+delay+self:AdditionalTime(spell.source, spell.slot) > GetGameTimer() then
						DrawCircle(spell.endPos.x,spell.endPos.y,spell.endPos.z,radius,2,5,ARGB(255,255,255,255))
						DrawCircle(spell.endPos.x,spell.endPos.y,spell.endPos.z,radius/1.5,2,5,ARGB(255,255,255,255))
					else
						TableRemove(self.DetectedSpells, _)
					end
				end
			end
		end
	end
end

function JustEvade:RotateVector2D(v, n, theta)
	x,y = v.x, v.z
	x_origin, y_origin = n.x, n.z
	local cs = MathCos(theta)
	local sn = MathSin(theta)
	local translated_x = x - x_origin
	local translated_y = y - y_origin
	local result_x = translated_x * cs - translated_y * sn
	local result_y = translated_x * sn + translated_y * cs
	result_x = result_x + x_origin
	result_y = result_y + y_origin
	return Vector(result_x, v.y, result_y)
end

function JustEvade:DrawRectangleOutline(startPos, endPos, pos, radius)
	if EMenu.Misc.ER:Value() > 0 then
		local z1 = startPos+Vector(Vector(endPos)-startPos):perpendicular():normalized()*(radius+EMenu.Misc.ER:Value())
		local z2 = startPos+Vector(Vector(endPos)-startPos):perpendicular2():normalized()*(radius+EMenu.Misc.ER:Value())
		local z3 = endPos+Vector(Vector(startPos)-endPos):perpendicular():normalized()*(radius+EMenu.Misc.ER:Value())
		local z4 = endPos+Vector(Vector(startPos)-endPos):perpendicular2():normalized()*(radius+EMenu.Misc.ER:Value())
		local c1 = WorldToScreen(0,z1)
		local c2 = WorldToScreen(0,z2)
		local c3 = WorldToScreen(0,z3)
		local c4 = WorldToScreen(0,z4)
		DrawLine(c1.x,c1.y,c2.x,c2.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
		DrawLine(c2.x,c2.y,c3.x,c3.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
		DrawLine(c3.x,c3.y,c4.x,c4.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
		DrawLine(c1.x,c1.y,c4.x,c4.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
	end
	local z1 = startPos+Vector(Vector(endPos)-startPos):perpendicular():normalized()*radius
	local z2 = startPos+Vector(Vector(endPos)-startPos):perpendicular2():normalized()*radius
	local z3 = endPos+Vector(Vector(startPos)-endPos):perpendicular():normalized()*radius
	local z4 = endPos+Vector(Vector(startPos)-endPos):perpendicular2():normalized()*radius
	local c1 = WorldToScreen(0,z1)
	local c2 = WorldToScreen(0,z2)
	local c3 = WorldToScreen(0,z3)
	local c4 = WorldToScreen(0,z4)
	DrawLine(c1.x,c1.y,c2.x,c2.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
	DrawLine(c2.x,c2.y,c3.x,c3.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
	DrawLine(c3.x,c3.y,c4.x,c4.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
	DrawLine(c1.x,c1.y,c4.x,c4.y,MathCeil(radius/100),ARGB(255, 255, 255, 255))
	if pos then
		DrawCircle(pos.x,pos.y,pos.z,radius,1,32,ARGB(255,255,255,255))
	end
end

function JustEvade:DrawCone(v1, v2, angle, radius, color)
	angle = angle*MathPi/180
	v1 = Vector(v1)
	v2 = Vector(v2)
	local a1 = Vector(Vector(v2)-Vector(v1)):rotated(0,-angle*.5,0)
	local a2 = nil
	DrawLine3D(v1.x,v1.y,v1.z,v1.x+a1.x,v1.y+a1.y,v1.z+a1.z,radius,color)
	for i = -angle*.5,angle*.5,angle*.1 do
		a2 = Vector(v2-v1):rotated(0,i,0)
		DrawLine3D(v1.x+a2.x,v1.y+a2.y,v1.z+a2.z,v1.x+a1.x,v1.y+a1.y,v1.z+a1.z,radius,color)
		a1 = a2
	end
	DrawLine3D(v1.x,v1.y,v1.z,v1.x+a1.x,v1.y+a1.y,v1.z+a1.z,radius,color)
end

function JustEvade:DrawRectangle(startPos, endPos, radius, radius2, t, c)
    local spos = Vector(endPos) - (Vector(endPos) - Vector(startPos)):normalized():perpendicular() * (radius2 or 400)
    local epos = Vector(endPos) + (Vector(endPos) - Vector(startPos)):normalized():perpendicular() * (radius2 or 400)
	local ePos = Vector(epos)
	local sPos = Vector(spos)
	local dVec = Vector(ePos - sPos)
	local sVec = dVec:normalized():perpendicular()*((radius)*.5)
	local TopD1 = WorldToScreen(0,sPos-sVec)
	local TopD2 = WorldToScreen(0,sPos+sVec)
	local BotD1 = WorldToScreen(0,ePos-sVec)
	local BotD2 = WorldToScreen(0,ePos+sVec)
	DrawLine(TopD1.x,TopD1.y,TopD2.x,TopD2.y,t,c)
	DrawLine(TopD1.x,TopD1.y,BotD1.x,BotD1.y,t,c)
	DrawLine(TopD2.x,TopD2.y,BotD2.x,BotD2.y,t,c)
	DrawLine(BotD1.x,BotD1.y,BotD2.x,BotD2.y,t,c)
end

function JustEvade:AdditionalTime(unit, spell)
	if unit.charName == "Caitlyn" and spell == 1 then return 1 end
	if unit.charName == "Gangplank" and spell == 3 then return 2 end
	if unit.charName == "Gragas" and spell == 0 then return 1 end
	if unit.charName == "Graves" and spell == 0 then return 1 end
	if unit.charName == "Irelia" and spell == 3 then return 1 end
	if unit.charName == "Jhin" and spell == 2 then return 1 end
	if unit.charName == "Jinx" and spell == 2 then return 1 end
	if unit.charName == "Katarina" and spell == 3 then return 2.5 end
	if unit.charName == "MissFortune" and spell == 3 then return 3 end
	if unit.charName == "Morgana" and spell == 1 then return 1 end
	if unit.charName == "Nasus" and spell == 2 then return 1 end
	if unit.charName == "Nidalee" and spell == 1 then return 1 end
	if unit.charName == "Nunu" and spell == 3 then return 3 end
	if unit.charName == "Rakan" and spell == 1 then return 1 end
	if unit.charName == "Rumble" and spell == 3 then return 5 end
	if unit.charName == "Singed" and spell == 1 then return 1 end
	if unit.charName == "Sion" and spell == 0 then return 2 end
	if unit.charName == "Soraka" and spell == 2 then return 1 end
	if unit.charName == "Swain" and spell == 1 then return 1.5 end
	if unit.charName == "Teemo" and spell == 3 then return 1 end
	if unit.charName == "Veigar" and spell == 2 then return 3.5 end
	if unit.charName == "Zac" and spell == 3 then return 2.5 end
	if unit.charName == "Ziggs" and spell == 1 then return 1 end
	if unit.charName == "Ziggs" and spell == 2 then return 1 end
	if unit.charName == "Zilean" and spell == 0 then return 1 end
	return 0
end

function JustEvade:CalculateEndPos(startPos, placementPos, unitPos, radius, range, collision, type)
	if type == "linear" or type == "threeway" or type == "conic" then
		if collision then
			for _,minion in pairs(minionManager.objects) do
				if minion and minion.alive and minion.team == MINION_ALLY and GetDistance(minion.pos, startPos) < range then
					local Collision = VectorPointProjectionOnLineSegment(startPos, placementPos, Vector(minion))
					if Collision and GetDistance(Collision, minion.pos) < (radius+minion.boundingRadius) then
						local range2 = GetDistance(startPos, Collision)
						local endPos = startPos-Vector(startPos-placementPos):normalized()*range2
						return endPos
					else
						local endPos = startPos-Vector(startPos-placementPos):normalized()*range
						return endPos
					end
				else
					local endPos = startPos-Vector(startPos-placementPos):normalized()*range
					return endPos
				end
			end
		else
			local endPos = startPos-Vector(startPos-placementPos):normalized()*range
			return endPos
		end
	elseif type == "circular" or type == "rectangular" or type == "annular" then
		if range > 0 then
			if GetDistance(unitPos, placementPos) > range then
				local endPos = startPos-Vector(startPos-placementPos):normalized()*range
				return endPos
			else
				local endPos = placementPos
				return endPos
			end
		else
			local endPos = unitPos
			return endPos
		end
	end
end

function JustEvade:Detect(unit, spell)
	if unit and spell and unit.team ~= myHero.team then
		if self.Spells[spell.name] then
			self.ReCalc = true
			local startPos = Vector(spell.startPos)
			local placementPos = Vector(spell.endPos)
			local unitPos = Vector(unit.pos)
			local SpellDet = self.Spells[spell.name]
			local SRadius = SpellDet.radius
			local SRange = SpellDet.range
			local SCol = SpellDet.collision
			local SType = SpellDet.type
			local endPos = self:CalculateEndPos(startPos, placementPos, unitPos, SRadius, SRange, SCol, SType)
			s = {slot = SpellDet.slot, source = unit, startTime = GetGameTimer(), startPos = Vector(spell.startPos), endPos = Vector(endPos), name = spell.name}
			TableInsert(self.DetectedSpells, s)
		end
	end
	if unit == myHero and _G.JustEvade then
		BlockCast()
	end
end
