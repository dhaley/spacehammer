require "preload"
local machine = require "statemachine"
local windows = require "windows"
local slack = require "slack"
require "preview-app"

local displayModalText = function(txt)
  hs.alert.closeAll()
  alert(txt, 999999)
end

allowedApps = {"Emacs", "Terminal"}
hs.hints.showTitleThresh = 4
hs.hints.titleMaxSize = 10
hs.hints.fontSize = 30
hs.hints.hintChars = {"S","A","D","F","J","K","L","E","W","C","M","P","G","H"}

local filterAllowedApps = function(w)
  if (not w:isStandard()) and (not utils.contains(allowedApps, w:application():name())) then
    return false;
  end
  return true;
end


-- A global variable for the Hyper Mode
k = hs.hotkey.modal.new({}, "F17")

-- Trigger existing hyper key shortcuts

k:bind({}, 'm', nil, function() hs.eventtap.keyStroke({"cmd","alt","shift","ctrl"}, 'm') end)


-- Enter Hyper Mode when F18 (Hyper/Capslock) is pressed
pressedF18 = function()
   k.triggered = false
   k:enter()
end

-- Leave Hyper Mode when F18 (Hyper/Capslock) is pressed,
--   send ESCAPE if no other keys are pressed.
releasedF18 = function()
   k:exit()
   if not k.triggered then
      hs.eventtap.keyStroke({}, 'ESC')
   end
end

-- Bind the Hyper key
f18 = hs.hotkey.bind({}, 'F18', pressedF18, releasedF18)



-- Hammerspoon config to send escape on short ctrl press
-- https://gist.github.com/arbelt/b91e1f38a0880afb316dd5b5732759f1
-- https://github.com/jasoncodes/dotfiles/blob/master/hammerspoon/control_escape.lua

send_return = false
last_mods = {}

control_key_handler = function()
   send_return = false
end

control_key_timer = hs.timer.delayed.new(0.15, control_key_handler)

control_handler = function(evt)
   local new_mods = evt:getFlags()
   if last_mods["ctrl"] == new_mods["ctrl"] then
      return false
   end
   if not last_mods["ctrl"] then
      last_mods = new_mods
      send_return = true
      control_key_timer:start()
   else
      if send_return then
         hs.eventtap.keyStroke({}, "RETURN")
      end
      last_mods = new_mods
      control_key_timer:stop()
   end
   return false
end

control_tap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, control_handler)
control_tap:start()
other_handler = function(evt)
   send_return = false
   return false
end

other_tap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, other_handler)
other_tap:start()

modals = {
  main = {
    init = function(self, fsm) 
      if self.modal then
        self.modal:enter()
      else
        self.modal = hs.hotkey.modal.new({"cmd"}, "space")
      end
      self.modal:bind("","space", nil, function() fsm:toIdle(); windows.activateApp("LaunchBar") end)
      self.modal:bind("","w", nil, function() fsm:toWindows() end)
      self.modal:bind("","a", nil, function() fsm:toApps() end)
      self.modal:bind("","j", nil, function()
                        local wns = hs.fnutils.filter(hs.window.allWindows(), filterAllowedApps)
                        hs.hints.windowHints(wns, nil, true)
                        fsm:toIdle()
      end)
      self.modal:bind("","escape", function() fsm:toIdle() end)
      function self.modal:entered() displayModalText "w - windows\na - apps\n j - jump" end
    end 
  },
  windows = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText "cmd + dhtn \t jumping\ndhtn \t\t\t\t halves\nalt + dhtn \t\t increments\nshift + dhtn \t resize\nn, p \t next, prev screen\ng \t\t\t\t\t grid\nm \t\t\t\t maximize\nu \t\t\t\t\t undo"
      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
      windows.bind(self.modal, fsm)
      self.modal:enter()
    end
  },
  apps = {
    init = function(self, fsm)
      self.modal = hs.hotkey.modal.new()
      displayModalText "e \t emacs\nc \t chrome\nt \t terminal\ns \t slack\nb \t brave"
      self.modal:bind("","escape", function() fsm:toIdle() end)
      self.modal:bind({"cmd"}, "space", nil, function() fsm:toMain() end)
      hs.fnutils.each({
          { key = "t", app = "Terminal" },
          { key = "c", app = "Google Chrome" },
          { key = "b", app = "Brave" },
          { key = "e", app = "Emacs" },
          { key = "g", app = "Gitter" }}, function(item)

          self.modal:bind("", item.key, function() windows.activateApp(item.app); fsm:toIdle()  end)
      end)

      slack.bind(self.modal, fsm)

      self.modal:enter()
    end
  }
}

local initModal = function(state, fsm)
  local m = modals[state]
  m.init(m, fsm)
end

exitAllModals = function()
  utils.each(modals, function(m)
               if m.modal then
                 m.modal:exit()
               end
  end)
end

local fsm = machine.create({
    initial = "idle",
    events = {
      { name = "toIdle",    from = "*", to = "idle" },
      { name = "toMain",    from = '*', to = "main" },
      { name = "toWindows", from = {'main','idle'}, to = "windows" },
      { name = "toApps",    from = {'main', 'idle'}, to = "apps" }
    },
    callbacks = {
      onidle = function(self, event, from, to)
        hs.alert.closeAll()
        exitAllModals()
      end,
      onmain = function(self, event, from, to)
        -- modals[from].modal:exit()
        initModal(to, self)
      end,
      onwindows = function(self, event, from, to)
        -- modals[from].modal:exit()
        initModal(to, self)
      end,
      onapps = function(self, event, from, to)
        -- modals[from].modal:exit()
        initModal(to, self)
      end
    }
})

fsm:toMain()

hs.alert.show("Config Loaded")
