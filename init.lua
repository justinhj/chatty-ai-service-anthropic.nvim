local chatty = require('chatty-ai')

-- https://docs.anthropic.com/en/api/getting-started

---@class CompletionServiceConfig
---@field public name string
---@field public stream_error_cb function
---@field public stream_complete_cb function
---@field public error_cb function
---@field public complete_cb function
---@field public stream_cb function
---@field public configure_call function

---@class AnthropicConfig
---@field api_key_name string?
---@field model string?
---@field version string?

---@type AnthropicConfig
local default_config = {
  api_key_name = 'ANTHROPIC_API_KEY',
  model = 'claude-3-5-sonnet-20240620',
  version = '2023-06-01',
}

local ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages'

local source = {}

source.create_service = function(name, config)
  local self = setmetatable({}, { __index = source })
  config = config or {}
  local merged_config = vim.tbl_deep_extend("force", {}, default_config, config)
  self.config = merged_config
  self.name = name
  return self
end

-- return url, headers, body
source.configure_call = function(self, user_prompt, completion_config, is_stream)
  local config = self.config
  local url = ANTHROPIC_URL
  local api_key = os.getenv(config.api_key_name)
  if not api_key then
    error('anthropic api key \'' .. config.api_key_name .. '\' not found in environment.')
  end
  local headers = {
      ['x-api-key'] = api_key,
      ['content-type'] = 'application/json',
      ['anthropic-version'] = config.version,
    }

  local body = {
    stream = is_stream,
    model = config.model,
    messages = {
      {
        content = completion_config.prompt .. '\n' .. user_prompt,
        role = 'user',
      },
    },
    system = completion_config.system,
    max_tokens = 8192
  }

  vim.print(vim.inspect(headers) .. vim.inspect(body) .. ' url ' .. url)
  return url, headers, body
end

source.complete_cb = function(raw_response)
  local response = vim.fn.json_decode(raw_response.body)
  local input_tokens = response.usage.input_tokens
  local output_tokens = response.usage.output_tokens
  local content = response.content
  if content[1].type == 'text' then
    return content[1].text, input_tokens, output_tokens
  else
    error('unexpected response type')
  end
end

source.stream_cb = function(raw_chunk)
  local data_raw = string.match(raw_chunk, "data: (.+)")

  if data_raw then
    local data = vim.json.decode(data_raw)

    local content = ''
    if data.delta and data.delta.text then
      content = data.delta.text
      return content
    end
  end
  return ''
end

source.stream_complete_cb = function(response)
  local body = response.body
  local lines = {}
  local text = ""

  for line in body:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local input_tokens = 0
  local output_tokens = 0

  for _, line in ipairs(lines) do
    if not line:match("^event:") then
      local stripped = line:gsub("^data: ", "")
      local data = vim.fn.json_decode(stripped)
      if data.type == "content_block_start" then
        text = text .. data.content_block.text
      elseif data.type == "content_block_delta" then
        text = text .. data.delta.text
      elseif data.type == 'message_start' then
        input_tokens = data.message.usage.input_tokens
      elseif data.type == 'message_delta' and data.delta.stop_reason == 'end_turn' then
        output_tokens = data.usage.output_tokens
      end
    end
  end

  return text, input_tokens, output_tokens
end

return {
  create_service = source.create_service
}
