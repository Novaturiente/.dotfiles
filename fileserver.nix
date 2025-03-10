services.samba = {
  enable = true;
  securityType = "user";
  openFirewall = true;
  settings = {
    global = {
      "workgroup" = "WORKGROUP";
      "server string" = "smbnix";
      "netbios name" = "smbnix";
      "security" = "user";
      #"use sendfile" = "yes";
      #"max protocol" = "smb2";
      # note: localhost is the ipv6 localhost ::1
      "hosts allow" = "192.168.0. 127.0.0.1 localhost";
      "hosts deny" = "0.0.0.0/0";
      "guest account" = "nobody";
      "map to guest" = "bad user";
    };
    "private" = {
      "path" = "/home/nova/";
      "browseable" = "yes";
      "read only" = "yes";
      "guest ok" = "no";
      "create mask" = "0644";
      "directory mask" = "0755";
      "force user" = "nova";
      "force group" = "nova";
    };
  };
};

services.samba-wsdd = {
  enable = true;
  openFirewall = true;
};

