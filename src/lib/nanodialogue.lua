-- nanodialogue: a dynamic dialogue system based off of pdDialogue

import "CoreLibs/animator"
import "CoreLibs/graphics"
import "CoreLibs/object"
import "CoreLibs/timer"

import "nanodialogue/funcs"
import "nanodialogue/char"

local Char = nanoDialogue_Char

local pd <const> = playdate
local gfx <const> = pd.graphics

local DIALOGUE_BOX_HEIGHT = 50
local DIALOGUE_BOX_WIDTH = 400
local DIALOGUE_BOX_PORTRAIT_HEIGHT = 64
local DIALOGUE_BOX_PADDING = 4

nanoDialogue = {}
class("nanoDialogue").extends()

--- FUNCTIONS FROM PDDIALOGUE ---

function nanoDialogue.wrap(lines, width, font)
  --[[
    lines: an array of strings
    width: the maximum width of each line (in pixels)
    font: the font to use (optional, uses default font if not provided)
    ]] --
  font = font or gfx.getFont()

  local result = {}

  for _, line in ipairs(lines) do
    local currentWidth, currentLine = 0, ""

    if line == "" or font:getTextWidth(line) <= width then
      table.insert(result, line)
      goto continue
    end

    for word in line:gmatch("%S+") do
      local wordWidth = font:getTextWidth(word)
      local newLine = currentLine .. (currentLine ~= "" and " " or "") .. word
      local newWidth = font:getTextWidth(newLine)

      if newWidth >= width then
        table.insert(result, currentLine)
        currentWidth, currentLine = wordWidth, word
      else
        currentWidth, currentLine = newWidth, newLine
      end
    end

    if currentWidth ~= 0 then
      table.insert(result, currentLine)
    end

    ::continue::
  end

  return result
end

function nanoDialogue.paginate(lines, height, font)
  --[[
        lines: array of strings (pre-wrapped)
        height: height to limit text (in pixels)
        font: optional, will get current font if not provided
    ]] --

  local result = {}
  local currentLine = {}

  font = font or gfx.getFont()

  local rows = nanoDialogue.getRows(height, font)

  for _, line in ipairs(lines) do
    if line == "" then
      -- If line is empty and currentLine has text...
      if #currentLine > 0 then
        -- Merge currentLine and add to result
        table.insert(result, table.concat(currentLine, "\n"))
        currentLine = {}
      end
    else
      -- If over row count...
      if #currentLine >= rows then
        -- Concat currentLine, add to result, and start new line
        table.insert(result, table.concat(currentLine, "\n"))
        currentLine = { line }
      else
        table.insert(currentLine, line)
      end
    end
  end

  -- If all lines are complete and currentLine is not empty, add to result
  if #currentLine > 0 then
    table.insert(result, table.concat(currentLine, "\n"))
    currentLine = {}
  end

  return result
end

function nanoDialogue.process(text, width, height, font) -- modified to ignore text effects
  --[[
    text: table containing strings and tables
    width: width to limit text (in pixels)
    height: height to limit text (in pixels)
    font: optional, will get current font if not provided
    ]] --
  local lines = {}
  font = font or gfx.getFont()

  local tmp = {}

  for i, v in ipairs(text) do
    if type(v) ~= "table" then
      table.insert(tmp, v)
    end
  end

  text = table.concat(tmp)

  -- Split newlines in text
  for line in text:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end

  -- Wrap the text
  local wrapped = nanoDialogue.wrap(lines, width, font)

  -- Paginate the wrapped text
  local paginated = nanoDialogue.paginate(wrapped, height, font)

  return paginated
end

function nanoDialogue.getRows(height, font)
  font = font or gfx.getFont()
  local lineHeight = font:getHeight() + font:getLeading()
  return math.floor(height / lineHeight)
end

--- END FUNCTIONS FROM PDDIALOGUE ---

function nanoDialogue.getEffectIndeces(cookedText)
  local indeces = {}

  for i, v in ipairs(cookedText) do
    if type(v) == "table" then
      indeces[tostring(i)] = v
    end
  end

  return indeces -- yes, yes, i know, keys are numbers but stringified.. it's dumb but it works
end

-- processes text to be used in nanodialogue.
function nanoDialogue.processEffects(text)
  local allchars = {}
  local cooked = {}
  local tmp = {}

  for c in string.gmatch(text, ".") do
    table.insert(allchars, c)
  end

  local inBrace = false
  local cct, args

  for i, v in ipairs(allchars) do
    if inBrace then
      if v == "}" then
        inBrace = false
        cct = table.concat(tmp)
        args = string.split(cct, " ")

        if string.sub(cct, 1, 1) == "/" then
          table.insert(cooked, { effect = string.sub(cct, 2, #cct), type = "end" })
        else
          table.insert(cooked, { effect = args[1], param = args[2] })
        end

        tmp = {}
      else
        table.insert(tmp, v)
      end
    else
      if v == "{" then
        inBrace = true
      else
        table.insert(cooked, v)
      end
    end
  end

  return cooked
end

nanoDialogueBox = {}
class("nanoDialogueBox").extends(nanoDialogue)


function nanoDialogueBox:init(text, font, invertedFont, rect)
  self.text = text
  self.font = font or gfx.getFont()
  self.invertedFont = invertedFont or gfx.getFont()

  self.cooked = self.processEffects(text)

  self.effectIndeces = self.getEffectIndeces(self.cooked)

  self.rect = rect or pd.geometry.rect.new(0, 240 - DIALOGUE_BOX_HEIGHT, DIALOGUE_BOX_WIDTH, DIALOGUE_BOX_HEIGHT)

  self.paginated = self.process(self.cooked, self.rect.width - DIALOGUE_BOX_PADDING * 2, self.rect.height - DIALOGUE_BOX_PADDING * 2, self.font)

  self.currentPage = 1
  self.offset = 0
  
  self.currentTextEffects = {}

  self.chars = {}

  self.currentChar = 1
  self.currentTotalChar = 1
  self.charTimer = pd.timer.new(0)

  self.ms = 0

  self.active = false
  self.pageDone = false
  self.done = false

  local pageDoneStuff = function ()
    if self.currentPage + 1 > #self.paginated then
      self.done = true
      self.active = false

      self.charTimer:remove()
      pd.timer.updateTimers()

      self:close()
    else
      self.currentPage += 1

      self.currentChar = 1

      self:createNewCharTimer(self.ms)

      for i, v in ipairs(self.chars) do
        v:destroy()
      end

      self.chars = {}

      self.offset = 0

      self.pageDone = false
    end
  end

  self.inputHandlers = {
    AButtonDown = function()
      if self.pageDone then
        pageDoneStuff()
      end
    end,
    BButtonDown = function()
      if self.pageDone then
        pageDoneStuff()
      else
        self:finishDialogue()
      end
    end
  }
end

function nanoDialogueBox:finishDialogue()
  while not self.pageDone do
    self:addChar(true)
  end
end

function nanoDialogueBox:createNewCharTimer(time)
  if self.charTimer then
    self.charTimer:remove()
  end

  self.charTimer = pd.timer.new(time)
  self.charTimer.repeats = true
  self.charTimer.timerEndedCallback = function() self:addChar() end
end

function nanoDialogueBox:addChar(noOnChar)
  if self.paginated[self.currentPage] then
    if self.currentChar - self.offset <= #self.paginated[self.currentPage] then
      if self.effectIndeces[tostring(self.currentTotalChar + ((self.currentPage - 1) * 2))] then
        local c = self.effectIndeces[tostring(self.currentTotalChar + ((self.currentPage - 1) * 2))]

        if c["type"] == "end" then
          table.remove(self.currentTextEffects, #self.currentTextEffects)

          if c["effect"] == "delay" then
            self:createNewCharTimer(self.ms)
          end
        else
          table.insert(self.currentTextEffects, c)

          if c["effect"] == "delay" then
            self:createNewCharTimer(tonumber(c["param"]))
          end
        end
        self.offset += 1
      else
        local c = string.sub(self.paginated[self.currentPage], self.currentChar - self.offset, self.currentChar - self.offset)

        if self.onChar and not noOnChar then
          self:onChar()
        end

        if c ~= nil then
          table.insert(self.chars,
            Char(c, table.deepcopy(self.currentTextEffects), self.font, self
              .invertedFont))
        end
      end

      self.currentChar += 1
      self.currentTotalChar += 1
    else
      self.charTimer:remove()
      self.pageDone = true
    end
  end
end

function nanoDialogueBox:open()
  pd.inputHandlers.push(self.inputHandlers)
  self:restartDialogue()
  self:start()
end

function nanoDialogueBox:start()
  self:createNewCharTimer(self.ms)
  self.active = true
end

function nanoDialogueBox:stop()
  self.charTimer:remove()
  self.active = false
end

function nanoDialogueBox:close()
  pd.inputHandlers.pop()
  self:restartDialogue()
  self:stop()

  if self.onClose then
    self:onClose()
  end
end

function nanoDialogueBox:restartDialogue()
  self.currentChar = 1
  self.currentPage = 1
  self.currentTotalChar = 1
  self.active = false
  self.done = false
  self.pageDone = false

  for i, v in ipairs(self.chars) do
    v:destroy()
  end

  self.chars = {}
  self:createNewCharTimer(self.ms)
  self.currentTextEffects = {}
  self.offset = 0
end

function nanoDialogueBox:setText(text)
  self.cooked = self.processEffects(text)
  self.effectIndeces = self.getEffectIndeces(self.cooked)
  self.paginated = self.process(self.cooked, DIALOGUE_BOX_WIDTH - DIALOGUE_BOX_PADDING * 2, DIALOGUE_BOX_HEIGHT - DIALOGUE_BOX_PADDING * 2, self.font)

  for i, v in ipairs(self.chars) do
    v:destroy()
  end

  self.chars = {}
end

function nanoDialogueBox:update()
  pd.timer.updateTimers()
end

function nanoDialogueBox:draw()
  gfx.setColor(gfx.kColorWhite)
  gfx.fillRect(self.rect)
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRect(self.rect)

  local x, y = self.rect.x + DIALOGUE_BOX_PADDING, self.rect.y + DIALOGUE_BOX_PADDING

  for i, c in ipairs(self.chars) do
    if c.char == "\n" then
      x = self.rect.x + DIALOGUE_BOX_PADDING
      y += self.font:getLeading() + self.font:getHeight()
    else
      c:update()
      c:draw(x, y)
      x = x + c.charW + c.charTracking
    end
  end

  if self.pageDone then
    local tx, ty = self.rect.x + DIALOGUE_BOX_PADDING + self.rect.width - 20,
        self.rect.y + DIALOGUE_BOX_PADDING + self.rect.height - 15
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(
      tx, ty,
      tx + 5, ty + 5,
      tx + 10, ty
    )
  end
end

nanoPortraitDialogueBox = {}
class("nanoPortraitDialogueBox").extends(nanoDialogueBox)

function nanoPortraitDialogueBox:init(name, portrait, text, font, invertedFont, imageDrawMode, rect)
  rect = rect or pd.geometry.rect.new(64, 240 - DIALOGUE_BOX_PORTRAIT_HEIGHT, DIALOGUE_BOX_WIDTH - 64, DIALOGUE_BOX_PORTRAIT_HEIGHT)

  self.imageDrawMode = imageDrawMode or gfx.kDrawModeCopy

  nanoPortraitDialogueBox.super.init(self, text, font, invertedFont, rect)

  self.portrait = portrait
  self.name = name or ""
end

function nanoPortraitDialogueBox:drawPortrait(x, y)
  local font = self.font or gfx.getFont()
  local textrect = pd.geometry.rect.new(0, y - (font:getHeight()), 64, font:getHeight())

  gfx.setColor(gfx.kColorWhite)
  gfx.fillRect(x, y, 64, 64)
  if self.name ~= "" then
    gfx.fillRect(textrect)
  end
  gfx.setColor(gfx.kColorBlack)
  gfx.drawRect(x, y, 64, self.rect.height)

  local origdrawMode = gfx.getImageDrawMode()
  if self.imageDrawMode ~= nil then
    gfx.setImageDrawMode(self.imageDrawMode)
  end
  self.portrait:draw(x, y)
  gfx.setImageDrawMode(origdrawMode)

  if self.name ~= "" then
    gfx.drawTextInRect(self.name, textrect, nil, nil, kTextAlignment.center, font)
    gfx.drawRect(textrect)
  end
end

function nanoPortraitDialogueBox:draw()
  self:drawPortrait(0, self.rect.y)

  nanoPortraitDialogueBox.super.draw(self)
end
