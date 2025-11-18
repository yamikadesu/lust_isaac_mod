local utils = {}

function utils.GetData(entity)
	local data = entity:GetData()
	if not data.Yami then data.Yami = {} end
	return data.Yami
end

function utils.TableLength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function utils.VectorEquals(v1, v2)
    -- Comparar los valores `x` e `y` de ambos vectores
    return v1.X == v2.X and v1.Y == v2.Y
end

-- << TABLE FUNCTIONS >> --
-- Checks if a value is present in a list / table
function utils.IsValueInList(list, id)
	for _, value in pairs(list) do
		if value == id then return true end
	end
	
	return false
end

-- Removes all values within the list / table
function utils.ClearList(list)
	for key in pairs(list) do
		list[key] = nil
	end
end

function utils.GetShotSpeed(player, minVal, maxVal)
	minVal = minVal or 4.0
	maxVal = maxVal or 12.0
	local shotSpeedBonus = 0
	if player:HasCollectible(CollectibleType.COLLECTIBLE_STYE) and pData.CurrentEye == utils.Eyes.RIGHT then
		shotSpeedBonus = shotSpeedBonus - 0.3
	end
	--print("shotSpeedBonus: ", shotSpeedBonus)
	local shotSpeed = player.ShotSpeed + shotSpeedBonus
	return math.max(minVal, math.min(maxVal, shotSpeed))
end

function utils.GetMeleeSize(player)
	local pData = utils.GetData(player)
	local tearRangeBonus = 0
	if pData.IsCrownActive then
		tearRangeBonus = tearRangeBonus + 5.25
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BLOOD_CLOT) and pData.CurrentEye == utils.Eyes.LEFT then
		tearRangeBonus = tearRangeBonus + 2.75
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_STYE) and pData.CurrentEye == utils.Eyes.RIGHT then
		tearRangeBonus = tearRangeBonus + 6.5
	end
	--print("tearRangeBonus: ", tearRangeBonus)
	local tearRange = player.TearRange + tearRangeBonus
    return math.max(((tearRange / 40) / 6.5) ^ 0.3, 1.0)
end

-- << MATH FUNCTIONS >> --
-- Returns a rounded number
function utils.Round(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

-- Returns a number that cannot go above or below a certain range
function utils.Clamp(value, minimum, maximum)
	return math.min(math.max(value, minimum), maximum)
end

-- Converts boolean to a given number based on the given condition
function utils.BoolToNum(condition, numTrue, numFalse)
	return condition and (numTrue or 1) or (numFalse or 0)
end

-- Returns the shortest distance to an angle
function utils.ShortAngleDis(from, to)
	local maxAngle = 360
	local disAngle = (to - from) % maxAngle
	
	return ((2 * disAngle) % maxAngle) - disAngle
end

-- Lerps the angle and returns the result
function utils.LerpAngle(from, to, fraction)
	return from + utils.ShortAngleDis(from, to) * fraction
end

-- Returns a value smoothly in a range of two values (working lerp)
function utils.Lerp(from, to, fraction)
	return from + (to - from) * fraction
end

-- << RNG FUNCTIONS >> --
-- Returns a random value from a group of given arguments
function utils.Choose(rng, ...)
	local args = {...}
	
	return args[rng:RandomInt(#args) + 1]
end

function utils.ChooseRemove(rng, list)
	local size = #list
	if size == 0 then return nil end

	local index = rng:RandomInt(size) + 1
	local value = list[index]

	list[index] = list[size]
	list[size] = nil
	
	return value
end

-- Returns random number between two values (includes decimals if floats are present)
function utils.RandomRange(rng, minimum, maximum)
	if math.type(minimum + maximum) == "integer" then
		return minimum + rng:RandomInt(maximum - minimum + 1)
	end
	
	return minimum + rng:RandomFloat() * (maximum - minimum)
end

function utils.RandomLuck(baseLuck, minimum, maximum, maxLuck)
	return math.max(minimum, math.min(maximum, baseLuck / maxLuck))
end

-- << VECTOR FUNCTIONS >> --
-- Converts a given vector to a corresponding direction
function utils.VectorToDirection(vector)
	local angle = vector:GetAngleDegrees()
	
	if math.abs(angle) < 45 then
		return Direction.RIGHT
		
	elseif math.abs(angle) > 135 then
		return Direction.LEFT
		
	elseif angle > 0 then
		return Direction.DOWN
		
	elseif angle < 0 then
		return Direction.UP
	end
	
	return Direction.NO_DIRECTION
end

function utils.ContainsDirection(directions, direction)
    for _, dir in ipairs(directions) do
        if utils.VectorEquals(dir, direction) then
            return true
        end
    end
    return false
end

function utils.RotateVector(vector, degrees)
    local radians = math.rad(degrees)
    local cosAngle = math.cos(radians)
    local sinAngle = math.sin(radians)
    return Vector(
        utils.Round(vector.X * cosAngle - vector.Y * sinAngle, 2),
        utils.Round(vector.X * sinAngle + vector.Y * cosAngle, 2)
    )
end

-- Converts a given direction to a corresponding string
utils.DirectionToString = {
	[Direction.NO_DIRECTION] = "",
	[Direction.UP] 		= "Up",
	[Direction.LEFT] 	= "Left",
	[Direction.DOWN] 	= "Down",
	[Direction.RIGHT] 	= "Right",
}

utils.Directions = {
	Vector(0, -1),   	-- Up
    Vector(-1, 0),  	-- Left
    Vector(0, 1),   	-- Down
    Vector(1, 0)   	-- Right
}

utils.Eyes = {
	NONE = 0,
	RIGHT = 1,
	LEFT = 2,
	NUM_EYES = 3
}

-- Converts a given direction to a corresponding vector
utils.DirectionToVector = {
	[Direction.NO_DIRECTION] = Vector.Zero,
	[Direction.UP] 		= Vector(0, -1),
	[Direction.LEFT] 	= Vector(-1, 0),
	[Direction.DOWN] 	= Vector(0, 1),
	[Direction.RIGHT] 	= Vector(1, 0),
}

utils.DirectionToVectorReversed = {
	[Direction.NO_DIRECTION] = Vector.Zero,
    [Direction.DOWN] 	= Vector(0, -1),
	[Direction.RIGHT] 	= Vector(-1, 0),
	[Direction.UP] 		= Vector(0, 1),
	[Direction.LEFT] 	= Vector(1, 0),
}

function utils.GetNumRandomShots(rng, luck)
	-- Base de probabilidades con suerte baja o nula
	local probabilities = {0.6, 0.25, 0.1, 0.05}  -- Para 0, 1, 2, y 3 disparos respectivamente

	-- Aumentar la probabilidad de más disparos adicionales según la suerte
	local luckFactor = math.min(luck * 0.05, 0.35) -- Factor adicional basado en suerte, con un límite

	-- Ajustar las probabilidades en función de la suerte
	probabilities[1] = probabilities[1] - luckFactor  -- Reducimos la probabilidad de 0 disparos
	probabilities[2] = probabilities[2] + (luckFactor / 2)
	probabilities[3] = probabilities[3] + (luckFactor / 3)
	probabilities[4] = probabilities[4] + (luckFactor / 4)

	-- Generar un número aleatorio y seleccionar en base a las probabilidades
	local randValue = rng:RandomFloat()
	if randValue <= probabilities[1] then
		return 0
	elseif randValue <= probabilities[1] + probabilities[2] then
		return 1
	elseif randValue <= probabilities[1] + probabilities[2] + probabilities[3] then
		return 2
	else
		return 3
	end
end

function utils.GetTearDamage(player, weaponType)
	if not weaponType then
		weaponType = WeaponType.WEAPON_TEARS
	end
	return player:GetTearHitParams(weaponType).TearDamage
end

function utils.IsTearVariant(tear, flag)
	return tear.TearVariant == flag
end

function utils.HasTearFlag(tears, flag)
	return (tears.TearFlags & flag) > 0
end

function utils.SetTearFlag(tears, flag)
	tears.TearFlags = tears.TearFlags | flag
end

function utils.SetAllTearFlag(player, tears, otherTears)
	local pData = utils.GetData(player)
	tears.TearFlags = otherTears.TearFlags
	if utils.HasTearFlag(otherTears, TearFlags.TEAR_BELIAL) then
		utils.SetTearFlag(tears, TearFlags.TEAR_HOMING)
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_GLAUCOMA) then
		local rand = utils.RandomRange(pData.RNG, 0.0, 1.0) 
		local prob = 0.05
		if rand <= prob then
			utils.SetTearFlag(tears, TearFlags.TEAR_CONFUSION)
		end
	end
end


-- << PLAYER FUNCTIONS >> --
-- Returns true if the currently held item has a charge bar already
function utils.HasChargeBarItem(player)
	if player:HasCollectible(CollectibleType.COLLECTIBLE_MONTEZUMAS_REVENGE) 
	or player:HasCollectible(CollectibleType.COLLECTIBLE_MAW_OF_THE_VOID) 
	or player:HasCollectible(CollectibleType.COLLECTIBLE_REVELATION) 
	then
		return true
	end
	
	return false
end

-- Returns the current weapon type
function utils.GetWeaponType(player)
	for weaponType = WeaponType.WEAPON_TEARS, WeaponType.NUM_WEAPON_TYPES - 1 do
		if utils.IsUsingWeapon(player, weaponType) then
			return weaponType
		end
	end
	
	return WeaponType.WEAPON_TEARS
end

function utils.IsUsingWeapon(player, weaponType, force)
	force = force or false
	if player:HasWeaponType(weaponType) then
		return true
	elseif force then
		return false
	end
	if weaponType == WeaponType.WEAPON_BRIMSTONE
		and player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
		return true
	end
	if weaponType == WeaponType.WEAPON_LASER
		and (player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY)
			or player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY_2)
			or player:HasCollectible(CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO)
			or player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_5)) then
		return true
	end
	if weaponType == WeaponType.WEAPON_TECH_X
		and player:HasCollectible(CollectibleType.COLLECTIBLE_TECH_X) then
		return true
	end
	if weaponType == WeaponType.WEAPON_KNIFE
		and player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) then
		return true
	end
	if weaponType == WeaponType.WEAPON_BOMBS
		and player:HasCollectible(CollectibleType.COLLECTIBLE_DR_FETUS) then
		return true
	end
	if weaponType == WeaponType.WEAPON_ROCKETS
		and player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) then
		return true
	end
	if weaponType == WeaponType.WEAPON_FETUS
		and player:HasCollectible(CollectibleType.COLLECTIBLE_C_SECTION) then
		return true
	end
	if weaponType == WeaponType.WEAPON_LUDOVICO_TECHNIQUE
		and player:HasCollectible(CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE) then
		return true
	end
	if weaponType == WeaponType.WEAPON_SPIRIT_SWORD
		and player:HasCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD) then
		return true
	end
	if weaponType == WeaponType.WEAPON_MONSTROS_LUNGS
		and player:HasCollectible(CollectibleType.COLLECTIBLE_MONSTROS_LUNG) then
		return true
	end
	if weaponType == WeaponType.WEAPON_TEARS then
		return true
	end
	return false
end

-- Returns the estimated amount of player's shooting animation length (trial and error method)
function utils.GetHeadFrameDelayCalc(player)
	return player.MaxFireDelay > 10 and 7 + math.floor(player.MaxFireDelay * 0.45) or 7 -- 11
end

-- Returns the player from a tear
function utils.GetPlayerFromTear(tear)
    local entity = tear.Parent or tear.SpawnerEntity
	
    if entity then
        if entity.Type == EntityType.ENTITY_PLAYER then
            return entity:ToPlayer()
        elseif entity.Type == EntityType.ENTITY_FAMILIAR 
		and entity.Variant == FamiliarVariant.INCUBUS 
		then
            return entity:ToFamiliar().Player:ToPlayer()
        end
    end
	
    return nil
end

function utils.CheckFlyingStatus(player)
	local pData = utils.GetData(player)
	if player.CanFly and not pData.PrevFlyingValue then
		pData.IsRenderChanged = true
		pData.PrevFlyingValue = true
	elseif not player.CanFly and pData.PrevFlyingValue then
		pData.IsRenderChanged = true
		pData.PrevFlyingValue = false
	end
end

-- Función que verifica si el jugador tiene Crown of Light y si está activa
function utils.CheckCrownOfLightStatus(player)
	local pData = utils.GetData(player)

    -- Verificar si el jugador tiene el item Crown of Light
    --if player:HasCollectible(CollectibleType.COLLECTIBLE_CROWN_OF_LIGHT) then
    if true then
        -- Verificar si el jugador tiene salud completa
        if player:GetHearts() == (player:GetMaxHearts() + 2*player:GetBoneHearts() )
			and not pData.IsCrownDamaged then
			if not pData.IsCrownActive then 
				pData.IsRenderChanged = true
				--print("CROWN IS ACTIVATED!", pData.IsRenderChanged)
			end
            pData.IsCrownActive = true
        else
			if pData.IsCrownActive then 
				pData.IsRenderChanged = true
				--print("CROWN IS NOT ACTIVATED!")
			end
            pData.IsCrownActive = false
        end
    else
		--player:AddCollectible(CollectibleType.COLLECTIBLE_CROWN_OF_LIGHT)
		if not pData.IsCrownActive then 
			pData.IsRenderChanged = true
		end
        pData.IsCrownActive = true
    end

	return pData.IsCrownActive
end

function utils.IsDirectionalShooting(player)
	return player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED)
	or player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_OF_THE_OCCULT)
	or utils.IsUsingWeapon(player, WeaponType.WEAPON_LUDOVICO_TECHNIQUE)
	--or player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK)
end

function utils.GetMarkedPos(player)
	for _, mark in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.TARGET)) do
	  if mark.SpawnerEntity and GetPtrHash(player) == GetPtrHash(mark.SpawnerEntity) then
		return mark.Position
	  end
	end
	for _, mark in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.OCCULT_TARGET)) do
	  if mark.SpawnerEntity and GetPtrHash(player) == GetPtrHash(mark.SpawnerEntity) then
		return mark.Position
	  end
	end
	return nil
  end

-- Returns the shooting direction as a vector
function utils.GetShootingDirection(player, reversed)
	reversed = reversed or false
	if reversed then
		local fireDirection = utils.DirectionToVectorReversed[player:GetFireDirection()]
		local lastFireDirection = utils.DirectionToVectorReversed[utils.VectorToDirection(player:GetLastDirection())]
		return fireDirection, lastFireDirection
	else
		local fireDirection = utils.DirectionToVector[player:GetFireDirection()]
		local lastFireDirection = utils.DirectionToVector[utils.VectorToDirection(player:GetLastDirection())]
		return fireDirection, lastFireDirection
	end
end


-- Returns true if a specific character is in the game
function utils.IsCharacterInGame(character)
	for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_PLAYER)) do
		local player = entity:ToPlayer()
		
		if player:GetPlayerType() == character then return true end
	end
	
	return false
end

-- Returns true if any specific character has the wanted collectible
function utils.AnyCharacterHasCollectible(character, collectible, ignoreModifiers)
	for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_PLAYER)) do
		local player = entity:ToPlayer()
		
		if player:GetPlayerType() == character then
			if player:HasCollectible(collectible, ignoreModifiers) then
				return true
			end
		end
	end
	
	return false
end


function utils.ApplyDamageBonus(player, meleeDamageMult, meleeChargeDamageMult, adjustedChargeTime)
	local pData = utils.GetData(player)
	local damageBonus = 0.0
	local damageMultiplier = pData.IsFullCharge and meleeChargeDamageMult or meleeDamageMult  -- Doble daño si está cargado
	if player:HasCollectible(CollectibleType.COLLECTIBLE_PROPTOSIS) then
		if pData.IsFullCharge then
			damageMultiplier = 0.5
		else 
			damageMultiplier = 1.5
		end
	end
	if pData.IsCrownActive then
		damageMultiplier = damageMultiplier + 2.0
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_CHOCOLATE_MILK) then
		local percentCharged = pData.ChargeProgress / adjustedChargeTime
		damageMultiplier = damageMultiplier + percentCharged * 1.5
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_LUMP_OF_COAL) then
		damageMultiplier = damageMultiplier + 0.5
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_STYE) and pData.CurrentEye == utils.Eyes.RIGHT then
		damageMultiplier = damageMultiplier + 0.28
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_CHEMICAL_PEEL) and pData.CurrentEye == utils.Eyes.LEFT then
		damageBonus = damageBonus + 2.0
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_BLOOD_CLOT) and pData.CurrentEye == utils.Eyes.LEFT then
		damageBonus = damageBonus + 1.0
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_MONSTROS_LUNG) then
		damageMultiplier = damageMultiplier + 0.5
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_DEAD_EYE) then
		local bonusDeadEye = 0
		
		if pData.SuccesfulEnemyHit == 1 then
			bonusDeadEye = 0.25
		elseif pData.SuccesfulEnemyHit == 2 then
			bonusDeadEye = 0.5
		elseif pData.SuccesfulEnemyHit == 3 then
			bonusDeadEye = 1
		elseif pData.SuccesfulEnemyHit >= 4 then
			bonusDeadEye = 2
		end
		
		damageMultiplier = damageMultiplier + bonusDeadEye
	end
	--print("damageBonus: ", damageBonus)
	--print("damageMultiplier: ", damageMultiplier)
	--print("Delay: ", pData.ChargeProgress)
	return (player.Damage + damageBonus) * damageMultiplier
end

-- << ENTITY FUNCTIONS >> --
-- Checks if an entity is an actual enemy
function utils.IsRealEnemy(entity)
	if entity:IsEnemy()
	and entity.Type ~= EntityType.ENTITY_FIREPLACE
	and entity.Type ~= EntityType.ENTITY_MOVABLE_TNT
	and entity.Type ~= EntityType.ENTITY_POOP
	then
		return true
	end
	
	return false
end

-- Checks if an enemy can be damaged
function utils.IsActiveVulnerableEnemy(entity)
	return utils.IsRealEnemy(entity) and entity:IsActiveEnemy() and entity:IsVulnerableEnemy()
end

function utils.GetDirectionFromSource(source, entity)
	return (entity.Position - source.Position):Normalized()
end

-- Knock backs the wanted entity from the source
function utils.ApplyKnockback(source, entity, knockback)
	entity.Velocity = entity.Velocity + (entity.Position - source.Position):Resized(knockback)
end

function utils.ApplyPullback(source, entity, knockback)
    entity.Velocity = entity.Velocity + (source.Position - entity.Position):Resized(knockback)
end

-- Returns the nearest enemy in a radius
function utils.GetNearestEnemy(source, ignoreFriendly)
	local nearestEnemy = nil
	local nearestDistance = math.huge
	
	for _, enemy in ipairs(Isaac.FindInRadius(source.Position, 9999, EntityPartition.ENEMY)) do
		local distanceSqr = source.Position:DistanceSquared(enemy.Position)
		
		if distanceSqr < nearestDistance and utils.IsActiveVulnerableEnemy(enemy)
		and not (ignoreFriendly and enemy:HasEntityFlags(EntityFlag.FLAG_FRIENDLY))
		then
			nearestDistance = distanceSqr
			nearestEnemy = enemy
		end
	end
	
	return nearestEnemy
end

-- A list of all pickups that cannot be pushed with a melee attack (based on the Forgotten)
local PICKUP_PUSH_BLACKLIST = {
	[PickupVariant.PICKUP_MEGACHEST] 	= true, -- The melee tries to push this one but it stays in place anyways
	[PickupVariant.PICKUP_COLLECTIBLE] 	= true,
	[PickupVariant.PICKUP_SHOPITEM] 	= true,
	[PickupVariant.PICKUP_BIGCHEST] 	= true,
	[PickupVariant.PICKUP_TROPHY] 		= true,
	[PickupVariant.PICKUP_BED] 			= true,
	[PickupVariant.PICKUP_MOMSCHEST] 	= true,
	[PickupVariant.PICKUP_MEGACHEST] 	= true,
}

function utils.OpenChest(player, pickup)
	local pData = utils.GetData(player)
	local canOpenChest = (
		pickup.Variant == PickupVariant.PICKUP_REDCHEST or    -- Cofre rojo
		pickup.Variant == PickupVariant.PICKUP_SPIKEDCHEST or -- Cofre con pinchos
		pickup.Variant == PickupVariant.PICKUP_MIMICCHEST or -- Cofre con pinchos
		pickup.Variant == PickupVariant.PICKUP_WOODENCHEST or -- Cofre con pinchos
		pickup.Variant == PickupVariant.PICKUP_HAUNTEDCHEST or -- Cofre con pinchos
		pickup.Variant == PickupVariant.PICKUP_CHEST          -- Cofre normal
	)

	-- Verifica si el cofre ya está abierto
	local sprite = pickup:GetSprite()
	local isAlreadyOpen = sprite:IsFinished("Open") or sprite:IsPlaying("Opened")

	-- Si es un cofre abrible, forzar su apertura
	if canOpenChest and not isAlreadyOpen then
		if pData.Game and pData.Game:GetRoom() then
			local room = pData.Game:GetRoom()
			if room:GetType() ~= RoomType.ROOM_CHALLENGE or room:IsAmbushDone() then
				sprite:Play("Open", true)
				pickup:TryOpenChest(player)  -- Abre el cofre automáticamente
				utils.GetData(pickup).Opened = true  -- Marca el cofre como abierto
			end
		end
	end
end

-- Pushes near pickups (not includes bomb entities)
function utils.PushNearPickups(player, position, radius, knockback)
	for _, entity in pairs(Isaac.FindInRadius(position, radius, EntityPartition.PICKUP)) do
		local pickup = entity:ToPickup()
		
		if player and utils.IsDirectionalShooting(player) then
			utils.OpenChest(player, pickup)
		end

		if pickup and not PICKUP_PUSH_BLACKLIST[pickup.Variant] and not pickup:IsShopItem() then
			if pickup.EntityCollisionClass ~= EntityCollisionClass.ENTCOLL_NONE then
				utils.ApplyKnockback(player, pickup, knockback)
			end
		end
	end
end

function utils.GetItem(player, pickup, source, position, radius, knockback)
	local pData = utils.GetData(player)
	if not source and utils.GetData(pickup).PostGotWhip then return end
	if utils.GetData(pickup).PreGotWhip and not source then
		utils.GetData(pickup).PostGotWhip = true
	end
	if pickup.Variant == PickupVariant.PICKUP_HEART then
		--print("Hearts Test: ", player:CanPickRedHearts(), player:GetHearts(), player:GetMaxHearts(), player:HasFullHearts(), player:GetSoulHearts())
		if pickup.SubType == HeartSubType.HEART_FULL and player:CanPickRedHearts() then
			if not source then 
				player:AddHearts(2)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_HALF and player:CanPickRedHearts() then
			if not source then 
				player:AddHearts(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_SOUL and player:CanPickSoulHearts() then
			if not source then 
				player:AddSoulHearts(2)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_ETERNAL then
			if not source then 
				player:AddEternalHearts(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_DOUBLEPACK and player:CanPickRedHearts() then
			if not source then 
				player:AddHearts(4)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_BLACK and player:CanPickBlackHearts() then
			if not source then 
				player:AddBlackHearts(2)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_GOLDEN and player:CanPickGoldenHearts() then
			if not source then 
				player:AddGoldenHearts(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_HALF_SOUL and player:CanPickSoulHearts() then
			if not source then 
				player:AddSoulHearts(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_BLENDED and (player:CanPickRedHearts() or player:CanPickSoulHearts()) then
			if not source then 
				player:AddHearts(1)
				player:AddSoulHearts(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == HeartSubType.HEART_BONE and player:CanPickBoneHearts() then
			if not source then 
				player:AddBoneHearts(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif source then
			utils.PushNearPickups(source, position, radius, knockback)
			return
		end
	elseif pickup.Variant == PickupVariant.PICKUP_KEY then
		--print("Keys Test: ", player:GetNumKeys(), player:HasGoldenKey())
		if pickup.SubType == KeySubType.KEY_NORMAL and player:GetNumKeys() <= 98 then
			if not source then 
				player:AddKeys(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == KeySubType.KEY_DOUBLEPACK and player:GetNumKeys() <= 98 then
			if not source then 
				player:AddKeys(2)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == KeySubType.KEY_GOLDEN and not player:HasGoldenKey() then
			if not source then 
				player:AddGoldenKey()
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif source then
			utils.PushNearPickups(source, position, radius, knockback)
			return
		end
	elseif pickup.Variant == PickupVariant.PICKUP_COIN then
		--print("Coins Test: ", player:GetNumCoins())
		if pickup.SubType == CoinSubType.COIN_PENNY and (player:GetNumCoins() <= 98 or 
			(player:HasCollectible(CollectibleType.COLLECTIBLE_DEEP_POCKETS) and player:GetNumCoins() <= 998)) then
			if not source then 
				player:AddCoins(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == CoinSubType.COIN_DOUBLEPACK and (player:GetNumCoins() <= 98 or 
			(player:HasCollectible(CollectibleType.COLLECTIBLE_DEEP_POCKETS) and player:GetNumCoins() <= 998)) then
			if not source then 
				player:AddCoins(2)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == CoinSubType.COIN_NICKEL and (player:GetNumCoins() <= 98 or 
			(player:HasCollectible(CollectibleType.COLLECTIBLE_DEEP_POCKETS) and player:GetNumCoins() <= 998)) then
			if not source then 
				player:AddCoins(5)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == CoinSubType.COIN_DIME and (player:GetNumCoins() <= 98 or 
			(player:HasCollectible(CollectibleType.COLLECTIBLE_DEEP_POCKETS) and player:GetNumCoins() <= 998)) then
			if not source then 
				player:AddCoins(10)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == CoinSubType.COIN_LUCKYPENNY and (player:GetNumCoins() <= 98 or 
			(player:HasCollectible(CollectibleType.COLLECTIBLE_DEEP_POCKETS) and player:GetNumCoins() <= 998)) then
				utils.GetData(pickup).PreGotWhip = true
				utils.GetData(pickup).PreGotWhipNotWait = true
			--if not source then 
				--player:AddCoins(1)
				--player:AnimateHappy()
				--pData.Game:GetHUD():ShowItemText("LUCKY PENNY", "Luck up")
				--SFXManager():Play(SoundEffect.SOUND_LUCKYPICKUP)


				----pickup.Touched = true
			--else
				--pickup).PreGotWhip = true
			--end
		elseif pickup.SubType == CoinSubType.COIN_GOLDEN and (player:GetNumCoins() <= 98 or 
			(player:HasCollectible(CollectibleType.COLLECTIBLE_DEEP_POCKETS) and player:GetNumCoins() <= 998)) then
				utils.GetData(pickup).PreGotWhip = true
				utils.GetData(pickup).PreGotWhipNotWait = true
		elseif pickup.SubType == CoinSubType.COIN_STICKYNICKEL then
			--[[if not source then 
				player:AddCoins(10)
			else
				pickup).PreGotWhip = true
			end--]]
			--SFXManager():Play(SoundEffect.SOUND_NICKELDROP)
			pickup:GetSprite():Play("Touched", true)
		elseif source then
			utils.PushNearPickups(source, position, radius, knockback)
			return
		end
	elseif pickup.Variant == PickupVariant.PICKUP_BOMB then
		--print("Bombs Test: ", player:GetNumBombs(), player:HasGoldenBomb())
		if pickup.SubType == BombSubType.BOMB_NORMAL and player:GetNumBombs() <= 98 then
			if not source then 
				player:AddBombs(1)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == BombSubType.BOMB_DOUBLEPACK and player:GetNumBombs() <= 98 then
			if not source then 
				player:AddBombs(2)
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif pickup.SubType == BombSubType.BOMB_GOLDEN and not player:HasGoldenBomb() then
			if not source then 
				player:AddGoldenBomb()
			else
				utils.GetData(pickup).PreGotWhip = true
			end
		elseif source then
			utils.PushNearPickups(source, position, radius, knockback)
			return
		end
	elseif pickup.Variant == PickupVariant.PICKUP_TRINKET then
		if not source then 
			player:DropTrinket(player.Position)

			player:AddTrinket(pickup.SubType)
		else
			utils.GetData(pickup).PreGotWhip = true
		end
	elseif pickup.Variant == PickupVariant.PICKUP_TAROTCARD then
		if not source then 
			player:DropPocketItem(0, player.Position)

			player:AddCard(pickup.SubType)
		else
			utils.GetData(pickup).PreGotWhip = true
		end
	elseif pickup.Variant == PickupVariant.PICKUP_PILL then
		if not source then 
			player:DropPocketItem(0, player.Position)

			player:AddPill(pickup.SubType)
		else
			utils.GetData(pickup).PreGotWhip = true
		end
	elseif pickup.Variant == PickupVariant.PICKUP_LIL_BATTERY then
		if player:NeedsCharge(ActiveSlot.SLOT_PRIMARY) or player:NeedsCharge(ActiveSlot.SLOT_SECONDARY)
			or player:NeedsCharge(ActiveSlot.SLOT_POCKET) or player:NeedsCharge(ActiveSlot.SLOT_POCKET2) then
				utils.GetData(pickup).PreGotWhip = true
				utils.GetData(pickup).PreGotWhipNotWait = true
		elseif source then
			utils.PushNearPickups(source, position, radius, knockback)
			return
		end
	elseif pickup.Variant == PickupVariant.PICKUP_GRAB_BAG then
		utils.GetData(pickup).PreGotWhip = true
		utils.GetData(pickup).PreGotWhipNotWait = true
	elseif pickup.Variant == PickupVariant.PICKUP_ITEM then
		if not source then 
			player:DropPocketItem(0, player.Position)
			
			player:PickUpItem(pickup.SubType)
		else
			utils.GetData(pickup).PreGotWhip = true
		end
	elseif source then
		utils.PushNearPickups(source, position, radius, knockback)
		return
	end
	if utils.GetData(pickup).PreGotWhip and source and not utils.GetData(pickup).PreGotWhipNotWait then
		--pickup.Timeout = 20
		pickup.Wait = 20
	end
end

-- Recoge pickups cercanos
function utils.CollectNearPickups(source, position, radius, knockback, delayGrabbingFrames)
	-- Obtiene el jugador
	local player = source:ToPlayer()
	if not player then return end

	for _, entity in pairs(Isaac.FindInRadius(position, radius, EntityPartition.PICKUP)) do
		local pickup = entity:ToPickup()
		
		if pickup and not PICKUP_PUSH_BLACKLIST[pickup.Variant] and not pickup:IsShopItem() then
			if pickup.EntityCollisionClass ~= EntityCollisionClass.ENTCOLL_NONE then
				
				if not utils.GetData(pickup).PreGotWhip then
					utils.GetData(pickup).PreGotWhip = false
				end

				if not utils.GetData(pickup).PostGotWhip then
					utils.GetData(pickup).PostGotWhip = false
				end

				utils.OpenChest(player, pickup)

				if not utils.GetData(pickup).PreGotWhip then
					utils.GetItem(player, pickup, source, position, radius, knockback)
					if utils.GetData(pickup).PreGotWhip then
						utils.ApplyPullback(source, pickup, knockback)
						-- Guardar el tiempo de eliminación en los datos del jugador
						utils.GetData(player).PickupRemoveTimer = utils.GetData(player).PickupRemoveTimer or {}
						utils.GetData(player).PickupRemoveTimer[pickup] = Game():GetFrameCount() + delayGrabbingFrames
					end
					
				end

			end
		end
	end
end

-- Pushes near pickups bomb entities and others
function utils.PushNearOthers(source, position, radius, knockback)
	for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_BOMB)) do
		local bomb = entity:ToBomb()
		
		if bomb and position:Distance(bomb.Position) <= radius then
			utils.ApplyKnockback(source, bomb, knockback)
		end
	end
	for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_TEAR)) do
		local tear = entity:ToTear()
		
		if tear and position:Distance(tear.Position) <= radius then
			if tear.Variant == TearVariant.EYE then
				utils.ApplyKnockback(source, tear, knockback)
				SFXManager():Play(SoundEffect.SOUND_CLAP)
			end
		end
	end
end

function utils.GetAnimationName(player, weaponSprite)
	local pData = utils.GetData(player)
	local animName = ""
	--[[
	if string.find(weaponSprite:GetAnimation(), "Idle") then
		if pData.IsFullCharge then
			animName = "Long1"
		else
			animName = "Swing1"
		end
	elseif string.find(weaponSprite:GetAnimation(), "Swing2") or string.find(weaponSprite:GetAnimation(), "Long2") then
		if pData.IsFullCharge then
			animName = "Long1"
		else
			animName = "Swing1"
		end
	elseif string.find(weaponSprite:GetAnimation(), "Swing1") or string.find(weaponSprite:GetAnimation(), "Long1") then
		if pData.IsFullCharge then
			animName = "Long2"
		else
			animName = "Swing2"
		end
	end
	]]--
	if pData.CurrentEye == utils.Eyes.RIGHT then
		if pData.IsFullCharge then
			animName = "Long1"
		else
			if player:HasCollectible(CollectibleType.COLLECTIBLE_PUPULA_DUPLEX) then
				animName = "Wide1"
			else
				animName = "Swing1"
			end
		end
	elseif pData.CurrentEye == utils.Eyes.LEFT then
		if pData.IsFullCharge then
			animName = "Long2"
		else
			if player:HasCollectible(CollectibleType.COLLECTIBLE_PUPULA_DUPLEX) then
				animName = "Wide2"
			else
				animName = "Swing2"
			end
		end
	end
	if not utils.CheckCrownOfLightStatus(player) then
		animName = animName .. "Alt"
	end
	return animName
end

function utils.FireTearFromPosition(player, position, tearParams, tearVariant)
	local pData = utils.GetData(player)
	local tearSpawnedVel = utils.DirectionToVector[player:GetHeadDirection()]:Resized(utils.GetShotSpeed(player))

	local tearSpawned = player:FireTear(position, tearSpawnedVel, false, false, false, player)
	tearSpawned.Variant = tearVariant

	utils.SetAllTearFlag(player, tearSpawned, tearParams)
	tearSpawned.CollisionDamage = tearParams.TearDamage
	tearSpawned.Size = tearParams.TearScale
	tearSpawned.Color = tearParams.TearColor
	tearSpawned.Height = tearParams.TearHeight -- Maybe it's not interesting
end

function utils.FireTearFromHead(player, tearParams, tearVariant)
	local pData = utils.GetData(player)
	local tearSpawnedVel = utils.DirectionToVector[player:GetHeadDirection()]:Resized(utils.GetShotSpeed(player))

	local tearPos = player.Position + player.TearsOffset + Vector(0, player.TearHeight) 
	local tearSpawned = player:FireTear(tearPos, tearSpawnedVel, false, false, false, player)
	tearSpawned.Variant = tearVariant

	utils.SetAllTearFlag(player, tearSpawned, tearParams)
	tearSpawned.CollisionDamage = tearParams.TearDamage
	tearSpawned.Size = tearParams.TearScale
	tearSpawned.Color = tearParams.TearColor
	tearSpawned.Height = tearParams.TearHeight -- Maybe it's not interesting
end

function utils.FireTearFromEnemy(player, enemy, tearParams, tearVariant, ignoreTime)
	local pData = utils.GetData(player)
	local tearSpawnedVel = player:GetLastDirection():Resized(utils.GetShotSpeed(player))
	if ignoreTime >= 0 then
		local rand = (utils.RandomRange(pData.RNG, 0.0, 1.0) * 180.0) - 90.0
		if pData.CurrentEye == utils.Eyes.LEFT then
			tearSpawnedVel = utils.RotateVector(tearSpawnedVel, -90 + rand)
		else 
			tearSpawnedVel = utils.RotateVector(tearSpawnedVel, 90 + rand)
		end
	end
	--local tearSpawned = Isaac.Spawn(EntityType.ENTITY_TEAR, tearVariant, 0, enemy.Position, tearSpawnedVel, player):ToTear()
	local tearSpawned = player:FireTear(enemy.Position, tearSpawnedVel, false, false, false, player)
	tearSpawned.Variant = tearVariant

	--print("TEAR SPAWNED!")
	utils.SetAllTearFlag(player, tearSpawned, tearParams)
	tearSpawned.CollisionDamage = tearParams.TearDamage
	tearSpawned.Size = tearParams.TearScale
	tearSpawned.Color = tearParams.TearColor
	tearSpawned.Height = tearParams.TearHeight -- Maybe it's not interesting
	if ignoreTime >= 0 then
		utils.GetData(tearSpawned).IgnoreCollisionWith = {GetPtrHash(enemy)}
		utils.GetData(tearSpawned).IgnoreCollisionWithTime = ignoreTime
	end
	--tearSpawned:AddVelocity(player:GetTearMovementInheritance(tearSpawned.Velocity - player.Velocity))
	--tearSpawned:SetTimeout(30)
	--tearSpawned.CollisionDamage = player.Damage
	--SFXManager():Play(SoundEffect.SOUND_TEARS_FIRE)
end

function utils.AdjustProbabilities(player, tearParams)
	local pData = utils.GetData(player)
	utils.SetAllTearFlag(player, tearParams, tearParams)
	--The vanilla prob is 25% at 13 luck max, as it is random direction it would be better to be improved
	if player:HasCollectible(CollectibleType.COLLECTIBLE_EUTHANASIA) then
		local rand = utils.RandomRange(pData.RNG, 0.0, 1.0) 
		local prob = math.max(0.0333, math.min(0.25, player.Luck / 13.0))
		if rand <= prob then
			utils.SetTearFlag(tearParams, TearFlags.TEAR_NEEDLE)
		end
	end
	if player:HasCollectible(CollectibleType.COLLECTIBLE_GLAUCOMA) then
		local rand = utils.RandomRange(pData.RNG, 0.0, 1.0) 
		local prob = 0.05
		if rand <= prob then
			utils.SetTearFlag(tearParams, TearFlags.TEAR_CONFUSION)
		end
	end
end

function utils.CharmNearEnemies(source, position, radius)
	local player = source.Parent:ToPlayer()
	if player then 
		local pData = utils.GetData(player)
		for _, enemy in pairs(Isaac.FindInRadius(position, radius, EntityPartition.ENEMY)) do
			if enemy and utils.IsActiveVulnerableEnemy(enemy) then
				local eData = utils.GetData(enemy)
				if not eData then eData = {} end
				if not eData.FriendlyHealth then
					eData.FriendlyHealth = enemy.HitPoints
				end
				if not enemy:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then
					if eData.FriendlyHealth <= 0.0 then
						enemy:AddCharmed(EntityRef(source), -1)
						enemy:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
						SFXManager():Play(SoundEffect.SOUND_POWERUP_SPEWER)
					else
						local currentDamage = utils.ApplyDamageBonus(player, 1.0, 1.5, 1.0) / math.max(0.5, pData.FriendlyDamageSpeed / player.ShotSpeed)
						if enemy:IsBoss() then
							local tearParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS)
							utils.AdjustProbabilities(player, tearParams)
							utils.DamageSpecificEnemy(enemy, source, currentDamage, 0, 0, tearParams)
						else
							eData.FriendlyHealth = math.max(0.0, eData.FriendlyHealth - currentDamage)
						end
						--SFXManager():Play(SoundEffect.SOUND_GOOATTACH0)
						SFXManager():Play(SoundEffect.SOUND_KISS_LIPS1)
					end
				end
			end
		end
	end
end

function utils.DamageSpecificEnemy(enemy, source, damage, flag, countdown, tearParams)
	local ownCollisionIgnoreTime = 5
	local ownCollisionIgnoreTimeShort = 1
	local player = source.Parent:ToPlayer()

	if player then 
		local pData = utils.GetData(player)

		local spawnedTear = false

		if player:HasCollectible(CollectibleType.COLLECTIBLE_GODS_FLESH) then
			--print("Called correctly B")
			local rand = utils.RandomRange(pData.RNG, 0.0, 1.0)
			--print("Called correctly C")
			if rand <= 0.1 then
				--print("Called correctly D")
				--utils.SetTearFlag(tearParams, TearFlags.TEAR_SHRINK)
				enemy:AddShrink(EntityRef(source), 30)
				--print("Called correctly E")
			end
		end

		--print("Called correctly F")

		if utils.HasTearFlag(tearParams, TearFlags.TEAR_POISON) then
			enemy:AddPoison(EntityRef(source), 30, utils.GetTearDamage(player))
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_BURN) then
			enemy:AddBurn(EntityRef(source), 30, utils.GetTearDamage(player))
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_SLOW) then
			enemy:AddSlowing(EntityRef(source), 30, 0.5, Color(0.68, 0.85, 0.9, 1, 0, 0, 0))
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_CONFUSION) then
			enemy:AddConfusion(EntityRef(source), 30, true)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_FEAR) then
			enemy:AddFear(EntityRef(source), 30)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_FREEZE) then
			enemy:AddFreeze(EntityRef(source), 30)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_CHARM) then
			enemy:AddCharmed(EntityRef(source), 30)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_SHRINK) then
			--print("HAS SHRINK FLAG!")
			enemy:AddShrink(EntityRef(source), 30)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_MIDAS) then
			enemy:AddMidasFreeze(EntityRef(source), 30)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_ICE) then
			enemy:AddEntityFlags(EntityFlag.FLAG_ICE)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_BAIT) then
			enemy:AddEntityFlags(EntityFlag.FLAG_BAITED)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_BACKSTAB) then
			enemy:AddEntityFlags(EntityFlag.FLAG_BLEED_OUT)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_MAGNETIZE) then
			enemy:AddEntityFlags(EntityFlag.FLAG_MAGNETIZED)
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_BOOGER) then
			utils.FireTearFromEnemy(player, enemy, tearParams, TearVariant.BOOGER, 0)
			spawnedTear = true
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_SPORE) then
			utils.FireTearFromEnemy(player, enemy, tearParams, TearVariant.SPORE, 0)
			spawnedTear = true
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_EGG) then
			utils.FireTearFromEnemy(player, enemy, tearParams, TearVariant.EGG, 0)
			spawnedTear = true
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_HORN) then
			utils.FireTearFromEnemy(player, enemy, tearParams, tearParams.TearVariant, 0)
			spawnedTear = true
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_RIFT) then
			--local brimBallVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
			local effectSpawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RIFT, 0, enemy.Position, Vector.Zero, player):ToEffect()
			--brimBall:AddVelocity(player:GetTearMovementInheritance(brimBall.Velocity - player.Velocity))
			effectSpawned:SetTimeout(60)
			effectSpawned.CollisionDamage = player.Damage * 0.5
			effectSpawned.Size = player.Damage * 4.0
			SFXManager():Play(SoundEffect.SOUND_PORTAL_SPAWN)
		end

		if utils.IsTearVariant(tearParams, TearVariant.FIST) then
			local npcEnemy = enemy:ToNPC()
			if npcEnemy and not npcEnemy:IsBoss() then
				npcEnemy:ResetPathFinderTarget()
				enemy:AddConfusion(EntityRef(source), 60, false)
				enemy:AddEntityFlags(EntityFlag.FLAG_THROWN | EntityFlag.FLAG_APPLY_IMPACT_DAMAGE)
				utils.ApplyKnockback(player, enemy, pData.PunchKnockback)
				SFXManager():Play(SoundEffect.SOUND_PUNCH)
				--utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.NEEDLE, ownCollisionIgnoreTime)
				--spawnedTear = true
			end
		end
		if utils.IsTearVariant(tearParams, TearVariant.NEEDLE) then
			utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.NEEDLE, ownCollisionIgnoreTime)
			spawnedTear = true
		end
		if utils.IsTearVariant(tearParams, TearVariant.RAZOR) then
			utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.RAZOR, ownCollisionIgnoreTime)
			spawnedTear = true
		end
		if utils.IsTearVariant(tearParams, TearVariant.BONE) then
			utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.BONE, ownCollisionIgnoreTime)
			spawnedTear = true
		end
		if utils.IsTearVariant(tearParams, TearVariant.TOOTH) then
			utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.TOOTH, ownCollisionIgnoreTime)
			spawnedTear = true
		end
		if utils.IsTearVariant(tearParams, TearVariant.COIN) then
			utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.COIN, ownCollisionIgnoreTime)
			spawnedTear = true
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_STICKY) then
			--print("HAS EXPLOSIVO!")
			utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.EXPLOSIVO, ownCollisionIgnoreTimeShort)
			spawnedTear = true
		end
		if utils.HasTearFlag(tearParams, TearFlags.TEAR_BELIAL) then
			--print("HAS EXPLOSIVO!")
			utils.FireTearFromEnemy(player, enemy, tearParams,TearVariant.BELIAL, ownCollisionIgnoreTimeShort)
			spawnedTear = true
		end

		local randTear = utils.RandomRange(pData.RNG, 0.0, 1.0)
		local probTear = math.max(pData.DefaultTearProbability, math.min(pData.MaxTearProbability, player.Luck / 10.0))
		if not spawnedTear and randTear <= probTear then
			utils.FireTearFromEnemy(player, enemy, tearParams, tearParams.TearVariant, 0)
			spawnedTear = true
		end

		enemy:TakeDamage(
			damage, 
			DamageFlag.DAMAGE_COUNTDOWN | (flag or 0), 
			EntityRef(source), 
			countdown or 0
		)
	end
end

-- Damages enemies in a certain radius
function utils.DamageNearEnemies(source, position, radius, damage, flag, countdown)
	local player = source.Parent:ToPlayer()

	if player then 
		local pData = utils.GetData(player)
		local tearParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS)
		utils.AdjustProbabilities(player, tearParams)
		local enemiesHit = 0
		
		for _, enemy in pairs(Isaac.FindInRadius(position, radius, EntityPartition.ENEMY)) do
			if enemy and utils.IsActiveVulnerableEnemy(enemy) and not enemy:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then

				utils.DamageSpecificEnemy(enemy, source, damage, flag, countdown, tearParams)
				
				enemiesHit = enemiesHit + 1
			end
		end

		if player:HasCollectible(CollectibleType.COLLECTIBLE_DEAD_EYE) then
			if enemiesHit > 0 then
				pData.UnsuccesfulEnemyHit = 0
				pData.SuccesfulEnemyHit = pData.SuccesfulEnemyHit + 1
			else
				pData.UnsuccesfulEnemyHit = pData.UnsuccesfulEnemyHit + 1
				local rand = utils.RandomRange(pData.RNG, 0.0, 1.0) 
				if (pData.UnsuccesfulEnemyHit <= 1 and rand <= 0.2) or
				   (pData.UnsuccesfulEnemyHit == 2 and rand <= 0.33) or
				   (pData.UnsuccesfulEnemyHit >= 3 and rand <= 0.5) then
					pData.SuccesfulEnemyHit = 0
				end
			end
		end
	end
end

function utils.FindGridEntitiesByDistance(room, position, radius)
    local entitiesInRange = {}  -- Tabla para almacenar entidades dentro del rango

    for gridIndex = 0, room:GetGridSize() - 1 do
        local gridEntity = room:GetGridEntity(gridIndex)

        if gridEntity and position:Distance(gridEntity.Position) <= radius * 1.33 then
            table.insert(entitiesInRange, gridEntity)  -- Añade la entidad a la tabla si está en el rango
        end
    end

    return entitiesInRange
end

function utils.DestroyEntitiesFromEntity(entity, entityTypeToDestroy, entityVariantToDestroy)
	entityVariantToDestroy = entityVariantToDestroy or -1
	for _, roomEntity in pairs(Isaac.FindByType(entityTypeToDestroy, entityVariantToDestroy)) do
		if roomEntity.SpawnerEntity then
			if GetPtrHash(roomEntity.SpawnerEntity) == GetPtrHash(entity) then
				roomEntity:Remove()
			end
		end
	end
end

-- Destroys destructible grid entities in a radius (going by tears standarts)
function utils.DestroyNearGrid(effect, position, radius)
	local room = Game():GetRoom()
	local player = effect.Parent:ToPlayer()
	if player then 
		for _, gridEnemy in pairs(Isaac.FindInRadius(position, radius, EntityPartition.ENEMY)) do
			if gridEnemy.Type == EntityType.ENTITY_FIREPLACE and gridEnemy.Variant == 10 then
				gridEnemy:TakeDamage(999, 0, EntityRef(nil), 0) -- Only damage can trigger it's death effects for some reason
			end
			
			if gridEnemy.Type == EntityType.ENTITY_FIREPLACE and gridEnemy.Variant <= 1
			or gridEnemy.Type == EntityType.ENTITY_MOVABLE_TNT
			or gridEnemy.Type == EntityType.ENTITY_POOP
			then
				gridEnemy:Kill()
			end
		end

		local tearParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS)
		local entitiesInRange = utils.FindGridEntitiesByDistance(room, position, radius)

		for _, gridEntity in ipairs(entitiesInRange) do
			if utils.HasTearFlag(tearParams, TearFlags.TEAR_ACID) then
				--print("IS ACID FLAG!")
				if gridEntity:GetType() == GridEntityType.GRID_ROCK 
					or gridEntity:GetType() == GridEntityType.GRID_ROCKB 
					or gridEntity:GetType() == GridEntityType.GRID_ROCKT 
					or gridEntity:GetType() == GridEntityType.GRID_ROCK_BOMB 
					or gridEntity:GetType() == GridEntityType.GRID_ROCK_ALT 
					or gridEntity:GetType() == GridEntityType.GRID_DOOR 
					or gridEntity:GetType() == GridEntityType.GRID_ROCK_SPIKED 
					or gridEntity:GetType() == GridEntityType.GRID_ROCK_ALT2 
					or gridEntity:GetType() == GridEntityType.GRID_ROCK_GOLD 
					or gridEntity:GetType() == GridEntityType.GRID_WALL 
				then
					gridEntity:Destroy()
				end
			end
			if gridEntity:GetType() == GridEntityType.GRID_POOP 
				or gridEntity:GetType() == GridEntityType.GRID_TNT 
			then
				gridEntity:Destroy()  -- Destruir entidad si es de tipo GRID_POOP o GRID_TNT
			end
		end
	end
end

-- << SLOT FUNCTIONS >> --
-- Removes spawned rewards from slots
function utils.RemoveSlotRewards(slot)
	local radius = 400
	
    for _, pickup in pairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
        if pickup.FrameCount <= 1 
		and pickup.SpawnerType == 0 
        and pickup.Position:Distance(slot.Position) <= radius 
		then
            pickup:Remove()
        end
    end

    for _, bomb in pairs(Isaac.FindByType(EntityType.ENTITY_BOMB)) do
        if bomb.Variant == BombVariant.BOMB_TROLL 
		or bomb.Variant == BombVariant.BOMB_SUPERTROLL 
		or bomb.Variant == BombVariant.BOMB_GOLDENTROLL 
		then
			if bomb.FrameCount <= 1 
			and bomb.SpawnerType == 0 
			and bomb.Position:Distance(slot.Position) <= radius 
			then
				bomb:Remove()
			end
		end
    end
end

-- Prevents slot's death from an explosion
function utils.PreventSlotDeath(slot)
	if slot.GridCollisionClass == EntityGridCollisionClass.GRIDCOLL_GROUND then
		utils.RemoveSlotRewards(slot)
		
		local room = Game():GetRoom()
		local slotPos = room:GetGridPosition(room:GetGridIndex(slot.Position))
		local newSlot = Isaac.Spawn(slot.Type, slot.Variant, slot.SubType, slotPos, Vector.Zero, slot.SpawnerEntity)
		
		SFXManager():Play(SoundEffect.SOUND_THUMBS_DOWN)
		slot:Remove()
		
		return newSlot
	end
end



-- << SPRITE FUNCTIONS >> --
-- Returns the last frame of the animation
function utils.GetLastFrame(sprite)
	local currentFrame = sprite:GetFrame()
	local lastFrame = 0
	
	sprite:SetLastFrame()
	lastFrame = sprite:GetFrame()
	sprite:SetFrame(currentFrame)
	
	return lastFrame
end


-- << MINI CHARGE BAR API >> --
-- A mini charge bar API by Freakman which adds a simple to use charge bar
utils.Yami_ChargeBar = setmetatable({
    SetCharge = function(self, chargeAmount, maxCharge)
        local lastCharge = self.chargeProgress
		
        self.chargeProgress = chargeAmount
        self.chargeProgressMax = maxCharge

        if chargeAmount <= 0 then
            if lastCharge > 0 then
                self.chargeAnim = "Disappear"
            end
			
            self.isCharged = false
			
        elseif chargeAmount < maxCharge then
            self.chargeAnim = "Charging"
			
        elseif chargeAmount >= maxCharge and not self.isCharged then
            self.isCharged = true
            self.chargeAnim = "StartCharged"
        end
    end,
    Render = function(self, position, minCrop, maxCrop)
        if self.chargeAnim == "Charging" then
            self.chargeSprite:SetFrame(self.chargeAnim, math.floor((self.chargeProgress / self.chargeProgressMax) * 100))

        elseif self.chargeAnim ~= "None" then
            if self.chargeSprite:IsFinished(self.chargeAnim) then
                if self.chargeAnim == "StartCharged" then
                    self.chargeAnim = "Charged"
					
                elseif self.chargeAnim == "Disappear" then
                    self.chargeAnim = "None"
                end
            end

            if not self.chargeSprite:IsPlaying(self.chargeAnim) then
                self.chargeSprite:Play(self.chargeAnim, true)
            else
                if Isaac.GetFrameCount() % 2 == 0 then -- has to be played at half speed for some reason
                    self.chargeSprite:Update()
                end
            end
			
        elseif self.chargeAnim == "None" then
            return
        end

        self.chargeSprite:Render(Isaac.WorldToScreen(position), minCrop, maxCrop)
    end
}, {
    __call = function(self)
        local chargeArgs = setmetatable({
			chargeAnim = "None",
			chargeProgress = 0,
			chargeProgressMax = 0,
			chargeSprite = Sprite(),
			isCharged = false,
		}, {__index = self})
		
		chargeArgs.chargeSprite:Load("gfx/chargebarLust.anm2", true)
		
		return chargeArgs
    end
})

-- En el bucle de actualización, asegúrate de eliminar el pickup cuando sea el momento
function utils.OnUpdate(player)
	if player then
		local data = utils.GetData(player)
		if data.PickupRemoveTimer then
			for pickup, frame in pairs(data.PickupRemoveTimer) do
				if Game():GetFrameCount() >= frame and not utils.GetData(pickup).PostGotWhip then
					if not utils.GetData(pickup).PreGotWhipNotWait then
						utils.GetItem(player, pickup)
						pickup:PlayPickupSound()
						pickup:Remove()
					else
						utils.GetData(pickup).PreGotWhip = false
						utils.GetData(pickup).PostGotWhip = false
						utils.GetData(pickup).PreGotWhipNotWait = false
						utils.ApplyPullback(player, pickup, 30.0)
					end
					data.PickupRemoveTimer[pickup] = nil  -- Eliminar el timer después de usarlo
				elseif utils.GetData(pickup).PreGotWhipNotWait then
					--utils.ApplyPullback(player, pickup, 20.0)
				end
			end
		end
	end
end

return utils