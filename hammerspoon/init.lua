-- ---------------------------------------------------------------------------
-- Hammerspoon init — kêu "Tink" mỗi khi bấm ↑/↓ lúc app terminal đang front
-- (frontmost). Dùng eventtap và TRẢ VỀ false (không nuốt phím) nên terminal/TUI
-- vẫn nhận ↑/↓ y như cũ: không vỡ auto-repeat, không mất modifier.
--
-- Giới hạn: chỉ biết app nào đang front, KHÔNG biết bên trong có session Claude
-- Code hay không — nên sẽ kêu cả khi cuộn lịch sử zsh. Sự kiện auto-repeat (giữ
-- phím) bị bỏ qua để khỏi kêu liên tục.
--
-- ⚠️ Cần cấp quyền Accessibility cho Hammerspoon (làm tay 1 lần):
--   System Settings → Privacy & Security → Accessibility → bật Hammerspoon
-- ---------------------------------------------------------------------------

-- App sẽ kêu khi bấm ↑/↓. Thêm ["Code"] = true nếu chạy Claude trong terminal
-- của VS Code (lưu ý: sẽ kêu cả khi bấm ↑/↓ trong editor VS Code).
local targetApps = { ["Alacritty"] = true, ["Code"] = true }

local arrowKeys = { [126] = true, [125] = true }  -- 126 = Up, 125 = Down

-- Kêu bằng afplay chạy nền: mỗi lần bấm là 1 tiến trình riêng, nên bấm nhanh
-- nhiều lần vẫn kêu đủ (dùng chung 1 hs.sound sẽ bị nuốt khi đang phát dở).
-- Giữ tham chiếu task trong `beeps` kẻo bị garbage-collect lúc đang chạy.
local TINK = "/System/Library/Sounds/Tink.aiff"
local beeps = {}
local function beep()
  local t
  t = hs.task.new("/usr/bin/afplay", function() beeps[t] = nil end, { TINK })
  beeps[t] = true
  t:start()
end

-- KHÔNG để `local`: eventtap phải là biến toàn cục kẻo Hammerspoon
-- garbage-collect (mất biến = tap ngừng chạy).
arrowTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  if arrowKeys[e:getKeyCode()]
     and e:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 0 then
    local app = hs.application.frontmostApplication()
    if app and targetApps[app:name()] then beep() end
  end
  return false  -- không nuốt phím: ↑/↓ vẫn tới terminal/TUI như thường
end)
arrowTap:start()

-- Tự nạp lại khi có *.lua trong ~/.hammerspoon thay đổi (watch.sh copy sang là
-- Hammerspoon tự reload). Lọc theo đuôi .lua để KHỎI reload vô hạn khi file
-- khác trong thư mục (log, .DS_Store, Spoons/...) thay đổi.
configWatcher = hs.pathwatcher.new(hs.configdir, function(files)
  for _, f in ipairs(files) do
    if f:sub(-4) == ".lua" then hs.reload(); return end
  end
end)
configWatcher:start()
