-- ---------------------------------------------------------------------------
-- Hammerspoon init — kêu "Tink" mỗi khi bấm ↑/↓ lúc Alacritty đang là cửa sổ
-- trước (frontmost). Dùng eventtap và TRẢ VỀ false (không nuốt phím) nên
-- terminal/TUI vẫn nhận ↑/↓ y như cũ: không vỡ auto-repeat, không mất modifier.
--
-- Giới hạn: chỉ biết "Alacritty đang front", KHÔNG biết bên trong có session
-- Claude Code hay không — nên sẽ kêu cả khi cuộn lịch sử zsh. Sự kiện
-- auto-repeat (giữ phím) bị bỏ qua để khỏi kêu liên tục.
--
-- ⚠️ Cần cấp quyền Accessibility cho Hammerspoon (làm tay 1 lần):
--   System Settings → Privacy & Security → Accessibility → bật Hammerspoon
-- ---------------------------------------------------------------------------

local arrowKeys = { [126] = true, [125] = true }  -- 126 = Up, 125 = Down
local tink = hs.sound.getByName("Tink")

-- KHÔNG để `local`: eventtap phải là biến toàn cục để Hammerspoon khỏi
-- garbage-collect (mất biến = tap ngừng chạy).
arrowTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  local app = hs.application.frontmostApplication()
  if app and app:name() == "Alacritty"
     and arrowKeys[e:getKeyCode()]
     and not e:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) then
    if tink then tink:play() end
  end
  return false  -- không nuốt phím: ↑/↓ vẫn tới terminal/TUI như thường
end)
arrowTap:start()

-- Tự nạp lại config khi ~/.hammerspoon/init.lua thay đổi (watch.sh copy sang là
-- Hammerspoon tự reload, khỏi cần lệnh ngoài).
configWatcher = hs.pathwatcher.new(hs.configdir, function() hs.reload() end)
configWatcher:start()
