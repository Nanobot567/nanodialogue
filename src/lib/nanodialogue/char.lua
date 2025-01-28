-- char class

nanoDialogue_Char = {}
class("nanoDialogue_Char").extends()

local pd <const> = playdate
local gfx <const> = pd.graphics

local Char = nanoDialogue_Char

local index = 0

function Char.resetGlobalCharIndex()
  index = 0
end

function Char:init(char, effects, font, invertedFont)
  self.font = font or gfx.getFont()
  self.invertedFont = invertedFont or gfx.getFont()

  self.char = char

  if char ~= "\n" then
    self.image = font:getGlyph(char)
    self.invertedImage = self.invertedFont:getGlyph(char)
    self.effectData = effects

    self.charW = font:getTextWidth(char)
    self.charTracking = self.font:getTracking()

    local hasSine = false

    for i, v in ipairs(self.effectData) do
      if v["effect"] == "wavy" then
        hasSine = true

        self.period = v["param"] or 2

        break
      elseif v["effect"] == "shake" then
        self.intensity = v["param"] or 1
      end
    end

    if hasSine then
      self.sineTimer = pd.timer.new(628)

      self.sineTimer.repeats = true
      self.sineTimer.reverses = true
    end
  end

  self.xmod, self.ymod = 0, 0
  self.inverted = false

  index = index + 1

  self.index = index
end

function Char:update()
  for i, v in ipairs(self.effectData) do
    if v["effect"] == "wavy" then
      self.ymod = (math.sin((self.sineTimer.currentTime / 100) + (self.index / self.period))) *
          2 -- NOTE: figure out how to reverse sine wave?
    elseif v["effect"] == "shake" then
      self.xmod = math.random(-self.intensity, self.intensity)
      self.ymod = math.random(-self.intensity, self.intensity)
    elseif v["effect"] == "invert" then
      self.inverted = true
    end
  end
end

function Char:draw(x, y)
  if self.inverted then
    self.invertedImage:draw(x + self.xmod, y + self.ymod)
  else
    self.image:draw(x + self.xmod, y + self.ymod)
  end
end

function Char:destroy()
  if self.sineTimer then
    self.sineTimer:remove()
  end
  self = nil
end
