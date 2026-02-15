-- ================================================
-- STUB SCRIPT v1.0 - Security & Validation
-- ================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ================================================
-- CONFIGURATION
-- ================================================
local CONFIG = {
    VALIDATION_URL = _G.__STUB_V__ or "https://silent-lake-0164.tutorkah21011.workers.dev/validate",
    LOADER_URL = _G.__STUB_L__ or "https://raw.githubusercontent.com/tutorkah21012-collab/Wtk/refs/heads/main/Uy.lua",
    DUELS_URL = _G.__STUB_T__ or "https://round-river-8781.cedsceds12.workers.dev/load-duels?key=",
    
    KEY = script_key or _G.script_key or "VINCITORE",
    SCRIPT_TYPE = "duels",
    
    MAX_RETRIES = 3,
    RETRY_DELAY = 2,
    TIMEOUT = 10,
}

-- ================================================
-- ANTI-CHEAT / SECURITY
-- ================================================
local Security = {}

-- Anti-tamper check
function Security:CheckIntegrity()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    -- Check if script is being debugged
    if gethiddenproperty or sethiddenproperty then
        return false, "Debug tools detected"
    end
    
    -- Check if script is being decompiled
    if decompile or getscriptbytecode then
        return false, "Decompiler detected"
    end
    
    -- Check if player is in valid game state
    if not LocalPlayer then
        return false, "Invalid player state"
    end
    
    return true, "OK"
end

-- Anti-duplicate execution
function Security:CheckDuplicate()
    if _G.__SCRIPT_LOADED__ then
        return false, "Script already running"
    end
    _G.__SCRIPT_LOADED__ = true
    return true, "OK"
end

-- Get hardware identifier
function Security:GetHWID()
    local hwid = nil
    
    -- Method 1: User ID (most reliable)
    if LocalPlayer and LocalPlayer.UserId then
        hwid = tostring(LocalPlayer.UserId)
    end
    
    -- Method 2: Fallback to executor fingerprint
    if not hwid then
        local success, result = pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if success and result then
            hwid = result
        end
    end
    
    -- Method 3: Generate unique ID
    if not hwid then
        hwid = HttpService:GenerateGUID(false)
        _G.__CACHED_HWID__ = hwid
    end
    
    return hwid
end

-- ================================================
-- VALIDATION
-- ================================================
local Validator = {}

function Validator:Validate()
    local success, integrity = Security:CheckIntegrity()
    if not success then
        return false, "Security check failed: " .. integrity
    end
    
    local duplicateCheck, duplicateMsg = Security:CheckDuplicate()
    if not duplicateCheck then
        return false, duplicateMsg
    end
    
    local hwid = Security:GetHWID()
    if not hwid then
        return false, "Failed to get hardware ID"
    end
    
    local requestData = {
        key = CONFIG.KEY,
        userId = LocalPlayer.UserId,
        username = LocalPlayer.Name,
        displayName = LocalPlayer.DisplayName,
        script_type = CONFIG.SCRIPT_TYPE,
        hwid = hwid,
        executor = identifyexecutor and identifyexecutor() or "Unknown",
        game_id = game.PlaceId,
        job_id = game.JobId
    }
    
    for attempt = 1, CONFIG.MAX_RETRIES do
        local success, result = pcall(function()
            local response = request({
                Url = CONFIG.VALIDATION_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(requestData)
            })
            
            if response.StatusCode == 200 then
                return HttpService:JSONDecode(response.Body)
            else
                error("HTTP " .. response.StatusCode)
            end
        end)
        
        if success and result then
            if result.success then
                return true, result.message or "Validation successful"
            else
                return false, result.message or "Validation failed"
            end
        else
            if attempt < CONFIG.MAX_RETRIES then
                task.wait(CONFIG.RETRY_DELAY)
            else
                return false, "Connection failed after " .. CONFIG.MAX_RETRIES .. " attempts"
            end
        end
    end
    
    return false, "Unknown error"
end

-- ================================================
-- LOADER
-- ================================================
local Loader = {}

function Loader:LoadScript(url)
    local success, result = pcall(function()
        return game:HttpGet(url, true)
    end)
    
    if not success then
        return false, "Failed to fetch script: " .. tostring(result)
    end
    
    if not result or result == "" then
        return false, "Script is empty"
    end
    
    local loadSuccess, loadedFunc = pcall(loadstring, result)
    if not loadSuccess or not loadedFunc then
        return false, "Failed to load script"
    end
    
    local execSuccess, execResult = pcall(loadedFunc)
    if not execSuccess then
        return false, "Script execution error: " .. tostring(execResult)
    end
    
    return true, "Script loaded successfully"
end

function Loader:LoadDuels()
    local url = CONFIG.DUELS_URL .. CONFIG.KEY
    return self:LoadScript(url)
end

function Loader:LoadMain()
    return self:LoadScript(CONFIG.LOADER_URL)
end

-- ================================================
-- UI NOTIFICATIONS
-- ================================================
local Notify = {}

function Notify:Send(title, message, duration)
    duration = duration or 5
    
    local success = pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = duration,
            Icon = "rbxassetid://6023426915"
        })
    end)
    
    if not success then
        warn("[" .. title .. "] " .. message)
    end
end

function Notify:Success(message)
    self:Send("✅ Success", message, 3)
end

function Notify:Error(message)
    self:Send("❌ Error", message, 5)
end

function Notify:Info(message)
    self:Send("ℹ️ Info", message, 3)
end

-- ================================================
-- MAIN EXECUTION
-- ================================================
local function Main()
    -- Show loading
    Notify:Info("Validating license...")
    
    -- Validate key
    local isValid, validationMessage = Validator:Validate()
    
    if not isValid then
        Notify:Error("Validation Failed: " .. validationMessage)
        
        -- Kick player after delay
        task.wait(3)
        if LocalPlayer then
            LocalPlayer:Kick("\n❌ License Validation Failed\n\n" .. validationMessage .. "\n\nPlease contact support.")
        end
        return
    end
    
    -- Validation successful
    Notify:Success("License validated!")
    
    -- Load main script
    Notify:Info("Loading script...")
    
    local loadSuccess, loadMessage = Loader:LoadMain()
    
    if not loadSuccess then
        Notify:Error("Load Failed: " .. loadMessage)
        task.wait(3)
        if LocalPlayer then
            LocalPlayer:Kick("\n❌ Script Load Failed\n\n" .. loadMessage)
        end
        return
    end
    
    -- Optional: Load duels if configured
    if CONFIG.SCRIPT_TYPE == "duels" and CONFIG.DUELS_URL ~= "" then
        task.wait(0.5)
        local duelsSuccess, duelsMessage = Loader:LoadDuels()
        if duelsSuccess then
            Notify:Success("Duels loaded!")
        else
            warn("Duels load failed:", duelsMessage)
        end
    end
    
    Notify:Success("Script loaded successfully!")
end

-- ================================================
-- ERROR HANDLER
-- ================================================
local function ErrorHandler()
    local success, error = pcall(Main)
    
    if not success then
        Notify:Error("Fatal Error: " .. tostring(error))
        
        task.wait(3)
        if LocalPlayer then
            LocalPlayer:Kick("\n❌ Fatal Error\n\n" .. tostring(error))
        end
    end
end

-- ================================================
-- EXECUTE
-- ================================================
task.spawn(ErrorHandler)
