local mod = RegisterMod("Lust (YamikaDesu)", 1) 

local version = "1.0"
local debugString = mod.Name .. " V" .. version .. " loaded successfully"
print(debugString)

local emptyPng = "gfx/empty.png"
local skinMain = "gfx/characters/costumes/character_Lust.png"
local skinAlt = "gfx/characters/costumes/character_Lust Alt.png"

local costume = Isaac.GetCostumeIdByPath("gfx/characters/character_Lust.anm2")
local costumeAlt = Isaac.GetCostumeIdByPath("gfx/characters/character_Lust Alt.anm2")
local costumeFlying = Isaac.GetCostumeIdByPath("gfx/characters/character_Lust Flying.anm2")
local costumeFlyingAlt = Isaac.GetCostumeIdByPath("gfx/characters/character_Lust Flying Alt.anm2")
local playerType = Isaac.GetPlayerTypeByName("Lust")
local weapon = Isaac.GetEntityVariantByName("Energy Whip")
local weaponAttack = Isaac.GetEntityVariantByName("Energy Whip Hitbox")

local utils = include("scripts/utils")

local rng = RNG()
local RECOMMENDED_SHIFT_IDX = 35

local meleeCanCollect = true -- Si el ataque cuerpo a cuerpo puede recoger o no objetos
local meleeDelayGrabbingFrames = 2 -- El delay del objeto llegando al jugador

-- Los tiempos se calculan por frames approx, por lo que normalmente 30-15 serían 1 seg

local meleeOffset = 12 
local meleeSpriteOffset = -10
local meleeSize = 16
local meleeDamageMult = 1.0
local meleeDistance = 50
local meleeRange = 40
local meleeKnockback = 10 -- Fuerza de empuje del melee
local meleeKnockbackSelf = 2 -- Fuerza inversa (al jugador) de empuje del melee
local meleeSizeTreshold = 1.6 -- Momento en el que los efectos del ataque se activan
local meleeTimeout = 9 -- Tiempo de espera para activar algunos efectos
local meleeWarmupMult = 0.66 -- Relativo al tiempo de espera, determina los frames exactos de ejecución de los efectos
local meleeChargeDamageMult = 1.5 -- Daño adicional que hace al cargar el arma
local meleeChargeInitDelay = 10 -- Tiempo de espera para diferenciar entre ataque y carga
local meleeChargeMinTime = 1  -- Tiempo mínimo de carga al tener la velocidad de disparo muy alta
local meleeChargeMaxTime = 30 -- Tiempo máximo de carga al tener la velocidad de disparo muy baja
local meleeLaserSize = 5
local directionalRotationSpeed = 20
local directionalDamageReduction = 5
local directionalSpeed = 2

local Lust = { -- Change Lorem everywhere to match your character. No spaces!
    DAMAGE = 0, -- These are all relative to Isaac's Lust stats.
    SPEED = 0,
    SHOTSPEED = .5,
    TEARHEIGHT = 1,
    TEARFALLINGSPEED = 1,
    LUCK = 0,
    FLYING = true,                                  
    TEARFLAG = 0, -- 0 is default
    TEARCOLOR = Color(1.0, 0.2, 0.6, 1.0, 0, 0, 0)  -- Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0) is default
}

-- Se ejecuta cuando el jugador está en caché
function Lust:OnCache(player, cacheFlag) -- I do mean everywhere!
    --if player:GetName() == "Lust" then -- Especially here!
    if player:GetPlayerType() == playerType then -- Especially here!
        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage + Lust.DAMAGE
        end
        if cacheFlag == CacheFlag.CACHE_SHOTSPEED then
            player.ShotSpeed = player.ShotSpeed + Lust.SHOTSPEED
        end
        if cacheFlag == CacheFlag.CACHE_RANGE then
            player.TearHeight = player.TearHeight - Lust.TEARHEIGHT
            player.TearFallingSpeed = player.TearFallingSpeed + Lust.TEARFALLINGSPEED
        end
        if cacheFlag == CacheFlag.CACHE_SPEED then
            player.MoveSpeed = player.MoveSpeed + Lust.SPEED
        end
        if cacheFlag == CacheFlag.CACHE_LUCK then
            player.Luck = player.Luck + Lust.LUCK
        end
        if cacheFlag == CacheFlag.CACHE_FLYING and Lust.FLYING then
            player.CanFly = true
        end
        if cacheFlag == CacheFlag.CACHE_TEARFLAG then
            player.TearFlags = player.TearFlags | Lust.TEARFLAG
        end
        if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
            player.TearColor = Lust.TEARCOLOR
        end
    end
end

function Lust:RemoveDataEffects(player, except)
    if player:GetPlayerType() == playerType then
        local pData = player:GetData()
        if pData.brimstoneBall and pData.brimstoneBall ~= except then 
            pData.brimstoneBall:Remove() 
            pData.brimstoneBall = nil
        end
        if pData.fireTechX and pData.fireTechX ~= except then 
            pData.fireTechX:Remove() 
            pData.fireTechX = nil
        end
        --if pData.mawVoidLaser and pData.mawVoidLaser ~= except then 
        --    pData.mawVoidLaser:Remove() 
        --    pData.mawVoidLaser = nil
        --end
    end
end

-- Inicializa al jugador
function Lust:InitPlayer(player)
    if player:GetPlayerType() == playerType then
        --player:AddNullCostume(costume)
        rng:SetSeed(Game():GetSeeds():GetStartSeed(), RECOMMENDED_SHIFT_IDX)
        local pData = player:GetData()
        pData.MeleeAttackTriggered = false
        pData.MeleeCooldown = 0
        pData.ChargeProgress = 0
        pData.DoOnceChargingSound = true
        pData.IsCrownActive = true
        pData.IsRenderChanged = true
        pData.PrevFlyingValue = Lust.FLYING
        pData.HadDirectionalMovement = false
        pData.IsInNewRoom = true
        pData.MomKnifeItem = nil
        pData.IsKnockBacked = false
        pData.IsCrownDamaged = false
        pData.CurrentEye = utils.Eyes.LEFT -- It will start with Right
        pData.RNG = rng
        pData.PrevAttackDirection = nil
        pData.TimeMarkSameDirection = 0
        pData.TimeAttacking = 0
        pData.TimeWithoutAttacking = 0
        pData.DeadToothRing = nil
        pData.EyeGreedAttacks = 0
        pData.IsDeadFirstCheck = true
        pData.DrFetusBombDirectional = nil
        pData.SpawnedFireDirectional = nil
        pData.IsNewRoom = true
        pData.MeleeLastFireDirection = Vector(0,0)
        --pData.MawOfVoidReady = false
        Lust:RemoveDataEffects(player)
    end
end

-- Inicializa el ataque cuerpo a cuerpo
function Lust:InitMelee(effect)
    if effect.Variant == weapon then
        effect.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
    elseif effect.Variant == weaponAttack then
        local hitboxData = effect:GetData()
        effect.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
        hitboxData.EntityList = {}
    end
end

-- Gestiona la lógica del arma
function Lust:UpdateWeapon(player)
    local pData = player:GetData()
        
    if player:GetPlayerType() ~= playerType then
        if pData.MeleeWeapon then
            pData.MeleeWeapon:Remove()
            pData.MeleeWeapon = nil
        end
    else
        if not pData.MeleeWeapon then
            pData.MeleeWeapon = Isaac.Spawn(EntityType.ENTITY_EFFECT, weapon, 0, player.Position, Vector.Zero, player):ToEffect()
            pData.MeleeWeapon:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
            pData.MeleeWeapon:FollowParent(player)
            pData.MeleeWeapon.ParentOffset = Vector(0, meleeOffset)
            --pData.MeleeWeapon:Update()
            
            for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, weapon)) do 
                if entity:HasCommonParentWithEntity(player) then
                    if GetPtrHash(entity) ~= GetPtrHash(pData.MeleeWeapon) then
                        entity:Remove()
                    end
                end
            end
        elseif pData.MeleeWeapon and not pData.MeleeWeapon:Exists() then
            pData.MeleeWeapon:Remove()
            pData.MeleeWeapon = nil
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) then
            local knifeDirection = utils.DirectionToVectorReversed[player:GetHeadDirection()]
            if not pData.MomKnifeItem then
                pData.MomKnifeItem = Isaac.Spawn(EntityType.ENTITY_KNIFE, 0, 0, player.Position, Vector.Zero, player):ToKnife()
                pData.MomKnifeItem:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                --pData.MomKnifeItem:AddTearFlags(TearFlags.TEAR_PERSISTENT)
                pData.MomKnifeItem.Parent = player
                --pData.MomKnifeItem:SetDamageSource(EntityType.ENTITY_PLAYER)
                pData.MomKnifeItem.CollisionDamage = player.Damage
                pData.MomKnifeItem.Position = player.Position + Vector(0, meleeOffset)
                --pData.MomKnifeItem:Update()
            end
            if pData.MomKnifeItem then
                local meleeSprite = pData.MomKnifeItem:GetSprite()
                pData.MomKnifeItem.Position = utils.Lerp(pData.MomKnifeItem.Position, player.Position + knifeDirection:Resized(meleeOffset), 0.4)
                pData.MomKnifeItem.Rotation = utils.LerpAngle(utils.Round(pData.MomKnifeItem.Rotation, 3), knifeDirection:GetAngleDegrees(), 0.4)
                --print(knifeDirection:GetAngleDegrees())
                --pData.MomKnifeItem.Position = player.Position + knifeDirection:Resized(meleeOffset)
                --pData.MomKnifeItem.SpriteRotation = knifeDirection:GetAngleDegrees()
                --pData.MomKnifeItem.SpriteOffset = knifeDirection:Resized(meleeOffset)
                pData.MomKnifeItem.SpriteScale = utils.GetMeleeSize(player) * Vector.One
                pData.MomKnifeItem:SetSize(utils.GetMeleeSize(player) * meleeSize, pData.MomKnifeItem.SizeMulti, 0)
                meleeSprite:LoadGraphics()
            end
        else
            if pData.MomKnifeItem then
                pData.MomKnifeItem:Remove()
                pData.MomKnifeItem = nil
            end
        end
    
        if pData.MeleeWeapon and pData.MeleeWeapon:Exists() then
            local melee = pData.MeleeWeapon
            local meleeSprite = melee:GetSprite()
            local meleeHitbox = pData.MeleeHitbox
            local meleeDirection = (meleeHitbox and meleeHitbox:Exists()) 
                                and (meleeHitbox.Position - player.Position) 
                                or utils.DirectionToVector[player:GetHeadDirection()] 
            if utils.IsDirectionalShooting(player) then
                local markedTargetPos = utils.GetMarkedPos(player)
                if markedTargetPos then
                    melee.Position = markedTargetPos
                else 
                    if not pData.HadDirectionalMovement or pData.IsNewRoom then
                        melee.Position = player.Position
                    else
                        melee.Position = melee.Position + player:GetAimDirection():Resized(utils.GetShotSpeed(player)*directionalSpeed)
                    end
                end
                melee.IsFollowing = false
                melee.SpriteRotation = melee.SpriteRotation + directionalRotationSpeed
                if melee.SpriteRotation >= 360 then
                    melee.SpriteRotation = melee.SpriteRotation - 360 
                end
                melee.DepthOffset = 2
                melee.SpriteOffset = Vector(0, 0)
                melee.SpriteScale = utils.GetMeleeSize(player) * Vector.One
                melee:SetSize(utils.GetMeleeSize(player) * meleeSize, melee.SizeMulti, 0)
            else
                if pData.HadDirectionalMovement then
                    melee.IsFollowing = true
                end
                if player:IsExtraAnimationFinished() then
                    melee.ParentOffset = utils.Lerp(melee.ParentOffset, meleeDirection:Resized(meleeOffset), 0.4)
                    melee.SpriteRotation = utils.LerpAngle(utils.Round(melee.SpriteRotation, 3), meleeDirection:GetAngleDegrees() - 90, 0.4)
                end
                
                melee.DepthOffset = -5
                melee.SpriteOffset = Vector(0, meleeSpriteOffset)
                melee.SpriteScale = utils.GetMeleeSize(player) * Vector.One
                melee:SetSize(utils.GetMeleeSize(player) * meleeSize, melee.SizeMulti, 0)
                meleeSprite:ReplaceSpritesheet(1, emptyPng)
                meleeSprite:ReplaceSpritesheet(2, emptyPng)
                meleeSprite:LoadGraphics()
            end
            pData.HadDirectionalMovement = utils.IsDirectionalShooting(player)
        end
    end

end

-- Gestiona el comportamiento de los efectos del ataque a melee
function Lust:UpdateEffect(effect)
    if effect.Variant == weaponAttack or effect.Variant == weapon then
        if effect.Parent and effect.Parent:ToPlayer() then
            local player = effect.Parent:ToPlayer()
            if player:GetPlayerType() == playerType then
                if utils.IsDirectionalShooting(player) and effect.Variant == weapon then
                    --if meleeCanCollect and not player:IsCoopGhost() then
                    --    utils.CollectNearPickups(player, effect.Position, effect.Size, meleeKnockback, meleeDelayGrabbingFrames, 6)
                    --else
                    utils.PushNearPickups(player, effect.Position, effect.Size, meleeKnockback)
                    --end
                    utils.PushNearBombs(player, effect.Position, effect.Size, meleeKnockback)
                    utils.DamageNearEnemies(effect, effect.Position, effect.Size, effect.CollisionDamage)
                    utils.DestroyNearGrid(effect, effect.Position, effect.Size)
                    effect.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
                elseif not utils.IsDirectionalShooting(player) and effect.Variant == weaponAttack then
                    if effect.Timeout <= math.ceil(meleeTimeout * meleeWarmupMult) and effect.Timeout == 6 then -- Small delay before actual  hittin'
                        if meleeCanCollect and not player:IsCoopGhost() then
                            utils.CollectNearPickups(player, effect.Position, effect.Size, meleeKnockback, meleeDelayGrabbingFrames)
                        else
                            utils.PushNearPickups(player, effect.Position, effect.Size, meleeKnockback)
                        end
        
                        utils.PushNearBombs(player, effect.Position, effect.Size, meleeKnockback)
                        utils.DamageNearEnemies(effect, effect.Position, effect.Size, effect.CollisionDamage)
                        utils.DestroyNearGrid(effect, effect.Position, effect.Size)
                        
                        effect.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
                    end
                    if effect.Timeout <= 0 then effect:Remove() end
                end
            end
        end
    end
end

-- Gestiona la lógica una vez golpea a la entidad
function Lust:OnHit(entity, amount, flag, source, countdown)
    if source.Type == EntityType.ENTITY_EFFECT and source.Variant == weaponAttack then
        local hitbox = source.Entity:ToEffect()
        local hitboxData = hitbox:GetData()
        
        if not hitboxData.EntityList or utils.IsValueInList(hitboxData.EntityList, entity.InitSeed) then return false end
        
        if hitbox.Parent and hitbox.Parent:ToPlayer() then
            local player = hitbox.Parent:ToPlayer()
            
            if player:GetPlayerType() == playerType then

                local pData = player:GetData()

                if not pData.IsKnockBacked then 
                    utils.ApplyKnockback(entity, player, meleeKnockbackSelf)
                    utils.ApplyKnockback(player, entity, meleeKnockback)
                    pData.IsKnockBacked = true
                end
                SFXManager():Play(SoundEffect.SOUND_WHIP_HIT)
            end
        end
        
        table.insert(hitboxData.EntityList, entity.InitSeed) -- Would be better idea to do that for pickups aswell, so they don't get pushed around so much
    end
end

-- Gestiona lo que ocurre después del melee (sinergias principalmente)
function Lust:PostUpdateMelee(player, lastFireDirection, effectPosAlt)
    if player:GetPlayerType() == playerType then
        local pData = player:GetData()
        local tearParams = player:GetTearHitParams(WeaponType.WEAPON_TEARS)
        
        if not utils.IsDirectionalShooting(player) then
            Lust:RemoveDataEffects(player)
        end
        --local fireDirection, lastFireDirection = utils.GetShootingDirection(player)
        local effectPos = player.Position + lastFireDirection:Resized(meleeDistance) 
        local effectPosTear = effectPos + player.TearsOffset + Vector(0, player.TearHeight) 
        -- Solo activar el escudo melee si el jugador tiene ítems que bloquean proyectiles.

        if utils.HasTearFlag(tearParams, TearFlags.TEAR_SHIELDED) then
            local internalPos = effectPos
            if utils.IsDirectionalShooting(player) then
                internalPos = effectPosAlt
            end
            --print("HAS SHIELDED")
            -- Buscar proyectiles en el área del melee y eliminarlos.
            local entities = Isaac.FindInRadius(internalPos, meleeDistance, EntityPartition.BULLET)
            for _, entity in ipairs(entities) do
                if entity.Type == EntityType.ENTITY_PROJECTILE and GetPtrHash(entity.SpawnerEntity) ~= GetPtrHash(player) then
                    if utils.HasTearFlag(tearParams, TearFlags.TEAR_HOMING) or utils.HasTearFlag(tearParams, TearFlags.TEAR_BELIAL) then
                        --print("HAS HOMING")
                        entity.SpawnerEntity = player
                        entity.Velocity = Vector(entity.Velocity.X * -1.0, entity.Velocity.Y * -1.0)
                        local projectile = entity:ToProjectile()
                        if projectile then
                            projectile:AddProjectileFlags(ProjectileFlags.CANT_HIT_PLAYER | ProjectileFlags.HIT_ENEMIES)
                        end
                    else
                        entity:Remove()  -- Eliminar proyectil.
                    end
                    SFXManager():Play(SoundEffect.SOUND_SCYTHE_BREAK)  -- Sonido opcional al bloquear.
                end
            end
        end

        local hasLaunchedFire = false
        local bothItems = player:HasCollectible(CollectibleType.COLLECTIBLE_GHOST_PEPPER) and player:HasCollectible(CollectibleType.COLLECTIBLE_BIRDS_EYE)

        -- Si tiene ambos ítems, ajustamos la probabilidad para ambos tipos de fuego
        local prob = math.max(0.0833, math.min(0.5, player.Luck/10.0))
        if bothItems then
            prob = math.max(0.125, math.min(1.0, player.Luck/7.0))
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_GHOST_PEPPER) then
            --print("HAS GHOST PEPPER!")
            local rand = utils.RandomRange(rng, 0.0, 1.0)
            --print("rand: ", rand)
            --print("prob: ", prob)
            -- Verificamos si se debe lanzar fuego y cuál lanzar (azul o rojo si tiene ambos ítems)
            if rand <= prob then
                if bothItems and utils.RandomRange(rng, 0, 1) < 0.5 then
                    -- 50% de probabilidad de alternar entre azul y rojo cuando tiene ambos ítems
                    if utils.IsDirectionalShooting(player) then
                        if not pData.SpawnedFireDirectional then
                            --print("SPAWNED RED FIRE!") 
                            pData.SpawnedFireDirectional = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, Vector.Zero, player):ToEffect()
                            pData.SpawnedFireDirectional.CollisionDamage = player.Damage * 3.0
                            pData.SpawnedFireDirectional:SetTimeout(60)
                            pData.SpawnedFireDirectional:GetData().IgnoreCollisionWithVariant = {weaponAttack, weapon}
                            pData.SpawnedFireDirectional:GetData().IgnoreCollisionWithTime = 5.0
                        end
                    else
                        --print("SPAWNED RED FIRE!") 
                        local redFlameVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                        local redFlame = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, redFlameVel, player):ToEffect()
                        redFlame.CollisionDamage = player.Damage * 3.0
                        redFlame:SetTimeout(60)
                        redFlame:GetData().IgnoreCollisionWithVariant = {weaponAttack, weapon}
                        redFlame:GetData().IgnoreCollisionWithTime = 5.0
                    end
                else
                    if utils.IsDirectionalShooting(player) then
                        if not pData.SpawnedFireDirectional then
                            --print("SPAWNED BLUE FIRE!") 
                            pData.SpawnedFireDirectional = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, effectPos, Vector.Zero, player):ToEffect()
                            pData.SpawnedFireDirectional.CollisionDamage = player.Damage * 3.0
                            pData.SpawnedFireDirectional:SetTimeout(60)
                            pData.SpawnedFireDirectional:GetData().IgnoreCollisionWithVariant = {weaponAttack, weapon}
                            pData.SpawnedFireDirectional:GetData().IgnoreCollisionWithTime = 5.0
                        end
                    else
                        --print("SPAWNED BLUE FIRE!")
                        local blueFlameVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                        local blueFlame = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, effectPos, blueFlameVel, player):ToEffect()
                        blueFlame.CollisionDamage = player.Damage * 3.0
                        blueFlame:SetTimeout(60)
                        blueFlame:GetData().IgnoreCollisionWithVariant = {weaponAttack, weapon}
                        blueFlame:GetData().IgnoreCollisionWithTime = 5.0
                    end
                end
                hasLaunchedFire = true
            end
            if pData.SpawnedFireDirectional then
                pData.SpawnedFireDirectional.Position = effectPosAlt
                pData.SpawnedFireDirectional.Velocity = Vector.Zero
                if pData.SpawnedFireDirectional:IsDead() then
                    pData.SpawnedFireDirectional:Remove()
                    pData.SpawnedFireDirectional = nil
                end
            end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRDS_EYE) and not hasLaunchedFire then
            local rand = utils.RandomRange(rng, 0.0, 1.0)
            if rand <= prob then
                if utils.IsDirectionalShooting(player) then
                    if not pData.SpawnedFireDirectional then
                        --print("SPAWNED RED FIRE!")
                        pData.SpawnedFireDirectional = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, Vector.Zero, player):ToEffect()
                        pData.SpawnedFireDirectional.CollisionDamage = player.Damage * 3.0
                        pData.SpawnedFireDirectional:SetTimeout(60)
                        pData.SpawnedFireDirectional:GetData().IgnoreCollisionWithVariant = {weaponAttack, weapon}
                        pData.SpawnedFireDirectional:GetData().IgnoreCollisionWithTime = 5.0
                    end
                else
                    --print("SPAWNED RED FIRE!")
                    local redFlameVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                    local redFlame = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, redFlameVel, player):ToEffect()
                    redFlame.CollisionDamage = player.Damage * 3.0
                    redFlame:SetTimeout(60)
                    redFlame:GetData().IgnoreCollisionWithVariant = {weaponAttack, weapon}
                    redFlame:GetData().IgnoreCollisionWithTime = 5.0
                end
                hasLaunchedFire = true
            end
            if pData.SpawnedFireDirectional then
                pData.SpawnedFireDirectional.Position = effectPosAlt
                pData.SpawnedFireDirectional.Velocity = Vector.Zero
                if pData.SpawnedFireDirectional:IsDead() then
                    pData.SpawnedFireDirectional:Remove()
                    pData.SpawnedFireDirectional = nil
                end
            end
        end

        if player:HasCollectible(CollectibleType.COLLECTIBLE_LARGE_ZIT) then
            local probShot = 0.1 -- Specify the prob of the large zit attack
            local rand = utils.RandomRange(rng, 0.0, 1.0)
            if rand <= prob then
                local zitCreep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, 0, effectPos, Vector.Zero, player):ToEffect()
            end
        end

        if utils.HasTearFlag(tearParams, TearFlags.TEAR_FETUS) 
            or utils.IsUsingWeapon(player, WeaponType.WEAPON_FETUS) then
            --print("SHOT TEAR FETUS!")
            --if pData.IsFullCharge then
            local tearVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
            local tearSpawned = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.FETUS, 0, effectPos, tearVel, player):ToTear()
            utils.SetAllTearFlag(player, tearSpawned, tearParams)
            tearSpawned:AddTearFlags(TearFlags.TEAR_HOMING | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL)
            if utils.IsUsingWeapon(player, WeaponType.WEAPON_BRIMSTONE) then
                --print("Added brimstone fetus!!")
                tearSpawned.TearFlags = tearSpawned.TearFlags | TearFlags.TEAR_FETUS_BRIMSTONE
            end
            if utils.IsUsingWeapon(player, WeaponType.WEAPON_SPIRIT_SWORD) then
                tearSpawned.TearFlags = tearSpawned.TearFlags | TearFlags.TEAR_FETUS_SWORD
            end
            if utils.IsUsingWeapon(player, WeaponType.WEAPON_KNIFE) then
                tearSpawned.TearFlags = tearSpawned.TearFlags | earFlags.TEAR_FETUS_KNIFE
            end
            if utils.IsUsingWeapon(player, WeaponType.WEAPON_TECH_X) then
                tearSpawned.TearFlags = tearSpawned.TearFlags | TearFlags.TEAR_FETUS_TECHX
            end
            if utils.IsUsingWeapon(player, WeaponType.WEAPON_LASER) then
                tearSpawned.TearFlags = tearSpawned.TearFlags | TearFlags.TEAR_FETUS_TECH
            end
            if utils.IsUsingWeapon(player, WeaponType.WEAPON_BONE) then
                tearSpawned.TearFlags = tearSpawned.TearFlags | TearFlags.TEAR_FETUS_BONE
            end
            if utils.IsUsingWeapon(player, WeaponType.WEAPON_BOMBS) then
                tearSpawned.TearFlags = tearSpawned.TearFlags | TearFlags.TEAR_FETUS_BOMBER
            end
            tearSpawned.CollisionDamage = player.Damage
            --end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_OF_GREED) then
            if pData.EyeGreedAttacks >= 19 then
                if player:GetNumCoins() > 0 then
                    player:AddCoins(-1)
                end
                local tearVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                local tearSpawned = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.COIN, 0, effectPosTear, tearVel, player):ToTear()
                tearSpawned:AddTearFlags(TearFlags.TEAR_MIDAS | TearFlags.TEAR_GREED_COIN)  
                tearSpawned.CollisionDamage = player.Damage
                --tearSpawned:SetTimeout(30)
                pData.EyeGreedAttacks = 0
            else
                pData.EyeGreedAttacks = pData.EyeGreedAttacks + 1
            end
        end
        if utils.IsUsingWeapon(player, WeaponType.WEAPON_BRIMSTONE)
            and not (utils.IsUsingWeapon(player, WeaponType.WEAPON_TECH_X)
                    or utils.IsUsingWeapon(player, WeaponType.WEAPON_LASER)) then
            if utils.IsDirectionalShooting(player) then
                if not pData.brimstoneBall then
                    pData.brimstoneBall = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BRIMSTONE_BALL, 0, effectPosAlt, Vector.Zero, player):ToEffect()
                    pData.brimstoneBall:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                    pData.brimstoneBall:FollowParent(player)
                    pData.brimstoneBall.IsFollowing = false
                end
                --Lust:RemoveDataEffects(player, pData.brimstoneBall)
                pData.brimstoneBall.Position = effectPosAlt
                --utils.SetAllTearFlag(player, pData.brimstoneBall, tearParams)
                pData.brimstoneBall.CollisionDamage = player.Damage / directionalDamageReduction
            else
                if pData.IsFullCharge then
                    local tearW = player:FireBrimstone(lastFireDirection, player, player.Damage):ToLaser()
                    utils.SetAllTearFlag(player, tearW, tearParams)
                else
                    local brimBallVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                    local brimBall = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BRIMSTONE_BALL, 0, effectPosTear, brimBallVel, player):ToEffect()
                    brimBall:AddVelocity(player:GetTearMovementInheritance(brimBall.Velocity - player.Velocity))
                    brimBall:SetTimeout(30)
                    brimBall.CollisionDamage = player.Damage
                end
                SFXManager():Play(SoundEffect.SOUND_BLOOD_LASER)
            end
        end
        if utils.IsUsingWeapon(player, WeaponType.WEAPON_TECH_X) 
            or utils.IsUsingWeapon(player, WeaponType.WEAPON_LASER) then
            if utils.IsDirectionalShooting(player) then
                if pData.brimstoneBall then
                    pData.brimstoneBall:Remove() 
                    pData.brimstoneBall = nil
                end
                if not pData.fireTechX then
                    pData.fireTechX = player:FireTechXLaser(effectPosAlt, Vector.Zero, meleeLaserSize, player, player.Damage / directionalDamageReduction):ToLaser()
                    pData.fireTechX:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                end
                --Lust:RemoveDataEffects(player, pData.fireTechX)
                pData.fireTechX.Position = effectPosAlt
                utils.SetAllTearFlag(player, pData.fireTechX, tearParams)
            else 
                if pData.IsFullCharge then
                    local tearW = player:FireTechLaser(effectPos, LaserOffset.LASER_TECH1_OFFSET, lastFireDirection, false, false, player, player.Damage):ToLaser()
                    if utils.IsUsingWeapon(player, WeaponType.WEAPON_BRIMSTONE) then
                        --print("BRIM TECH WITH WEAPON TECH X!")
                        tearW.Variant = LaserVariant.BRIM_TECH
                    end
                    utils.SetAllTearFlag(player, tearW, tearParams)
                else
                    local tearW = player:FireTechXLaser(effectPos, lastFireDirection, meleeLaserSize, player, player.Damage):ToLaser()
                    tearW:AddVelocity(player:GetTearMovementInheritance(tearW.Velocity - player.Velocity))
                    tearW:SetTimeout(30)
                    utils.SetAllTearFlag(player, tearW, tearParams)
                end
                SFXManager():Play(SoundEffect.SOUND_REDLIGHTNING_ZAP_BURST)
            end
        end
        -- or player:HasCollectible(CollectibleType.COLLECTIBLE_EPIC_FETUS) 
        if utils.IsUsingWeapon(player, WeaponType.WEAPON_BOMBS) 
            or utils.IsUsingWeapon(player, WeaponType.WEAPON_ROCKETS)  then
            if utils.IsDirectionalShooting(player) then
                if not pData.DrFetusBombDirectional then
                    pData.DrFetusBombDirectional = player:FireBomb(effectPosAlt, Vector.Zero, player)
                    --pData.DrFetusBombDirectional:AddVelocity(Vector(-pData.DrFetusBombDirectional.Velocity.X, -pData.DrFetusBombDirectional.Velocity.Y))
                    if utils.IsUsingWeapon(player, WeaponType.WEAPON_BRIMSTONE) then
                        pData.DrFetusBombDirectional:AddTearFlags(TearFlags.TEAR_BRIMSTONE_BOMB)
                    end
                end
                if pData.DrFetusBombDirectional then
                    pData.DrFetusBombDirectional.Position = effectPosAlt
                    pData.DrFetusBombDirectional.Velocity = Vector.Zero
                    if pData.DrFetusBombDirectional:IsDead() then
                        pData.DrFetusBombDirectional:Remove()
                        pData.DrFetusBombDirectional = nil
                    end
                end
            else
                local bomb = player:FireBomb(effectPos, Vector.Zero, player)
                --bomb.Flags = tearParams.TearFlags
                --if utils.HasTearFlag(tearParams, TearFlags.TEAR_BELIAL) then
                --    utils.SetTearFlag(bomb, TearFlags.TEAR_HOMING)
                --end
                if utils.IsUsingWeapon(player, WeaponType.WEAPON_BRIMSTONE) then
                    bomb:AddTearFlags(TearFlags.TEAR_BRIMSTONE_BOMB)
                end
            end
        end
    end
end

-- Gestiona la lógica del ataque a melee
function Lust:UpdateMelee(player)
    if player:GetPlayerType() == playerType then
        local pData = player:GetData()

        --local headPosition = player.Position + player.TearsOffset + Vector(0, player.TearHeight) 
        local headPosition = player.Position + Vector(0, player.TearHeight) 

        -- Inicialización de la barra de carga si no existe
        if not pData.ChargeBar then
            pData.ChargeBar = utils.ChargeBar()
        end

        -- Inicialización del contador de retraso si no existe
        if not pData.ChargeStartDelay then
            pData.ChargeStartDelay = 0
        end

        if pData.IsFullCharge then
            pData.ChargeProgress = 0
            pData.IsFullCharge = false
        end

        -- Calcula la duración ajustada de la carga del melee
        local fireDelay = player.MaxFireDelay  -- Evitar divisiones entre 0
        if fireDelay == 0 then 
            fireDelay = 0.1
        end

        -- Usamos una interpolación inversa para ajustar el tiempo de carga
        local adjustedChargeTime = math.max(
            (fireDelay * (meleeChargeMaxTime / 10)),
            meleeChargeMinTime
        )

        local fireInput = player:GetShootingInput()
        local fireDirection, lastFireDirection = utils.GetShootingDirection(player)
        local isShooting = fireDirection:Length() > 0.2 or (fireInput:Length() > 0.2 and fireDirection:Length() > 0.2)

        if utils.IsDirectionalShooting(player) then
            pData.MeleeHitbox = pData.MeleeWeapon
            pData.MeleeHitbox:SetDamageSource(EntityType.ENTITY_PLAYER)
            pData.MeleeHitbox.CollisionDamage = player.Damage / directionalDamageReduction
            if isShooting then
                if player:HasCollectible(CollectibleType.COLLECTIBLE_DEAD_TOOTH) then
                    if not pData.DeadToothRing then
                        pData.DeadToothRing = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FART_RING, 0, headPosition, Vector.Zero, player):ToEffect()
                        pData.DeadToothRing:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                        pData.DeadToothRing:FollowParent(player)
                        --pData.DeadToothRing.SortingLayer = SortingLayer.SORTING_NORMAL
                        pData.DeadToothRing.DepthOffset = 200
                    else 
                        --pData.DeadToothRing.CollisionDamage = player.Damage / directionalDamageReduction
                    end
                end
            end
            --pData.MeleeHitbox:Update()
            Lust:PostUpdateMelee(player, lastFireDirection, pData.MeleeHitbox.Position)
        else 
            -- Detectamos si el jugador ha soltado el disparo
            local hasReleased = not isShooting and pData.WasShooting
    
            if pData.MeleeWeapon and pData.MeleeWeapon:Exists() then
                local weaponSprite = pData.MeleeWeapon:GetSprite()
    
                -- Cargar la barra mientras el botón está pulsado
                if isShooting then

                    if player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK) then
                        pData.MeleeLastFireDirection = player:GetLastDirection()
                    else
                        pData.MeleeLastFireDirection = fireDirection
                    end
                    
                    -- Incrementar el tiempo de espera antes de cargar la barra
                    pData.ChargeStartDelay = math.min(pData.ChargeStartDelay + 1, meleeChargeInitDelay) -- Retraso de 30 frames (medio segundo a 60 FPS)
                    
                    -- Si ha pasado el tiempo de espera, empieza a cargar la barra
                    if pData.ChargeStartDelay >= meleeChargeInitDelay then
                        if pData.DoOnceChargingSound then
                            SFXManager():Play(SoundEffect.SOUND_LIGHTBOLT_CHARGE)
                            pData.DoOnceChargingSound = false
                        end
                        pData.ChargeProgress = math.min(pData.ChargeBar.chargeProgress + 1, adjustedChargeTime) -- Incrementa progresivamente hasta 100
                        pData.ChargeBar:SetCharge(pData.ChargeProgress, adjustedChargeTime) -- Actualiza la barra
                    end

                    --local timeToSpawnMawVoid = 45
                    pData.TimeAttacking = pData.TimeAttacking + 1
                    --print("pData.TimeAttacking: ", pData.TimeAttacking)
                    --if pData.TimeAttacking >= timeToSpawnMawVoid then
                    --    pData.MawOfVoidReady = true
                       -- print("Maw ready!")
                   -- end

                   if player:HasCollectible(CollectibleType.COLLECTIBLE_DEAD_TOOTH) then
                        if not pData.DeadToothRing then
                            pData.DeadToothRing = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FART_RING, 0, headPosition, Vector.Zero, player):ToEffect()
                            pData.DeadToothRing:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                            pData.DeadToothRing:FollowParent(player)
                            --pData.DeadToothRing.SortingLayer = SortingLayer.SORTING_NORMAL
                            pData.DeadToothRing.DepthOffset = 200
                        else 
                            --pData.DeadToothRing.CollisionDamage = player.Damage / directionalDamageReduction
                        end
                    end
                else
                    -- Resetear la barra si el botón se ha soltado
                    pData.ChargeBar:SetCharge(0, adjustedChargeTime)
                    pData.ChargeStartDelay = 0
                end
                
                -- Si soltó el disparo, ejecuta el ataque
                if hasReleased then
                    if pData.DeadToothRing then
                        pData.DeadToothRing:Remove()
                        pData.DeadToothRing = nil
                    end

                    if player.FireDelay <= 0 and not pData.MeleeAttackTriggered and player:IsExtraAnimationFinished() and player.ControlsEnabled then
                        pData.DoOnceChargingSound = true
                        -- Comprobar si la barra está cargada al máximo
                        pData.IsFullCharge = pData.ChargeProgress >= adjustedChargeTime
                        -- Control de animaciones del ataque
                        local animName = utils.GetAnimationName(player, weaponSprite)
    
                        --print(animName)
    
                        --weaponSprite:Update()
                        pData.CurrentEye = (pData.CurrentEye % (utils.Eyes.NUM_EYES - 1)) + 1
                        --print("Aim: ", player:GetLastDirection())

                        lastFireDirection = pData.MeleeLastFireDirection
                        
                        if player:HasCollectible(CollectibleType.COLLECTIBLE_EPIPHORA) then
                            if pData.PrevAttackDirection and utils.VectorEquals(pData.PrevAttackDirection, lastFireDirection) then
                                if pData.TimeMarkSameDirection == 0 then
                                    pData.TimeMarkSameDirection = pData.TimeAttacking
                                end 
                            else
                                pData.PrevAttackDirection = lastFireDirection
                                pData.TimeMarkSameDirection = 0
                            end
                        end

                        --local numAttacks = 1
                        local attacks = {}

                        local roundedX = utils.Round(lastFireDirection.X, 1)
                        local roundedY = utils.Round(lastFireDirection.Y, 1)
                        local isDiagonal = (math.abs(roundedX) == 0.7) and (math.abs(roundedY) == 0.7)

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_EYE) then
                            local rand = utils.RandomRange(rng, 0.0, 1.0)
                            local prob = math.max(0.0, math.min(1.0, player.Luck / 2.0))
                            if rand <= prob then
                                local oppositeDirection = Vector(lastFireDirection.X * -1.0, lastFireDirection.X * -1.0)
                                if not utils.ContainsDirection(attacks, oppositeDirection) then
                                    table.insert(attacks, oppositeDirection)
                                end 
                            end
                        end

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_LOKIS_HORNS) then
                            local rand = utils.RandomRange(rng, 0.0, 1.0)
                            local prob = math.max(0.125, math.min(1.0, (player.Luck+5.0) / 20.0))
                            --print("rand: ", rand)
                            --print("prob: ", prob)
                            if rand <= prob then
                                for _, direction in ipairs(utils.Directions) do
                                    if not utils.ContainsDirection(attacks, direction) then
                                        table.insert(attacks, direction)
                                        --numAttacks = numAttacks + 1
                                    end
                                end
                            end
                        end

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_INNER_EYE) then
                            if not utils.ContainsDirection(attacks, lastFireDirection) then
                                table.insert(attacks, lastFireDirection)
                                --numAttacks = numAttacks + 1
                            end
                            if isDiagonal then
                                -- Si es diagonal, añadir las direcciones ortogonales
                                local orthogonal1 = Vector(math.sign(roundedX), 0)
                                local orthogonal2 = Vector(0, math.sign(roundedY))
                                
                                if not utils.ContainsDirection(attacks, orthogonal1) then
                                    table.insert(attacks, orthogonal1)
                                    --numAttacks = numAttacks + 1
                                end
                                if not utils.ContainsDirection(attacks, orthogonal2) then
                                    table.insert(attacks, orthogonal2)
                                    --numAttacks = numAttacks + 1
                                end
                            else
                                -- Si es cardinal, añadir las direcciones diagonales adyacentes
                                local diagonal1, diagonal2
                                if roundedX ~= 0 then
                                    -- Dirección horizontal (como (1, 0) o (-1, 0))
                                    diagonal1 = Vector(roundedX * 0.7, 0.7)
                                    diagonal2 = Vector(roundedX * 0.7, -0.7)
                                else
                                    -- Dirección vertical (como (0, 1) o (0, -1))
                                    diagonal1 = Vector(0.7, roundedY * 0.7)
                                    diagonal2 = Vector(-0.7, roundedY * 0.7)
                                end
                                
                                if not utils.ContainsDirection(attacks, diagonal1) then
                                    table.insert(attacks, diagonal1)
                                    --numAttacks = numAttacks + 1
                                end
                                if not utils.ContainsDirection(attacks, diagonal2) then
                                    table.insert(attacks, diagonal2)
                                    --numAttacks = numAttacks + 1
                                end
                            end
                        end

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_SORE) then
                            local randDirections = {
                                Vector(1, 0),                       -- 0 grados
                                Vector(0.866, 0.5),                 -- 30 grados
                                Vector(0.5, 0.866),                 -- 60 grados
                                Vector(0, 1),                       -- 90 grados
                                Vector(-0.5, 0.866),                -- 120 grados
                                Vector(-0.866, 0.5),                -- 150 grados
                                Vector(-1, 0),                      -- 180 grados
                                Vector(-0.866, -0.5),               -- 210 grados
                                Vector(-0.5, -0.866),               -- 240 grados
                                Vector(0, -1),                      -- 270 grados
                                Vector(0.5, -0.866),                -- 300 grados
                                Vector(0.866, -0.5)                 -- 330 grados
                            }
                            local numRandomShots = utils.GetNumRandomShots(rng, player.Luck)

                            -- Añadir direcciones aleatorias de randDirections a attacks
                            for _ = 1, numRandomShots do
                                local randomIndex = rng:RandomInt(#randDirections) + 1  -- Seleccionar una dirección aleatoria
                                local randomDirection = randDirections[randomIndex]
                                
                                -- Asegurarse de no duplicar direcciones en attacks
                                if not utils.ContainsDirection(attacks, randomDirection) then
                                    table.insert(attacks, randomDirection)
                                end
                            end
                        end

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_THE_WIZ) then
                            if isDiagonal then
                                -- Si es diagonal, añadir las direcciones ortogonales
                                local orthogonal1 = Vector(math.sign(roundedX), 0)
                                local orthogonal2 = Vector(0, math.sign(roundedY))
                                
                                if not utils.ContainsDirection(attacks, orthogonal1) then
                                    table.insert(attacks, orthogonal1)
                                    --numAttacks = numAttacks + 1
                                end
                                if not utils.ContainsDirection(attacks, orthogonal2) then
                                    table.insert(attacks, orthogonal2)
                                    --numAttacks = numAttacks + 1
                                end
                            else
                                -- Si es cardinal, añadir las direcciones diagonales adyacentes
                                local diagonal1, diagonal2
                                if roundedX ~= 0 then
                                    -- Dirección horizontal (como (1, 0) o (-1, 0))
                                    diagonal1 = Vector(roundedX * 0.7, 0.7)
                                    diagonal2 = Vector(roundedX * 0.7, -0.7)
                                else
                                    -- Dirección vertical (como (0, 1) o (0, -1))
                                    diagonal1 = Vector(0.7, roundedY * 0.7)
                                    diagonal2 = Vector(-0.7, roundedY * 0.7)
                                end
                                
                                if not utils.ContainsDirection(attacks, diagonal1) then
                                    table.insert(attacks, diagonal1)
                                    --numAttacks = numAttacks + 1
                                end
                                if not utils.ContainsDirection(attacks, diagonal2) then
                                    table.insert(attacks, diagonal2)
                                    --numAttacks = numAttacks + 1
                                end
                            end
                        end

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_20_20) then
                            -- Angulos en grados para los disparos en forma de abanico
                            local angles = {-10, 10}
                            --local isFirstAngle = true

                            -- Generar las direcciones de disparo en abanico
                            for _, angle in ipairs(angles) do
                                local attackDirection = utils.RotateVector(lastFireDirection, angle)
                                if not utils.ContainsDirection(attacks, attackDirection) then
                                    table.insert(attacks, attackDirection)
                                    --numAttacks = numAttacks + 1
                                end
                            end
                        end

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_MUTANT_SPIDER) then
                            -- Angulos en grados para los disparos en forma de abanico
                            local angles = {-25, -15, 15, 25}
                            --local isFirstAngle = true

                            -- Generar las direcciones de disparo en abanico
                            for _, angle in ipairs(angles) do
                                local attackDirection = utils.RotateVector(lastFireDirection, angle)
                                if not utils.ContainsDirection(attacks, attackDirection) then
                                    table.insert(attacks, attackDirection)
                                    --numAttacks = numAttacks + 1
                                end
                            end
                        end

                        if not utils.ContainsDirection(attacks, lastFireDirection)
                            and not player:HasCollectible(CollectibleType.COLLECTIBLE_20_20)
                            and not player:HasCollectible(CollectibleType.COLLECTIBLE_MUTANT_SPIDER)
                            and not player:HasCollectible(CollectibleType.COLLECTIBLE_THE_WIZ) then
                            table.insert(attacks, lastFireDirection)
                            --numAttacks = numAttacks + 1
                        end
                        
                        --print("Damage Val: ", utils.GetTearDamage(player))

                        if animName ~= "" then
                            weaponSprite:Play(animName, true)
                        end

                        --local mainFireDirection = lastFireDirection
                        --local doOnceSprite = true

                        for _, direction in ipairs(attacks) do

                            --if numAttacks > 1 then
                            lastFireDirection = direction
                            --end

                            -- Crear el hitbox del ataque
                            pData.MeleeHitbox = Isaac.Spawn(EntityType.ENTITY_EFFECT, weaponAttack, 0, player.Position, Vector.Zero, player):ToEffect()
                            local hitbox = pData.MeleeHitbox
                            local hitboxSprite = hitbox:GetSprite()
        
                            -- Configurar el hitbox con la animación del arma
                            hitboxSprite:Play(weaponSprite:GetAnimation(), true)
                            hitboxSprite.Rotation = lastFireDirection:GetAngleDegrees() - 90
                            hitboxSprite.Offset = lastFireDirection:Resized(-meleeDistance * 0.5) + Vector(0, meleeSpriteOffset)
        
                            local vecScale = Vector.One
                            --if pData.IsFullCharge then 
                            --    vecScale =  Vector(0.4, 2.0)
                            --end
                            
                            --print("Animation long 2: ", vecScale);
                            
                            hitboxSprite.Scale = utils.GetMeleeSize(player) * vecScale
                            hitboxSprite:ReplaceSpritesheet(0, emptyPng)
                            hitboxSprite:ReplaceSpritesheet(3, emptyPng)
                            hitboxSprite:LoadGraphics()
                            --if doOnceSprite and (utils.VectorEquals(mainFireDirection, lastFireDirection) or not utils.ContainsDirection(attacks, mainFireDirection)) then
                            --    print("Removed attack Mainvector: ", mainFireDirection)
                            --    print("Removed attack Lastvector: ", lastFireDirection)
                            --    wea:ReplaceSpritesheet(1, emptyPng)
                            --    hitboxSprite:ReplaceSpritesheet(2, emptyPng)
                            --    doOnceSprite = false
                            --end
        
                            -- Ajustes del hitbox y colisiones
                            hitbox.DepthOffset = -100
        
                            --[[
                            vecScale = hitbox.SizeMulti
                            if pData.IsFullCharge then 
                                vecScale =  Vector(2.0, 0.4)
                            end
                            print("Animation long 3: ", vecScale);
                            ]]--
        
                            hitbox:SetSize(utils.GetMeleeSize(player) * meleeRange, hitbox.SizeMulti, 12)
                            hitbox:FollowParent(player)
                            hitbox.ParentOffset = lastFireDirection * meleeDistance
                            hitbox:SetDamageSource(EntityType.ENTITY_PLAYER)
        
                            -- Ajustar el daño del ataque
                            local damageBonus = 0.0
                            local damageMultiplier = pData.IsFullCharge and meleeChargeDamageMult or meleeDamageMult  -- Doble daño si está cargado
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
                            --print("damageBonus: ", damageBonus)
                            --print("damageMultiplier: ", damageMultiplier)
                            --print("Delay: ", pData.ChargeProgress)
                            hitbox.CollisionDamage = (player.Damage + damageBonus) * damageMultiplier
                            hitbox:SetTimeout(meleeTimeout)
                            --hitbox:Update()
                            -- Actualización de tiempos y estados
                            local fireDelayMultiplier = 1.0
                            local fireDelayBonus = 0.0
                            if player:HasCollectible(CollectibleType.COLLECTIBLE_EPIPHORA) and pData.TimeMarkSameDirection ~= 0 then
                                local timeDiff = math.max(0.0, pData.TimeAttacking - pData.TimeMarkSameDirection)
                                local maxTimeEpiphoraSpeed = 100
                                --print("pData.TimeMarkSameDirection: ", pData.TimeMarkSameDirection)
                                --print("timeDiff: ", timeDiff)
                                fireDelayMultiplier = fireDelayMultiplier * (1.0 - (0.5 * math.min(1.0, timeDiff / maxTimeEpiphoraSpeed) ))
                                --print("fireDelayMultiplier: ", fireDelayMultiplier)
                            end
                            if player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_DROPS) and pData.CurrentEye == utils.Eyes.LEFT then
                                fireDelayMultiplier = fireDelayMultiplier * (1.0 - 0.4)
                            end
                            --print("fireDelayMultiplier: ", fireDelayMultiplier)
                            player.FireDelay = (player.MaxFireDelay + fireDelayBonus) * fireDelayMultiplier
                            player.HeadFrameDelay = utils.GetHeadFrameDelayCalc(player)
        
                            Lust:PostUpdateMelee(player, lastFireDirection, nil)
                        end
                        
                        -- Efecto de pantalla si el tamaño supera el umbral
                        if utils.GetMeleeSize(player) > meleeSizeTreshold then
                            game:ShakeScreen(meleeTimeout)
                        end
    
                        -- Reproducir sonido y ejecutar callback
                        if pData.IsFullCharge then
                            SFXManager():Play(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK)
                        else
                            SFXManager():Play(SoundEffect.SOUND_LIGHTBOLT)
                        end
                        
                        -- Marcar que el ataque fue ejecutado
                        pData.MeleeAttackTriggered = true
                    end
                else
                    -- Resetear el estado del ataque si es necesario
                    if player.FireDelay <= 0 or pData.MeleeAttackTriggered then
                        pData.MeleeAttackTriggered = false
                    end
                end

                if isShooting then
                    pData.TimeWithoutAttacking = 0
                end
            end
    
            -- Guardar si el jugador está disparando para detectar "al soltar"
            pData.WasShooting = isShooting
        end

    end
end

-- Gestiona la lógica de renderizado (especialmente de la barra de carga)
function Lust:RenderPlayer(player)
    -- Renderizar la barra de carga si existe
    if player:GetPlayerType() == playerType then
        local pData = player:GetData()
        utils.CheckFlyingStatus(player)
        utils.CheckCrownOfLightStatus(player)
        if player:IsCoopGhost() then
            if pData.IsDeadFirstCheck then
                --player:TryRemoveNullCostume(costumeAlt)
                --player:AddNullCostume(costume)
                --local playerSprite = player:GetSprite()
                --playerSprite:ReplaceSpritesheet(0, skinMain)
                --playerSprite:LoadGraphics()
                pData.IsDeadFirstCheck = false
                pData.IsRenderChanged = true
            end
        else
            if pData.IsRenderChanged then
                --print("pData.IsRenderChanged = TRUE")
                if pData.IsCrownActive then
                    player:TryRemoveNullCostume(costumeFlyingAlt)
                    player:TryRemoveNullCostume(costumeAlt)
                    --print("Has Crown. Can Fly", player.CanFly)
                    if player.CanFly then
                        player:TryRemoveNullCostume(costume)
                        player:AddNullCostume(costumeFlying)
                    else
                        player:TryRemoveNullCostume(costumeFlying)
                        player:AddNullCostume(costume)
                    end
                    --local playerSprite = player:GetSprite()
                    --playerSprite:ReplaceSpritesheet(0, skinMain)
                    --playerSprite:LoadGraphics()
                else
                    player:TryRemoveNullCostume(costumeFlying)
                    player:TryRemoveNullCostume(costume)
                    --print("Does not have Crown. Can Fly", player.CanFly)
                    if player.CanFly then
                        player:TryRemoveNullCostume(costumeAlt)
                        player:AddNullCostume(costumeFlyingAlt)
                    else
                        player:TryRemoveNullCostume(costumeFlyingAlt)
                        player:AddNullCostume(costumeAlt)
                    end
                    --local playerSprite = player:GetSprite()
                    --playerSprite:ReplaceSpritesheet(0, skinAlt)
                    --playerSprite:LoadGraphics()
                end

                local weaponSprite = pData.MeleeWeapon:GetSprite()
                if utils.CheckCrownOfLightStatus(player) then
                    weaponSprite:Play("Idle", true)
                else 
                    weaponSprite:Play("IdleAlt", true)
                end

                pData.IsRenderChanged = false
            end
            pData.IsDeadFirstCheck = true
        end

        if not utils.IsDirectionalShooting(player) and Options.ChargeBars and pData.ChargeBar then
            local pChargeBarOffset = utils.HasChargeBarItem(player) and -1 or 1
            local pOffset = player:GetFlyingOffset() + Vector(18 * pChargeBarOffset, -54) * player.SpriteScale

            --local position = player.Position + Vector(0, -40)  -- Posición sobre el jugador
            pData.ChargeBar:Render(player.Position + pOffset)
        end
    end
end

function Lust:UpdatePlayer(player)
    if player:GetPlayerType() == playerType then
        local pData = player:GetData()
        if not pData.MeleeAttackTriggered and not utils.IsDirectionalShooting(player) then
            pData.TimeWithoutAttacking = pData.TimeWithoutAttacking + 1
            if pData.TimeWithoutAttacking >= 5 then
                pData.TimeAttacking = 0
                pData.TimeMarkSameDirection = 0
            end
        end
        --print("TimeMarkSameDirection: ", pData.TimeMarkSameDirection)
        --print("timeDiff: ", math.max(0.0, pData.TimeAttacking - pData.TimeMarkSameDirection))
        pData.IsKnockBacked = false
        if pData.IsNewRoom then
            --print("ENABLING CROWN AGAIN!")
            pData.IsCrownDamaged = false

            if pData.DeadToothRing then
                pData.DeadToothRing:Remove()
                pData.DeadToothRing = nil
            end
        end
        pData.IsNewRoom = false
    end
end

function Lust:OnDamage(entity, amount, flag, source, countdown)
    local player = entity:ToPlayer()
    if player and player:GetPlayerType() == playerType then
        --print("PLAYER IS DAMAGED!")
        local pData = player:GetData()
        pData.IsCrownDamaged = true
    end
end

function Lust:OnNewRoom()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity.Type == EntityType.ENTITY_PLAYER then
            local player = entity:ToPlayer() -- Convierte la entidad en un jugador

            -- Verifica si el tipo de jugador coincide con el especificado
            if player and player:GetPlayerType() == playerType then
                local pData = player:GetData() -- Obtiene los datos del jugador

                -- Guarda una variable única en los datos del jugador
                pData.IsNewRoom = true
            end
        end
    end
end


function Lust:OnTearPreColl(entity, colEntity, low)
    local eData = entity:GetData()

    if eData.IgnoreCollisionWithVariant and utils.IsValueInList(eData.IgnoreCollisionWithVariant, colEntity.Variant) then
        if eData.IgnoreCollisionWithTime > 0 then
            eData.IgnoreCollisionWithTime = eData.IgnoreCollisionWithTime - 1
        end
        return true
    end
    if eData.IgnoreCollisionWith and utils.IsValueInList(eData.IgnoreCollisionWith, GetPtrHash(colEntity)) then
        if eData.IgnoreCollisionWithTime > 0 then
            eData.IgnoreCollisionWithTime = eData.IgnoreCollisionWithTime - 1
        end
        return true
    end
end

mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE, CallbackPriority.DEFAULT, function(_, player, cacheFlag)
    Lust:OnCache(player, cacheFlag)
end)
mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_INIT, CallbackPriority.DEFAULT, function(_, player)
    Lust:InitPlayer(player)
end)
mod:AddPriorityCallback(ModCallbacks.MC_POST_EFFECT_INIT, CallbackPriority.DEFAULT, function(_, effect)
    Lust:InitMelee(effect)
end)
mod:AddPriorityCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, CallbackPriority.DEFAULT, function(_, player)
    Lust:UpdateWeapon(player)
    Lust:UpdateMelee(player)
    Lust:UpdatePlayer(player)
    utils.OnUpdate(player)
end)
mod:AddPriorityCallback(ModCallbacks.MC_POST_NEW_ROOM, CallbackPriority.DEFAULT, function(_)
    Lust:OnNewRoom()
end)
mod:AddPriorityCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, CallbackPriority.DEFAULT, function(_, effect)
    Lust:UpdateEffect(effect)
end)
mod:AddPriorityCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, CallbackPriority.DEFAULT, function(_, entity, colEntity, low)
    if Lust:OnTearPreColl(entity, colEntity, low) then
        return true
    end
end)
mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, CallbackPriority.DEFAULT, function(_, entity, amount, flag, source, countdown)
    Lust:OnHit(entity, amount, flag, source, countdown)
end)
mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, 300, function(_, entity, amount, flag, source, countdown) -- too late
    Lust:OnDamage(entity, amount, flag, source, countdown)
end)
mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_RENDER, CallbackPriority.DEFAULT, function(_, player)
    Lust:RenderPlayer(player)
end)