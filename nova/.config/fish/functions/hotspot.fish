function hotspot
    nmcli dev wifi hotspot ifname wlp0s20f3 ssid Novapc password "$HOTSPOT_PASSWORD"
end
