import "lib/nanodialogue"

local pd <const> = playdate
local gfx <const> = pd.graphics

local TEXT = "hello~! this is nanoDialogue, a dialogue system based off of pdDialogue.\n\nit allows for dynamic text effects, such as {wavy}floating text{/wavy}, {shake}shaky text{/shake}, {delay 60}character adding delay{/delay}, and {invert}inverted text!{/invert}"

local image = gfx.image.new(64, 64, gfx.kColorBlack)

local portrait = nanoPortraitDialogueBox("dummy", image, TEXT, nil, gfx.getFont(gfx.font.kVariantBold))
local dialogue = nanoDialogueBox(TEXT, nil, gfx.getFont(gfx.font.kVariantBold))

function pd.update()
  pd.timer.updateTimers()
  gfx.clear()

  if portrait.active then
    portrait:update()
    portrait:draw()
  end

  if dialogue.active then
    dialogue:update()
    dialogue:draw()
  end
end

function pd.AButtonDown()
  dialogue:open()
end

function pd.BButtonDown()
  portrait:open()
end
