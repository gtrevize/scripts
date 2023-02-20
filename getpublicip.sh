echo -n "using HTTP: "
curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//' 

echo -n "using DNS: "
host myip.opendns.com resolver1.opendns.com | grep "address" | cut -f4 -d' '


