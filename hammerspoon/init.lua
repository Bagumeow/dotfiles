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
local targetApps = { ["Alacritty"] = true }

local arrowKeys = { [126] = true, [125] = true }  -- 126 = Up, 125 = Down
local tink = hs.sound.getByName("Tink")
           or hs.sound.getByFile("/System/Library/Sounds/Tink.aiff")

-- KHÔNG để `local`: eventtap phải là biến toàn cục kẻo Hammerspoon
-- garbage-collect (mất biến = tap ngừng chạy).
arrowTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  if arrowKeys[e:getKeyCode()]
     and e:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 0 then
    local app = hs.application.frontmostApplication()
    if app and targetApps[app:name()] and tink then tink:play() end
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
