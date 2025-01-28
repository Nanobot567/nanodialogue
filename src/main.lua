import "lib/nanodialogue"

local pd <const> = playdate
local gfx <const> = pd.graphics

local TEXT = "hello! {wavy}testing wavy text{/wavy}. {invert}here{/invert} {shake}is some more{/shake} {delay 100}text{/delay} to check wrapping.\n\nthis should be a new page of {invert}text.\n\n{/invert}i'm very glad this works!\n\nhere's another {wavy}very very very{/wavy} long text box {invert}just to show that more things are possible!{/invert} (and here's a bunch more text to stress test the thing)"

local image = gfx.image.new(64, 64, gfx.kColorBlack)

local portrait = nanoPortraitDialogueBox(TEXT, image)
local dialogue = nanoDialogueBox(TEXT)

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
