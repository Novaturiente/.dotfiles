# NIX OS CONFIGURATION


#virt manager
virsh net-start default
virsh net-autostart default


#ADB
adb tcpip 5555
adb connect ip
