# -------------------------------
#
# SCC Router Base Configuration
# NCAE Router Initial Setup()
# Bridge + Jump
#
# ------------------------------

:delay 5

# ---- Global Team Number ----
:global teamNum
:if ([:typeof $teamNum] = "nothing") do={
  :error "Set :global teamNum <n> before running"
}

# ---- Interface Names (Verify with /interface print) ----
:local WANBR "WAN"
:local LANBR "LAN"
:local WANIF "ether1"
:local LANIF "ether2"

# ---- SCC Competition Infrastructure (Needs Update Once Topology Is Released) ----
:local CompGW         "172.16.0.1"          ;# Scoring engine/ upstream gateway
:local CompDns        "172.16.0.12"         ;# Competition upstream CompDns
:local CompNet        "172.16.0.0/16"       ;# Broader competition / scoring network
:local scoringNet     "172.16.10.0/24"      ;# Scoring engine subnet (if separate)
:local CompJumphost   "172.16.12.15"        ;# White-team / competition jump host
:local teamJumphost   "172.16.15.1"         ;# our team's out-of-band jump host

# ---- Team Addressing (UPDATE ONCE TOPOLOGY IS RELEASED) ----
:local TEAM $teamNum
:local WANIP ("172.16." . $TEAM . ".1/16")  ;# External WAN
:local LANIP ("192.168." . $TEAM . ".1/24") ;# Internal LAN
:local LANNET ("192.168." . $TEAM . ".0/24");# Internal LAN Subnet

# ---- Internal Scored Server IPs (UPDATE ONCE TOPOLOGY IS RELEASED) ---- 
:local WEBIP  ("192.168." . $TEAM . ".10")  ;# HTTP/HTTPS Web Server
:local DNSIP  ("192.168." . $TEAM . ".12")  ;# Internal/Public DNS Server
:local MAILIP ("192.168." . $TEAM . ".25")  ;# Mail Server (SMTP/IMAP/POP3)
:local DBIP   ("192.168." . $TEAM . ".30")  ;# Database Server (If External)
:local FTPIP  ("192.168." . $TEAM . ".40")  ;# FTP / File Server
#:local ADIP  ("192.168." . $TEAM . ".50")  ;# AD / WinRM / RDP Jump (uncomment if scored)

# ---- Wait for Interfaces to Exist ----
:local tries 0
:while (([len [/interface find name=$WANIF]] = 0) || ([:len [/interface find name=$LANIF]] = 0)) do={
  :delay 1
  :set tries ($tries + 1)
  :if ($tries > 20) do={
    :log error "Interfaces not ready"
    :error "Interface wait timeout"

  }

}

# ---- Wait for Interface to be Running ----
:set tries 0
:while (([/interface get $WANIF running] = false) || ([/interface get $LANIF running] = false)) do={
  :delay 1
  :set tries ($tries + 1)
  :if tries ($tries > 20) do={
    :log warning "Interfaces not fully running yet; continuing"
    :break

  }

}

# ---- Create Bridges if missing ----
:if ([len [/interface bridge find name=$WANBR]] = 0) do={
  /interface bridge add name=$WANBR
}
:if ([len [/interface bridge find name=$LANBR]] = 0) do={
  /interface bridge add name =$LANBR
}

# ---- Add bridge ports safely ----
:if ([:len [/interface bridge port find bridge=$WANBR interface=$WANIF]] = 0) do={
  /interface brudge port add bridge=$WANBR interface=$WANIF
}
:if ([:len [/interface bridge port find bridge=$LANBR interface=$LANIF]] = 0) do={
    /interface bridge port add bridge=$LANBR interface=$LANIF
}

:delay 2

# ---- Remove managed IPs safely ----
:foreach id in=[/ip address find comment~"^SCC"] do ={
  /ip address remove $id
}

# ---- Assign addresses to bridges ----
/ip address add address=$WANIP interface=$WANBR comment="SCC-WAN"
/ip address add address=$LANIP interface=$LANBR comment="SCC-LAN"

# ---- Default route ----
:foreach id in=[/ip route find comment="SCC-Default"] do={
    /ip route remove $id
}
/ip route add dst-address=0.0.0.0/0 gateway=$compGw comment="SCC-Default"

# ---- DNS ----
/ip dns set servers=$compDns allow-remote-requests=no

# ---- Clean Managed Nat Rules ---- 
:foreach id in=[/ip firewall nat find comment~"^SCC-"] do={
    /ip firewall nat remove $id
}
# Outbound NAT for internal clients
/ip firewall nat add chain=srcnat src-address=$LANNET out-interface=$WANBR action=masquerade comment="SCC-MASQ"

# ---- Port Forwards (REMOVE OR UNCOMMENT BASED ON SCORED SERVICES) ----
# Web (HTTP/HTTPS)
/ip firewall nat add chain=dstnat in-interface=$WANBR protocol=tcp dst-port=80 action=dst-nat to-addresses=$WEBIP to-ports=80 comment="SCC-DST-HTTP"
/ip firewall nat add chain=dstnat in-interface=$WANBR protocol=tcp dst-port=443 action=dst-nat to-addresses=$WEBIP to-ports=443 comment="SCC-DST-HTTPS"

# DNS (TCP/UDP 53)
/ip firewall nat add chain=dstnat in-interface=$WANBR protocol=tcp dst-port=53 action=dst-nat to-addresses=$DNSIP to-ports=53 comment="SCC-DST-DNS-TCP"
/ip firewall nat add chain=dstnat in-interface=$WANBR protocol=udp dst-port=53 action=dst-nat to-addresses=$DNSIP to-ports=53 comment="SCC-DST-DNS-UDP"

# Mail (Uncomment if SMTP/IMAP/POP3 are scored)
# /ip firewall nat add chain=dstnat in-interface=$WANBR protocol=tcp dst-port=25 action=dst-nat to-addresses=$MAILIP to-ports=25 comment="SCC-DST-SMTP"
# /ip firewall nat add chain=dstnat in-interface=$WANBR protocol=tcp dst-port=143 action=dst-nat to-addresses=$MAILIP to-ports=143 comment="SCC-DST-IMAP"
# /ip firewall nat add chain=dstnat in-interface=$WANBR protocol=tcp dst-port=993 action=dst-nat to-addresses$MAILIP to-ports=993 comment="SCC-DST-IMAPS"

# FTP (Uncomment if FTP is scored — note passive ports may also be needed)
# /ip firewall nat add chain=dstnat in-interface=$WANBR protocol=tcp dst-port=21

# ---- Clean managed filter rules ----
:foreach id in=[/ip firewall filter find comment~"^SCC-"] do={
    /ip firewall filter remove $id
}

# INPUT chain (Traffic destined TO the router itself)
/ip firewall filter add chain=input connection-state=established,related action=accept comment="SCC-IN-EST"
/ip firewall filter add chain=input connection-state=invalid action=drop comment="SCC-IN-DROP-INVALID"
/ip firewall filter add chain=input in-interface=$WANBR protocol=icmp action=accept comment="SCC-IN-ICMP-WAN"
/ip firewall filter add chain=input in-interface=$WANBR protocol=tcp dst-port=22 src-address=$compJumphost action=accept comment="SCC-IN-SSH-COMP-JUMPHOST"
/ip firewall filter add chain=input in-interface=$WANBR protocol=tcp dst-port=22 src-address=$teamJumphost action=accept comment="SCC-IN-SSH-TEAM-JUMPHOST"
/ip firewall filter add chain=input in-interface=$LANBR protocol=tcp dst-port=22 action=accept comment="SCC-IN-SSH-LAN"
/ip firewall filter add chain=input in-interface=$WANBR action=drop comment="SCC-IN-DROP-WAN"

# FORWARD chain (Traffic passing THROUGH the router)
/ip firewall filter add chain=forward connection-state=established,related action=accept comment="SCC-FWD-EST"
/ip firewall filter add chain=forward connection-state=invalid action=drop comment="SCC-FWD-DROP-INVALID"

# Allow any inbound WAN traffic that matched a dstnat rule
/ip firewall filter add chain=forward in-interface=$WANBR connection-state=new connection-nat-state=dstnat action=accept comment="SCC-FWD-ALLOW-PORTFORWARDS"

# Drop anything from WAN that was not port-forwarded
/ip firewall filter add chain=forward in-interface=$WANBR connection-state=new connection-nat-state=!dstnat action=drop comment="SCC-FWD-DROP-UNFWD-WAN"

# Allow LAN clients to reach competition DNS & scoring infrastructure
/ip firewall filter add chain=forward in-interface=$LANBR dst-address=$compDns protocol=udp dst-port=53 action=accept comment="SCC-FWD-COMP-DNS-UDP"
/ip firewall filter add chain=forward in-interface=$LANBR dst-address=$compDns protocol=tcp dst-port=53 action=accept comment="SCC-FWD-COMP-DNS-TCP"

# Allow LAN clients general internet access (if internet is provided in SCC)
/ip firewall filter add chain=forward in-interface=$LANBR out-interface=$WANBR src-address=$LANNET action=accept comment="SCC-FWD-LAN-INTERNET"

 Reject lateral movement into other teams' subnets inside competition space
/ip firewall filter add chain=forward in-interface=$LANBR connection-state=new dst-address=$compNet action=reject reject-with=icmp-admin-prohibited comment="SCC-FWD-REJECT-COMPNET"

# ---- SSH & Service Hardening ----
/ip ssh set forwarding-enabled=local strong-crypto=yes
/ip service set telnet disabled=yes
/ip service set api disabled=yes
/ip service set api-ssl disabled=yes
/ip service set ftp disabled=yes
/ip service set www disabled=yes
/ip service set winbox address=$LANNET

# ---- Extra Hardening ----
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
/tool bandwidth-server set enabled=no
/ip neighbor discovery-settings set discover-interface-list=none
/ip proxy set enabled=no
/ip socks set enabled=no
/ip upnp set enabled=no
/ip cloud set update-time=no

# ---- Set identity ----
/system identity set name=("SCC-Router-Team" . $TEAM)

:log info ("SCC router base applied — TEAM=" . $TEAM)
