local function emit(value)
  print(rex.json.encode(value))
  io.stdout:flush()
end

local function call(method, args)
  local result, err = rex.call(method, args or {})
  assert(result, err)
  return result
end

local epoch = 0

local function snapshot()
  local observed_epoch = epoch
  local clients = call("client.list")
  local blocks = {}
  for _, session in ipairs(call("session.list").sessions or {}) do
    for _, block in ipairs(call("session.list_blocks", { session_id = session.session_id }).blocks or {}) do
      block.session_id = session.session_id
      blocks[#blocks + 1] = block
    end
  end
  if observed_epoch ~= epoch then
    rex.after(0.1, snapshot)
    return
  end
  emit({ type = "snapshot", clients = clients.clients, blocks = blocks })
end

call("session.attach_all", { event_scope = "all" })

rex.on("block_owner_changed", function(ctx, ev)
  epoch = epoch + 1
  local observed_epoch = epoch
  local current
  for _, block in ipairs(call("session.list_blocks", { session_id = ctx.session_id }).blocks or {}) do
    if block.block_id == ev.block_id then
      current = block
      break
    end
  end
  local clients = call("client.list").clients
  if observed_epoch ~= epoch then return end
  if not current then
    snapshot()
    return
  end
  emit({
    type = "owner",
    block_id = ev.block_id,
    session_id = ctx.session_id,
    owner = current.owner,
    reset_history = current.owner ~= ev.owner and not current.owner,
    clients = clients,
  })
end)

for _, event in ipairs({ "block_created", "block_closed", "session_created", "session_destroyed", "client_changed", "client_left" }) do
  rex.on(event, snapshot)
end

rex.every(10, snapshot)

rex.every(2, function()
  call("server.whoami")
  emit({ type = "heartbeat" })
end)

snapshot()
