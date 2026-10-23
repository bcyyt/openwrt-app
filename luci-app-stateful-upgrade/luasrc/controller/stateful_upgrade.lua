module("luci.controller.stateful_upgrade", package.seeall)

local BIN = "/usr/sbin/stateful-upgrade"
local IMAGE = "/tmp/stateful-upgrade/firmware.bin"

function index()
	if not nixio.fs.access(BIN) then
		return
	end

	entry({"admin", "system", "stateful_upgrade"}, template("stateful_upgrade/overview"), _("Stateful Upgrade"), 88).dependent = false
	entry({"admin", "system", "stateful_upgrade", "preview"}, call("action_preview")).leaf = true
	entry({"admin", "system", "stateful_upgrade", "status"}, call("action_status")).leaf = true
	entry({"admin", "system", "stateful_upgrade", "report"}, call("action_report")).leaf = true
	entry({"admin", "system", "stateful_upgrade", "upgrade"}, call("action_upgrade")).leaf = true
end

local function json_exec(cmd)
	local sys = require "luci.sys"
	local http = require "luci.http"
	http.prepare_content("application/json")
	http.write(sys.exec(cmd))
end

function action_preview()
	json_exec(BIN .. " preview")
end

function action_status()
	local sys = require "luci.sys"
	local http = require "luci.http"
	http.prepare_content("application/json")
	local st = sys.exec(BIN .. " status"):gsub("%s+$", "")
	if st == "" then
		st = "idle"
	end
	http.write(string.format('{"status":"%s"}', st))
end

function action_report()
	json_exec(BIN .. " report")
end

function action_upgrade()
	local fs = require "nixio.fs"
	local sys = require "luci.sys"
	local http = require "luci.http"

	fs.mkdirr("/tmp/stateful-upgrade")

	local fp
	http.setfilehandler(function(meta, chunk, eof)
		if not fp then
			if meta and meta.name == "image" then
				fp = io.open(IMAGE, "w")
			end
		end
		if fp and chunk then
			fp:write(chunk)
		end
		if fp and eof then
			fp:close()
			fp = nil
		end
	end)

	local function fail(msg)
		luci.template.render("stateful_upgrade/overview", { upgrade_error = msg })
	end

	if http.formvalue("do_upgrade") then
		local st = fs.stat(IMAGE)
		if not st or not st.size or st.size < 1 then
			return fail(_("Firmware image missing, unreadable, or empty"))
		end
		http.prepare_content("text/html; charset=utf-8")
		http.write("<html><body><h3>")
		http.write(_("Snapshot saved, flashing firmware. The device will reboot."))
		http.write("</h3></body></html>")
		http.close()
		sys.exec(BIN .. " upgrade " .. IMAGE)
		return
	end

	luci.template.render("stateful_upgrade/overview")
end
