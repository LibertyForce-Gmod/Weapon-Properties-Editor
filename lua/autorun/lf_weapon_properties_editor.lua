-- Weapon Properties Editor
-- by LibertyForce http://steamcommunity.com/id/libertyforce


if SERVER then


AddCSLuaFile()
local von = include( "lf_shared/von_1_3_4.lua" )

util.AddNetworkString( "lf_weapon_properties_editor" )

local Weapons_Edited = {}
local Weapons_Replaced = {}
local Weapons_TempActive = {}
local dir = "lf_weapon_properties_editor"
local dir_presets = dir.."/presets_v1_0"

if not file.Exists( dir, "DATA" ) then file.CreateDir( dir ) end
if not file.Exists( dir_presets, "DATA" ) then file.CreateDir( dir_presets ) end


local function netmsg( id )
	net.Start( "lf_weapon_properties_editor" )
	net.WriteUInt( id, 4 )
end

local function Notify( ply, id )
	netmsg( 0 )
	net.WriteUInt( id, 3 )
	net.Send( ply )
end

local function ApplyChanges( weapon )
	
	local tbl = weapons.GetStored( weapon.Class )
	if not istable( tbl ) then return end
	
	Weapons_Edited[weapon.Class] = weapon
	
	if istable( tbl.Primary ) and istable( weapon.Primary ) then
		if tbl.Primary.Ammo then tbl.Primary.Ammo = weapon.Primary.Ammo end
		if tbl.Primary.Damage then tbl.Primary.Damage = weapon.Primary.Damage end
		if tbl.Primary.ClipSize then tbl.Primary.ClipSize = weapon.Primary.ClipSize end
		if tbl.Primary.DefaultClip then tbl.Primary.DefaultClip = weapon.Primary.DefaultClip end
	end
	if istable( tbl.Secondary ) and istable( weapon.Secondary ) then
		if tbl.Secondary.Ammo then tbl.Secondary.Ammo = weapon.Secondary.Ammo end
		if tbl.Secondary.Damage then tbl.Secondary.Damage = weapon.Secondary.Damage end
		if tbl.Secondary.ClipSize then tbl.Secondary.ClipSize = weapon.Secondary.ClipSize end
		if tbl.Secondary.DefaultClip then tbl.Secondary.DefaultClip = weapon.Secondary.DefaultClip end
	end
	if tbl.Slot then tbl.Slot = weapon.Slot end
	if tbl.SlotPos then tbl.SlotPos = weapon.SlotPos end
	if istable( tbl.FireModes ) and istable( weapon.FireModes ) then
		if tbl.FireModes[1] then tbl.FireModes[1] = weapon.FireModes[1] end
		if tbl.FireModes[2] then tbl.FireModes[2] = weapon.FireModes[2] end
		if tbl.FireModes[3] then tbl.FireModes[3] = weapon.FireModes[3] end
	end
	
	netmsg( 1 )
	net.WriteTable( weapon )
	net.Broadcast()
	
end

local function RespawnWeapon( weapon )
	
	for _, ply in pairs( player.GetAll() ) do
		if ply:HasWeapon( weapon ) then
			local ammo1 = ply:GetWeapon( weapon ):Clip1()
			local ammo2 = ply:GetWeapon( weapon ):Clip2()
			ply:StripWeapon( weapon )
			
			local wep_ent = ply:Give( weapon, true )
			local maxammo1 = wep_ent:GetMaxClip1()
			local maxammo2 = wep_ent:GetMaxClip2()
			if ammo1 > maxammo1 then ammo1 = maxammo1 end
			if ammo2 > maxammo2 then ammo2 = maxammo2 end
			wep_ent:SetClip1( ammo1 )
			wep_ent:SetClip2( ammo2 )
		end
	end
	
end


local function GetPresets( ply )
	
	local files = file.Find( dir_presets.."/*.txt", "DATA" )
	if not istable( files ) then return end
	
	netmsg( 3 )
	net.WriteTable( files )
	net.Send( ply )
	
end

local function SavePreset( weapon_class, ply )
	
	if istable( Weapons_Edited[weapon_class] ) then
		file.Write( dir_presets.."/"..tostring( weapon_class )..".txt", von.serialize( Weapons_Edited[weapon_class] ) )
		Notify( ply, 1 )
	else
		Notify( ply, 2 )
	end
	
end

local function DeletePreset( filename, ply )
	
	if file.Exists( dir_presets.."/"..filename..".txt", "DATA" ) then
		file.Delete( dir_presets.."/"..filename..".txt" )
	end
	
	GetPresets( ply )
	
end

local function GetReplacements( ply )
	
	if not istable( Weapons_Replaced ) then return end
	
	netmsg( 6 )
	net.WriteTable( Weapons_Replaced )
	net.Send( ply )
	
end

local function SaveReplacement( weapon, value, ply )
	
	if not istable( Weapons_Replaced ) then return end
	if weapon == value or Weapons_Replaced[value] then -- Prevents loops
		Weapons_Replaced[weapon] = nil
		Notify( ply, 3 )
		return
	end
	Weapons_Replaced[weapon] = value
	
	file.Write( dir.."/replacements.txt", von.serialize( Weapons_Replaced ) )
	GetReplacements( ply )
	
end

local function DeleteReplacement( weapon, ply )
	
	if not istable( Weapons_Replaced ) then return end
	Weapons_Replaced[weapon] = nil
	
	file.Write( dir.."/replacements.txt", von.serialize( Weapons_Replaced ) )
	if ply then GetReplacements( ply ) end
	
end

local function LoadFiles()
	
	if file.Exists( dir.."/replacements.txt", "DATA" ) then
		Weapons_Replaced = von.deserialize( file.Read( dir.."/replacements.txt", "DATA" ) ) or {}
	end
	
	local files = file.Find( dir_presets.."/*.txt", "DATA" )
	if not istable( files ) then return end
	for _, filename in pairs( files ) do
		local weapon_class = string.TrimRight( filename, ".txt" )
		local weapon = von.deserialize( file.Read( dir_presets.."/"..tostring( filename ), "DATA" ) )
		
		if not istable( weapon ) then continue end
		if weapon.Class ~= weapon_class then continue end
		if not istable( weapon.Primary ) or not istable( weapon.Secondary ) or not istable( weapon.FireModes ) then continue end
		
		ApplyChanges( weapon )
	end
	files = nil
	
end
hook.Add( "InitPostEntity", "lf_weapon_properties_editor_init", LoadFiles )
if player.GetCount() > 0 then LoadFiles() end -- Debug (for lua refresh)


net.Receive("lf_weapon_properties_editor", function( len, ply )
	
	if not ply:IsSuperAdmin() then return end
	local func = net.ReadUInt( 4 )
	
	if func == 0 then -- Player Notifications
		--
	elseif func == 1 then -- Apply weapon changes to server and clients
		ApplyChanges( net.ReadTable() )
		Notify( ply, 0 )
	elseif func == 2 then -- Saving Presets
		SavePreset( net.ReadString(), ply )
	elseif func == 3 then -- Getting Presets List
		GetPresets( ply )
	elseif func == 4 then -- Deleting Presets
		DeletePreset( net.ReadString(), ply )
	elseif func == 5 then -- Saving Replacements
		SaveReplacement( net.ReadString(), net.ReadString(), ply )
	elseif func == 6 then -- Getting Replacements
		GetReplacements( ply )
	elseif func == 7 then -- Deleting Replacements
		DeleteReplacement( net.ReadString(), ply )
	elseif func == 8 then -- Refresh weapon entities
		RespawnWeapon( net.ReadString() )
	end
	
end )


hook.Add( "PlayerAuthed", "lf_weapon_properties_editor_authed", function( ply )
	for k, weapon in pairs( Weapons_Edited ) do
		netmsg( 1 )
		net.WriteTable( weapon )
		net.Send( ply )
	end
end )

hook.Add( "PlayerCanPickupWeapon", "lf_weapon_properties_editor_pickup", function( ply, wep_ent )
	local wep_ent = wep_ent
	local wep_class = wep_ent:GetClass()
	if Weapons_Replaced[wep_class] then
		if not Weapons_TempActive[wep_ent] then -- Prevents running more then once per entity
			Weapons_TempActive[wep_ent] = true
			timer.Simple( 2, function() Weapons_TempActive[wep_ent] = nil end )
			wep_ent:Remove()
			
			if Weapons_Replaced[Weapons_Replaced[wep_class]] then return false end -- Prevents loops
			
			local weapon = ply:GetWeapon( Weapons_Replaced[wep_class] )
					
			if Weapons_Replaced[wep_class] ~= "" and not IsValid( weapon ) then
				weapon = ply:Give( Weapons_Replaced[wep_class], true )
				if IsValid( weapon ) and not weapon:IsWeapon() then
					weapon:Remove()
					DeleteReplacement( wep_class )
				elseif IsValid( weapon ) then
					weapon:SetClip1( weapon:GetMaxClip1() )
					weapon:SetClip2( 0 )
				end
			else
				if not IsValid( weapon ) then weapon = wep_ent end
				local clip = weapon:GetMaxClip1()
				if clip <= 0 then clip = 1 end
				local ammo = game.GetAmmoName( weapon:GetPrimaryAmmoType() )
				if ammo then ply:GiveAmmo( clip, ammo ) end
			end
		end
		return false
	end
end )


end

-----------------------------------------------------------------------------------------------------------------------------------------------------

if CLIENT then


local Version = "1.0"
local Menu = { Main = {}, Editor = {}, PresetList = {}, Replacements = {} }

local default_ammo_types = {
	"none",
	"Pistol",
	"357",
	"SMG1",
	"AR2",
	"Buckshot",
	"XBowBolt",
	"Grenade",
	"RPG_Round",
	"slam",
	"SMG1_Grenade",
	"AR2AltFire",
	"AlyxGun",
	"SniperRound",
	"SniperPenetratedRound",
	"Thumper",
	"Gravity",
	"Battery",
	"GaussEnergy",
	"CombineCannon",
	"AirboatGun",
	"StriderMinigun",
	"HelicopterGun",
	"9mmRound",
	"MP5_Grenade",
	"Hornet",
	"StriderMinigunDirect",
	"CombineHeavyCannon"
}

local default_weapon_classes = {
	"weapon_crowbar",
	"weapon_physcannon",
	"weapon_stunstick",
	"weapon_pistol",
	"weapon_357",
	"weapon_smg1",
	"weapon_ar2",
	"weapon_shotgun",
	"weapon_crossbow",
	"weapon_frag",
	"weapon_rpg",
	"weapon_slam",
	"weapon_bugbait"
}

local function KeyboardOn( pnl )
	if ( IsValid( Menu.Main.Frame ) and IsValid( pnl ) and pnl:HasParent( Menu.Main.Frame ) ) then
		Menu.Main.Frame:SetKeyboardInputEnabled( true )
	end
end
hook.Add( "OnTextEntryGetFocus", "lf_weapon_properties_editor_keyboard_on", KeyboardOn )
local function KeyboardOff( pnl )
	if ( IsValid( Menu.Main.Frame ) and IsValid( pnl ) and pnl:HasParent( Menu.Main.Frame ) ) then
		Menu.Main.Frame:SetKeyboardInputEnabled( false )
	end
end
hook.Add( "OnTextEntryLoseFocus", "lf_weapon_properties_editor_keyboard_off", KeyboardOff )


local function netmsg( id )
	net.Start( "lf_weapon_properties_editor" )
	net.WriteUInt( id, 4 )
end

local function ApplyChanges( weapon )
	
	local tbl = weapons.GetStored( weapon.Class )
	if not istable( tbl ) then return end
	
	if istable( tbl.Primary ) and istable( weapon.Primary ) then
		if tbl.Primary.Ammo then tbl.Primary.Ammo = weapon.Primary.Ammo end
		if tbl.Primary.Damage then tbl.Primary.Damage = weapon.Primary.Damage end
		if tbl.Primary.ClipSize then tbl.Primary.ClipSize = weapon.Primary.ClipSize end
		if tbl.Primary.DefaultClip then tbl.Primary.DefaultClip = weapon.Primary.DefaultClip end
	end
	if istable( tbl.Secondary ) and istable( weapon.Secondary ) then
		if tbl.Secondary.Ammo then tbl.Secondary.Ammo = weapon.Secondary.Ammo end
		if tbl.Secondary.Damage then tbl.Secondary.Damage = weapon.Secondary.Damage end
		if tbl.Secondary.ClipSize then tbl.Secondary.ClipSize = weapon.Secondary.ClipSize end
		if tbl.Secondary.DefaultClip then tbl.Secondary.DefaultClip = weapon.Secondary.DefaultClip end
	end
	if tbl.Slot then tbl.Slot = weapon.Slot end
	if tbl.SlotPos then tbl.SlotPos = weapon.SlotPos end
	if istable( tbl.FireModes ) and istable( weapon.FireModes ) then
		if tbl.FireModes[1] then tbl.FireModes[1] = weapon.FireModes[1] end
		if tbl.FireModes[2] then tbl.FireModes[2] = weapon.FireModes[2] end
		if tbl.FireModes[3] then tbl.FireModes[3] = weapon.FireModes[3] end
	end
	
end

local function Notify( msg )
	if msg == 0 then notification.AddLegacy( "Weapon modifications applied.", NOTIFY_GENERIC, 5 )
	elseif msg == 1 then notification.AddLegacy( "Preset saved successfully.", NOTIFY_GENERIC, 5 )
	elseif msg == 2 then notification.AddLegacy( "Weapon is not modified. Apply settings first.", NOTIFY_ERROR, 5 )
	elseif msg == 3 then notification.AddLegacy( "Not possible. Remove conflicting replacements first.", NOTIFY_ERROR, 5 )
	elseif msg == 4 then notification.AddLegacy( "Weapon class invalid. Please enter the class of a registered SWEP.", NOTIFY_ERROR, 5 )
	end
end


net.Receive("lf_weapon_properties_editor", function()
	
	local func = net.ReadUInt( 4 )
	
	if func == 0 then -- Player Notifications
		Notify( net.ReadUInt( 3 ) )
	elseif func == 1 then -- Apply weapon changes to server and clients
		ApplyChanges( net.ReadTable() )
	elseif func == 2 then -- Saving Presets
		--
	elseif func == 3 then -- Getting Presets List
		if IsValid( Menu.PresetList.List ) then
			Menu.PresetList.List:Populate( net.ReadTable() )
		end
	elseif func == 4 then -- Deleting Presets
		--
	elseif func == 5 then -- Saving Replacements
		--
	elseif func == 6 then -- Getting Replacements List
		if IsValid( Menu.Replacements.List ) then
			Menu.Replacements.List:Populate( net.ReadTable() )
		end
	elseif func == 7 then -- Deleting Replacements
		--
	elseif func == 8 then -- Refresh weapon entities
		--
	end
	
end )


-- Blur Code by: https://facepunch.com/member.php?u=237675
local blur = Material( "pp/blurscreen" )
local function DrawBlur( panel, amount )
	local x, y = panel:LocalToScreen( 0, 0 )
	local scrW, scrH = ScrW(), ScrH()
	surface.SetDrawColor( 255, 255, 255 )
	surface.SetMaterial( blur )
	for i = 1, 3 do
		blur:SetFloat( "$blur", ( i / 3 ) * ( amount or 6 ) )
		blur:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect( x * -1, y * -1, scrW, scrH )
	end
end


function Menu.Editor:Init( weapon_class )
	
	local tbl = weapons.GetStored( weapon_class )
	if not istable( tbl ) then
		Notify( 4 )
		return
	end
	local weapon = {}
	weapon.Primary, weapon.Secondary, weapon.FireModes = {}, {}, {}
	weapon.Class = weapon_class
	if istable( tbl.Primary ) then
		if tbl.Primary.Ammo then weapon.Primary.Ammo = tbl.Primary.Ammo end
		if tbl.Primary.Damage then weapon.Primary.Damage = tbl.Primary.Damage end
		if tbl.Primary.ClipSize then weapon.Primary.ClipSize = tbl.Primary.ClipSize end
		if tbl.Primary.DefaultClip then weapon.Primary.DefaultClip = tbl.Primary.DefaultClip end
	end
	if istable( tbl.Secondary ) then
		if tbl.Secondary.Ammo then weapon.Secondary.Ammo = tbl.Secondary.Ammo end
		if tbl.Secondary.Damage then weapon.Secondary.Damage = tbl.Secondary.Damage end
		if tbl.Secondary.ClipSize then weapon.Secondary.ClipSize = tbl.Secondary.ClipSize end
		if tbl.Secondary.DefaultClip then weapon.Secondary.DefaultClip = tbl.Secondary.DefaultClip end
	end
	if tbl.Slot then weapon.Slot = tbl.Slot end
	if tbl.SlotPos then weapon.SlotPos = tbl.SlotPos end
	if istable( tbl.FireModes ) then
		if tbl.FireModes[1] then weapon.FireModes[1] = tbl.FireModes[1] end
		if tbl.FireModes[2] then weapon.FireModes[2] = tbl.FireModes[2] end
		if tbl.FireModes[3] then weapon.FireModes[3] = tbl.FireModes[3] end
	end
	
	local Frame = vgui.Create( "DFrame", Menu.Main.Frame )
	local fw, fh = 600, 600
	local pw, ph = fw - 10, fh - 34
	Frame:SetPos( ( ScrW() / 2 ) - ( fw / 2 ), ( ScrH() / 2 ) - ( fh / 2 ) )
	Frame:SetSize( fw, fh )
	Frame:SetTitle( weapon.Class )
	Frame:SetVisible( true )
	Frame:SetDraggable( true )
	Frame:SetScreenLock( false )
	Frame:ShowCloseButton( true )
	Frame:MakePopup()
	Frame:SetKeyboardInputEnabled( false )
	function Frame:Paint( w, h )
		DrawBlur( self, 2 )
		draw.RoundedBox( 10, 0, 0, w, h, Color( 0, 99, 177, 200 ) ) return true
	end
	function Frame.lblTitle:Paint( w, h )
		draw.SimpleTextOutlined( Frame.lblTitle:GetText(), "DermaDefaultBold", 1, 2, Color( 255, 255, 255, 255 ), 0, 0, 1, Color( 0, 0, 0, 255 ) ) return true
	end
	
	local pnl = Frame:Add( "DPanel" )
	pnl:Dock( FILL )
	pnl:DockPadding( 10, 10, 10, 10 )
	
	local prop = pnl:Add( "DCategoryList" )
	prop:Dock( FILL )
	
	local function AddLineText( list, text, val )
		local line = list:Add( "DPanel" )
		line:DockPadding( 5, 2, 5, 2 )
		line:SetDrawBackground( false )
		local id
		if val then
			local lbl = line:Add( "DLabel" )
			lbl:Dock( LEFT )
			lbl:SetWide( 239 )
			lbl:SetDark( true )
			lbl:SetText( text )
			
			id = line:Add( "DTextEntry" )
			id:Dock( FILL )
			id:SetText( val or "" )
		else
			local lbl = line:Add( "DLabel" )
			lbl:Dock( FILL )
			lbl:SetText( text )
		end
		return line, id
	end
	
	local function AddLineInt( list, text, val, min, max )
		local line = list:Add( "DPanel" )
		line:DockPadding( 5, 2, 5, 2 )
		line:SetDrawBackground( false )
		local id
		if val then
			id = line:Add( "DNumSlider" )
			id:Dock( FILL )
			id:SetDark( true )
			id:SetDecimals( 0 )
			id:SetMinMax( min, max )
			id:SetText( text )
			id:SetValue( val or 0 )
		else
			local lbl = line:Add( "DLabel" )
			lbl:Dock( FILL )
			lbl:SetText( text )
		end
		return line, id
	end
	
	
	local cat = prop:Add( "Primary Ammo" )
	local list = vgui.Create( "DListLayout" )
	cat:SetContents( list )
	
	local line, rPriAmmo = AddLineText( list, "Ammo Type:", weapon.Primary.Ammo )
	if rPriAmmo then
		local c = line:Add( "DComboBox" )
		c:Dock( RIGHT )
		c:SetWide( 100 )
		c:SetSortItems( false )
		c:SetValue( "Default Types" )
		for _, v in pairs( default_ammo_types ) do
			c:AddChoice( v )
		end
		function c:OnSelect( index, value )
			rPriAmmo:SetText( value )
			c:SetValue( "Default Types" )
		end
	end
	
	local line, rPriDamage = AddLineInt( list, "Damage:", weapon.Primary.Damage, 0, 1000 )
	local line, rPriClipSize = AddLineInt( list, "Clip Size:", weapon.Primary.ClipSize, 0, 500 )
	local line, rPriDefaultClip = AddLineInt( list, "Default number of rounds:", weapon.Primary.DefaultClip, 0, 500 )
	
	
	local cat = prop:Add( "Secondary Ammo" )
	local list = vgui.Create( "DListLayout" )
	cat:SetContents( list )
	
	local line, rSecAmmo = AddLineText( list, "Ammo Type:", weapon.Secondary.Ammo )
	if rSecAmmo then
		local c = line:Add( "DComboBox" )
		c:Dock( RIGHT )
		c:SetWide( 100 )
		c:SetSortItems( false )
		c:SetValue( "Default Types" )
		for _, v in pairs( default_ammo_types ) do
			c:AddChoice( v )
		end
		function c:OnSelect( index, value )
			rSecAmmo:SetText( value )
			c:SetValue( "Default Types" )
		end
	end
	
	local line, rSecDamage = AddLineInt( list, "Damage:", weapon.Secondary.Damage, 0, 1000 )
	local line, rSecClipSize = AddLineInt( list, "Clip Size:", weapon.Secondary.ClipSize, 0, 500 )
	local line, rSecDefaultClip = AddLineInt( list, "Default number of rounds:", weapon.Secondary.DefaultClip, 0, 500 )
	
	
	local cat = prop:Add( "Weapon Slots" )
	local list = vgui.Create( "DListLayout" )
	cat:SetContents( list )
	
	local niceslot
	if weapon.Slot then niceslot = weapon.Slot + 1 end
	local line, rSlot = AddLineInt( list, "Slot (1 - 6 recommended):", niceslot, 1, 10 )
	local line, rSlotPos = AddLineInt( list, "Slot Position:", weapon.SlotPos, 0, 127 )
	
	
	local cat = prop:Add( "FireModes" )
	local list = vgui.Create( "DListLayout" )
	cat:SetContents( list )
	
	local line, rFireModes1 = AddLineText( list, "Option 1:", weapon.FireModes[1] )
	local line, rFireModes2 = AddLineText( list, "Option 2:", weapon.FireModes[2] )
	local line, rFireModes3 = AddLineText( list, "Option 3:", weapon.FireModes[3] )
	
	
	
	local subpnl = pnl:Add( "DPanel" )
	subpnl:Dock( BOTTOM )
	subpnl:DockMargin( 0, 10, 0, 0 )
	subpnl:SetHeight( 20 )
	subpnl:SetDrawBackground( false )
	
	local lw = ( pw - 10 ) / 2 - 10
	
	local b = subpnl:Add( "DButton" )
	b:Dock( LEFT )
	b:SetWide( lw )
	b:SetText( "Save modifications as preset" )
	b.DoClick = function()
		netmsg( 2 )
		net.WriteString( weapon.Class )
		net.SendToServer()
	end
	
	local b = subpnl:Add( "DButton" )
	b:Dock( RIGHT )
	b:SetWide( lw )
	b:SetText( "Force update of all players with this weapon" )
	b.DoClick = function()
		netmsg( 8 )
		net.WriteString( weapon.Class )
		net.SendToServer()
	end
	
	local b = pnl:Add( "DButton" )
	b:Dock( BOTTOM )
	b:DockMargin( 0, 10, 0, 0 )
	b:SetHeight( 30 )
	b:SetText( "Apply Changes" )
	b.DoClick = function()
		if rPriAmmo then weapon.Primary.Ammo = tostring( rPriAmmo:GetValue() ) end
		if rPriDamage then weapon.Primary.Damage = math.Round( rPriDamage:GetValue() ) end
		if rPriClipSize then weapon.Primary.ClipSize = math.Round( rPriClipSize:GetValue() ) end
		if rPriDefaultClip then weapon.Primary.DefaultClip = math.Round( rPriDefaultClip:GetValue() ) end
		if rSecAmmo then weapon.Secondary.Ammo = tostring( rSecAmmo:GetValue() ) end
		if rSecDamage then weapon.Secondary.Damage = math.Round( rSecDamage:GetValue() ) end
		if rSecClipSize then weapon.Secondary.ClipSize = math.Round( rSecClipSize:GetValue() ) end
		if rSecDefaultClip then weapon.Secondary.DefaultClip = math.Round( rSecDefaultClip:GetValue() ) end
		if rSlot then weapon.Slot = math.Round( rSlot:GetValue() - 1 ) end
		if rSlotPos then weapon.SlotPos = math.Round( rSlotPos:GetValue() ) end
		if rFireModes1 then weapon.FireModes[1] = tostring( rFireModes1:GetValue() ) end
		if rFireModes2 then weapon.FireModes[2] = tostring( rFireModes2:GetValue() ) end
		if rFireModes3 then weapon.FireModes[3] = tostring( rFireModes3:GetValue() ) end
		
		netmsg( 1 )
		net.WriteTable( weapon )
		net.SendToServer()
	end
	
end

function Menu.PresetList:Init()
	
	local Frame = vgui.Create( "DFrame", Menu.Main.Frame )
	local fw, fh = 320, 600
	local pw, ph = fw - 10, fh - 34
	Frame:SetPos( 335, 10 )
	Frame:SetSize( fw, fh )
	Frame:SetTitle( "Presets" )
	Frame:SetVisible( true )
	Frame:SetDraggable( true )
	Frame:SetScreenLock( false )
	Frame:ShowCloseButton( true )
	Frame:MakePopup()
	Frame:SetKeyboardInputEnabled( false )
	function Frame:Paint( w, h )
		DrawBlur( self, 2 )
		draw.RoundedBox( 10, 0, 0, w, h, Color( 0, 99, 177, 200 ) ) return true
	end
	function Frame.lblTitle:Paint( w, h )
		draw.SimpleTextOutlined( Frame.lblTitle:GetText(), "DermaDefaultBold", 1, 2, Color( 255, 255, 255, 255 ), 0, 0, 1, Color( 0, 0, 0, 255 ) ) return true
	end
	
	local pnl = Frame:Add( "DPanel" )
	pnl:Dock( FILL )
	pnl:DockPadding( 10, 10, 10, 10 )
	
	Menu.PresetList.List = pnl:Add( "DListView" )
	Menu.PresetList.List:Dock( FILL )
	Menu.PresetList.List:SetMultiSelect( true )
	Menu.PresetList.List:AddColumn( "Presets" )
	function Menu.PresetList.List:DoDoubleClick( id, sel )
		local weapon = tostring( sel:GetValue( 1 ) )
		Menu.Editor:Init( weapon )
	end
	
	function Menu.PresetList.List:Populate( files )
		self:Clear()
		for _, v in pairs( files ) do
			self:AddLine( string.TrimRight( v, ".txt" ) )
		end
		self:SortByColumn( 1 )
	end
	
	netmsg( 3 )
	net.SendToServer()
	
	local b = pnl:Add( "DButton" )
	b:Dock( BOTTOM )
	b:DockMargin( 0, 10, 0, 0 )
	b:SetHeight( 20 )
	b:SetText( "Delete selected files" )
	b.DoClick = function()
		local sel = Menu.PresetList.List:GetSelected()
		for k, v in pairs( sel ) do
			local filename = tostring( v:GetValue(1) )
			netmsg( 4 )
			net.WriteString( filename )
			net.SendToServer()
		end
	end
	
end

function Menu.Replacements:Init()
	
	local Frame = vgui.Create( "DFrame", Menu.Main.Frame )
	local fw, fh = 600, 600
	local pw, ph = fw - 10, fh - 34
	Frame:SetPos( ( ScrW() / 2 ) - ( fw / 2 ), ( ScrH() / 2 ) - ( fh / 2 ) )
	Frame:SetSize( fw, fh )
	Frame:SetTitle( "Weapon Replacements" )
	Frame:SetVisible( true )
	Frame:SetDraggable( true )
	Frame:SetScreenLock( false )
	Frame:ShowCloseButton( true )
	Frame:MakePopup()
	Frame:SetKeyboardInputEnabled( false )
	function Frame:Paint( w, h )
		DrawBlur( self, 2 )
		draw.RoundedBox( 10, 0, 0, w, h, Color( 0, 99, 177, 200 ) ) return true
	end
	function Frame.lblTitle:Paint( w, h )
		draw.SimpleTextOutlined( Frame.lblTitle:GetText(), "DermaDefaultBold", 1, 2, Color( 255, 255, 255, 255 ), 0, 0, 1, Color( 0, 0, 0, 255 ) ) return true
	end
	
	local pnl = Frame:Add( "DPanel" )
	pnl:Dock( FILL )
	pnl:DockPadding( 10, 10, 10, 10 )
	
	local lw = ( pw - 10 ) / 2 - 10
	
	local subpnl = pnl:Add( "DPanel" )
	subpnl:Dock( TOP )
	subpnl:DockMargin( 0, 0, 0, 10 )
	subpnl:SetHeight( 105 )
	subpnl:SetDrawBackground( false )
	
	local left = subpnl:Add( "DPanel" )
	left:Dock( LEFT )
	left:SetWide( lw )
	left:SetDrawBackground( false )
	
	local right = subpnl:Add( "DPanel" )
	right:Dock( RIGHT )
	right:SetWide( lw )
	right:SetDrawBackground( false )
	
	local lbl = left:Add( "DLabel" )
	lbl:Dock( TOP )
	lbl:DockMargin( 0, 0, 0, 10 )
	lbl:SetHeight( 15 )
	lbl:SetDark( true )
	lbl:SetText( "Picking up this weapon ..." )
	
	local lbl = right:Add( "DLabel" )
	lbl:Dock( TOP )
	lbl:DockMargin( 0, 0, 0, 10 )
	lbl:SetHeight( 15 )
	lbl:SetDark( true )
	lbl:SetText( "will give players this weapon ..." )
	
	local c = left:Add( "DComboBox" )
	c:Dock( TOP )
	c:DockMargin( 0, 0, 0, 10 )
	c:SetHeight( 20 )
	c:SetSortItems( false )
	c:SetValue( "Copy default HL2 weapon" )
	for _, v in pairs( default_weapon_classes ) do
		c:AddChoice( v )
	end
	function c:OnSelect( index, value )
		Menu.Replacements.LeftEntry:SetText( value )
		c:SetValue( "Copy default HL2 weapon" )
	end
	
	local lbl = right:Add( "DLabel" )
	lbl:Dock( TOP )
	lbl:DockMargin( 0, 0, 0, 10 )
	lbl:SetHeight( 20 )
	lbl:SetDark( true )
	lbl:SetText( "(Leave the right field empty, to block the weapon.)" )
	
	local b = left:Add( "DButton" )
	b:Dock( TOP )
	b:DockMargin( 0, 0, 0, 10 )
	b:SetHeight( 20 )
	b:SetText( "Copy weapon from main menu" )
	b.DoClick = function()
		local text = Menu.Main.WeaponEntry:GetValue()
		Menu.Replacements.LeftEntry:SetValue( text )
	end
	
	local b = right:Add( "DButton" )
	b:Dock( TOP )
	b:DockMargin( 0, 0, 0, 10 )
	b:SetHeight( 20 )
	b:SetText( "Copy weapon from main menu" )
	b.DoClick = function()
		local text = Menu.Main.WeaponEntry:GetValue()
		Menu.Replacements.RightEntry:SetValue( text )
	end
	
	Menu.Replacements.LeftEntry = left:Add( "DTextEntry" )
	Menu.Replacements.LeftEntry:Dock( TOP )
	Menu.Replacements.LeftEntry:SetHeight( 20 )
	
	Menu.Replacements.RightEntry = right:Add( "DTextEntry" )
	Menu.Replacements.RightEntry:Dock( TOP )
	Menu.Replacements.LeftEntry:SetHeight( 20 )
	
	local b = pnl:Add( "DButton" )
	b:Dock( TOP )
	b:DockMargin( 0, 0, 0, 20 )
	b:SetHeight( 30 )
	b:SetText( "Add weapon replacement" )
	b.DoClick = function()
		local key = tostring( Menu.Replacements.LeftEntry:GetValue() )
		if key == "" then return end
		local value = tostring( Menu.Replacements.RightEntry:GetValue() )
		netmsg( 5 )
		net.WriteString( key )
		net.WriteString( value )
		net.SendToServer()
	end
	
	Menu.Replacements.List = pnl:Add( "DListView" )
	Menu.Replacements.List:Dock( FILL )
	Menu.Replacements.List:SetMultiSelect( true )
	Menu.Replacements.List:AddColumn( "Replace ..." )
	Menu.Replacements.List:AddColumn( "with ..." )
	function Menu.Replacements.List:DoDoubleClick( id, sel )
		local key = tostring( sel:GetValue( 1 ) )
		local value = tostring( sel:GetValue( 2 ) )
		Menu.Replacements.LeftEntry:SetText( key )
		Menu.Replacements.RightEntry:SetText( value )
	end
	
	function Menu.Replacements.List:Populate( list )
		self:Clear()
		for k, v in pairs( list ) do
			self:AddLine( k, v )
		end
		self:SortByColumn( 1 )
	end
	
	netmsg( 6 )
	net.SendToServer()
	
	local b = pnl:Add( "DButton" )
	b:Dock( BOTTOM )
	b:DockMargin( 0, 10, 0, 0 )
	b:SetHeight( 20 )
	b:SetText( "Delete selected replacements" )
	b.DoClick = function()
		local sel = Menu.Replacements.List:GetSelected()
		for k, v in pairs( sel ) do
			local weapon = tostring( v:GetValue(1) )
			netmsg( 7 )
			net.WriteString( weapon )
			net.SendToServer()
		end
	end
	
end

function Menu.Main:Init()
	
	Menu.Main.Frame = vgui.Create( "DFrame" )
	local Frame = Menu.Main.Frame
	local fw, fh = 320, ScrH() - 20
	local pw, ph = fw - 10, fh - 34
	Frame:SetPos( 10, 10 )
	Frame:SetSize( fw, fh )
	Frame:SetTitle( "Weapon Properties Editor "..Version )
	Frame:SetVisible( true )
	Frame:SetDraggable( true )
	Frame:SetScreenLock( false )
	Frame:ShowCloseButton( true )
	Frame:MakePopup()
	Frame:SetKeyboardInputEnabled( false )
	function Frame:Paint( w, h )
		DrawBlur( self, 2 )
		draw.RoundedBox( 10, 0, 0, w, h, Color( 0, 99, 177, 200 ) ) return true
	end
	function Frame.lblTitle:Paint( w, h )
		draw.SimpleTextOutlined( Frame.lblTitle:GetText(), "DermaDefaultBold", 1, 2, Color( 255, 255, 255, 255 ), 0, 0, 1, Color( 0, 0, 0, 255 ) ) return true
	end
	
	local pnl = Frame:Add( "DPanel" )
	pnl:Dock( FILL )
	pnl:DockPadding( 10, 10, 10, 10 )
	
	local b = pnl:Add( "DButton" )
	b:Dock( TOP )
	b:DockMargin( 0, 0, 0, 10 )
	b:SetHeight( 30 )
	b:SetText( "Edit Weapon" )
	b.DoClick = function()
		local name = tostring( Menu.Main.WeaponEntry:GetValue() )
		if name == "" then return end
		Menu.Editor:Init( name )
	end
	
	Menu.Main.WeaponEntry = pnl:Add( "DTextEntry" )
	Menu.Main.WeaponEntry:Dock( TOP )
	Menu.Main.WeaponEntry:DockMargin( 0, 0, 0, 20 )
	Menu.Main.WeaponEntry:SetHeight( 20 )
	
	local b = pnl:Add( "DButton" )
	b:Dock( TOP )
	b:DockMargin( 0, 0, 0, 10 )
	b:SetHeight( 20 )
	b:SetText( "Get class of active weapon" )
	b.DoClick = function()
		local weapon = LocalPlayer():GetActiveWeapon()
		if IsValid( weapon ) then
			Menu.Main.WeaponEntry:SetValue( weapon:GetClass() )
		else
			Menu.Main.WeaponEntry:SetValue( "" )
		end
	end
	
	Menu.Main.WeaponList = pnl:Add( "DListView" )
	Menu.Main.WeaponList:Dock( FILL )
	Menu.Main.WeaponList:SetMultiSelect( false )
	Menu.Main.WeaponList:AddColumn( "Class" )
	Menu.Main.WeaponList:AddColumn( "Name" )
	function Menu.Main.WeaponList:DoDoubleClick( id, sel )
		local weapon = tostring( sel:GetValue( 1 ) )
		Menu.Main.WeaponEntry:SetValue( weapon )
	end
	
	function Menu.Main.WeaponList:Populate()
		self:Clear()
		for k, v in pairs( weapons.GetList() ) do
			if v.Spawnable then
				self:AddLine( v.ClassName, v.PrintName )
			end
		end
		self:SortByColumn( 1 )
	end
	Menu.Main.WeaponList:Populate()
	
	local b = pnl:Add( "DButton" )
	b:Dock( BOTTOM )
	b:DockMargin( 0, 20, 0, 0 )
	b:SetHeight( 30 )
	b:SetText( "Weapon Replacements" )
	b.DoClick = function()
		Menu.Replacements:Init()
	end
	
	local b = pnl:Add( "DButton" )
	b:Dock( BOTTOM )
	b:DockMargin( 0, 10, 0, 0 )
	b:SetHeight( 20 )
	b:SetText( "Manage Preset Files" )
	b.DoClick = function()
		Menu.PresetList:Init()
	end
	
end

function Menu.Toggle()
	if LocalPlayer():IsSuperAdmin() then
		if IsValid( Menu.Main.Frame ) then
			Menu.Main.Frame:Close()
		else
			Menu.Main:Init()
		end
	else
		if IsValid( Menu.Main.Frame ) then Menu.Main.Frame:Close() end
	end
end

concommand.Add( "weapon_properties_editor", Menu.Toggle )


-- Spawn Menu entry.
local function SpawnMenu_Entry( panel )
	panel:AddControl("Label", {Text = "Administrator Settings:"})
	local a = panel:AddControl("Button", {Label = "Open Menu", Command = "weapon_properties_editor"})
	a:SetSize(0, 50)
	a:SetEnabled( LocalPlayer():IsSuperAdmin() )
end
hook.Add( "PopulateToolMenu", "lf_weapon_properties_editor_spawnmenu", function() spawnmenu.AddToolMenuOption( "Options", "Player", "lf_weapon_properties_editor_spawnmenu_entry", "Weapon Editor", "", "", SpawnMenu_Entry, {} ) end )


end
