-- ---------------------------------------------------------------------------
-- orca/open-in-orca.applescript — applet trung gian cho Finder.
--
-- install.sh compile file này thành ~/Applications/Open in Orca.app bằng
-- osacompile. Applet AppleScript được LaunchServices coi là app nhận MỌI loại
-- file, nên nó xuất hiện trong "Open With" và nhận được double-click — thứ mà
-- Orca.app không làm được (không khai báo CFBundleDocumentTypes).
--
-- Applet không xử lý gì cả, chỉ chuyển path cho ~/.config/orca/open-in-orca.sh.
-- Sửa logic thì sửa file .sh, không phải file này.
-- ---------------------------------------------------------------------------

on open theFiles
	set paths to ""
	repeat with f in theFiles
		set paths to paths & " " & quoted form of (POSIX path of f)
	end repeat
	runOpener(paths)
end open

-- Mở applet trực tiếp (không kèm file): cho chọn file thủ công.
on run
	try
		set chosen to choose file with prompt "Chọn file để mở trong Orca:" with multiple selections allowed
	on error number -128 -- user bấm Cancel
		return
	end try
	set paths to ""
	repeat with f in chosen
		set paths to paths & " " & quoted form of (POSIX path of f)
	end repeat
	runOpener(paths)
end run

on runOpener(paths)
	if paths is "" then return
	try
		do shell script "$HOME/.config/orca/open-in-orca.sh" & paths
	on error errMsg
		-- Script tự bắn notification cho lỗi của nó; đây là lưới an toàn cuối
		-- (thiếu script, sai quyền chạy...).
		display notification errMsg with title "Open in Orca" subtitle "Applet lỗi"
	end try
end runOpener
