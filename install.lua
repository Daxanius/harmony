local args = { ... }
local branch = "main"

if #args > 0 then
    branch = args[1]
end

local repoURL = "https://raw.githubusercontent.com/Daxanius/harmony/" .. branch

-- List of files to download and their paths
local files = {
    "/harmony.lua",
    "/harmony/config.lua",
    "/harmony/gui.lua",
    "/harmony/lib.lua",
    "/harmony/update.lua",
    "/harmony/version.txt",
    "/harmony/theme/default.lua"
}

-- Function to download and save a file
local function downloadFile(fileName)
    local url = repoURL .. fileName
    local response = http.get(url)
    if response then
        local fileContent = response.readAll()
        response.close()

        local filePath = fileName
        local file = fs.open(filePath, "w")
        file.write(fileContent)
        file.close()
        print("Updated " .. fileName)
    else
        print("Failed to download " .. fileName)
    end
end

-- Remove basalt if it exists
if fs.exists("/basalt.lua") then
    fs.delete("/basalt.lua")
end

-- Install basalt
shell.run("wget", "run", "https://raw.githubusercontent.com/Pyroxenium/Basalt/refs/heads/master/docs/install.lua release ", "release")

-- Download all files
for _, file in ipairs(files) do
    downloadFile(file)
end

print("Installation complete.")
