local source = {}

source.new = function (client)
  local self = setmetatable({}, { __index = source })
  self.client = client
  self.request_id = nil
  self.resolve_request_id = nil
  self.execute_request_id = nil
  return self
end

---Return trigger characters
---@return string[]
source.get_trigger_characters = function(self)
  return self:_get(self.client.server_capabilities, { 'completionProvider', 'triggerCharacters' }) or {};
end

---Return should completion or not.
---@param ctx cmp.Context
---@return boolean
source.match = function(self, ctx)
  for _, client in vim.lsp.buf_get_clients(ctx.bufnr) do
    if client == self.client then
      return true
    end
  end
  return false
end

---Invoke completion
---@param request any
---@param callback fun(response: any)
source.complete = function (self, request, callback)
  if self.client.is_stopped() then
    return callback()
  end

  local params = vim.lsp.util.make_position_params()
  params.context = {}
  params.context.triggerKind = request.completion_context.triggerKind
  params.context.triggerCharacter = request.completion_context.triggerCharacter

  if self.request_id ~= nil then
    self.client.cancel_request(self.request_id)
  end

  local _, request_id = self.client.request('textDocument/completion', params, function(_, _, response)
    callback(response)
  end)
  self.request_id = request_id
end

---Resolve completion item
---@param completion_item lsp.CompletionItem
---@param callback fun(response: any)
source.resolve = function (self, completion_item, callback)
  if self.resolve_request_id ~= nil then
    self.client.cancel_request(self.resolve_request_id)
  end
  local _, resolve_request_id = self.client.request('completionItem/resolve', completion_item, function(_, _, response)
    callback(response)
  end)
  self.resolve_request_id = resolve_request_id
end

---Execute command
---@param completion_item  lsp.CompletionItem
---@param callback  fun()
source.execute = function (self, completion_item, callback)
  if self.execute_request_id ~= nil then
    self.client.cancel_request(self.execute_request_id)
  end
  if completion_item.command then
    local _, execute_request_id = self.client.request('workspace/executeCommand', completion_item.command, function(_, _, _)
      callback()
    end)
    self.execute_request_id = execute_request_id
  else
    callback()
    self.execute_request_id = nil
  end
end

---Get object by path
---@param root table
---@param paths string[]
---@return any
source._get = function(_, root, paths)
  local c = root
  for _, path in ipairs(paths) do
    c = c[path]
    if not c then
      return nil
    end
  end
  return c
end

return source

