include( "shared.lua" )

local reload = true
function ENT:Think()
	-- Autoreload helper
	if ( reload ) then
		self:Initialize()
		reload = false
	end
end

function ENT:Initialize()
	local min, max = self:GetCollisionBounds()
	self:PhysicsInitConvex( {
		Vector( min.x, min.y, min.z ),
		Vector( min.x, min.y, max.z ),
		Vector( min.x, max.y, min.z ),
		Vector( min.x, max.y, max.z ),
		Vector( max.x, min.y, min.z ),
		Vector( max.x, min.y, max.z ),
		Vector( max.x, max.y, min.z ),
		Vector( max.x, max.y, max.z )
	} )

	-- Set up solidity and movetype
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	-- Enable custom collisions on the entity
	self:EnableCustomCollisions( true )

	self.Models = {}
	local ent = self:AddModel(
		"models/hunter/plates/plate1x1.mdl",
		Vector(),
		Angle(),
		1,
		"prk_gradient",
		Color( 255, 255, 255, 255 )
	)
		local size = PRK_Editor_Square_Size
		local collision = self:OBBMaxs() - self:OBBMins()
		local border = 0.004
		local scale = Vector( collision.x / size, collision.y / size + border, collision.z / size + border )
		local mat = Matrix()
			mat:Scale( scale )
	ent:EnableMatrix( "RenderMultiply", mat )
	local add = Vector( 1, 1, 1 ) * 1500
	ent:SetRenderBounds( self:OBBMins(), self:OBBMaxs(), add )
	self:SetRenderBounds( self:OBBMins(), self:OBBMaxs(), add )
end

function ENT:Think()
	-- Fail safe, can be removed if client graphic settings are changed
	if ( self.Models[1] and self.Models[1]:IsValid() ) then
		self.Models[1]:SetPos( self:GetPos() )
		self.Models[1]:SetAngles( self:GetAngles() )
	else
		self:Initialize()
	end
end

function ENT:Draw()
	-- self:DrawModel()
	-- debugoverlay.Box( self:GetPos(), self:OBBMins(), self:OBBMaxs(), FrameTime() / 2, Color( 255, 255, 0, 100 ) )
end

function ENT:OnRemove()
	for k, v in pairs( self.Models ) do
		v:Remove()
	end
end

function ENT:AddModel( mdl, pos, ang, scale, mat, col )
	local model = ClientsideModel( mdl )
		model:SetPos( self:GetPos() + pos )
		model:SetAngles( ang )
		model:SetModelScale( scale )
		model:SetMaterial( mat )
		model:SetColor( col )
		model.Pos = pos
		model.Ang = ang
		-- model.RenderBoundsMin, model.RenderBoundsMax = model:GetRenderBounds()
	table.insert(
		self.Models,
		model
	)
	return model
end
