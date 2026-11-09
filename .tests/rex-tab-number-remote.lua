local host = assert(rex.args.host)
local response, err = rex.call("client.action", {
  action = "go_to_tab_number",
  origin = "key",
  server = host,
  servers = { { name = host, id = host } },
  session_id = assert(rex.args.remote_session),
  block_id = assert(rex.args.remote_block),
})
assert(response, err)
for _, action in ipairs(response.client_actions or {}) do
  rex.client.queue(action.action, action.args)
end
return {
  passed = true,
  host = host,
  remote_session = rex.args.remote_session,
  client_actions = response.client_actions,
  dialog_input = "native",
}
