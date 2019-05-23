--[[
Copyright (c) 2009-2014 Vincent Pelletier

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Note:
    This AddOn's source code is specifically designed to work with
    World of Warcraft's interpreted AddOn system.
    You have an implicit license to use this AddOn with these facilities
    since that is its designated purpose as per:
    http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
--]]

-- lua
local ceil = math.ceil
local floor = math.floor
local select = select
local ipairs = ipairs
local pairs = pairs
local next = next
local setmetatable = setmetatable
local error = error
local tostring = tostring
local type = type
local string = string
local sformat = string.format
local slower = string.lower
local supper = string.upper
local strim = strtrim
local table = table
local tinsert = table.insert
local tconcat = table.concat
local tsort = table.sort

-- WoW API
-- GLOBALS: AddFriend, RemoveFriend, GetNumFriends, GetFriendInfo
-- GLOBALS: SetFriendNotes, ShowFriends, GuildRoster, IsInGuild
-- GLOBALS: GetNumGuildMembers, GetGuildRosterInfo

-- LibStub
-- GLOBALS: LibStub

-- DoIKnowYou (optional dependency for showing notes in the friends list)
-- GLOBALS: DoIKnowYou

-- This addon
-- GLOBALS: SyncFriends

SyncFriends = LibStub("AceAddon-3.0"):NewAddon("SyncFriends", "AceConsole-3.0",
  "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("SyncFriends", true)

local POOL_STRUCTURE_VERSION = 1

local current_playerName = UnitName("player")

local DoIKnowYouDB = DoIKnowYou and DoIKnowYou.db
local DoIKnowYouRealm = DoIKnowYouDB and DoIKnowYouDB.realm
local DoIKnowYouData = DoIKnowYouRealm and DoIKnowYouRealm.data
local DoIKnowYouProfile = DoIKnowYouDB and DoIKnowYouDB.profile
local DoIKnowYouPrimaryChar = DoIKnowYouRealm and DoIKnowYouRealm.primaryChar
local DoIKnowYouLocale = DoIKnowYou and LibStub("AceLocale-3.0"):GetLocale("DoIKnowYou", false)

local function copyTable(...)
    --[[
      Iterate over given parameters and returns the result of successive table
      updates.
      Does not modify any of parameters.
      XXX: Does a first-level copy: subtables will not be duplicated.
    --]]
    local result = {}
    for i = 1, select("#", ...) do
        for key, value in pairs(select(i, ...)) do
            result[key] = value
        end
    end
    return result
end

local function isMapEmpty(some_map)
    for _, _ in pairs(some_map) do
        return false
    end
    return true
end

local function getMapLen(some_map)
    local result = 0
    for _, _ in pairs(some_map) do
        result = result + 1
    end
    return result
end

local function addGetSet(scope_list, class, titlecased_property, scope_getter,
                         scope_setter)
    --[[
      Generate accessors for given property, and return their names in a
      mapping, like: {[scope_name] = {get = getter_name, set = setter_name}}
      Those accessors store/retrieve data to/from their own scope in an AceDB
      storage.
      Also creates a synthetic accessor which takes care of property
      precedence.

      @param scope_list List of scope in decreasing precedence order
      @param class Addon object to create accessors on
      @param titlecased_property Name of the property, title-cased.
      @param scope_getter
      @param scope_setter
        Both scope_getter and scope_setter receive the scope as first
        parameter, folossed by any received parameter. Typicaly, they will be
        "info" (getter) and "info, value" (setter).

      Alters: class

      TODO: Check parameter sanity
      XXX: AceDB storage is expected to be accessible with "class.db".
      TODO: cleanup local namespace upon exit, as it will survive (we bind
      functions referencing local namespace, so it won't be garbage-collected)
      and might become a memory hog if used at a big scale.
    --]]

    -- Create individual getters
    local scope_name, scope_option, scoped_name, getter_name, setter_name
    local result = {}
    local getter_list = {}
    for _, scope_name in pairs(scope_list) do
        scoped_name = scope_name..titlecased_property
        getter_name = "get"..scoped_name
        setter_name = "set"..scoped_name
        -- scope_attribute must be local to this loop, otherwise each iteration
        -- will overwrite previous' data, hence breaking auto-generated
        -- accessor.
        local scope_attribute = slower(scope_name)

        if not class[setter_name] then
            class[setter_name] = function(self, ...)
                scope_setter(self.db[scope_attribute], ...)
            end
        end
        if not class[getter_name] then
            class[getter_name] = function(self, ...)
                return scope_getter(self.db[scope_attribute], ...)
            end
        end

        result[scope_name] = {get = getter_name, set = setter_name}
        tinsert(getter_list, getter_name)
    end

    -- Create synthetic getter
    class["get"..titlecased_property] = function(self, ...)
        local result
        for _, getter in pairs(getter_list) do
            result = self[getter](self, ...)
            if result ~= nil then
                break
            end
        end
        return result
    end

    return result
end

local GLOBAL_SCOPE = "Global"
local CHAR_SCOPE = "Char"

--[[
    XXX: Both options should:
    - have their scope in the description
    - be name-less (but that prevent tooltip from being displayed)
    - be of default width (but that doesn't allow them to be on the same line)
    So for now, stick to an ugly-but-usable layout.
--]]
local SCOPE_OPTION_MAP = {
    [GLOBAL_SCOPE] = {
        name = L["Global setting"],
        width = "full",
        order = 1,
    },
    [CHAR_SCOPE] = {
        name = L["Character override"],
        width = "full",
        order = 2,
    },
}

local function overridableOptionGroupArgs(option, desc, scope_set, ...)
    --[[
      Create 2 copies of given option and link them with (auto-generated)
      property accessors.
      That property will be stored at 2 scopes:
      - Character scope
      - Global scope
      The former overriding setting from the latter.

      @param option Option definition
      @param desc Option description
      @param scope_set Which scopes must be generated (scope -> boolean table)
      @param ... (passed to addGetSet)

      TODO: Support more than just "toggle" option type.
      XXX: hardcodes the way scopes are nested in option_map
    --]]
    local scope_precedence_list = {CHAR_SCOPE, GLOBAL_SCOPE}
    local scope_list = {}
    local args = {
        desc = {
            name = desc,
            type = "description",
            order = 0,
        },
    }
    local scope_option_data
    local reverse_enabled_scope_list = {}

    if scope_set == nil then
        scope_set = {}
        for _, scope in pairs(scope_precedence_list) do
            scope_set[scope] = true
        end
    end

    for _, scope in pairs(scope_precedence_list) do
        if scope_set[scope] then
            tinsert(scope_list, scope)
            tinsert(reverse_enabled_scope_list, 1, scope)
        end
    end

    local has_super_scope = false
    for _, scope in pairs(reverse_enabled_scope_list) do
        scope_option_data = SCOPE_OPTION_MAP[scope]
        if scope_option_data == nil then
            error(sformat(L["Unknown scope %s"], tostring(scope)))
        else
            args[scope] = copyTable(option, scope_option_data)
            if option.type == "toggle" and has_super_scope then
                args[scope]['tristate'] = true
            end
            has_super_scope = true
        end
    end

    local needs_getset = false
    if option.type == "toggle" then
        needs_getset = true
    end

    if needs_getset then
        for scope, getset in pairs(addGetSet(scope_list, ...))
        do
            args[scope].get = getset.get
            args[scope].set = getset.set
        end
    end
    return args
end

local function slashCommand(option, class, function_name, argc)
    --[[
      Transforms an option into a slash command with automated parameter
      parsing.

      @param option Option definition to alter
      @param class Addon object defining command method
      @param function_name Name of the function to call on class
      @param argc (opt) The number of arguments to parse

      Alters: option

      TODO: Check parameter sanity better
      XXX: It is dirty to use options for this purpose
    --]]
    local dummy_setter
    option.guiHidden = true
    option.type = "input"
    if argc == 0 then
        -- Don't bother wrapping, we are not expecting parameters.
        dummy_setter = function_name
    else
        if not argc then
            argc = 1e9 -- XXX: This seems to mean "unlimited" for GetArgs.
        end
        dummy_setter = function(info, input)
            class[function_name](class, class:GetArgs(input, argc, 1))
        end
    end
    option.set = dummy_setter
    return option
end

local function dynamicGroup(option, class, method_name)
    --[[
      Returns class[method_name]
      when "args" key is accessed.
      This makes it possible for an option group to be dynamicaly generated.

      @param option Option definition
      @param class Class to call method from
      @param method_name Name of the method to call upon "args" attribute
        access

      Alters: option

      XXX: There should be a better way to do this...
      TODO: Check parameter sanity
    --]]
    local metatable = {
        __index = function(_, key)
            local result
            if key == "args" then
                result = class[method_name](class)
            end
            return result
        end
    }
    setmetatable(option, metatable)
    return option
end

-- This "class" is merely used as a separate namespace to avoid adding those
-- functions to SyncFriends. It is used as a handler for actions defined in
-- ui_sync_pool_action_option
local UISyncPoolOptionHandlers = {}

local options = {
    name = "SyncFriends",
    handler = SyncFriends,
    type = "group",
    childGroups = "tab",
    args = {
        pool = {
            name = L["Sync data"],
            type = "group",
            order = 0,
            args = {
                skip = slashCommand({
                        name = "skip <playerName>",
                        desc = L["Skip given player name in sync"],
                    },
                    SyncFriends, "skipPlayerName", 1),
                register = slashCommand({
                        name = "register <playerName> <add|remove>",
                        desc = L["Register playerName for addition "..
                                 "(default) or removal"],
                    },
                    SyncFriends, "registerFromCommand", 2),
                forget = slashCommand({
                        name = "forget <playerName>",
                        desc = L["Forget about playerName (but don't mark "..
                                 "him for removal)"],
                    },
                    SyncFriends, "forget", 1),
                sync = {
                    name = L["Sync"],
                    desc = L["Manually trigger a synchronisation with sync"..
                             " pool"],
                    type = "execute",
                    func = "importExport",
                },
                dump = {
                    name = L["Dump"],
                    desc = L["Dumps sync pool to default chat window"],
                    type = "execute",
                    func = "dump",
                    guiHidden = true,
                },
                flush = {
                    name = L["Flush"],
                    desc = L["Empties the content of the sync pool"],
                    func = "flushPool",
                    type = "execute",
                    confirm = true,
                },
                sync_pool = dynamicGroup({
                        name = L["Friends"],
                        type = "group",
                        handler = UISyncPoolOptionHandlers,
                        cmdHidden = true,
                    },
                    SyncFriends, "getUISyncPoolOption"),
            },
        },
        options = {
            name = L["Options"],
            type = "group",
            order = 1,
            args = {
                auto_import = {
                    name = L["Auto-import"],
                    inline = true,
                    type = "group",
                    args = overridableOptionGroupArgs({
                            type = "toggle",
                        },
                        L["Whether friends should be imported upon startup"],
                        nil,
                        SyncFriends, "AutoImport",
                        function(scope, info) return scope.auto_import end,
                        function(scope, info, value)
                            scope.auto_import = value end),
                    order = 0,
                },
                auto_export = {
                    name = L["Auto-export"],
                    inline = true,
                    type = "group",
                    args = overridableOptionGroupArgs({
                            type = "toggle",
                        },
                        L["Whether friends should be made known to "..
                          "synchronisation upon startup, addition and "..
                          "removal"],
                        nil,
                        SyncFriends, "AutoExport",
                        function(scope, info) return scope.auto_export end,
                        function(scope, info, value)
                            scope.auto_export = value end),
                    order = 1,
                },
                use_global_note = {
                    name = L["Sync notes"],
                    inline = true,
                    type = "group",
                    args = overridableOptionGroupArgs({
                            type = "toggle",
                        },
                        L["Whether notes should be synchronised along with "..
                          "friends"],
                        nil,
                        SyncFriends, "UseGlobalNote",
                        function(scope, info) return scope.sync_notes end,
                        function(scope, info, value)
                            scope.sync_notes = value end),
                    order = 2,
                },
                auto_forget = {
                    name = L["Auto-forget"],
                    inline = true,
                    type = "group",
                    args = overridableOptionGroupArgs({
                            type = "toggle",
                        },
                        L["Whether friends should be forgotten about when no"..
                          " alt knows them anymore"],
                        nil,
                        SyncFriends, "AutoForget",
                        function(scope, info) return scope.auto_forget end,
                        function(scope, info, value)
                            scope.auto_forget = value end),
                    order = 3,
                },
                auto_remove_guilmate = {
                    name = L["Auto-remove guildmates"],
                    inline = true,
                    type = "group",
                    args = overridableOptionGroupArgs({
                            type = "toggle",
                        },
                        L["Whether friends in current alt's guild should be "..
                          "removed from its friend list (they will be added "..
                          "back when they or the alt leaves the quild)."],
                        nil,
                        SyncFriends, "AutoRemoveGuildmates",
                        function(scope, info)
                            return scope.auto_remove_guildmates end,
                        function(scope, info, value)
                            scope.auto_remove_guildmates = value end),
                    order = 4,
                },
                auto_add_alts = {
                    name = L["Auto-add alts"],
                    inline = true,
                    type = "group",
                    args = overridableOptionGroupArgs({
                            type = "toggle",
                        },
                        L["Whether alts should be added to other alts' "..
                          "friend lists"],
                        {[GLOBAL_SCOPE] = true},
                        SyncFriends, "AutoAddAlts",
                        function(scope, info)
                            return scope.auto_add_alts end,
                        function(scope, info, value)
                            scope.auto_add_alts = value end),
                    order = 5,
                },
            },
        },
    }
}

LibStub("AceConfig-3.0-ElvUI"):RegisterOptionsTable("SyncFriends", options,
    {"sf", "syncfriends"})
LibStub("AceConfigDialog-3.0-ElvUI"):AddToBlizOptions("SyncFriends")

-- IMPORTANT: The Burning Crusade only supports having 50 people on your friends list,
-- and this variable ensures that we don't attempt to add more people after that.
-- However, the SyncFriends addon *itself* will remember infinite people, in its
-- own pool (cache) of all friends from all of your alts! So you will never lose any
-- friends data even if the game is full. It's always stored in your SyncFriends pool!
local MAX_FRIEND_COUNT = 50

-- Action flags.
local ADD_ACTION = 1
local REMOVE_ACTION = 2
local SKIP_ACTION = 3

-- Queue to ensure that this addon follows the allowed rate limits by servers,
-- and only performs one add/remove-action at a time UNTIL that action succeeds.
local FriendQueue = {
    queue = {},
    pending = nil, -- Will hold name of person from queue we're waiting on AddFriend/RemoveFriend result for...
    attempt = 0, -- How many attempts we've given that person...
    timerHandle = nil, -- Handle to the "anti-stuck" timer...
}

function FriendQueue:GetAllFriends()
    local nilFound = false
    local allFriends = {}
    local playerName
    for i = 1, GetNumFriends() do
        playerName = GetFriendInfo(i)
        if playerName == nil then
            nilFound = true
            break
        else
            allFriends[playerName] = true
        end
    end

    return allFriends, nilFound
end

function FriendQueue:Add(playerName, ignore)
    self.queue[playerName] = {
        action = ADD_ACTION,
        ignore = ignore,
    }
    if not self.pending then
        self:DoNext()
    end
end

function FriendQueue:Remove(playerName, ignore)
    self.queue[playerName] = {
        action = REMOVE_ACTION,
        ignore = ignore,
    }
    if not self.pending then
        self:DoNext()
    end
end

function FriendQueue:DoNext()
    if self.pending and not self.queue[self.pending] then
        -- Clear any lingering "pending" entry that has been deleted from queue.
        self.pending = nil
        self.attempt = 0
    end
    if not self.pending then
        -- Get next queue entry (or nil if queue is empty).
        self.pending = next(self.queue)
        self.attempt = 0
    end
    if self.pending then
        -- Process the active "pending" entry.
        self.attempt = self.attempt + 1
        local data = self.queue[self.pending]
        local apiCall = (data.action == ADD_ACTION and AddFriend) or (data.action == REMOVE_ACTION and RemoveFriend)
        if apiCall then
            -- Check if the desired action is already accomplished and doesn't need to happen again.
            local allFriends, nilFound = FriendQueue:GetAllFriends()
            if not nilFound then -- No nil = List is fully loaded.
                local success = self:_CheckSuccess(allFriends, self.pending, data.action)
                if success then
                    apiCall = false -- Will cause the "else"-path below which clears this entry and tries next.
                end
            end
        end
        if self.attempt <= 5 and apiCall then
            SyncFriends:CancelTimer(self.timerHandle, true) -- Cancel any previous, untriggered timer.
            self.timerHandle = SyncFriends:ScheduleTimer(FriendQueue.HandleTimerTrigger, 5, FriendQueue) -- Anti-stuck timer (5s).
            apiCall(self.pending, data.ignore) -- Result of this API call will cause FRIENDLIST_UPDATE to trigger.
        else
            -- Invalid action or too many attempts; remove person from queue and re-trigger to get another entry.
            self.queue[self.pending] = nil
            self:DoNext()
        end
    end
end

function FriendQueue:HandleTimerTrigger()
    -- Timeout ("FRIENDLIST_UPDATE" didn't trigger). Perform anti-stuck action
    -- by retrying or skipping that entry (if too many attempts).
    FriendQueue:DoNext()
end

function FriendQueue:_CheckSuccess(allFriends, playerName, desiredAction)
    if desiredAction == ADD_ACTION then
        if allFriends[playerName] then
            return true
        end
    elseif desiredAction == REMOVE_ACTION then
        if not allFriends[playerName] then
            return true
        end
    end

    return false
end

function FriendQueue:HandleFriendsUpdate(allFriends)
    -- This function is called with the full list of ALL of the player's friends, after a friends list
    -- update has been performed (adding/removing), or if that event has been triggered manually (by "ShowFriends()").
    SyncFriends:CancelTimer(self.timerHandle, true) -- Cancel any untriggered "anti-stuck" timer.
    if self.pending and self.queue[self.pending] then
        local data = self.queue[self.pending]
        local success = self:_CheckSuccess(allFriends, self.pending, data.action)
        if success then
            self.queue[self.pending] = nil
        end
    end
    self:DoNext() -- Process next queue entry (if any remains), or retry current entry if necessary...
end

-- Action implementations.
local ACTION_MAP = {
    [ADD_ACTION] = function(self, playerName, friend_set)
        local result
        if not (friend_set[playerName]
           or (self:getAutoRemoveGuildmates()
               and self.current_player_guildmates[playerName])) then
            if getMapLen(friend_set) >= MAX_FRIEND_COUNT then
                result = sformat(L["You have reached the maximum "..
                  "number of friends, could not add %s"], playerName)
            else
                FriendQueue:Add(playerName)
                friend_set[playerName] = true
                result = sformat(L["Added %s"], playerName)
            end
        end
        return result
    end,
    [REMOVE_ACTION] = function(self, playerName, friend_set)
        local result
        if friend_set[playerName] then
            FriendQueue:Remove(playerName)
            friend_set[playerName] = nil
            result = sformat(L["Removed %s"], playerName)
        else
            -- Prevent stale "known by" references in pool, in case SyncFriends
            -- was turned off when that friend was (manually) removed.
            self:unsetKnownBy(playerName)
        end
        return result
    end,
    [SKIP_ACTION] = function(self, playerName, friend_set)
        if not friend_set[playerName] then
            -- Prevent stale "known by" references in pool, in case SyncFriends
            -- was turned off when that friend was (manually) removed.
            self:unsetKnownBy(playerName)
        end
    end,
}

local ACTION_NAME_MAP = {
    [ADD_ACTION] = "|cff00ff00"..L["addition"].."|r",
    [REMOVE_ACTION] = "|cffff0000"..L["removal"].."|r",
    [SKIP_ACTION] = "|cff555555"..L["skipping"].."|r",
}

local ACTION_LIST_PREFIX_MAP = {
    [ADD_ACTION] = "|cff00ff00++|r ",
    [REMOVE_ACTION] = "|cffff0000--|r ",
    [SKIP_ACTION] = "|cff555555**|r ",
}

local STATUS_SELF = 0
local STATUS_ALT = 1
local STATUS_FRIEND = 2
local STATUS_OTHER = 3

local STATUS_COLOR = {
    [STATUS_SELF] = "ff00ff00",
    [STATUS_ALT] = "ffffee77",
    [STATUS_FRIEND] = nil, -- default color
    [STATUS_OTHER] = "ff777777",
}

local STATUS_NAME = {
    [STATUS_SELF] = L["It's me !"],
    [STATUS_ALT] = L["An alt"],
    [STATUS_FRIEND] = L["A friend"],
    [STATUS_OTHER] = L["Unknown"],
}

SyncFriends.current_player_guildmates = {}

function SyncFriends:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SyncFriendsDB")
    self:RegisterEvent("FRIENDLIST_UPDATE")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_GUILD_UPDATE")
    if self:getAutoAddAlts() == nil then
        -- Defaults AutoAddAlts to true
        self:setGlobalAutoAddAlts(nil, true)
    end
    self.nil_in_last_friendlist_update = false
    self.nil_in_last_friendlist_update_warned = false
end

function SyncFriends:OnEnable()
    if self:getAutoImport() == nil and self:getAutoExport() == nil then
        self:Print(L["SyncFriends must be configured before it does anything"])
    else
        self:importExport()
    end

    -- XXX: Those hooks store actions whithout any possible way to check if
    -- hooked function had an effect at all. Removing a non-existent friend
    -- or adding a non-existent player from/to friend list will pollute the
    -- pool.
    self:SecureHook("AddFriend")
    self:Hook("RemoveFriend", true) -- XXX: Pre-hooks securely? A regular "SecureHook("RemoveFriend")" post-hook works too...
    self:SecureHook("SetFriendNotes")
end

function SyncFriends:OnDisable()
    self:UnhookAll()
end

function SyncFriends:FRIENDLIST_UPDATE(...)
    -- For some reason, some friends might still be nil after receiving
    -- FRIENDLIST_UPDATE event, so we must check if there are nils to decide
    -- if the list is really loaded.
    local allFriends, nilFound = FriendQueue:GetAllFriends()
    if nilFound then
        if self.nil_in_last_friendlist_update and
                not self.nil_in_last_friendlist_update_warned then
            self:Print(L["Warning: Some friend's data isn't loaded after "..
                "two (or more) refresh requests. SyncFriends will need "..
                "more time to start."])
            self.nil_in_last_friendlist_update_warned = true
        end
        self.nil_in_last_friendlist_update = true
        -- Trigger another FRIENDLIST_UPDATE
        ShowFriends()
    else
        FriendQueue:HandleFriendsUpdate(allFriends)

        self.nil_in_last_friendlist_update = false
        self.nil_in_last_friendlist_update_warned = false
        self.friend_list_loaded = true
        if self.friendlist_update_callback then
            self.friendlist_update_callback(self)
            self.friendlist_update_callback = nil
        end

        -- Since we've definitely got the 100% loaded friend list now, and have fired our
        -- callback (above) if any exists, it's now safe to unregister the event again.
        -- UPDATE: No... the event will stay registered forever, due to the FriendQueue
        -- system. If we constantly register/unregister the event, it often misses
        -- triggering, and that causes FriendQueue to fall back to its slow anti-stuck
        -- timer instead. Staying registered is no problem; this event fires twice every
        -- time the user opens their friends list, but so what?! The work our function
        -- does here finishes in just a handful of milliseconds.
        --self:UnregisterEvent("FRIENDLIST_UPDATE")
    end
end

function SyncFriends:PLAYER_GUILD_UPDATE(...)
    self.guild_roster_loaded = nil
    self.current_player_guildmates = {}
    self:importExport()
end

function SyncFriends:GUILD_ROSTER_UPDATE(event, changed)
    local is_in_guild = IsInGuild()
    if not is_in_guild or changed then
        self.current_player_guildmates = {}
        if is_in_guild and changed then
            for x = 1, GetNumGuildMembers(true) do
                self.current_player_guildmates[GetGuildRosterInfo(x)] = true
            end
        end
    end
    self.guild_roster_loaded = true
    if self.guild_roster_update_callback then
        self.guild_roster_update_callback(self)
        self.guild_roster_update_callback = nil
    end
    self:UnregisterEvent("GUILD_ROSTER_UPDATE")
end

function SyncFriends:_cleanupNameInput(playerName)
    -- Validate and clean up the input, since "/friend somebody" or "/removefriend sOmEbODY" would give us illegal-case input.
    if type(playerName) ~= "string" then return; end
    playerName = strim(playerName) -- Remove leading/trailing whitespace.
    if playerName == "" then return; end
    playerName = self:_properNameCase(playerName)
    return playerName
end

function SyncFriends:AddFriend(playerName, ignoreOrNote)
    -- "ignore" is a fake argument which is expected to be True when an addon
    -- is temporarily adding a friend, which should not be synchronised.
    -- One such example is BadBoy_Levels.
    -- This API change was initially suggested by Tekkub, author of
    -- FriendsWithBenefits.
    -- However, the official AddFriend API already uses the 2nd parameter for
    -- its "player note", such as in "/friend somebody hello" in which case
    -- their saved note would be set to "hello". In fact, even if the user
    -- just types "/friend somebody", the second parameter is provided as an
    -- empty string in that situation! In OTHER official cases, arg2 is nil.
    if ignoreOrNote ~= true then
        playerName = self:_cleanupNameInput(playerName) -- Fix dirty user input...
        if not playerName then return; end -- Don't proceed if we lack a name at this point (ie. cleanup gave us nothing left).
        if self:getAutoExport() then
            self:storeAction(playerName, ADD_ACTION, false)
        end
        if self:getPool()[playerName] then
            self:setKnownBy(playerName)

            -- Also store the note if one exists and the user has enabled note syncing.
            if type(ignoreOrNote) == "string" and
                self:getUseGlobalNoteForFriend(playerName) then
                local noteText = strim(ignoreOrNote)
                if noteText ~= "" then
                    self:setNote(playerName, noteText)
                end
            end
        end
    end
end

function SyncFriends:getFriendInfo(friendIndex)
    -- Note: returns name only (first return value)
    local playerName = GetFriendInfo(friendIndex)
    if playerName == nil then
        error("Friend index "..tostring(friendIndex).." invalid. "..
            "GetNumFriends() = "..tostring(GetNumFriends()))
    end
    return playerName
end

function SyncFriends:RemoveFriend(playerNameOrIndex, ignore)
    -- "playerNameOrIndex": is a string in situations like "/removefriend someone", or index (ie 2) if removing via Blizzard's Friends panel.
    -- "ignore" parameter: see SyncFriends:AddFriend.
    if ignore ~= true then
        local playerName
        if type(playerNameOrIndex) == "number" then
            playerName = self:getFriendInfo(playerNameOrIndex) -- No need to clean this up any further!
        else
            playerName = self:_cleanupNameInput(playerNameOrIndex) -- Fix dirty user input...
        end
        if not playerName then return; end -- Don't proceed if we lack a name at this point (ie. cleanup gave us nothing left).
        if self:getAutoExport() then
            self:storeAction(playerName, REMOVE_ACTION, false)
        end
        self:unsetKnownBy(playerName)
    end
end

function SyncFriends:SetFriendNotes(friendIndex, noteText)
    local playerName = self:getFriendInfo(friendIndex)
    if self:getUseGlobalNoteForFriend(playerName) then
        self:setNote(playerName, noteText)
    end
end

function SyncFriends:getPoolContainer()
    return self.db.factionrealm
end

function SyncFriends:getPool()
    local container = self:getPoolContainer()
    local pool = container.pool
    if pool == nil then
        container.pool = {}
        pool = container.pool
    end
    if container.pool_version == nil then
        for playerName, action in pairs(pool) do
            pool[playerName] = {action = action}
        end
        container.pool_version = POOL_STRUCTURE_VERSION
    end
    return pool
end

function SyncFriends:flushPool()
    self:getPoolContainer().pool = {}
    self:flushUISyncPoolOption()
    self:Print(L["Pool flushed"])
end

function SyncFriends:skipPlayerName(playerName)
    self:storeAction(playerName, SKIP_ACTION, true)
end

local COMMAND_ACTION_MAP = {
  add = ADD_ACTION,
  remove = REMOVE_ACTION,
}

function SyncFriends:registerFromCommand(playerName, action_name)
    local action
    if action_name == nil then
        action = ADD_ACTION
    else
        action = COMMAND_ACTION_MAP[action_name]
        if action == nil then
            error(sformat(L["Unknown action %s"], tostring(action_name)))
        end
    end
    self:storeAction(playerName, action, true)
end

function SyncFriends:forget(playerName)
    self:getPool()[playerName] = nil
    self:forgetUISyncPoolOption(playerName)
end

function SyncFriends:getCharUseGlobalNoteMap()
    local container = self.db.char
    local result = container.use_global_note
    if result == nil then
        container.use_global_note = {}
        result = container.use_global_note
    end
    return result
end

function SyncFriends:getCharUseGlobalNoteForFriend(playerName)
    return self:getCharUseGlobalNoteMap()[playerName]
end

function SyncFriends:getUseGlobalNoteForFriend(playerName)
    local result = self:getCharUseGlobalNoteForFriend(playerName)
    if result == nil then
        result = self:getUseGlobalNote()
    end
    return result
end

function SyncFriends:setCharUseGlobalNoteForFriend(playerName, value)
    self:getCharUseGlobalNoteMap()[playerName] = value
end

function SyncFriends:getNote(playerName)
    local pool = self:getPool()
    local playerData = pool[playerName]
    if playerData == nil then
        error("Unknown player name "..tostring(playerName))
    end
    return playerData.note
end

function SyncFriends:setNote(playerName, value)
    local pool = self:getPool()
    local playerData = pool[playerName]
    if playerData == nil then
        error("Cannot set a note for unknown player name "..tostring(
            playerName))
        return
    end
    playerData.note = value
end

function SyncFriends:setKnownBy(playerName)
    local playerData = self:getPool()[playerName]
    if not playerData then
        error(tostring(playerName).." is not in pool, cannot set it known "..
            "by current toon")
        return
    end
    local known_by = playerData.known_by
    if not known_by then
        playerData.known_by = {}
        known_by = playerData.known_by
    end
    known_by[current_playerName] = true
end

function SyncFriends:unsetKnownBy(playerName)
    local playerData = self:getPool()[playerName]
    if playerData then
        local known_by = playerData.known_by
        if known_by then
            known_by[current_playerName] = nil
            if (not playerData.is_alt) and isMapEmpty(known_by)
               and self:getAutoForget() then
                self:Print(sformat(L["Forgetting about %s"],
                    self:getPrintablePlayerName(playerName, playerData)))
                self:forget(playerName)
            end
        end
    end
end

function SyncFriends:getKnownBySet(playerName)
    local result
    local playerData = self:getPool()[playerName]
    if playerData and playerData.known_by then
        result = playerData.known_by
    else
        result = {}
    end
    return result
end

function SyncFriends:storeAction(playerName, action, force, is_alt)
    local pool = self:getPool()
    local playerData = pool[playerName]
    local message
    local need_ui_sync_pool_add
    if not playerData then
        need_ui_sync_pool_add = true
        pool[playerName] = {}
        playerData = pool[playerName]
        message = L["Marking new %s for %s"]
    else
        message = L["Marking %s for %s"]
    end
    if is_alt ~= nil then
        self:setAltState(playerName, is_alt)
    end
    local old_value = pool[playerName].action
    if (old_value ~= SKIP_ACTION or force) and old_value ~= action then
        self:Print(sformat(message,
            self:getPrintablePlayerName(playerName, playerData),
            ACTION_NAME_MAP[action]))
        pool[playerName].action = action
    end
    if need_ui_sync_pool_add then
        -- User is adding somebody to the pool.
        -- NOTE: We're calling addUISyncPoolOption only after playerData is fully set.
        self:addUISyncPoolOption(playerName, playerData)
    elseif old_value ~= action then
        -- User is updating action for an existing person, so refresh their GUI colors.
        self:_refreshUISyncPoolOption(playerName)
    end
end

function SyncFriends:setAltState(playerName, is_alt)
    self:getPool()[playerName].is_alt = is_alt
end

function SyncFriends:importExport()
    local pool = self:getPool()
    local friend_set = {}
    local storeAction, message, playerName, action, setNote, note, pool_note,
        _, use_pool_note, playerData, printable_player_name, all_loaded,
        auto_remove_guildmates, friend_count

    all_loaded = true
    if not self.friend_list_loaded then
        all_loaded = false
        if not self.friendlist_update_callback then
            -- Make us be called when FRIENDLIST_UPDATE is fired next
            self.friendlist_update_callback = SyncFriends.importExport
            -- Causes FRIENDLIST_UPDATE to be fired
            ShowFriends()
        end
    end
    if IsInGuild() and not self.guild_roster_loaded then
        all_loaded = false
        if not self.guild_roster_update_callback then
            self:RegisterEvent("GUILD_ROSTER_UPDATE")
            -- Make us be called when GUILD_ROSTER_UPDATE is fired next
            self.guild_roster_update_callback = SyncFriends.importExport
            -- Causes GUILD_ROSTER_UPDATE to be fired
            GuildRoster()
        end
    end
    if not all_loaded then
        return
    end

    if self:getAutoExport() then
        storeAction = self.storeAction
        setNote = self.setNote
    else
        storeAction = function() end
        setNote = storeAction
    end

    -- Update pool data with friend list content
    -- Also fill a "known friend" mapping, for faster lookup when
    -- reading sync pool.
    friend_count = GetNumFriends()
    for x = 1, friend_count do
        playerName, _, _, _, _, _, note = GetFriendInfo(x)
        if playerName == nil then
            -- Temporary, not worth translating
            self:Print(sformat("Export: nil player name for friend %s out "..
                "of %s, aborting. Please report.", tostring(x),
                tostring(friend_count)))
            break
        end
        if pool[playerName] == nil then
            storeAction(self, playerName, ADD_ACTION, false)
            setNote(self, playerName, note)
        end
        friend_set[playerName] = true
        if pool[playerName] then
            -- This case will not be entered if storeAction is a no-op
            -- (auto-export disabled). setKnownBy tests pool entry presence,
            -- but emits a warning. We don't want this.
            self:setKnownBy(playerName)
        end
    end
    if pool[current_playerName] == nil then
        if self:getAutoAddAlts() then
            action = ADD_ACTION
        else
            action = SKIP_ACTION
        end
        -- Add self to pool data if enabled in configuration and not already
        -- present in sync pool.
        storeAction(self, current_playerName, action, false, true)
    else
        -- Mark current player as being an alt, for cases where a player
        -- creates an alt with the name of a former friend.
        self:setAltState(current_playerName, true)
    end
    if self:getAutoImport() then
        auto_remove_guildmates = self:getAutoRemoveGuildmates()
        -- Update friend list with pool data
        for playerName, playerData in pairs(pool) do
            -- We don't want (and cannot) make player be a friend of
            -- himself. Also, do nothing for guildmates when they are set to be
            -- removed from friend list: removal will be done a bit later.
            if current_playerName ~= playerName and
               not (auto_remove_guildmates and
                   self.current_player_guildmates[playerName]) then
                action = ACTION_MAP[playerData.action]
                if action == nil then
                    message = sformat(L["Unknown action %s for %s, "..
                      "skipping"], tostring(playerData.action), playerName)
                else
                    message = action(self, playerName, friend_set)
                end
                if message ~= nil then
                    self:Print(message)
                end
            end
        end
        friend_count = GetNumFriends()
        for x = 1, friend_count do
            playerName, _, _, _, _, _, note = GetFriendInfo(x)
            if playerName == nil then
                -- Temporary, not worth translating
                self:Print(sformat("Import: nil player name for friend %s "..
                    "out of %s, aborting. Please report.", tostring(x),
                    tostring(friend_count)))
                break
            end
            repeat
                if auto_remove_guildmates
                   and self.current_player_guildmates[playerName] then
                    -- That player is part of our guild, remove him from friend
                    -- list. He must not be marked for deletion by our hook.
                    self:Print("Removing friend from same guild.")
                    FriendQueue:Remove(x, true)
                    break
                end
                -- Update friend notes
                -- TODO: check that adding a friend and its note is done in a
                -- single importExport call. Otherwise, try with an
                -- intermediate "ShowFriends()" call.
                playerData = pool[playerName]
                if playerData == nil then
                    break
                end
                pool_note = playerData.note
                -- WoW does not currently store empty descriptions as empty
                -- strings but as nil. Hence the additional check to avoid
                -- unneeded updates.
                if pool_note ~= nil and pool_note ~= note and
                   (pool_note ~= "" or note ~= nil)  and
                   self:getUseGlobalNoteForFriend(playerName) then
                    if note ~= nil then
                        printable_player_name = self:getPrintablePlayerName(playerName,
                            playerData)
                        self:Print(sformat(L["Replacing %s note '%s' "..
                            "with '%s'"], printable_player_name, note,
                            pool_note))
                    end
                    SetFriendNotes(x, pool_note)
                end
            until true
        end
    end
end

function SyncFriends:_getPlayerStatus(playerName, playerData)
    local result = STATUS_FRIEND
    if playerName == current_playerName then -- It's me !
        result = STATUS_SELF
    else
        if not playerData then
            playerData = self:getPool()[playerName]
        end
        if not playerData then -- Not a known friend
            result = STATUS_OTHER
        elseif playerData.is_alt then -- It's an alt
            result = STATUS_ALT
        end
    end
    return result
end

function SyncFriends:getPrintablePlayerStatus(playerName, playerData)
    local result = STATUS_NAME[self:_getPlayerStatus(playerName, playerData)]
    if not result then
        result = '(unknown status)'
    end
    return result
end

function SyncFriends:getPrintablePlayerName(playerName, playerData)
    local result = STATUS_COLOR[self:_getPlayerStatus(playerName, playerData)]
    if result then
        result = "|c"..result..playerName.."|r"
    else
        result = playerName
    end
    return result
end

function SyncFriends:dump()
    local action_name
    self:Print(L["Dump start"])
    for playerName, playerData in pairs(self:getPool()) do
        action_name = ACTION_NAME_MAP[playerData.action]
        if action_name == nil then
            action_name = "|cffff4444"..L["UNKNOWN ACTION"].."|r"
        end
        self:Print(self:getPrintablePlayerName(playerName, playerData)..": "..
            action_name)
    end
end

local function getKnownBy(info)
    local friend_name = info[#info-1]
    local result = {L["Known by"]..":"}
    for by, _ in pairs(SyncFriends:getKnownBySet(friend_name)) do
        tinsert(result, SyncFriends:getPrintablePlayerName(by))
    end
    return tconcat(result, "\n")
end

local ui_sync_pool_action_option = {
    action = {
        name = L["Action"],
        type = "select",
        values = ACTION_NAME_MAP,
        get = "getAction",
        set = "setAction",
        style = "dropdown",
        order = 0,
    },
    forget = {
        name = L["Forget"],
        type = "execute",
        func = "doForget",
        confirm = true,
        order = 1,
    },
    use_global_note = {
        name = L["Use global note"],
        desc = L["Whether current character should use global note for this"..
                 " character"],
        type = "toggle",
        get = "getCharUseGlobalNoteForFriend",
        set = "setCharUseGlobalNoteForFriend",
        tristate = true,
        order = 2,
    },
    note = {
        name = L["Note"],
        type = "input",
        get = "getNote",
        set = "setNote",
        disabled = "canSetNote",
        order = 3,
    },
    known_by = {
        name = getKnownBy,
        type = "description",
        order = 4,
    },
}

function UISyncPoolOptionHandlers:getAction(info)
    local friend_name = info[#info-1]
    return SyncFriends:getPool()[friend_name].action
end

function UISyncPoolOptionHandlers:setAction(info, value)
    local friend_name = info[#info-1]
    SyncFriends:storeAction(friend_name, value, true)
end

function UISyncPoolOptionHandlers:doForget(info)
    local friend_name = info[#info-1]
    SyncFriends:forget(friend_name)
end

function UISyncPoolOptionHandlers:getCharUseGlobalNoteForFriend(info)
    local friend_name = info[#info-1]
    return SyncFriends:getCharUseGlobalNoteForFriend(friend_name)
end

function UISyncPoolOptionHandlers:setCharUseGlobalNoteForFriend(info, value)
    local friend_name = info[#info-1]
    SyncFriends:setCharUseGlobalNoteForFriend(friend_name, value)
end

function UISyncPoolOptionHandlers:getNote(info)
    local friend_name = info[#info-1]
    return SyncFriends:getNote(friend_name)
end

function UISyncPoolOptionHandlers:setNote(info, value)
    local friend_name = info[#info-1]
    SyncFriends:setNote(friend_name, value)
end

function UISyncPoolOptionHandlers:canSetNote(info)
    local friend_name = info[#info-1]
    return not SyncFriends:getUseGlobalNoteForFriend(friend_name)
end

function SyncFriends:addUISyncPoolOption(friend_name, friend_data)
    if self.ui_sync_pool_option_cache then
        self:_addUISyncPoolOption({[friend_name] = friend_data})
    end
end

function SyncFriends:_getFormattedUIPoolName(friend_name, friend_data)
    -- returns the person's name with a colored prefix based on the configured action for that person
    local prefix, display_name
    if friend_data and friend_data.action then
        prefix = ACTION_LIST_PREFIX_MAP[friend_data.action]
    end
    display_name = self:getPrintablePlayerName(friend_name, friend_data)
    if prefix then
        display_name = prefix .. display_name
    end

    return display_name
end

function SyncFriends:_getFormattedUIPoolDesc(friend_name, friend_data)
    local desc = self:getPrintablePlayerStatus(friend_name, friend_data)

    if desc and DoIKnowYouData then
        local friend_name_upper = supper(friend_name)
        local dikyData = DoIKnowYouData[friend_name_upper]
        if dikyData then
            -- Extract total reputation points as a clean number and formatted string.
            local rep = dikyData.total or 0
            local repStr
            if (ceil(rep) > 0) then
                rep = ceil(rep)
                repStr = DoIKnowYouLocale["Positive"] .. " (+" .. rep .. ")"
            elseif (floor(rep) < 0) then
                rep = floor(rep)
                repStr = DoIKnowYouLocale["Negative"] .. " (" .. tostring(rep) .. ")" -- Automatically gets a "-" prefix.
            else
                rep = 0
                repStr = DoIKnowYouLocale["Neutral"]
            end

            desc = desc .. "\n\nDoIKnowYou: " .. DoIKnowYou:getRepColor(rep) .. repStr .. "|r"

            -- Extract their note, preferring ones written by the player themselves,
            -- but also supporting "trusted authors" (a "DoIKnowYouEnhancedTBC" feature).
            local note
            if DoIKnowYouPrimaryChar then
                local ownData = dikyData[DoIKnowYouPrimaryChar]
                if ownData and ownData.note ~= nil and ownData.note ~= "" then
                    note = ownData.note
                end
            end
            if (not note) and DoIKnowYouProfile.trustedCommentAuthors then -- Only exists in "DoIKnowYouEnhancedTBC".
                for _,author in ipairs(DoIKnowYouProfile.trustedCommentAuthors) do
                    local trustedData = dikyData[author]
                    if trustedData and trustedData.note ~= nil and trustedData.note ~= "" then
                        note = author .. " says: \"" .. trustedData.note .. "\""
                        break -- stop scanning
                    end
                end
            end

            if note then
                desc = desc .. "\n" .. DoIKnowYou:getRepColor(rep) .. note .. "|r"
            end
        end
    end

    return desc
end

function SyncFriends:_addUISyncPoolOption(friend_map)
    self.ui_sync_pool_option_cache_renumber = true
    for friend_name, friend_data in pairs(friend_map) do
        self.ui_sync_pool_option_cache[friend_name] = {
            name = self:_getFormattedUIPoolName(friend_name, friend_data),
            type = "group",
            args = ui_sync_pool_action_option,
            desc = self:_getFormattedUIPoolDesc(friend_name, friend_data),
        }
    end
end

function SyncFriends:_refreshUISyncPoolOption(friend_name)
    -- no need to renumber here
    local pool = self:getPool()
    local friend_data = pool[friend_name]
    if self.ui_sync_pool_option_cache and self.ui_sync_pool_option_cache[friend_name] and friend_data then
        -- refresh the name and description of the pool option
        self.ui_sync_pool_option_cache[friend_name].name = self:_getFormattedUIPoolName(friend_name, friend_data)
        self.ui_sync_pool_option_cache[friend_name].desc = self:_getFormattedUIPoolDesc(friend_name, friend_data)
    end
end

function SyncFriends:forgetUISyncPoolOption(friend_name)
    -- no need to renumber here
    if self.ui_sync_pool_option_cache then
        self.ui_sync_pool_option_cache[friend_name] = nil
    end
end

function SyncFriends:flushUISyncPoolOption()
    self.ui_sync_pool_option_cache = nil
end

function SyncFriends:getUISyncPoolOption()
    -- Returns an option mapping generated from existing synchronisation pool,
    -- with actions possible for each entry.
    local friend_set = self.ui_sync_pool_option_cache
    if not friend_set then
        self.ui_sync_pool_option_cache = {}
        friend_set = self.ui_sync_pool_option_cache
        self:_addUISyncPoolOption(self:getPool())
        self.ui_sync_pool_option_cache_renumber = true
    end
    if self.ui_sync_pool_option_cache_renumber then
        -- Order entries by "raw" name explicitly.
        -- Otherwise, they will be sorted by their colored name, which
        -- causes list to be sorted by color and then name...
        local first, last, center, offset
        local title_list = {}
        for friend_name, _ in pairs(friend_set) do
            tinsert(title_list, friend_name)
        end
        tsort(title_list)
        for order, friend_name in pairs(title_list) do
            friend_set[friend_name].order = order
        end
        self.ui_sync_pool_option_cache_renumber = nil
    end
    return friend_set
end

function SyncFriends:_properNameCase(playerName)
    return (slower(playerName):gsub("^%l", supper)) -- Transform to "Propername" case.
end

-- DoIKnowYou Addon Integration:
if DoIKnowYou and DoIKnowYou.sendMyData then
    -- All DoIKnowYou data writing functions (such as changing reputation
    -- or writing notes) will cause its "sendMyData" to be called. So we
    -- hook that to auto-update our SyncFriends descriptions when DoIKnowYou
    -- changes, to ensure that we'll always integrate the latest notes/ratings!
    -- NOTE: The AceConfigDialog list will render the changed description in
    -- realtime, since the ".desc" field is used for tooltip data, so as soon
    -- as the user hovers over a person, they'll always see the latest ".desc".

    -- Refuse to update if "sendMyData" was called via DoIKnowYou's syncing,
    -- when WE were asked to send our data OUT (that's via "RequestData").
    -- NOTE: We also won't update on "ReceiveData" when we get data from
    -- others, since that would require a lot of code for little benefit.
    local doUpdate = true
    local origRequestData = DoIKnowYou.RequestData
    DoIKnowYou.RequestData = function(self, ...)
        doUpdate = false
        local ret = origRequestData(self, ...)
        doUpdate = true
        return ret
    end

    -- Now install the core hook which detects when data needs updating.
    local origSendMyData = DoIKnowYou.sendMyData
    DoIKnowYou.sendMyData = function(self, name_upper, ...)
        local ret = origSendMyData(self, name_upper, ...)
        if name_upper and doUpdate then
            local name = SyncFriends:_properNameCase(name_upper)
            SyncFriends:_refreshUISyncPoolOption(name) -- NOTE: Does nothing if we don't have that person in our list.
        end
        return ret
    end
end
