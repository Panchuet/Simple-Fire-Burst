behaviour("SimpleBurstFire")

-- Keys:
--   startNonBurst         (bool)   : If true, the weapon starts in non-burst mode instead of burst mode
--   nonBurstAuto          (bool)   : If true, non-burst mode will fire in full-auto instead of semi-auto
--   nonResetting          (bool)   : If true, leftover shots carry over to the next trigger pull (M16A2 style)
--   burstCount            (int)    : Total number of shots fired per burst
--   botBurstCooldown      (float)  : Cooldown time in seconds between bursts specifically for bots
--   switchCooldown        (float)  : Lockout time in seconds before you can switch modes again, best if you match the switch animation length
--   switchKeybind         (string) : Lowercase keybind of the key you want to use to switch modes
--   switchParameterName   (string) : Name of the animator trigger parameter to play on switch
--   selectorValues        (string) : Two space-separated integers for the selector lever position per mode e.g. "0 1" (mode 0 = burst, mode 1 = non-burst)
--   selectorParameterName (string) : Name of the animator integer parameter that holds the selector lever position

function SimpleBurstFire:Start()
    self.weapon = self.gameObject.GetComponent(Weapon)
    self.animator = self.gameObject.GetComponent(Animator)
    self.dataContainer = self.gameObject.GetComponent(DataContainer)

    self.modeIndex = self.dataContainer.GetBool("startNonBurst") and 1 or 0
    self.nonBurstAuto = self.dataContainer.GetBool("nonBurstAuto")
    self.nonResetting = self.dataContainer.GetBool("nonResetting")

    self.burstCount = self.dataContainer.GetInt("burstCount")
    self.botBurstCooldown = self.dataContainer.GetFloat("botBurstCooldown")

    self.switchCooldown = self.dataContainer.GetFloat("switchCooldown")
    self.switchKeybind = self.dataContainer.GetString("switchKeybind")

    self.selectorValues = {}
    for match in (self.dataContainer.GetString("selectorValues") .. " "):gmatch("(.-) ") do
        table.insert(self.selectorValues, tonumber(match))
    end

    if self.animator ~= nil then
        self.switchParameter = self.animator.StringToHash(self.dataContainer.GetString("switchParameterName"))
        self.selectorParameter = self.animator.StringToHash(self.dataContainer.GetString("selectorParameterName"))
    end

    self.switchTimer = 0
    self.shotsFired = 0
    self.botCooldownTimer = 0
    self.burstLocked = false
    
    if self.weapon ~= nil then
        self.weapon.onSpawnProjectiles.AddListener(self, "OnFire")
    end

    self:ApplyMode()
end

function SimpleBurstFire:OnFire()
    if self.modeIndex ~= 0 then return end

    self.shotsFired = self.shotsFired + 1
    if self.shotsFired >= self.burstCount then
        self.weapon.LockWeapon()
        self.burstLocked = true
        
        if self.weapon.user ~= nil and self.weapon.user.isBot then
            self.botCooldownTimer = self.botBurstCooldown
        end
    end
end

function SimpleBurstFire:ApplyMode()
    self.weapon.isAuto = self.modeIndex == 0 and true or self.nonBurstAuto
    
    if self.animator ~= nil then
        self.animator.SetInteger(self.selectorParameter, self.selectorValues[self.modeIndex + 1])
    end
    
    self.shotsFired = 0
    self.burstLocked = false
    self.botCooldownTimer = 0
end

function SimpleBurstFire:SwitchMode()
    self.modeIndex = 1 - self.modeIndex
    self.switchTimer = self.switchCooldown
    self.weapon.LockWeapon()
    
    if self.animator ~= nil then
        self.animator.SetTrigger(self.switchParameter)
    end
    
    self:ApplyMode()
end

function SimpleBurstFire:OnEnable()
    if self.animator == nil then return end
    self.animator.SetInteger(self.selectorParameter, self.selectorValues[self.modeIndex + 1])
end

function SimpleBurstFire:Update()
    if self.weapon == nil then return end

    if self.switchTimer > 0 then
        self.switchTimer = self.switchTimer - Time.deltaTime

        if self.switchTimer <= 0 then
            self.weapon.UnlockWeapon()
        end
    end

    if self.switchTimer <= 0
        and not self.weapon.isReloading
        and self.weapon.user ~= nil
        and self.weapon.user.isPlayer
        and Input.GetKeyDown(self.switchKeybind)
    then
        self:SwitchMode()
    end

    if self.modeIndex == 0 then
        local triggerReleased = not self.weapon.isHoldingFire

        if self.weapon.user ~= nil and self.weapon.user.isBot then
            if self.burstLocked then
                if self.botCooldownTimer > 0 then
                    self.botCooldownTimer = self.botCooldownTimer - Time.deltaTime
                else
                    self.weapon.UnlockWeapon()
                    self.burstLocked = false
                    self.shotsFired = 0
                end
            end
        else
            if self.burstLocked and triggerReleased then
                self.weapon.UnlockWeapon()
                self.burstLocked = false
                self.shotsFired = 0
            end
        end

        if not self.nonResetting and triggerReleased then
            self.shotsFired = 0
        end
    end
end