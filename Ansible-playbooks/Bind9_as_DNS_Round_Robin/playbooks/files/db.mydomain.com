$ORIGIN .
$TTL 86400      ; 1 day
mydomain.com     IN SOA dns.mydomain.com. postmaster.mydomain.com. (
                                1          ; serial
                                21600      ; refresh (6 hours)
                                3600       ; retry (1 hour)
                                604800     ; expire (1 week)
                                21600      ; minimum (6 hours)
                                )
                        NS      dns.mydomain.com.
$ORIGIN mydomain.com.
node1		A	192.168.10.51
node2		A	192.168.10.52
dns		A	192.168.10.50
www		A	192.168.10.51
www		A	192.168.10.52