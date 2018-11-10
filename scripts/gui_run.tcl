if [file exists "../Default.wcfg"] {
	wcfg open "../Default.wcfg";
} else {
	wcfg open "../../Default.wcfg";
}

run 10us;