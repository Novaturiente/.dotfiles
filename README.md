# NIX OS CONFIGURATION


#virt manager
#!/bin/bash
virsh net-start default
virsh net-autostart default


#ADB
#!/bin/bash
adb tcpip 5555
adb connect ip
