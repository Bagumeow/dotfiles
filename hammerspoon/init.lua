-- ---------------------------------------------------------------------------
-- Hammerspoon init — kêu "Tink" mỗi khi bấm phím mũi tên (↑/↓/←/→) lúc app front
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

-- App sẽ kêu khi bấm phím mũi tên. Thêm ["Code"] = true nếu chạy Claude trong
-- terminal VS Code (lưu ý: kêu cả khi bấm mũi tên trong editor VS Code).
local targetApps = { ["Alacritty"] = true}

-- 126=Up, 125=Down, 123=Left, 124=Right
local arrowKeys = { [126] = true, [125] = true, [123] = true, [124] = true }

-- Kêu bằng afplay chạy nền: mỗi lần bấm là 1 tiến trình riêng, nên bấm nhanh
-- nhiều lần vẫn kêu đủ (dùng chung 1 hs.sound sẽ bị nuốt khi đang phát dở).
-- Giữ tham chiếu task trong `beeps` kẻo bị garbage-collect lúc đang chạy.

-- [RANDOM] Gom mọi *.mp3 trong ~/.hammerspoon (deploy từ audio/) -> mỗi lần bấm
-- chọn ngẫu nhiên 1 tiếng. Comment cả block SOUNDS này nếu muốn dùng 1 file cố
-- định ở dưới. (Thêm file mới: chạy ./install.sh hoặc reload Hammerspoon.)

---
--- local SOUNDS = {}
--- for f in hs.fs.dir(hs.configdir) do
---   if f:sub(-4):lower() == ".mp3" then SOUNDS[#SOUNDS + 1] = hs.configdir .. "/" .. f end
--- end
--- math.randomseed(os.time())
---
-- [CỐ ĐỊNH] 1 file. Comment dòng SOUND này nếu đang dùng random ở trên.
local SOUND = hs.configdir .. "/gta_sa_effect_4.mp3"

local beeps = {}
local function beep()
  -- Có SOUNDS (random) thì ưu tiên; không thì dùng SOUND cố định; cuối là Tink.
  local file = (SOUNDS and #SOUNDS > 0) and SOUNDS[math.random(#SOUNDS)]
            or SOUND or "/System/Library/Sounds/Tink.aiff"
  local t
  t = hs.task.new("/usr/bin/afplay", function() beeps[t] = nil end, { file })
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
