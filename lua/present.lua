local floatwindow = require("floatwindow")

local M = {}

M.setup = function()
  -- Nothing
end

---@class present.Slides
---@field presentation string[]
---
---Take some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
  local presentation = { slides = {} }
  local current_slide = {}

  local separator = "^#"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide > 0 then
        table.insert(presentation.slides, current_slide)
      end

      current_slide = {}
    elseif #presentation.slides == 0 and #current_slide == 0 then
      goto continue
    end

    table.insert(current_slide, line)
    ::continue::
  end

  table.insert(presentation.slides, current_slide)

  return presentation
end

M.start_presentation = function(opts)
  opts.buf = vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(opts.buf, 0, -1, false)

  local parsed = parse_slides(lines)

  local float = floatwindow.create_floating_window({ buf = -1 })

  local current_slide = 1
  vim.keymap.set("n", "n", function()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
  end, {
    buffer = float.buf,
  })

  vim.keymap.set("n", "p", function()
    current_slide = math.max(current_slide - 1, 1)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
  end, {
    buffer = float.buf,
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(float.win, true)
  end, {
    buffer = float.buf,
  })

  vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
end

vim.api.nvim_create_user_command("Present", M.start_presentation, {})

return M
