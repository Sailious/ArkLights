-- 云控对接
-- 为什么不用local，因为有些解释器的require有bug。
cloud = {}
m = cloud

m.deviceToken = ''
m.server = ''
m.heartBeatTid = -1
m.status = 1

m.setDeviceToken = function(deviceToken) m.deviceToken = strOr(deviceToken) end

m.setServer = function(server) m.server = strOr(server) end
m.enabled =
  function() return #strOr(m.server) > 0 and #strOr(m.deviceToken) > 0 end

m.heartBeat = function()
  local data = {status = m.status, deviceToken = m.deviceToken}
  local res, code = httpPost(m.server .. "/heartBeat", JsonEncode(data), 30,
                             "Content-Type: application/json")
  return res, code
end

m.getTask = function()
  local res, code = httpGet(m.server .. "/getTask?" .. "deviceToken=" ..
                              m.deviceToken, 30,
                            'Content-Type: application/json')
  return res, code
end

m.failTask = function(imageUrl, type)
  type = type or 'failTask'
  local data = {deviceToken = m.deviceToken, imageUrl = imageUrl}
  local res, code = httpPost(m.server .. "/" .. type, JsonEncode(data),
                             'Content-Type: application/json')
  return res, code
end

m.completeTask =
  function(imageUrl) return m.failTask(imageUrl, 'completeTask') end

m.solveTask = function(data)
  if not table.includes({"daily", "rogue"}, data.taskType) then return end
  local username = data.account
  local password = data.password
  local server = data.server
  local config = data.config
  local status
  status, config = pcall(JsonDecode, config)
  config = status and config or {}
  restartSimpleMode(taskType, username, password, server, config)
end

m.fetchSolveTask = function()
  if not m.enabled() then return end
  while true do
    local res, code = m.getTask()
    log("code", code)
    log("res", res)
    local status, data
    status, data = pcall(JsonDecode, res)
    -- log("data",data)
    if type(data) == 'table' and type(data.data) == 'table' then
      m.solveTask(data.data)
    end
    ssleep(5)
  end
end

m.startHeartBeat = function()
  if not m.enabled() then return end
  local f = function()
    while true do
      m.heartBeat()
      ssleep(5)
    end
  end
  m.heartBeatTid = beginThread(f)
end

m.stopHeartBeat = function() stopThread(m.heartBeatTid) end

restartSimpleMode = function(taskType, username, password, server, config)
  local x
  -- set recommend config over default
  -- x = loadOneUIConfig("main")
  -- x["fight_ui"] = "jm hd ce ls ap pr"
  -- for i = 1, 12 do x["now_job_ui" .. i] = true end
  -- x["now_job_ui8"] = false
  -- x["crontab_text"] = "4:00 12:00 20:00"
  -- saveOneUIConfig("main", x)
  --
  -- x = loadOneUIConfig("debug")
  -- x["max_jmfight_times"] = "1"
  -- x["max_login_times_5min"] = "3"
  -- x["QQ"] = strOr(config.QQ) .. '#' .. strOr(config.deviceName)
  -- x["multi_account_choice_weekday_only"] =
  --   strOr(config.weekdayOnly, x["multi_account_choice_weekday_only"])
  --
  -- x["qqnotify_beforemail"] = true
  -- x["qqnotify_afterenter"] = true
  -- x["qqnotify_beforeleaving"] = true
  -- x["qqnotify_beforemission"] = true
  -- x["qqnotify_save"] = true
  -- x["collect_beforeleaving"] = true
  -- -- 一是完成日常任务，二是间隔时间最长可以11小时，提高容错
  -- x["zero_san_after_fight"] = true
  -- x["max_drug_times_" .. str(1) .. "day"] = "99"
  -- x["max_drug_times_" .. str(2) .. "day"] = "99"
  -- x["max_drug_times_" .. str(3) .. "day"] = "1"
  -- x["max_drug_times_" .. str(4) .. "day"] = "1"
  -- x["max_drug_times_" .. str(5) .. "day"] = "1"
  -- x["max_drug_times_" .. str(6) .. "day"] = "1"
  -- x["max_drug_times_" .. str(7) .. "day"] = "1"
  -- x["enable_log"] = false
  -- x["disable_killacc"] = false
  -- x["keepalive_interval"] = "900"
  -- saveOneUIConfig("debug", x)
  --
  -- x = loadOneUIConfig("multi_account")
  -- x["multi_account_end_closeotherapp"] = true
  -- x["multi_account_end_closeapp"] = true
  -- x["multi_account_choice"] = "1-30"
  -- x["multi_account_enable"] = true
  -- saveOneUIConfig("multi_account", x)

  -- set task config
  if #strOr(username) == 0 or #strOr(password) == 0 then return end
  if not table.includes({0, 1}, server) then return end

  local hook = [[
clossapp(appid)
clossapp(bppid)
cloud_task=true
crontab_enable=false
multi_account_enable=false
username=]] .. string.format("%q", username) .. [[;
password=]] .. string.format("%q", password) .. [[;
server=]] .. server
  if taskType == 'rogue' then
    hook = hook .. [[;extra_mode="战略前瞻投资"]]
  end
  if #strOr(config.fight) > 0 then
    hook = hook .. [[;fight_ui=]] .. string.format("%q", config.fight)
  end
  if config.maxDrugTimes then
    hook = hook .. [[;max_drug_times=]] .. str(config.maxDrugTimes)
  end
  if config.maxStoneTimes then
    hook = hook .. [[;max_stone_times=]] .. str(config.maxStoneTimes)
  end
  if type(config.operator) == 'table' then
    hook = hook .. [[;zl_best_operator=]] .. str(config.operator[1])
    hook = hook .. [[;zl_skill_times=]] .. str(config.operator[2])
    hook = hook .. [[;zl_skill_idx=]] .. str(config.operator[3])
  end
  if config.skipHard == true then
    hook = hook .. [[;zl_skip_hard=]] .. str(config.skipHard)
  end
  if config.maxLevel then
    hook = hook .. [[;zl_max_level=]] .. str(config.maxLevel)
  end

  hook = hook .. [[;saveConfig("restart_mode_hook",]] ..
           string.format("%q", hook) .. ')'
  log("hook", hook)
  ssleep(1000)
  saveConfig("hideUIOnce", "true")
  saveConfig("restart_mode_hook", hook)
  restartScript()
end