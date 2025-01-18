--- ISNT WORKING ON TEST CUZ DONT EXISTS
local floatwindow = require("floatwindow")

local M = {}

M.setup = function()
  -- Nothing
end

---@class present.Slide
---@field title string
---@field body string[]

---@class present.Slides
---@field slides present.Slide[]

---Take some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
  local presentation = { slides = {} }
  local current_slide = {
    title = "",
    body = {},
  }

  local separator = "^#"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(presentation.slides, current_slide)
      end

      current_slide = {
        title = line,
        body = {},
      }
    else
      table.insert(current_slide.body, line)
    end
  end

  table.insert(presentation.slides, current_slide)

  return presentation
end

local create_window_config = function()
  local width = vim.o.columns
  local height = vim.o.lines

  local header_height = 1 -- 1 + border
  local footer_height = 1 -- 1 + no border
  local body_height = height - header_height - footer_height - 2

  return {
    background = {
      floating = {
        buf = -1,
        win = -1,
      },
      opts = {
        relative = "editor",
        style = "minimal",
        zindex = 1,
        width = width,
        height = height,
        col = 0,
        row = 0,
        border = "none",
      },
      enter = false,
    },
    header = {
      floating = {
        buf = -1,
        win = -1,
      },
      opts = {
        relative = "editor",
        style = "minimal",
        zindex = 3,
        width = width,
        height = header_height,
        col = 0,
        row = 0,
        border = { " ", " ", " ", " ", " ", " ", " ", " " },
      },
      enter = false,
    },
    body = {
      floating = {
        buf = -1,
        win = -1,
      },
      opts = {
        relative = "editor",
        style = "minimal",
        zindex = 2,
        width = width - 10,
        height = body_height,
        col = 10,
        row = 2,
        border = { " ", " ", " ", " ", " ", " ", " ", " " },
      },
    },
    footer = {
      floating = {
        buf = -1,
        win = -1,
      },
      opts = {
        relative = "editor",
        style = "minimal",
        zindex = 3,
        width = width,
        height = footer_height,
        col = 0,
        row = height - footer_height,
      },
      enter = false,
    },
  }
end

local state = {
  parsed = {},
  current_slide = 1,
  float = {},
  title = "",
}

local foreach_float = function(callback)
  for name, float in pairs(state.float) do
    callback(name, float)
  end
end

local present_keymap = function(mode, key, callback)
  vim.keymap.set(mode, key, callback, {
    buffer = state.float.body.floating.buf,
  })
end

local end_presentation = function(restore)
  for option, config in pairs(restore) do
    vim.opt[option] = config.original
  end

  foreach_float(function(_, float)
    pcall(vim.api.nvim_win_close, float.floating.win, true)
  end)
end

M.start_presentation = function(opts)
  opts.buf = vim.api.nvim_get_current_buf()

  state.current_slide = 1

  local lines = vim.api.nvim_buf_get_lines(opts.buf, 0, -1, false)
  state.parsed = parse_slides(lines)
  state.title = vim.fn.expand("%:t") == "" and "----" or vim.fn.expand("%:t")

  state.float = create_window_config()

  state.float.background.floating = floatwindow.create_floating_window(state.float.background)
  state.float.footer.floating = floatwindow.create_floating_window(state.float.footer)
  state.float.header.floating = floatwindow.create_floating_window(state.float.header)

  state.float.body.floating = floatwindow.create_floating_window(state.float.body)

  foreach_float(function(_, float)
    vim.bo[float.floating.buf].filetype = "markdown"
  end)

  local set_slide_content = function(id)
    local slide = state.parsed.slides[id]

    if slide == nil then
      vim.print("File not valid")
      end_presentation({})
      return
    end

    local padding = string.rep(" ", (state.float.header.opts.width - #slide.title) / 2)
    local title = padding .. slide.title

    local footer = string.format("  %s | %d / %d", state.title, id, #state.parsed.slides)

    vim.api.nvim_buf_set_lines(state.float.footer.floating.buf, 0, -1, false, { footer })
    vim.api.nvim_buf_set_lines(state.float.header.floating.buf, 0, -1, false, { title })
    vim.api.nvim_buf_set_lines(state.float.body.floating.buf, 0, -1, false, slide.body)
  end

  -- NOTE: KEYMAPS
  present_keymap("n", "n", function()
    state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
    set_slide_content(state.current_slide)
  end)

  present_keymap("n", "p", function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    set_slide_content(state.current_slide)
  end)

  present_keymap("n", "q", function()
    vim.api.nvim_win_close(state.float.body.floating.win, true)
  end)

  -- NOTE: CONFIGS TO RESTORE
  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      presente = 0,
    },
  }

  for option, config in pairs(restore) do
    vim.opt[option] = config.presente
  end

  -- NOTE: AUTO COMMANDS
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.float.body.floating.buf,
    callback = function()
      end_presentation(restore)
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("present-resized", {}),
    callback = function()
      if not vim.api.nvim_win_is_valid(state.float.body.floating.win) or state.float.body.floating.win == nil then
        return
      end

      local updated = create_window_config()

      foreach_float(function(name, float)
        float.opts = updated[name].opts
        vim.api.nvim_win_set_config(float.floating.win, updated[name].opts)
      end)

      set_slide_content(state.current_slide)
    end,
  })

  set_slide_content(state.current_slide)
end

vim.api.nvim_create_user_command("Present", M.start_presentation, {})

M._parse_slides = parse_slides

return M
