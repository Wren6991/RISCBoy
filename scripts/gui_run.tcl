# Navigate up directories until we find a file called "Default.wcfg"
# Stop if we get to root

set cfgdir [file normalize .];
while {"$cfgdir" != "/"} {
	if [file exists $cfgdir/Default.wcfg] {
		wcfg open $cfgdir/Default.wcfg
		break
	}
	set cfgdir [file normalize $cfgdir/..]
}

run 100us;