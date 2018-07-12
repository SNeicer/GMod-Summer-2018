--
-- Prickly Summer 2018
-- 03/06/18
--
-- Level Generation
--

local DEBUG						= true
local PRK_GEN_COLLIDE_ALL		= false
local PRK_GEN_DONT				= 4000
local PRK_GEN_DONT_SIZEMULT		= 1 / PRK_Gen_SizeModifier
local PRK_GEN_COLLISION_BORDER	= 90 / 100

local PRK_GEN_TYPE_FLOOR	= 1
local PRK_GEN_TYPE_WALL		= 2
local PRK_GEN_TYPE_CEILING	= 3

PRK_GEN_TYPE_MAT = {}
PRK_GEN_TYPE_MAT[PRK_GEN_TYPE_FLOOR]	= "models/rendertarget" -- "phoenix_storms/bluemetal"
PRK_GEN_TYPE_MAT[PRK_GEN_TYPE_WALL]		= "prk_gradient" -- "phoenix_storms/dome"
PRK_GEN_TYPE_MAT[PRK_GEN_TYPE_CEILING]	= "models/rendertarget" -- "phoenix_storms/metalset_1-2"

local size = PRK_Plate_Size
local hsize = size / 2

local HelperModels = {
	Anchor = {
		Model = "models/props_c17/pulleyhook01.mdl",
		Angle = Angle( 180, 0, 0 ),
	},
	Attach = {
		Model = "models/props_junk/PushCart01a.mdl",
		Angle = Angle( 0, 0, 0 ),
	},
	-- Min = {
		-- Model = "models/mechanics/solid_steel/l-beam__16.mdl",
		-- Angle = Angle( 0, 0, 0 ),
	-- },
	-- Max = {
		-- Model = "models/hunter/tubes/tube2x2x+.mdl",
		-- Angle = Angle( 0, 0, 0 ),
	-- },
}

local LastGen = {} -- Table of all rooms last generated
local ToGen = {} -- Table of rooms still to try attach points for
local CurrentRoomID = 0 -- Indices for rooms
local room

concommand.Add( "prk_gen", function( ply, cmd, args )
	PRK_Gen_Remove()
	PRK_Gen( ply:GetPos() - Vector( 0, 0, 100 ) )
end )

function PRK_Gen( origin )
	LastGen = {}
	CurrentRoomID = 0

	-- Create each helper model entity
	for k, v in pairs( HelperModels ) do
		local ent = PRK_CreateProp( v.Model, origin, v.Angle )
		v.Ent = ent
	end

--	-- Generate first room
	ToGen = {
		{
			AttachPoints = {
				{
					Pos = origin
				}
			}
		}
	}
	PRK_Gen_Step()
end

-- local room = nil
local plan
local index_try = 1
local orient_try = 1
function PRK_Gen_Step()
	if ( !ToGen or #ToGen == 0 or #ToGen[1].AttachPoints == 0 ) then
		PRK_Gen_End()
		return
	end

	local origin = ToGen[1].AttachPoints[1].Pos

	local function next_attach()
		-- Ensure parents are removed
		for k, v in pairs( room.Ents ) do
			v:SetParent( nil )
		end

		-- Reset for next point
		room = nil
		orient_try = 1
		inde = 1
		CurrentRoomID = CurrentRoomID + 1

		-- Remove ToGen element if no more attachpoints to try
		table.remove( ToGen[1].AttachPoints, 1 )
		if ( #ToGen[1].AttachPoints == 0 ) then
			table.remove( ToGen, 1 )
		end
	end
	local function next_step()
		-- PRK_Gen_Step()
		timer.Simple( 0.01, function() PRK_Gen_Step() end )
	end

	if ( !room ) then
		local rooms = PRK_Gen_LoadRooms()
		-- plan = rooms[2]
		plan = rooms[math.random( 1, #rooms )]

		room = {}
			room.Origin = origin
		room.Ents = {}
		for k, mod in pairs( plan.Models ) do
			local class = "prop_physics"
				if ( mod.Type == PRK_GEN_TYPE_FLOOR ) then
					class = "prk_floor"
				elseif ( mod.Type == PRK_GEN_TYPE_WALL ) then
					class = "prk_wall"
				end
			local ent = PRK_CreateEnt(
				class,
				mod.Mod,
				room.Origin + mod.Pos,
				mod.Ang
			)
			if ( mod.Type != nil ) then
				ent:SetMaterial( PRK_GEN_TYPE_MAT[mod.Type] )
			end
			if ( #room.Ents != 0 ) then
				ent:SetParent( room.Ents[1] )
			end
			ent.Collide = mod.Collide or PRK_GEN_COLLIDE_ALL
			ent.PRK_Room = CurrentRoomID
			table.insert( room.Ents, ent )
		end
		room.AttachPoints = table.shallowcopy( plan.AttachPoints )

		index_try = 1
		orient_try = 1
	else
		local att = room.AttachPoints[index_try]
		print( "-0" )
		print( index_try )
		PrintTable( room.AttachPoints )

		-- Move anchor to correct position
		local anchor = HelperModels["Anchor"].Ent
		anchor:SetPos( room.Origin + att.Pos )
		anchor:SetAngles( HelperModels["Anchor"].Angle )

		-- Parent all to anchor helper
		for k, v in pairs( room.Ents ) do
			v:SetParent( anchor )
		end

		-- Rotate
		anchor:SetAngles( HelperModels["Anchor"].Angle + Angle( 0, 90 * ( orient_try - 1 ), 0 ) )

		-- Move anchor to origin attach point
		anchor:SetPos( room.Origin )

		-- If no collision then store this room
		local collide = false
		for _, v in pairs( room.Ents ) do
			if ( v.Collide ) then
				local pos = v:GetPos()
				local min, max = v:OBBMins(), v:OBBMaxs()
					-- Slightly smaller to avoid border crossover
					local bor = PRK_GEN_COLLISION_BORDER
					min = min * bor
					max = max * bor
					if ( v.Collide != true ) then -- Must be table
						min = min + Vector( 0, 0, v.Collide[1] )
						max = max + Vector( 0, 0, v.Collide[2] )
					end
				for k, collision in pairs( ents.FindInBox( pos + min, pos + max ) ) do
					if ( collision.Collide and collision.PRK_Room != nil and collision.PRK_Room != CurrentRoomID ) then
						collide = true
						debugoverlay.Box( pos, min, max, 2, Color( 255, 0, 0, 100 ) )
					end
				end
				debugoverlay.Box( pos, min, max, 2, Color( 255, 255, 0, 100 ) )
			end
		end
		if ( !collide ) then
			table.insert( LastGen, room )

			local temp_orient = orient_try
			-- Add newest room
			local temp_room = LastGen[#LastGen]
			local attachpoints = {}
			for k, v in pairs( temp_room.AttachPoints ) do
				-- Chance to not use this attach point
				-- With less chance as the generation continues
				local use = true
				local donttarget = PRK_GEN_DONT
				local rnd = math.random( 1, donttarget ) * ( CurrentRoomID * PRK_GEN_DONT_SIZEMULT )
				if ( rnd >= donttarget ) then
					use = false
				end

				if ( use and k != index_try ) then
					local helper = HelperModels["Attach"].Ent
					-- Undo parent
					helper:SetParent( nil )

					-- Undo move
					anchor:SetPos( temp_room.Origin + att.Pos )

					-- Undo rotation
					anchor:SetAngles( HelperModels["Anchor"].Angle )

					-- Set attach helper position
					helper:SetPos( temp_room.Origin + v.Pos )

					-- Parent back to anchor
					helper:SetParent( anchor )

					-- Rotate back
					anchor:SetAngles( HelperModels["Anchor"].Angle + Angle( 0, 90 * ( orient_try - 1 ), 0 ) )

					-- Move back
					anchor:SetPos( temp_room.Origin )

					-- Store pos
					local point = {
						Pos = helper:GetPos()
					}
					table.insert( attachpoints, point )
				end
			end

			-- Must be after attach point etc
			next_attach()

			table.insert( ToGen, { AttachPoints = attachpoints } )

			next_step()

			return
		end

		-- Otherwise undo rotation and parents
		anchor:SetPos( room.Origin + att.Pos )
		anchor:SetAngles( HelperModels["Anchor"].Angle )
		for k, v in pairs( room.Ents ) do
			v:SetParent( nil )
		end

		-- setup next
		orient_try = orient_try + 1
		if ( orient_try > 4 ) then
			orient_try = 1
			index_try = index_try + 1
			if ( index_try > #room.AttachPoints ) then
				for p, ent in pairs( room.Ents ) do
					ent:Remove()
				end
				next_attach()
			end
		end
	end

	next_step()
end

function PRK_Gen_End()
	-- Remove each helper model entity
	for k, v in pairs( HelperModels ) do
		v.Ent:Remove()
		v.Ent = nil
	end
end

function PRK_Gen_RotateAround( room, attach, angle )
	local ent = room.Ents[1]
		if ( !ent.OriginalPos ) then
			ent.OriginalPos = ent:GetPos()
		end
	local attpos = attach.Pos

	local mat_inverse = Matrix()
		mat_inverse:SetTranslation( attpos )

	local mat_rot = Matrix()
		mat_rot:SetAngles( ent:GetAngles() + Angle( 0, angle, 0 ) )

	local mat_trans = Matrix()
		mat_trans:SetTranslation( -attpos )

	-- Move to origin, rotate, move from origin
	local mat_final = ( mat_inverse * mat_rot ) * mat_trans
	local pos = mat_final:GetTranslation()
	local ang = mat_final:GetAngles()
	ent:SetPos( ent.OriginalPos + pos )
	ent:SetAngles( ang )
end

function PRK_Gen_RotatePointAround( point, pointangle, attach, angle )
	local attpos = attach.Pos

	local mat_inverse = Matrix()
		mat_inverse:SetTranslation( attpos )

	local mat_rot = Matrix()
		mat_rot:SetAngles( pointangle + Angle( 0, angle, 0 ) )

	local mat_trans = Matrix()
		mat_trans:SetTranslation( -attpos )

	-- Move to origin, rotate, move from origin
	local mat_final = ( mat_inverse * mat_rot ) * mat_trans
	local pos = mat_final:GetTranslation()
	local ang = mat_final:GetAngles()
	return pos, ang
end

function PRK_Gen_LoadRooms()
	local rooms = {}
		-- Find all room data files
		local files, directories = file.Find( PRK_Path_Rooms .. "*", "DATA" )
		for k, filename in pairs( files ) do
			local room = file.Read( PRK_Path_Rooms .. filename )
				-- Convert from json back to table format
				room = util.JSONToTable( room )
				-- Parse the room creation instructions into the correct level gen instructions
				room.AttachPoints = {}
				for _, model in pairs( room.ModelExportInstructions ) do
					if ( model.Editor_Ent == "Attach Point" ) then
						table.insert( room.AttachPoints, { Pos = model.Pos } )
					end
				end
				room.Models = {}
				for _, part in pairs( room.Parts ) do
					table.insert( room.Models, {
						Pos = part.position,
						Ang = Angle( 0, 0, 0 ),
						Mod = "models/hunter/plates/plate1x1.mdl",
						Type = PRK_GEN_TYPE_FLOOR,
						Collide = true,
					} )
				end
				-- Debug output
				PrintTable( room )
			table.insert( rooms, room )
		end
	return rooms
end

function PRK_Gen_Remove()
	for k, v in pairs( LastGen ) do
		for _, ent in pairs( v.Ents ) do
			if ( ent and ent:IsValid() ) then
				ent:Remove()
			end
		end
	end
	LastGen = {}
end
