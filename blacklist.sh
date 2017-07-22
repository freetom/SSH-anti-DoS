## Script that put in black list all the IP addresses that have failed to log in remotely
##
## This script requires root to manage the kernel's IP tables

sudo ipset -v >/dev/null 2>&1 || { echo "This script requires ipset but it's not installed. Aborting." >&2; exit 1; }

if [ -f "tmp" -o -f "tmpp" ]
	then echo "This script requires that there are no files names 'tmp' and 'tmpp' in the current folder"
	exit 1
fi

#remote shell?
client_ip=$(who am i|awk '{ print $5}' | tr -d '()')
if [[ -z "$client_ip" ]]
	then echo "Local session"
else
	echo "Remote session, ignoring IP address $client_ip"
fi

#extract all IP addresses that failed to log in remotely
cat auth.log* | grep "authentication failure" | awk 'NF>1{print $NF}' | grep "rhost" | cut -d '=' -f2 | sort -u > tmp

#evict the current SSH client IP
if [[ "$client_ip" ]]
	then cat tmp | grep -v "$client_ip" > tmpp
	mv tmpp tmp
fi


#setup ip tables
if [ $(sudo ipset list blacklist | grep -q 'not exist') ]
	then sudo ipset create blacklist hash:ip hashsize 4096
fi

sudo iptables -I INPUT -m set --match-set blacklist src -j DROP
sudo iptables -I FORWARD -m set --match-set blacklist src -j DROP
##

#black list them all
cat tmp | while read x; do ip=$(echo $x | cut -d ' ' -f1); if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then ipset add blacklist $ip; fi; done;
rm tmp
echo ""
echo "A total of $(sudo ipset list blacklist | wc -l) IP addresses are now in blacklist"
echo ""
