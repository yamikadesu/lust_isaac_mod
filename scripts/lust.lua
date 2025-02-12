local mod = RegisterMod("Lust (YamikaDesu)", 1) 

local version = "1.6"
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
local friendlyHalo = Isaac.GetEntityVariantByName("Friendly Halo")

local utils = include("scripts/utils")

local game = Game()
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

local Lust = { 
    DAMAGE = 0, -- These are all relative to Isaac's Lust stats.
    SPEED = 0,
    SHOTSPEED = .5,
    TEARRANGE = 0,
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
            player.TearRange = player.TearRange + Lust.TEARRANGE
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
        if pData.Yami.BrimstoneBall and pData.Yami.BrimstoneBall ~= except then 
            pData.Yami.BrimstoneBall:Remove() 
            pData.Yami.BrimstoneBall = nil
        end
        if pData.Yami.FireTechX and pData.Yami.FireTechX ~= except then 
            pData.Yami.FireTechX:Remove() 
            pData.Yami.FireTechX = nil
        end
        if pData.Yami.TerraRockBall and pData.Yami.TerraRockBall ~= except then
            pData.Yami.TerraRockBall:Remove() 
            pData.Yami.TerraRockBall = nil
        end
        if pData.Yami.EvilEyeBall and pData.Yami.EvilEyeBall ~= except then
            pData.Yami.EvilEyeBall:Remove() 
            pData.Yami.EvilEyeBall = nil
        end
    end
end

-- Inicializa al jugador
function Lust:InitPlayer(player)
    if player:GetPlayerType() == playerType then
        --player:AddNullCostume(costume)
        rng:SetSeed(Game():GetSeeds():GetStartSeed(), RECOMMENDED_SHIFT_IDX)
        local pData = player:GetData()
        pData.Yami = {}
        pData.Yami.DefaultTearProbability = 0.05
        pData.Yami.MaxTearProbability = 0.5
        pData.Yami.MeleeAttackTriggered = false
        pData.Yami.MeleeCooldown = 0
        pData.Yami.ChargeProgress = 0
        pData.Yami.ChargingValue = 0
        pData.Yami.DoOnceChargingSound = true
        pData.Yami.IsCrownActive = true
        pData.Yami.IsRenderChanged = true
        pData.Yami.PrevFlyingValue = Lust.FLYING
        pData.Yami.HadDirectionalMovement = false
        pData.Yami.IsInNewRoom = true
        pData.Yami.MomKnifeItem = nil
        pData.Yami.IsKnockBacked = false
        pData.Yami.IsCrownDamaged = false
        pData.Yami.CurrentEye = utils.Eyes.LEFT -- It will start with Right
        pData.Yami.RNG = rng
        pData.Yami.Game = game
        pData.Yami.PrevAttackDirection = nil
        pData.Yami.TotalAttacksNum = 0
        pData.Yami.TimeMarkSameDirection = 0
        pData.Yami.TimeAttacking = 0
        pData.Yami.TimeWithoutAttacking = 0
        pData.Yami.SuccesfulEnemyHit = 0
        pData.Yami.UnsuccesfulEnemyHit = 0
        pData.Yami.DeadToothRing = nil
        pData.Yami.EyeGreedAttacks = 0
        pData.Yami.EvilEyeDirectionalDelay = 10
        pData.Yami.EvilEyeDirectionalCount = 0
        pData.Yami.IsDeadFirstCheck = true
        pData.Yami.DrFetusBombDirectional = nil
        pData.Yami.SpawnedFireDirectional = nil
        pData.Yami.IsNewRoom = true
        pData.Yami.FriendlyHalo = nil
        pData.Yami.FriendlyDamageSpeed = 4.0
        pData.Yami.FriendlyDamageDelayTemp = 0
        pData.Yami.MeleeLastFireDirection = Vector(0,0)
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
        if not hitboxData.Yami then hitboxData.Yami = {} end
        hitboxData.Yami.EntityList = {}
    end
end

-- Gestiona la lógica del arma
function Lust:UpdateWeapon(player)
    local pData = player:GetData()
        
    if player:GetPlayerType() ~= playerType then
        if pData.Yami.MeleeWeapon then
            pData.Yami.MeleeWeapon:Remove()
            pData.Yami.MeleeWeapon = nil
        end
    else
        if not pData.Yami.MeleeWeapon then
            pData.Yami.MeleeWeapon = Isaac.Spawn(EntityType.ENTITY_EFFECT, weapon, 0, player.Position, Vector.Zero, player):ToEffect()
            pData.Yami.MeleeWeapon:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
            pData.Yami.MeleeWeapon:FollowParent(player)
            pData.Yami.MeleeWeapon.ParentOffset = Vector(0, meleeOffset)
            --pData.Yami.MeleeWeapon:Update()
            
            for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, weapon)) do 
                if entity:HasCommonParentWithEntity(player) then
                    if GetPtrHash(entity) ~= GetPtrHash(pData.Yami.MeleeWeapon) then
                        entity:Remove()
                    end
                end
            end
        elseif pData.Yami.MeleeWeapon and not pData.Yami.MeleeWeapon:Exists() then
            pData.Yami.MeleeWeapon:Remove()
            pData.Yami.MeleeWeapon = nil
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_KNIFE) then
            local knifeDirection = utils.DirectionToVectorReversed[player:GetHeadDirection()]
            if not pData.Yami.MomKnifeItem then
                pData.Yami.MomKnifeItem = Isaac.Spawn(EntityType.ENTITY_KNIFE, 0, 0, player.Position, Vector.Zero, player):ToKnife()
                pData.Yami.MomKnifeItem:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                --pData.Yami.MomKnifeItem:AddTearFlags(TearFlags.TEAR_PERSISTENT)
                pData.Yami.MomKnifeItem.Parent = player
                --pData.Yami.MomKnifeItem:SetDamageSource(EntityType.ENTITY_PLAYER)
                pData.Yami.MomKnifeItem.CollisionDamage = player.Damage
                pData.Yami.MomKnifeItem.Position = player.Position + Vector(0, meleeOffset)
                --pData.Yami.MomKnifeItem:Update()
            end
            if pData.Yami.MomKnifeItem then
                local meleeSprite = pData.Yami.MomKnifeItem:GetSprite()
                pData.Yami.MomKnifeItem.Position = utils.Lerp(pData.Yami.MomKnifeItem.Position, player.Position + knifeDirection:Resized(meleeOffset), 0.4)
                pData.Yami.MomKnifeItem.Rotation = utils.LerpAngle(utils.Round(pData.Yami.MomKnifeItem.Rotation, 3), knifeDirection:GetAngleDegrees(), 0.4)
                --print(knifeDirection:GetAngleDegrees())
                --pData.Yami.MomKnifeItem.Position = player.Position + knifeDirection:Resized(meleeOffset)
                --pData.Yami.MomKnifeItem.SpriteRotation = knifeDirection:GetAngleDegrees()
                --pData.Yami.MomKnifeItem.SpriteOffset = knifeDirection:Resized(meleeOffset)
                pData.Yami.MomKnifeItem.SpriteScale = utils.GetMeleeSize(player) * Vector.One
                pData.Yami.MomKnifeItem:SetSize(utils.GetMeleeSize(player) * meleeSize, pData.Yami.MomKnifeItem.SizeMulti, 0)
                meleeSprite:LoadGraphics()
            end
        else
            if pData.Yami.MomKnifeItem then
                pData.Yami.MomKnifeItem:Remove()
                pData.Yami.MomKnifeItem = nil
            end
        end
    
        if pData.Yami.MeleeWeapon and pData.Yami.MeleeWeapon:Exists() then
            local melee = pData.Yami.MeleeWeapon
            local meleeSprite = melee:GetSprite()
            local meleeHitbox = pData.Yami.MeleeHitbox
            local meleeDirection = (meleeHitbox and meleeHitbox:Exists()) 
                                and (meleeHitbox.Position - player.Position) 
                                or utils.DirectionToVector[player:GetHeadDirection()] 
            if utils.IsDirectionalShooting(player) then
                local markedTargetPos = utils.GetMarkedPos(player)
                if markedTargetPos then
                    melee.Position = markedTargetPos
                else 
                    if not pData.Yami.HadDirectionalMovement or pData.Yami.IsNewRoom then
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
                if pData.Yami.HadDirectionalMovement then
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
            pData.Yami.HadDirectionalMovement = utils.IsDirectionalShooting(player)
        end
    end

end

-- Gestiona el comportamiento de los efectos del ataque a melee
function Lust:UpdateEffect(effect)
    if effect.Parent and effect.Parent:ToPlayer() then
        local player = effect.Parent:ToPlayer()
        if player:GetPlayerType() == playerType then
            local pData = player:GetData()
            if effect.Variant == weaponAttack or effect.Variant == weapon then
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
            elseif effect.Variant == friendlyHalo then
                if pData.Yami.FriendlyDamageDelayTemp >= (player.MaxFireDelay + 1.0) / 2.0 then
                    pData.Yami.FriendlyDamageDelayTemp = 0
                    utils.CharmNearEnemies(effect, effect.Position, effect.Size)
                else
                    pData.Yami.FriendlyDamageDelayTemp = pData.Yami.FriendlyDamageDelayTemp + 1
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
        if not hitboxData.Yami then hitboxData.Yami = {} end
        if not hitboxData.Yami.EntityList or utils.IsValueInList(hitboxData.Yami.EntityList, entity.InitSeed) then return false end
        
        if hitbox.Parent and hitbox.Parent:ToPlayer() then
            local player = hitbox.Parent:ToPlayer()
            
            if player:GetPlayerType() == playerType then

                local pData = player:GetData()

                if not pData.Yami.IsKnockBacked then 
                    utils.ApplyKnockback(entity, player, meleeKnockbackSelf)
                    utils.ApplyKnockback(player, entity, meleeKnockback)
                    pData.Yami.IsKnockBacked = true
                end
                SFXManager():Play(SoundEffect.SOUND_WHIP_HIT)
            end
        end
        
        table.insert(hitboxData.Yami.EntityList, entity.InitSeed) -- Would be better idea to do that for pickups aswell, so they don't get pushed around so much
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

        local headDirection = utils.VectorToDirection(lastFireDirection)
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
                if entity.Type == EntityType.ENTITY_PROJECTILE and (not entity.SpawnerEntity or GetPtrHash(entity.SpawnerEntity) ~= GetPtrHash(player)) then
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
        -- math.max(0.0833, math.min(0.5, player.Luck/10.0))
        local prob = utils.RandomLuck(player.Luck, 0.0833, 0.5, 10.0)
        if bothItems then
            -- math.max(0.125, math.min(1.0, player.Luck/7.0))
            prob = utils.RandomLuck(player.Luck, 0.125, 1.0, 7.0)
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
                        if not pData.Yami.SpawnedFireDirectional then
                            --print("SPAWNED RED FIRE!") 
                            pData.Yami.SpawnedFireDirectional = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, Vector.Zero, player):ToEffect()
                            pData.Yami.SpawnedFireDirectional.CollisionDamage = player.Damage * 3.0
                            pData.Yami.SpawnedFireDirectional:SetTimeout(60)
                            if not pData.Yami.SpawnedFireDirectional:GetData().Yami then pData.Yami.SpawnedFireDirectional:GetData().Yami = {} end
                            pData.Yami.SpawnedFireDirectional:GetData().Yami.IgnoreCollisionWithVariant = {weaponAttack, weapon}
                            pData.Yami.SpawnedFireDirectional:GetData().Yami.IgnoreCollisionWithTime = 5.0
                        end
                    else
                        --print("SPAWNED RED FIRE!") 
                        local redFlameVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                        local redFlame = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, redFlameVel, player):ToEffect()
                        redFlame.CollisionDamage = player.Damage * 3.0
                        redFlame:SetTimeout(60)
                        if not redFlame:GetData().Yami then redFlame:GetData().Yami = {} end
                        redFlame:GetData().Yami.IgnoreCollisionWithVariant = {weaponAttack, weapon}
                        redFlame:GetData().Yami.IgnoreCollisionWithTime = 5.0
                    end
                else
                    if utils.IsDirectionalShooting(player) then
                        if not pData.Yami.SpawnedFireDirectional then
                            --print("SPAWNED BLUE FIRE!") 
                            pData.Yami.SpawnedFireDirectional = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, effectPos, Vector.Zero, player):ToEffect()
                            pData.Yami.SpawnedFireDirectional.CollisionDamage = player.Damage * 3.0
                            pData.Yami.SpawnedFireDirectional:SetTimeout(60)
                            if not pData.Yami.SpawnedFireDirectional:GetData().Yami then pData.Yami.SpawnedFireDirectional:GetData().Yami = {} end
                            pData.Yami.SpawnedFireDirectional:GetData().Yami.IgnoreCollisionWithVariant = {weaponAttack, weapon}
                            pData.Yami.SpawnedFireDirectional:GetData().Yami.IgnoreCollisionWithTime = 5.0
                        end
                    else
                        --print("SPAWNED BLUE FIRE!")
                        local blueFlameVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                        local blueFlame = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, effectPos, blueFlameVel, player):ToEffect()
                        blueFlame.CollisionDamage = player.Damage * 3.0
                        blueFlame:SetTimeout(60)
                        if not blueFlame:GetData().Yami then blueFlame:GetData().Yami = {} end
                        blueFlame:GetData().Yami.IgnoreCollisionWithVariant = {weaponAttack, weapon}
                        blueFlame:GetData().Yami.IgnoreCollisionWithTime = 5.0
                    end
                end
                hasLaunchedFire = true
            end
            if pData.Yami.SpawnedFireDirectional then
                pData.Yami.SpawnedFireDirectional.Position = effectPosAlt
                pData.Yami.SpawnedFireDirectional.Velocity = Vector.Zero
                if pData.Yami.SpawnedFireDirectional:IsDead() then
                    pData.Yami.SpawnedFireDirectional:Remove()
                    pData.Yami.SpawnedFireDirectional = nil
                end
            end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRDS_EYE) and not hasLaunchedFire then
            local rand = utils.RandomRange(rng, 0.0, 1.0)
            if rand <= prob then
                if utils.IsDirectionalShooting(player) then
                    if not pData.Yami.SpawnedFireDirectional then
                        --print("SPAWNED RED FIRE!")
                        pData.Yami.SpawnedFireDirectional = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, Vector.Zero, player):ToEffect()
                        pData.Yami.SpawnedFireDirectional.CollisionDamage = player.Damage * 3.0
                        pData.Yami.SpawnedFireDirectional:SetTimeout(60)
                        if not pData.Yami.SpawnedFireDirectional:GetData().Yami then pData.Yami.SpawnedFireDirectional:GetData().Yami = {} end
                        pData.Yami.SpawnedFireDirectional:GetData().Yami.IgnoreCollisionWithVariant = {weaponAttack, weapon}
                        pData.Yami.SpawnedFireDirectional:GetData().Yami.IgnoreCollisionWithTime = 5.0
                    end
                else
                    --print("SPAWNED RED FIRE!")
                    local redFlameVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                    local redFlame = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.RED_CANDLE_FLAME, 0, effectPos, redFlameVel, player):ToEffect()
                    redFlame.CollisionDamage = player.Damage * 3.0
                    redFlame:SetTimeout(60)
                    if not redFlame:GetData().Yami then redFlame:GetData().Yami = {} end
                    redFlame:GetData().Yami.IgnoreCollisionWithVariant = {weaponAttack, weapon}
                    redFlame:GetData().Yami.IgnoreCollisionWithTime = 5.0
                end
                hasLaunchedFire = true
            end
            if pData.Yami.SpawnedFireDirectional then
                pData.Yami.SpawnedFireDirectional.Position = effectPosAlt
                pData.Yami.SpawnedFireDirectional.Velocity = Vector.Zero
                if pData.Yami.SpawnedFireDirectional:IsDead() then
                    pData.Yami.SpawnedFireDirectional:Remove()
                    pData.Yami.SpawnedFireDirectional = nil
                end
            end
        end

        if player:HasCollectible(CollectibleType.COLLECTIBLE_LARGE_ZIT) then
            local probShot = 0.1 -- Specify the prob of the large zit attack
            local rand = utils.RandomRange(rng, 0.0, 1.0)
            if rand <= probShot then
                local zitCreep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_WHITE, 0, effectPos, Vector.Zero, player):ToEffect()
            end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
            if pData.Yami.FriendlyHalo then
                if utils.IsDirectionalShooting(player) then
                    pData.Yami.FriendlyHalo.Position = effectPosAlt
                end
            end
        end
        if utils.HasTearFlag(tearParams, TearFlags.TEAR_FETUS) 
            or utils.IsUsingWeapon(player, WeaponType.WEAPON_FETUS) then
            --print("SHOT TEAR FETUS!")
            --if pData.Yami.IsFullCharge then
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
            if utils.IsDirectionalShooting(player) then
                --local probTear = 0.02 
                --local rand = utils.RandomRange(rng, 0.0, 1.0)
                if pData.Yami.EyeGreedAttacks >= 199 then
                    local tearVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                    local tearSpawned = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.COIN, 0, effectPosTear, tearVel, player):ToTear()
                    tearSpawned:AddTearFlags(TearFlags.TEAR_MIDAS | TearFlags.TEAR_GREED_COIN)  
                    tearSpawned.CollisionDamage = player.Damage
                    pData.Yami.EyeGreedAttacks = 0
                else
                    pData.Yami.EyeGreedAttacks = pData.Yami.EyeGreedAttacks + 1
                end
            else
                if pData.Yami.EyeGreedAttacks >= 19 then
                    if player:GetNumCoins() > 0 then
                        player:AddCoins(-1)
                    end
                    local tearVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                    local tearSpawned = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.COIN, 0, effectPosTear, tearVel, player):ToTear()
                    tearSpawned:AddTearFlags(TearFlags.TEAR_MIDAS | TearFlags.TEAR_GREED_COIN)  
                    tearSpawned.CollisionDamage = player.Damage
                    --tearSpawned:SetTimeout(30)
                    pData.Yami.EyeGreedAttacks = 0
                else
                    pData.Yami.EyeGreedAttacks = pData.Yami.EyeGreedAttacks + 1
                end
            end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_IMMACULATE_HEART) then
            local probImmHeart = 0.2 
            if utils.IsDirectionalShooting(player) then
                probImmHeart = 0.02
            end
            local rand = utils.RandomRange(rng, 0.0, 1.0)
            if rand <= probImmHeart then
                local tearVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                local tearSpawned = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE, 0, effectPosTear, tearVel, player):ToTear()
                tearSpawned:AddTearFlags(TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_ORBIT_ADVANCED) 
                tearSpawned.CollisionDamage = player.Damage
            end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_HOLY_LIGHT) then
            if utils.IsDirectionalShooting(player) then
                local probLight = utils.RandomLuck(player.Luck, 0.01, 0.05, 9.0)
                local rand = utils.RandomRange(rng, 0.0, 1.0)
                if rand <= probLight then
                    local lightSpawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, effectPosAlt, Vector.Zero, player):ToEffect()
                    lightSpawned.CollisionDamage = 3.0 * player.Damage
                    SFXManager():Play(SoundEffect.SOUND_ANGEL_BEAM)
                end
            else
                local probLight = utils.RandomLuck(player.Luck, 0.1, 0.5, 9.0)
                local rand = utils.RandomRange(rng, 0.0, 1.0)
                if rand <= probLight then
                    local lightSpawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.CRACK_THE_SKY, 0, effectPos, Vector.Zero, player):ToEffect()
                    lightSpawned.CollisionDamage = 3.0 * player.Damage
                    SFXManager():Play(SoundEffect.SOUND_ANGEL_BEAM)
                end
            end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_EVIL_EYE) then
            if utils.IsDirectionalShooting(player) then
                if not pData.Yami.EvilEyeBall then
                    pData.Yami.EvilEyeBall = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.EVIL_EYE, 0, effectPosAlt, Vector.Zero, player):ToEffect()
                    pData.Yami.EvilEyeBall:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                end
                --pData.Yami.EvilEyeBall.Velocity = (effectPosAlt - pData.Yami.EvilEyeBall.Position):Resized(5.0)
                pData.Yami.EvilEyeBall.Position = effectPosAlt
                if pData.Yami.EvilEyeDirectionalCount >= pData.Yami.EvilEyeDirectionalDelay then
                    pData.Yami.EvilEyeBall:GetSprite():Stop()
                    if headDirection == Direction.LEFT then
                        pData.Yami.EvilEyeBall:GetSprite():Play("ShootSide", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = true
                    elseif headDirection == Direction.UP then
                        pData.Yami.EvilEyeBall:GetSprite():Play("ShootUp", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = false
                    elseif headDirection == Direction.RIGHT then
                        pData.Yami.EvilEyeBall:GetSprite():Play("ShootSide", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = false
                    elseif headDirection == Direction.DOWN then
                        pData.Yami.EvilEyeBall:GetSprite():Play("ShootDown", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = false
                    end
                    local tearVel = utils.DirectionToVector[headDirection]:Resized(utils.GetShotSpeed(player, 1.0)*10.0)
                    player:FireTear(pData.Yami.EvilEyeBall.Position, tearVel, false, false, false, player)
                    pData.Yami.EvilEyeDirectionalCount = 0
                else
                    if headDirection == Direction.LEFT then
                        pData.Yami.EvilEyeBall:GetSprite():Play("IdleSide", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = true
                    elseif headDirection == Direction.UP then
                        pData.Yami.EvilEyeBall:GetSprite():Play("IdleUp", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = false
                    elseif headDirection == Direction.RIGHT then
                        pData.Yami.EvilEyeBall:GetSprite():Play("IdleSide", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = false
                    elseif headDirection == Direction.DOWN then
                        pData.Yami.EvilEyeBall:GetSprite():Play("IdleDown", true)
                        pData.Yami.EvilEyeBall:GetSprite().FlipX = false
                    end
                    local fireDelay = player.MaxFireDelay  -- Evitar divisiones entre 0
                    if fireDelay == 0 then 
                        fireDelay = 0.1
                    end
                    local increment = math.max(0.25, math.min(pData.Yami.EvilEyeDirectionalDelay, 1.0 / fireDelay))
                    pData.Yami.EvilEyeDirectionalCount = pData.Yami.EvilEyeDirectionalCount + increment
                end
                if pData.Yami.EvilEyeBall and pData.Yami.EvilEyeBall:IsDead() then
                    pData.Yami.EvilEyeBall:Remove() 
                    pData.Yami.EvilEyeBall = nil
                end
            else
                local probLight = utils.RandomLuck(player.Luck, 0.0333, 0.10, 20.0)
                local rand = utils.RandomRange(rng, 0.0, 1.0)
                if rand <= probLight then
                    local tearVel = lastFireDirection:Resized(utils.GetShotSpeed(player, 1.0)*3.0)
                    local lightSpawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.EVIL_EYE, 0, effectPosTear, tearVel, player):ToEffect()
                end
                for _, roomEntity in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.EVIL_EYE)) do
                    if roomEntity.Variant == EffectVariant.EVIL_EYE and roomEntity.SpawnerEntity then
                        local playerOwner = roomEntity.SpawnerEntity:ToPlayer()
                        if playerOwner and GetPtrHash(playerOwner) == GetPtrHash(player) then
                            roomEntity:GetSprite():Stop()
                            if headDirection == Direction.LEFT then
                                roomEntity:GetSprite():Play("ShootSide", true)
                                roomEntity:GetSprite().FlipX = true
                            elseif headDirection == Direction.UP then
                                roomEntity:GetSprite():Play("ShootUp", true)
                                roomEntity:GetSprite().FlipX = false
                            elseif headDirection == Direction.RIGHT then
                                roomEntity:GetSprite():Play("ShootSide", true)
                                roomEntity:GetSprite().FlipX = false
                            elseif headDirection == Direction.DOWN then
                                roomEntity:GetSprite():Play("ShootDown", true)
                                roomEntity:GetSprite().FlipX = false
                            end
                            local tearVel = utils.DirectionToVector[headDirection]:Resized(utils.GetShotSpeed(player, 1.0)*10.0)
                            player:FireTear(roomEntity.Position, tearVel, false, false, false, player)
                        end
                    end
                end 
            end
        end
        if player:HasCollectible(CollectibleType.COLLECTIBLE_TERRA) then
            if utils.IsDirectionalShooting(player) then
                if not pData.Yami.TerraRockBall then
                    pData.Yami.TerraRockBall = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.ROCK, 0, effectPosAlt, Vector.Zero, player):ToTear()
                    pData.Yami.TerraRockBall:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                    pData.Yami.TerraRockBall:AddTearFlags(TearFlags.TEAR_ROCK | TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL)  
                    --pData.Yami.TerraRockBall:FollowParent(player)
                    --pData.Yami.TerraRockBall.IsFollowing = false
                end
                --Lust:RemoveDataEffects(player, pData.Yami.BrimstoneBall)
                pData.Yami.TerraRockBall.Position = effectPosAlt
                --utils.SetAllTearFlag(player, pData.Yami.BrimstoneBall, tearParams)
                pData.Yami.TerraRockBall.CollisionDamage = player.Damage / directionalDamageReduction
                if pData.Yami.TerraRockBall and pData.Yami.TerraRockBall:IsDead() then
                    pData.Yami.TerraRockBall:Remove() 
                    pData.Yami.TerraRockBall = nil
                end
            else
                local tearVel = lastFireDirection:Resized(utils.GetShotSpeed(player))
                local tearSpawned = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.ROCK, 0, effectPosTear, tearVel, player):ToTear()
                tearSpawned:AddTearFlags(TearFlags.TEAR_ROCK)  
                tearSpawned.CollisionDamage = player.Damage
            end
        end
        if utils.IsUsingWeapon(player, WeaponType.WEAPON_BRIMSTONE)
            and not (utils.IsUsingWeapon(player, WeaponType.WEAPON_TECH_X)
                    or utils.IsUsingWeapon(player, WeaponType.WEAPON_LASER)) then
            if utils.IsDirectionalShooting(player) then
                if not pData.Yami.BrimstoneBall then
                    pData.Yami.BrimstoneBall = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BRIMSTONE_BALL, 0, effectPosAlt, Vector.Zero, player):ToEffect()
                    pData.Yami.BrimstoneBall:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                    pData.Yami.BrimstoneBall:FollowParent(player)
                    pData.Yami.BrimstoneBall.IsFollowing = false
                end
                --Lust:RemoveDataEffects(player, pData.Yami.BrimstoneBall)
                pData.Yami.BrimstoneBall.Position = effectPosAlt
                --utils.SetAllTearFlag(player, pData.Yami.BrimstoneBall, tearParams)
                pData.Yami.BrimstoneBall.CollisionDamage = player.Damage / directionalDamageReduction
            else
                if pData.Yami.IsFullCharge then
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
                if pData.Yami.BrimstoneBall then
                    pData.Yami.BrimstoneBall:Remove() 
                    pData.Yami.BrimstoneBall = nil
                end
                if not pData.Yami.FireTechX then
                    pData.Yami.FireTechX = player:FireTechXLaser(effectPosAlt, Vector.Zero, meleeLaserSize, player, player.Damage / directionalDamageReduction):ToLaser()
                    pData.Yami.FireTechX:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                end
                --Lust:RemoveDataEffects(player, pData.Yami.FireTechX)
                pData.Yami.FireTechX.Position = effectPosAlt
                utils.SetAllTearFlag(player, pData.Yami.FireTechX, tearParams)
            else 
                if pData.Yami.IsFullCharge then
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
                if not pData.Yami.DrFetusBombDirectional then
                    pData.Yami.DrFetusBombDirectional = player:FireBomb(effectPosAlt, Vector.Zero, player)
                    --pData.Yami.DrFetusBombDirectional:AddVelocity(Vector(-pData.Yami.DrFetusBombDirectional.Velocity.X, -pData.Yami.DrFetusBombDirectional.Velocity.Y))
                    if utils.IsUsingWeapon(player, WeaponType.WEAPON_BRIMSTONE) then
                        pData.Yami.DrFetusBombDirectional:AddTearFlags(TearFlags.TEAR_BRIMSTONE_BOMB)
                    end
                end
                if pData.Yami.DrFetusBombDirectional then
                    pData.Yami.DrFetusBombDirectional.Position = effectPosAlt
                    pData.Yami.DrFetusBombDirectional.Velocity = Vector.Zero
                    if pData.Yami.DrFetusBombDirectional:IsDead() then
                        pData.Yami.DrFetusBombDirectional:Remove()
                        pData.Yami.DrFetusBombDirectional = nil
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
        if not pData.Yami.ChargeBar then
            pData.Yami.ChargeBar = utils.Yami_ChargeBar()
        end

        -- Inicialización del contador de retraso si no existe
        if not pData.Yami.ChargeStartDelay then
            pData.Yami.ChargeStartDelay = 0
        end

        if pData.Yami.IsFullCharge then
            pData.Yami.ChargeProgress = 0
            pData.Yami.IsFullCharge = false
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
        pData.Yami.ChargingValue = math.max(0.0, math.min(1.0, pData.Yami.ChargeProgress / adjustedChargeTime))
        
        local fireInput = player:GetShootingInput()

        local fireDirection, lastFireDirection = utils.GetShootingDirection(player)
        --local isShooting = fireDirection:Length() > 0.2 or (fireInput:Length() > 0.2 and fireDirection:Length() > 0.2)
        local isShooting = fireDirection:Length() > 0.2 or fireInput:Length() > 0.2

        if player:HasCollectible(CollectibleType.COLLECTIBLE_KIDNEY_STONE) then
            --print("Is Shooting: ", fireDirection, fireInput)
        end

        if utils.IsDirectionalShooting(player) then
            pData.Yami.MeleeHitbox = pData.Yami.MeleeWeapon
            pData.Yami.MeleeHitbox:SetDamageSource(EntityType.ENTITY_PLAYER)
            pData.Yami.MeleeHitbox.CollisionDamage = player.Damage / directionalDamageReduction
            if isShooting then
                if player:HasCollectible(CollectibleType.COLLECTIBLE_DEAD_TOOTH) then
                    if not pData.Yami.DeadToothRing then
                        pData.Yami.DeadToothRing = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FART_RING, 0, headPosition, Vector.Zero, player):ToEffect()
                        pData.Yami.DeadToothRing:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                        pData.Yami.DeadToothRing:FollowParent(player)
                        --pData.Yami.DeadToothRing.SortingLayer = SortingLayer.SORTING_NORMAL
                        pData.Yami.DeadToothRing.DepthOffset = 200
                    else 
                        --pData.Yami.DeadToothRing.CollisionDamage = player.Damage / directionalDamageReduction
                    end
                end
            end
            --pData.Yami.MeleeHitbox:Update()
            Lust:PostUpdateMelee(player, lastFireDirection, pData.Yami.MeleeHitbox.Position)
        else 
            -- Detectamos si el jugador ha soltado el disparo
            local hasReleased = not isShooting and pData.Yami.WasShooting
    
            local inverseCharge = player:HasCollectible(CollectibleType.COLLECTIBLE_NEPTUNUS)

            if pData.Yami.MeleeWeapon and pData.Yami.MeleeWeapon:Exists() then
                local weaponSprite = pData.Yami.MeleeWeapon:GetSprite()

                if inverseCharge then
                    -- Incrementar el tiempo de espera antes de cargar la barra
                    pData.Yami.ChargeStartDelay = math.min(pData.Yami.ChargeStartDelay + 1, meleeChargeInitDelay) -- Retraso de 30 frames (medio segundo a 60 FPS)

                    if pData.Yami.ChargeStartDelay >= meleeChargeInitDelay then
                        if pData.Yami.DoOnceChargingSound then
                            SFXManager():Play(SoundEffect.SOUND_LIGHTBOLT_CHARGE)
                            pData.Yami.DoOnceChargingSound = false
                        end
                        pData.Yami.ChargeProgress = math.min(pData.Yami.ChargeBar.chargeProgress + 1, adjustedChargeTime) -- Incrementa progresivamente hasta 100
                        pData.Yami.ChargeBar:SetCharge(pData.Yami.ChargeProgress, adjustedChargeTime) -- Actualiza la barra
                    end
                end

                -- Cargar la barra mientras el botón está pulsado
                if isShooting then

                    if player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK) then
                        pData.Yami.MeleeLastFireDirection = player:GetLastDirection()
                    else
                        pData.Yami.MeleeLastFireDirection = fireDirection
                    end
                    
                    if not inverseCharge then
                        -- Incrementar el tiempo de espera antes de cargar la barra
                        pData.Yami.ChargeStartDelay = math.min(pData.Yami.ChargeStartDelay + 1, meleeChargeInitDelay) -- Retraso de 30 frames (medio segundo a 60 FPS)
                        
                        -- Si ha pasado el tiempo de espera, empieza a cargar la barra
                        if pData.Yami.ChargeStartDelay >= meleeChargeInitDelay then
                            if pData.Yami.DoOnceChargingSound then
                                SFXManager():Play(SoundEffect.SOUND_LIGHTBOLT_CHARGE)
                                pData.Yami.DoOnceChargingSound = false
                            end
                            pData.Yami.ChargeProgress = math.min(pData.Yami.ChargeBar.chargeProgress + 1, adjustedChargeTime) -- Incrementa progresivamente hasta 100
                            pData.Yami.ChargeBar:SetCharge(pData.Yami.ChargeProgress, adjustedChargeTime) -- Actualiza la barra
                        end

                    end


                    --local timeToSpawnMawVoid = 45
                    pData.Yami.TimeAttacking = pData.Yami.TimeAttacking + 1
                    --print("pData.Yami.TimeAttacking: ", pData.Yami.TimeAttacking)
                    --if pData.Yami.TimeAttacking >= timeToSpawnMawVoid then
                    --    pData.Yami.MawOfVoidReady = true
                       -- print("Maw ready!")
                   -- end

                   if player:HasCollectible(CollectibleType.COLLECTIBLE_DEAD_TOOTH) then
                        if not pData.Yami.DeadToothRing then
                            pData.Yami.DeadToothRing = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.FART_RING, 0, headPosition, Vector.Zero, player):ToEffect()
                            pData.Yami.DeadToothRing:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                            pData.Yami.DeadToothRing:FollowParent(player)
                            --pData.Yami.DeadToothRing.SortingLayer = SortingLayer.SORTING_NORMAL
                            pData.Yami.DeadToothRing.DepthOffset = 200
                        else 
                            --pData.Yami.DeadToothRing.CollisionDamage = player.Damage / directionalDamageReduction
                        end
                    end
                else
                    -- Resetear la barra si el botón se ha soltado
                    if not inverseCharge then
                        pData.Yami.ChargeBar:SetCharge(0, adjustedChargeTime)
                        pData.Yami.ChargeStartDelay = 0
                    end
                end
                

                -- Si soltó el disparo, ejecuta el ataque
                if hasReleased then
                    if inverseCharge then
                        pData.Yami.ChargeBar:SetCharge(0, adjustedChargeTime)
                        pData.Yami.ChargeStartDelay = 0
                    end

                    if pData.Yami.DeadToothRing then
                        pData.Yami.DeadToothRing:Remove()
                        pData.Yami.DeadToothRing = nil
                    end

                    if player.FireDelay <= 0 and not pData.Yami.MeleeAttackTriggered and player:IsExtraAnimationFinished() and player.ControlsEnabled then
                        pData.Yami.DoOnceChargingSound = true
                        -- Comprobar si la barra está cargada al máximo
                        pData.Yami.IsFullCharge = pData.Yami.ChargeProgress >= adjustedChargeTime
                        
                        pData.Yami.CurrentEye = (pData.Yami.CurrentEye % (utils.Eyes.NUM_EYES - 1)) + 1

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL) then
                            pData.Yami.CurrentEye = utils.Eyes.RIGHT
                        end 
                        
                        -- Control de animaciones del ataque
                        local animName = utils.GetAnimationName(player, weaponSprite)
    
                        --print(animName)
    
                        --weaponSprite:Update()
                        --print("Aim: ", player:GetLastDirection())

                        lastFireDirection = pData.Yami.MeleeLastFireDirection
                        
                        if player:HasCollectible(CollectibleType.COLLECTIBLE_EPIPHORA) then
                            if pData.Yami.PrevAttackDirection and utils.VectorEquals(pData.Yami.PrevAttackDirection, lastFireDirection) then
                                if pData.Yami.TimeMarkSameDirection == 0 then
                                    pData.Yami.TimeMarkSameDirection = pData.Yami.TimeAttacking
                                end 
                            else
                                pData.Yami.PrevAttackDirection = lastFireDirection
                                pData.Yami.TimeMarkSameDirection = 0
                            end
                        end

                        --local numAttacks = 1
                        local attacks = {}

                        local roundedX = utils.Round(lastFireDirection.X, 1)
                        local roundedY = utils.Round(lastFireDirection.Y, 1)
                        local isDiagonal = (math.abs(roundedX) == 0.7) and (math.abs(roundedY) == 0.7)

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_EYE) then
                            local rand = utils.RandomRange(rng, 0.0, 1.0)
                            --local prob = math.max(0.0, math.min(1.0, player.Luck / 2.0))
                            local prob = utils.RandomLuck(player.Luck, 0.0, 1.0, 2.0)
                            if rand <= prob then
                                local oppositeDirection = Vector(lastFireDirection.X * -1.0, lastFireDirection.X * -1.0)
                                if not utils.ContainsDirection(attacks, oppositeDirection) then
                                    table.insert(attacks, oppositeDirection)
                                end 
                            end
                        end

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_LOKIS_HORNS) then
                            local rand = utils.RandomRange(rng, 0.0, 1.0)
                            --local prob = math.max(0.125, math.min(1.0, (player.Luck+5.0) / 20.0))
                            local prob = utils.RandomLuck(player.Luck + 5.0, 0.125, 1.0, 20.0)
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

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_CURSED_EYE) then
                            local numberAttacks = math.max(0, math.min(4, pData.Yami.ChargingValue / 0.25))

                            local angles = {-15, -5, 5, 15}

                            while numberAttacks > 0 do
                                local angle = utils.ChooseRemove(rng, angles)
                                local attackDirection = utils.RotateVector(lastFireDirection, angle)
                                if not utils.ContainsDirection(attacks, attackDirection) then
                                    table.insert(attacks, attackDirection)
                                    --numAttacks = numAttacks + 1
                                end
                                numberAttacks = numberAttacks - 1 
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

                        if player:HasCollectible(CollectibleType.COLLECTIBLE_MONSTROS_LUNG) 
                            or (player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL) and pData.Yami.TotalAttacksNum%15 == 0) then
                            -- Angulos en grados para los disparos en forma de abanico
                            local angles = {-20, -10, 10, 20}
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

                            pData.Yami.TotalAttacksNum = pData.Yami.TotalAttacksNum + 1

                            --if numAttacks > 1 then
                            lastFireDirection = direction
                            --end

                            -- Crear el hitbox del ataque
                            pData.Yami.MeleeHitbox = Isaac.Spawn(EntityType.ENTITY_EFFECT, weaponAttack, 0, player.Position, Vector.Zero, player):ToEffect()
                            local hitbox = pData.Yami.MeleeHitbox
                            local hitboxSprite = hitbox:GetSprite()
        
                            -- Configurar el hitbox con la animación del arma
                            hitboxSprite:Play(weaponSprite:GetAnimation(), true)
                            hitboxSprite.Rotation = lastFireDirection:GetAngleDegrees() - 90
                            hitboxSprite.Offset = lastFireDirection:Resized(-meleeDistance * 0.5) + Vector(0, meleeSpriteOffset)
        
                            local vecScale = Vector.One
                            --if pData.Yami.IsFullCharge then 
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
                            if pData.Yami.IsFullCharge then 
                                vecScale =  Vector(2.0, 0.4)
                            end
                            print("Animation long 3: ", vecScale);
                            ]]--
        
                            hitbox:SetSize(utils.GetMeleeSize(player) * meleeRange, hitbox.SizeMulti, 12)
                            hitbox:FollowParent(player)
                            hitbox.ParentOffset = lastFireDirection * meleeDistance
                            hitbox:SetDamageSource(EntityType.ENTITY_PLAYER)
        
                            -- Ajustar el daño del ataque
                            --print("damageBonus: ", damageBonus)
                            --print("damageMultiplier: ", damageMultiplier)
                            --print("Delay: ", pData.Yami.ChargeProgress)
                            hitbox.CollisionDamage = utils.ApplyDamageBonus(player, meleeDamageMult, meleeChargeDamageMult, adjustedChargeTime)
                            hitbox:SetTimeout(meleeTimeout)
                            --hitbox:Update()
                            -- Actualización de tiempos y estados
                            local fireDelayMultiplier = 1.0
                            local fireDelayBonus = 0.0
                            if player:HasCollectible(CollectibleType.COLLECTIBLE_EPIPHORA) and pData.Yami.TimeMarkSameDirection ~= 0 then
                                local timeDiff = math.max(0.0, pData.Yami.TimeAttacking - pData.Yami.TimeMarkSameDirection)
                                local maxTimeEpiphoraSpeed = 100
                                --print("pData.Yami.TimeMarkSameDirection: ", pData.Yami.TimeMarkSameDirection)
                                --print("timeDiff: ", timeDiff)
                                fireDelayMultiplier = fireDelayMultiplier * (1.0 - (0.5 * math.min(1.0, timeDiff / maxTimeEpiphoraSpeed) ))
                                --print("fireDelayMultiplier: ", fireDelayMultiplier)
                            end
                            if player:HasCollectible(CollectibleType.COLLECTIBLE_EYE_DROPS) and pData.Yami.CurrentEye == utils.Eyes.LEFT then
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
                        if pData.Yami.IsFullCharge then
                            SFXManager():Play(SoundEffect.SOUND_REDLIGHTNING_ZAP_WEAK)
                        else
                            SFXManager():Play(SoundEffect.SOUND_LIGHTBOLT)
                        end
                        
                        -- Marcar que el ataque fue ejecutado
                        pData.Yami.MeleeAttackTriggered = true
                    end
                else
                    -- Resetear el estado del ataque si es necesario
                    if player.FireDelay <= 0 or pData.Yami.MeleeAttackTriggered then
                        pData.Yami.MeleeAttackTriggered = false
                    end
                end

                if isShooting then
                    pData.Yami.TimeWithoutAttacking = 0
                end
            end
    
            -- Guardar si el jugador está disparando para detectar "al soltar"
            pData.Yami.WasShooting = isShooting
        end

        if not isShooting then
            pData.Yami.ChargeProgress = 0
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
            if pData.Yami.IsDeadFirstCheck then
                --player:TryRemoveNullCostume(costumeAlt)
                --player:AddNullCostume(costume)
                --local playerSprite = player:GetSprite()
                --playerSprite:ReplaceSpritesheet(0, skinMain)
                --playerSprite:LoadGraphics()
                pData.Yami.IsDeadFirstCheck = false
                pData.Yami.IsRenderChanged = true
            end
        else
            if pData.Yami.IsRenderChanged then
                --print("pData.Yami.IsRenderChanged = TRUE")
                if pData.Yami.IsCrownActive then
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

                local weaponSprite = pData.Yami.MeleeWeapon:GetSprite()
                if utils.CheckCrownOfLightStatus(player) then
                    weaponSprite:Play("Idle", true)
                else 
                    weaponSprite:Play("IdleAlt", true)
                end

                pData.Yami.IsRenderChanged = false
            end
            pData.Yami.IsDeadFirstCheck = true
        end

        if player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
            if not pData.Yami.FriendlyHalo and pData.Yami.IsCrownActive then
                local headPosition = player.Position + Vector(0, player.TearHeight)
                pData.Yami.FriendlyHalo = Isaac.Spawn(EntityType.ENTITY_EFFECT, friendlyHalo, 1, headPosition, Vector.Zero, player):ToEffect()
                pData.Yami.FriendlyHalo:AddEntityFlags(EntityFlag.FLAG_DONT_OVERWRITE | EntityFlag.FLAG_PERSISTENT)
                pData.Yami.FriendlyHalo:FollowParent(player)
                pData.Yami.FriendlyHalo.Color = Color(0.2, 1.0, 1.0, 0.7, 0, 0, 0) 
                --pData.Yami.FriendlyHalo.ParentOffset = Vector(0, meleeOffset)
            end

            if pData.Yami.FriendlyHalo then
                if not pData.Yami.IsCrownActive then
                    pData.Yami.FriendlyHalo:Remove()
                    pData.Yami.FriendlyHalo = nil
                else 
                    if utils.IsDirectionalShooting(player) then
                        pData.Yami.FriendlyHalo.IsFollowing = false
                    else
                        pData.Yami.FriendlyHalo.IsFollowing = true
                    end
                    local sizeRange = player.TearRange / 6.0
                    pData.Yami.FriendlyHalo:SetSize(sizeRange, pData.Yami.FriendlyHalo.SizeMulti, 12)
                    --pData.Yami.FriendlyHalo.SpriteScale = sizeRange / 40.0 * pData.Yami.FriendlyHalo.SizeMulti
                    pData.Yami.FriendlyHalo.SpriteScale = sizeRange / 40.0 * pData.Yami.FriendlyHalo.SizeMulti
                end
            end
        end

        if not utils.IsDirectionalShooting(player) and Options.ChargeBars and pData.Yami.ChargeBar then
            local pChargeBarOffset = utils.HasChargeBarItem(player) and -1 or 1
            local pOffset = player:GetFlyingOffset() + Vector(18 * pChargeBarOffset, -54) * player.SpriteScale

            --local position = player.Position + Vector(0, -40)  -- Posición sobre el jugador
            pData.Yami.ChargeBar:Render(player.Position + pOffset)
        end
    end
end

function Lust:UpdatePlayer(player)
    if player:GetPlayerType() == playerType then
        local pData = player:GetData()
        if not pData.Yami.MeleeAttackTriggered and not utils.IsDirectionalShooting(player) then
            pData.Yami.TimeWithoutAttacking = pData.Yami.TimeWithoutAttacking + 1
            if pData.Yami.TimeWithoutAttacking >= 5 then
                pData.Yami.TimeAttacking = 0
                pData.Yami.TimeMarkSameDirection = 0
            end
        end
        --print("TimeMarkSameDirection: ", pData.Yami.TimeMarkSameDirection)
        --print("timeDiff: ", math.max(0.0, pData.Yami.TimeAttacking - pData.Yami.TimeMarkSameDirection))
        pData.Yami.IsKnockBacked = false

        if not utils.IsDirectionalShooting(player) then
            Lust:RemoveDataEffects(player)
        end

        local headDirection = player:GetHeadDirection()

        for _, roomEntity in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.EVIL_EYE)) do
            if roomEntity.SpawnerEntity then
                local playerOwner = roomEntity.SpawnerEntity:ToPlayer()
                if playerOwner and GetPtrHash(playerOwner) == GetPtrHash(player) then
                    local lastAnimation = roomEntity:GetSprite():GetAnimation()
                    if roomEntity:GetSprite():IsFinished(lastAnimation) then
                        if lastAnimation == "ShootDown" then
                            roomEntity:GetSprite():Play("IdleDown")
                        elseif lastAnimation == "ShootSide" then
                            roomEntity:GetSprite():Play("IdleSide")
                        elseif lastAnimation == "ShootUp" then
                            roomEntity:GetSprite():Play("IdleUp")
                        end
                    end
                end
            end
        end 

        if pData.Yami.IsNewRoom then
            --print("ENABLING CROWN AGAIN!")
            pData.Yami.IsCrownDamaged = false

            if pData.Yami.DeadToothRing then
                pData.Yami.DeadToothRing:Remove()
                pData.Yami.DeadToothRing = nil
            end
        end
        pData.Yami.IsNewRoom = false
    end
end

function Lust:OnDamage(entity, amount, flag, source, countdown)
    local player = entity:ToPlayer()
    if player and player:GetPlayerType() == playerType then
        --print("PLAYER IS DAMAGED!")
        local pData = player:GetData()
        pData.Yami.IsCrownDamaged = true

    end
end

function Lust:OnNewRoom()
    for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PLAYER)) do
        local player = entity:ToPlayer() -- Convierte la entidad en un jugador

        -- Verifica si el tipo de jugador coincide con el especificado
        if player and player:GetPlayerType() == playerType then
            local pData = player:GetData() -- Obtiene los datos del jugador

            -- Guarda una variable única en los datos del jugador
            pData.Yami.IsNewRoom = true
        end
    end
end


function Lust:OnTearPreColl(entity, colEntity, low)
    local eData = entity:GetData()
    if not eData.Yami then eData.Yami = {} end
    if eData.Yami.IgnoreCollisionWithVariant and utils.IsValueInList(eData.Yami.IgnoreCollisionWithVariant, colEntity.Variant) then
        if eData.Yami.IgnoreCollisionWithTime > 0 then
            eData.Yami.IgnoreCollisionWithTime = eData.Yami.IgnoreCollisionWithTime - 1
        end
        return true
    end
    if eData.Yami.IgnoreCollisionWith and utils.IsValueInList(eData.Yami.IgnoreCollisionWith, GetPtrHash(colEntity)) then
        if eData.Yami.IgnoreCollisionWithTime > 0 then
            eData.Yami.IgnoreCollisionWithTime = eData.Yami.IgnoreCollisionWithTime - 1
        end
        return true
    end
end

function Lust:OnPlayerPreColl(player, colEntity, low)
    if player:GetPlayerType() == playerType then
        local pData = player:GetData()
        if player:HasCollectible(CollectibleType.COLLECTIBLE_CURSED_EYE) then
            if pData.Yami.ChargingValue > 0.0 and pData.Yami.ChargingValue < 1.0 and colEntity.CollisionDamage > 0.0 then
                --player:GetSprite():Stop()
                player:AnimateTeleport(true)
                local level = game:GetLevel()
                local roomIndex = level:GetRandomRoomIndex(false, rng:GetSeed())
                game:StartRoomTransition(roomIndex, Direction.NO_DIRECTION, RoomTransitionAnim.TELEPORT)
                --SFXManager():Play(SoundEffect.SOUND_HELL_PORTAL2)
                return true
            end
        end
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

mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_COLLISION, CallbackPriority.DEFAULT, function(_, player, colEntity, low)
    if Lust:OnPlayerPreColl(player, colEntity, low) then
        return true
    end
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