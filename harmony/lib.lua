local dfpwm = require("cc.audio.dfpwm")
local speakers = { peripheral.find("speaker") }
local decoder = dfpwm.make_decoder()

Volume = 1

local function playChunk(chunk)
    local callBacks = {}
    local returnValue = nil

    for _, speaker in pairs(speakers) do
        table.insert(callBacks, function()
            returnValue = speaker.playAudio(chunk, Volume or 1)
        end)
    end

    parallel.waitForAll(table.unpack(callBacks))

    return returnValue
end

local HarmonySession = {
    _host = "https://localhost:8000/",
    _token = nil,
    _log_function = function(message)
        print(message)
    end,
    _maxStreamFails = 5,
    _streamFailCooldown = 0.1,
    _historyWatchPercent = 0.1,
    streamSize = 16 * 1024,
    user = nil,
    verbose = false,
    songState = nil,
    historySize = 10,
    mode = "normal",
    songs = {},
    history = {}
}

function HarmonySession:new(host, historySize, historyWatchPercent, streamSize, maxStreamFails, streamFailCooldown,
                            verbose, logFunction)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    self._host = host or self._host
    self.historySize = historySize
    self._historyWatchPercent = historyWatchPercent
    self._maxStreamFails = maxStreamFails
    self._streamFailCooldown = streamFailCooldown
    self.streamSize = streamSize * 1024

    if logFunction ~= nil then
        self._log_function = logFunction
    end

    self.verbose = verbose or false
    return o
end

function HarmonySession:_log(message)
    if self.verbose then
        self._log_function(message)
    end
end

function HarmonySession:_add_to_history(song)
    if #self.history + 1 > self.historySize then -- Keep a max of 10 songs in the history
        table.remove(self.history, 1)
    end

    self.history[#self.history + 1] = song
end

function HarmonySession:_makeRequest(endpoint, method, data, binary)
    local url = self._host .. endpoint
    local body = data and textutils.serializeJSON(data) or nil
    local headers = { ["Content-Type"] = "application/json", ["Authorization"] = self._token }
    local request = {
        url = url,
        method = method,
        headers = headers,
        body = body
    }

    self:_log("Making " .. method .. " request to " .. url)

    http.request(request)

    while true do
        local event, response_url, responseBody, res = os.pullEvent()
        if event == "http_success" and response_url == url then
            self:_log("Request successful: " .. url)

            if binary then
                return true, responseBody.readAll()
            else
                return true, textutils.unserializeJSON(responseBody.readAll())
            end
        elseif event == "http_failure" and response_url == url then
            self:_log("Request failed: " .. url .. " " .. responseBody)

            if res == nil then
                return false, responseBody
            else
                return false, res.readAll()
            end
        end
    end
end

function HarmonySession:popHistory()
    if #self.history == 0 then
        return nil -- No song to pop if history is empty
    end

    -- Pop the last song from the history
    local song = self.history[#self.history]
    table.remove(self.history, #self.history)

    if song == nil then
        return session.songState.song
    end

    return song
end

function HarmonySession:getServerVersion()
    local success, response = self:_makeRequest("", "GET")

    if success then
        self:_log("Fetch server version success: " .. response)
    else
        self:_log("Fetch server version failed: " .. response)
    end

    return success, response
end

function HarmonySession:login(username, password)
    local success, response = self:_makeRequest("user/login", "POST", { name = username, password = password })

    if success then
        self.user = response.user
        self._token = response.token

        self:_log("Login successful for user: " .. username)
    else
        self:_log("Login failed for user: " .. username)
    end

    return success, response
end

function HarmonySession:register(username, password)
    local success, response = self:_makeRequest("user", "POST", { name = username, password = password })

    if success then
        self:_log("Registration successful for user: " .. username)
        return self:login(username, password); -- Login after registration
    else
        self:_log("Registration failed for user: " .. username)
    end

    return success, response
end

function HarmonySession:listSongs(query)
    local success, response

    if query == nil then
        success, response = self:_makeRequest("song", "GET")
    else
        success, response = self:_makeRequest("song/find/" .. query, "GET")
    end

    if success then
        self:_log("Fetching songs successful")
    else
        self:_log("Fetching songs failed: " .. response)
    end

    return success, response
end

function HarmonySession:loadStream(song)
    local success, response = self:_makeRequest("stream/open/" .. song.file_id, "POST") -- Open file stream

    if success then
        self.songState = {
            position = 0,
            size = tonumber(response),
            fails = 0,
            song = song,
            shouldStop = false
        }
    else
        self:_log("Opening stream failed: " .. response)
    end

    return success
end

function HarmonySession:playStream()
    if self.songState == nil then
        return false, "No song loaded"
    end

    while self.songState.position * self.streamSize < self.songState.size do
        local s, chunk = self:_makeRequest(
            "stream/read/" ..
            self.songState.song.file_id ..
            "?start=" ..
            self.songState.position * self.streamSize .. "&length=" .. self.streamSize,
            "GET", nil, true) -- Open file stream

        if self.songState.position * self.streamSize / self.songState.size > self._historyWatchPercent and not (#self.history ~= 0 and self.history[#self.history].id == self.songState.song.id) then
            self:_add_to_history(self.songState.song)
        end

        if s then
            while not playChunk(decoder(chunk)) do
                os.pullEvent("speaker_audio_empty")
            end

            self.songState.position = self.songState.position + 1
            self.songState.fails = 0
        else
            self.songState.fails = self.songState.fails + 1

            if self.songState.fails > self._maxStreamFails then -- Stop playing after multiple failed attempts
                self.songState = nil
                return false
            end

            sleep(self._streamFailCooldown) -- Wait before attempting again
        end

        if self.songState.shouldStop then
            break
        end
    end

    self.songState = nil
    return true
end

function HarmonySession:stopStream()
    if self.songState == nil then
        return false, "No stream playing"
    end

    self.songState.shouldStop = true

    for _, speaker in pairs(speakers) do
        speaker.stop()
    end
end

function HarmonySession:addSong(name, author, youtubeURL)
    local body = {
        name = name,
        youtube_url = youtubeURL
    }

    if author ~= nil and author ~= "" then
        body.author = author
    end

    local success, response = self:_makeRequest("song", "POST", body) -- Open file stream

    if success then
        self:_log("Adding song successful: " .. response.youtube_url)
    else
        self:_log("Adding song failed: " .. response)
    end

    return success, response
end

return HarmonySession
