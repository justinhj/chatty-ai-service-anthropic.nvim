-- setup chatty and the anthropic config
local chatty = require('chatty-ai')
local anthropic = require('init') -- TODO this would be the plugin name

---@type AnthropicConfig
local anthropic_config = {
  -- change model etc
}

-- Create the services

local s1 = anthropic.create_service('gpt-4o', anthropic_config)

chatty.setup({})

chatty.register_service(s1)

-- chatty.list_services()

vim.api.nvim_set_keymap('n', '<leader>ac', [[<cmd>lua require('chatty-ai').complete("gpt-4o", "filetype_input", 'code_writer', 'buffer_replace', false)<CR>]], {noremap = true, silent = true })

vim.api.nvim_set_keymap('n', '<leader>as', [[<cmd>lua require('chatty-ai').complete("gpt-4o", "filetype_input", 'code_writer', 'buffer_replace', true)<CR>]], {noremap = true, silent = true })
