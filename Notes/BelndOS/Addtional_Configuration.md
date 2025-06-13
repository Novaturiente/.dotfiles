---
id: Additional cofigurations
aliases: []
tags: []
---

## Github Setup

- Generate SSH key
```
ssh-keygen -t ed25519 -C "novaturiente@proton.me"
```
- Add pub key to account

- Update to ssh remote
```
git remote set-url origin git@github.com:Novaturiente/
```

- configure git
```
git config --global user.email "Novaturiente@proton.me"
git config --global user.name "Novaturiente"
```


## Configure Network manager DNS

```
nmcli connection show
nmcli connection modify "YOUR_CONNECTION_NAME" ipv4.ignore-auto-dns yes
nmcli connection modify "YOUR_CONNECTION_NAME" ipv4.dns "1.1.1.1 8.8.8.8"

nmcli connection modify "YOUR_CONNECTION_NAME" ipv6.ignore-auto-dns yes
nmcli connection modify "YOUR_CONNECTION_NAME" ipv6.dns "2606:4700:4700::1111 2001:4860:4860::8888"

nmcli connection down "YOUR_CONNECTION_NAME" && nmcli connection up "YOUR_CONNECTION_NAME"
```

