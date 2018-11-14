#! /bin/bash

origin='https://idp0.hiz-saarland.de/'
url="$origin/passwd/"
agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36"
agent="Mozilla/5.0 CHANGE YOUR PASSWORD POLICY! YOU [EXPLITIVE] [EXPLETIVE]!!!"
referer="$url"
log="/dev/shm/$USER-$0.log"
debug=0
rotations=15
num_random=6
mode=passwd
base="Az0!"

opts="hr:l:u:n:dq"
longopts="help,rotations,log,user,num-random,debug,quiet"

function usage() {
	echo -e "usage:
	$(basename $0) [options] [long-options] mode

		Options:
			-h|--help       Help message
			-r|--rotations  Number of rotations (Current: $rotations).
			-u|--user       Username to use (Current: $user).
			-l|--log        Logfile to use (Current: $log).
			-n|--num-random Number of random bytes to sample (Current: $num_random).
			-d|--debug      Increase verbosity (Currently: $debug).
			-q|--quiet      Decrease verbosity (Currently: $debug).
		
		Modes:
			passwd  Change password
			rotate  Starting and ending from the current password, change it many times so that the history is forgotten.
		Current mode: $mode.
	"
}

ARGS=`getopt -n "$0" -l $longopts -o $opts -- "$@"`
if (( err=$? )); then echo -e $usage ; exit $err ; fi
eval set -- $ARGS

while true; do
        case "$1" in
        -l|--log) log="$2";shift 2;;
        -u|--user) user="$2";shift 2;;
        -d|--debug) debug=$((debug+1));shift;;
        -q|--quiet) debug=$((debug-1));shift;;
        -r|--rotations) rotations="$2";shift 2;;
        -h|--help) usage;exit 0;;
        --) shift;break;;
        *) echo "INTERNAL OPTION ERROR: $1";exit 1 ;;
        esac
done

if (( $# )) ; then mode="$1"; shift; fi

function make_random_password() {
	local random=$(head -c $((num_random+2)) /dev/urandom | base64 | head -c $num_random)
	echo "$base$random"
}

function debug() {
	local level=$1
	shift
	local txt=$( printf "$@" )
	if (( $debug>=$level )); then 
		echo "$txt" >&2;
	fi
	echo "$txt" >>"$log"
}


function do_curl() {
	local curl
	if (( $debug )); then
		local args=$(printf "'%s' " "$@")
		debug 2 "Running curl: %s" "$args";
	fi
	curl "$@" 
}

function get_response() {
	local oldpassword="$1"
	local newpassword="$2"
	local confirmpassword
	if (( $# > 2 )); then
		confirmpassword="$3" ;
	else
		confirmpassword="$newpassword"
	fi
	do_curl "$url" --silent \
		-H 'Cache-Control: max-age=0' \
		-H "Origin: $origin" -H 'Upgrade-Insecure-Requests: 1' \
		-H 'Content-Type: application/x-www-form-urlencoded' \
		-H 'User-Agent: $agent' \
		-H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
		-H 'Referer: $referer' \
		-H 'Accept-Encoding: gzip, deflate, br' \
		-H 'Accept-Language: en-US,en;q=0.9' \
		--data-urlencode "login=$user" \
		--data-urlencode "oldpassword=$oldpassword" \
		--data-urlencode "newpassword=$newpassword" \
		--data-urlencode "confirmpassword=$confirmpassword"
	debug 1 "[%s] Change password for user:%s '%s'->'%s'... " "$(date -Ins)" "$user" "$oldpassword" "$newpassword"
}


function parse_response() {
	local response=$( get_response "$@" )
	echo "$response" > /tmp/last
	warning_txt=$( echo "$response" | sed -e 's/</\n</g;s/>/>\n/g' | sed -e 's/^\s\+//;/^$/d' | grep -v '^$' | grep -A 8 '<div class="result alert alert-\([^"]\+\)">' )
	errored=$?
	warning=$( echo "$warning_txt" | grep -v '^<' )
	# echo "*==$warning_txt===$warning==*" >> /tmp/warn
	if [ "$errored" -eq 1 ]; then result=Success ; else result="Error: $warning" ; fi
	debug 1 "Result: %s" "$result"
}


function passwd () {
	read -sp "Old Password: " oldpasswd; echo
	read -sp "New Password: " newpasswd; echo
	read -sp "Confirm Password: " confirmpasswd; echo
	parse_response "$oldpasswd" "$newpasswd" "$confirmpasswd"
	echo 
}

function rotate() {
	read -sp "Old Password: " oldpasswd; echo
	passwd_from="$oldpasswd"
	for ((i=1;i<$rotations;i++)); do 
		debug 1 "Rotation %d/%d" $i $rotations
		random_pass=$(make_random_password)
		newpasswd="$random_pass"
		parse_response "$passwd_from" "$newpasswd"
		passwd_from="$newpasswd"
	done
	debug 1 "Rotation %d/%d" $i $rotations
	parse_response "$passwd_from" "$oldpasswd"
}

case "$mode" in 
	passwd) passwd; exit;;
	rotate) rotate; exit;;
	*) echo "Unknown mode."; usage; exit 1 ;;
esac


response=$( get_response )
echo $response >&2
warning_txt=$( echo "$response" | sed -e 's/</\n</g;s/>/>\n/g' | sed -e 's/^\s\+//;/^$/d' | grep -v '^$' | grep -A 8 '<div class="result alert alert-warning">' )
errored=$?
warning=$( echo "$warning_txt" | grep -v '^<' )

echo "$errored===$warning_txt===$warning"



