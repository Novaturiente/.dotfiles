function winsopen
    podman-compose -f ~/.config/winapps/compose.yaml start
    and sleep 5
    and xfreerdp3 /u:Nova /p:$WINAPPS_PASSWORD /v:127.0.0.1 /cert:ignore /sound /microphone +dynamic-resolution /sec:tls /f +span +home-drive
end
