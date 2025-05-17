local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require 'telescope.config'.values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local previewers = require 'telescope.previewers'
local ts_utils = require 'telescope.utils'

local uv = vim.loop
local api = vim.api

local check_scnvim_loaded = function()
  local scnvim_loaded = pcall(require, "scnvim")
  if not scnvim_loaded then
    vim.notify("SCNvim is not loaded - please make sure to load SCNvim first", vim.log.levels.ERROR)
    return false
  end
  return true
end

local scnvim_class_definitions = function(opts)
  opts = opts or {}

  if not check_scnvim_loaded() then return end

  local path = require "scnvim.path"
  local tagsPath = path.get_cache_dir() .. "/tags"
  
  local ok, tagsFile = pcall(io.open, tagsPath)
  if not ok or not tagsFile then
    vim.notify("Could not open tags file at: " .. tagsPath, vim.log.levels.ERROR)
    return
  end

  local tagEntries = {}

  for line in tagsFile:lines() do
    local tagname, tagpath, tagline = line:match("^(.-)\t(.-)\t(.-)\t")
    if tagname and tagpath and tagline then
      table.insert(tagEntries, {
        tagname = tagname,
        tagpath = tagpath,
        tagline = tonumber(tagline) or 1,
      })
    end
  end

  tagsFile:close()

  table.sort(tagEntries, function(a, b) return a.tagname < b.tagname end)

  local display_entries = {}
  for _, entry in ipairs(tagEntries) do
    table.insert(display_entries, {
      value = entry.tagname,
      display = entry.tagname,
      ordinal = entry.tagname,
      filename = entry.tagpath,
      lnum = entry.tagline,
    })
  end

  -- Safe file opening function
  local function safe_open_file(filename, lnum)
    local ok, _ = pcall(vim.cmd, "silent tabedit " .. vim.fn.fnameescape(filename))
    if ok then
      api.nvim_win_set_cursor(0, {lnum, 0})
    else
      vim.notify("Failed to open file: " .. filename, vim.log.levels.ERROR)
    end
  end

  pickers.new(opts or {}, {
    prompt_title = "SuperCollider Class Definitions",
    finder = finders.new_table({
      results = display_entries,
      entry_maker = function(entry)
        return {
          value = entry.value,
          display = entry.display,
          ordinal = entry.ordinal,
          filename = entry.filename,
          lnum = entry.lnum,
        }
      end
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.vim_buffer_cat.new(opts),
    attach_mappings = function(prompt_bufnr, map)
      local open_class = function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          safe_open_file(selection.filename, selection.lnum)
        end
      end

      map("i", "<CR>", open_class)
      map("n", "<CR>", open_class)

      return true
    end,
  }):find()
end

return scnvim_class_definitions
