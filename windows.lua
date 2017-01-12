local windows = {}

-- hs.window.setFrameCorrectness = true

-- define window movement/resize operation mappings
local arrowMap = {
  t = { half = { 0, 0, 1,.5}, movement = { 0,-20}, complement = "d", resize = "Shorter" },
  h = { half = { 0,.5, 1,.5}, movement = { 0, 20}, complement = "n", resize = "Taller" },
  d = { half = { 0, 0,.5, 1}, movement = {-20, 0}, complement = "h", resize = "Thinner" },
  n = { half = {.5, 0,.5, 1}, movement = { 20, 0}, complement = "t", resize = "Wider" },
}

-- compose screen quadrants from halves
local function quadrant(t1, t2)
  return {t1[1] + t2[1], t1[2] + t2[2], .5, .5}
end

-- move and/or resize windows
local function rect(rect)
  return function()
    undo:push()
    local win = fw()
    if win then win:move(rect) end
  end
end

windows.bind = function(modal, fsm)
  -- maximize window
  modal:bind("","m", function()
               rect({0, 0, 1, 1})()
               windows.highlighActiveWin()
  end)

  -- undo
  modal:bind("", "u", function() undo:pop() end)

  -- moving/re-sizing windows
  hs.fnutils.each({"d", "n", "t", "h"}, function(arrow)
      local dir = { d = "Left", h = "Down", t = "Up", n = "Right"}
      -- screen halves
      modal:bind({}, arrow, function()
          undo:push()
          rect(arrowMap[arrow].half)()
      end)
      -- incrementally
      modal:bind({"alt"}, arrow, function()
          undo:push()
          hs.grid['pushWindow'..dir[arrow]](fw()) 
      end)

      modal:bind({"shift"}, arrow, function()
          undo:push()
          hs.grid['resizeWindow'..arrowMap[arrow].resize](fw())
      end)
  end)

  -- window grid
  hs.grid.setMargins({0, 0})
  modal:bind("", "g", function()
                local gridSize = hs.grid.getGrid()
                undo:push()
                hs.grid.setGrid("3x2")
                hs.grid.show(function() hs.grid.setGrid(gridSize) end)
                fsm:toIdle()
  end)

  -- jumping between windows
  hs.fnutils.each({"d", "n", "t", "h"}, function(arrow)
      modal:bind({"cmd"}, arrow, function()
          if arrow == "d" then fw().filter.defaultCurrentSpace:focusWindowWest(nil, true, true) end
          if arrow == "n" then fw().filter.defaultCurrentSpace:focusWindowEast(nil, true, true) end
          if arrow == "h" then fw().filter.defaultCurrentSpace:focusWindowSouth(nil, true, true) end
          if arrow == "t" then fw().filter.defaultCurrentSpace:focusWindowNorth(nil, true, true) end
          windows.highlighActiveWin()
      end)
  end)

  -- moving windows around screens
  modal:bind({}, 'p', function() undo:push(); fw():moveOneScreenNorth() end)
  modal:bind({}, 'n', function() undo:push(); fw():moveOneScreenSouth() end)
end

-- undo for window operations
undo = {}

function undo:push()
  local win = fw()
  if win and not undo[win:id()] then
    self[win:id()] = win:frame()
  end
end

function undo:pop()
  local win = fw()
  if win and self[win:id()] then
    win:setFrame(self[win:id()])
    self[win:id()] = nil
  end
end

windows.highlighActiveWin = function()
  local rect = hs.drawing.rectangle(fw():frame())
  rect:setStrokeColor({["red"]=1,  ["blue"]=0, ["green"]=1, ["alpha"]=1})
  rect:setStrokeWidth(5)
  rect:setFill(false)
  rect:show()
  hs.timer.doAfter(0.3, function() rect:delete() end)
end

windows.activateApp = function(appName)
  hs.application.launchOrFocus(appName)

  local app = hs.application.find(appName)
  if app then
    app:activate()
    hs.timer.doAfter(0.1, windows.highlighActiveWin)
    app:unhide()
  end
end

windows.setMouseCursorAtApp = function(appTitle)
  local sf = hs.application.find(appTitle):findWindow(appTitle):frame()
  local desired_point = hs.geometry.point(sf._x + sf._w - (sf._w * 0.10), sf._y + sf._h - (sf._h * 0.10)) 
  hs.mouse.setAbsolutePosition(desired_point)
end
return windows
