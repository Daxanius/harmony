-- update.lua
local config = require("config")

local function readLocalVersion()
    if not fs.exists(config.localVersionPath) then
        return nil
    end
    local file = fs.open(config.localVersionPath, "r")
    local version = file.readAll()
    file.close()
    return version
end

local function fetchRemoteVersion()
    local response = http.get(config.remoteURL .. "/harmony/version.txt")
    if response then
        local remoteVersion = response.readAll()
        response.close()
        return remoteVersion
    else
        return nil
    end
end

function checkForUpdates()
    local localVersion = readLocalVersion()
    local remoteVersion = fetchRemoteVersion()

    if not localVersion or not remoteVersion then
        return false -- Technicall an error fetching versions
    end

    return localVersion ~= remoteVersion
end

function update()
    shell.run("wget", "run", config.remoteURL .. "/" .. "install.lua")
end
