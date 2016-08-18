local APP_CFG = require("cfg")

module("KV_INFO_LIST")

OWN_INFO = {
	format = {"boolean","number","string","function"},
	keywords = APP_CFG["keywords"],
	workfunc = APP_CFG["workfunc"],
}
