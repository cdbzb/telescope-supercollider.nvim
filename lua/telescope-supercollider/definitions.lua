local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require 'telescope.config'.values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local previewers = require 'telescope.previewers'
local ts_utils = require 'telescope.utils'
local defaulter = ts_utils.make_default_callable

local uv = vim.loop
local api = vim.api

local check_scnvim_loaded = function()
  local scnvim_loaded, scnvim = pcall(require, "scnvim")
  assert(scnvim_loaded, "SCNvim is not loaded - please make sure to load SCNvim first")
end

local scnvim_class_definitions = function(opts)
  opts = opts or {}

  check_scnvim_loaded()

  local path = require "scnvim/path".get_plugin_root_dir()
  local tagsPath = require "scnvim/path".get_cache_dir() .. "/tags"
  local tagsFile = io.open(tagsPath)
  local tagEntries = {} -- We'll store both the tag and line number now

  for line in tagsFile:lines() do
    local tagname, tagpath, tagline, _ = line:match("%s*(.-)\t%s*(.-)\t%s*(.-)\t%s*(.-)")
    if tagname and tagpath and tagline then
      table.insert(tagEntries, {
        tagname = tagname,
        tagpath = tagpath,
        tagline = tonumber(tagline) or 1, -- Default to line 1 if parsing fails
      })
    end
  end

  tagsFile:close()

  -- Sort the entries alphabetically by tagname
  table.sort(tagEntries, function(a, b) return a.tagname < b.tagname end)

  -- Create a display table for Telescope
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

  -- Run a telescope finder that searches through the tagKeys
  pickers.new(opts or {}, {
    prompt_title = "SuperCollider class definitions",
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
    previewer = previewers.vim_buffer_cat.new(opts), -- Add previewer to see the file content
    attach_mappings = function(prompt_bufnr, map)
      local open_class = function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          -- Open the file in a new tab and jump to the line
          vim.cmd("tabedit " .. selection.filename)
          api.nvim_win_set_cursor(0, {selection.lnum, 0})
        end
      end

      map("i", "<CR>", open_class)
      map("n", "<CR>", open_class)

      return true
    end,
  }):find()
end

return scnvim_class_definitions
