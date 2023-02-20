#!/bin/bash

TARGETS="75.75.75.75 8.8.8.8 75.75.76.76 8.8.4.4"
INTERVAL=60
MAX_LATENCY=1500
PING_COUNT=10
MAX_ERRORS=3
TARGET_THRESHOLD=2
COOL_DOWN=60
RECHECK_PRIMARY=60

let "timeout=$MAX_LATENCY * $PING_COUNT / 1000"

PRIMARY_GATEWAY="192.168.10.1"
SECONDARY_GATEWAY="192.168.11.1"

BEFORE_SWITCH_CMD=""
AFTER_SWITCH_CMD=""

PING=`which ping`
IP=`which ip`
DATE=`which date`
DATE_FORMAT=""
MAILX=`which mailx`
TAIL=`which tail`
MKTEMP=`which mktemp`
TOUCH=`which touch`
CHMOD=`which chmod`

HOSTNAME=`which hostname`
HOST=`$HOSTNAME`

LOG_FILE="/var/log/checkvpn.log"
log_file_mode="640"
LOG_CONSOLE=""
LOG_DEBUG=""
PROGRAM_NAME=`basename $0`
PID=$$
PIDFILE="/var/run/checkvpn.pid"
LOG_ID="$PROGRAM_NAME[$PID]"
#EMAIL="dante.passalacqua@hotmail.com"
LOG_LINES=50

function logger() {
	timestamp=`$DATE +"%b %d %H:%M:%S"`
	LINE="$timestamp $LOG_ID $*" 
	echo $LINE >> $LOG_FILE 2>&1
	if [ ! -f "$LOG_FILE" ] ; then
		$TOUCH $LOG_FILE
		$CHMOD $LOG_FILE_MODE $LOG_FILE
	fi
	if [ ! -z "$LOG_CONSOLE" ] ; then
		echo "$LINE" >&2
	fi
}

function log_info() {
	logger "INFO: $*"
}

function log_warn() {
	logger "WARN: $*"
}

function log_error() {
	logger "ERROR: $*"
	mail_log
}

function log_debug() {
	if [ ! -z "$LOG_DEBUG" ] ; then
		logger "DEBUG: $*"
	fi
}

function mail_log() {
	if [ -z "$EMAIL" ] ; then
		return
	fi
	TEMPLOG=`$MKTEMP`
	$TAIL -$LOG_LINES $LOG_FILE > $TEMPLOG
	$MAILX -s "\"$1 from $HOST\"" $EMAIL < $TEMPLOG
	if [ "$?" != "0" ] ; then 
		log_error "sending mail to '$EMAIL'"
		return
	fi
	log_info "Email sent to '$EMAIL'"
}

function check_targets() {
	let down=0
	ALL_TARGETS="$*"
	log_debug "checking all targets '$ALL_TARGETS'"
	for t in $ALL_TARGETS ; do
		RESULT=`check_target $t`
		if [ "$RESULT" -eq "0" ] ; then
			log_debug "Target: '$t' is UP"
		else
			log_info "Target: '$t' is DOWN"
			let "down=$down + 1"
			if [ "$down" -ge "$TARGET_THRESHOLD" ] ; then
				log_info "Targets down: '$down' reached threshold $TARGET_THRESHOLD. Stoping test"
				break;		
			fi
		fi
	done
	
	echo $down
}

function check_target() {
	TARGET=$1
	log_debug "checking target '$TARGET'"
	if [ -z "$TARGET" ] ; then
		log_error "must specify a target to check"
		echo 3
	else
		log_debug $PING -w $timeout -n -q -c $PING_COUNT $TARGET
		$PING -w $timeout -n -q -c $PING_COUNT $TARGET > /dev/null 2>&1
		echo $?
	fi
}

function add_gateway() {
	NEW_GATEWAY=$1
	if [ -z "$NEW_GATEWAY" ] ; then
		log_error "must indicate a gateway to add"
		return 1
	else
		log_debug "$IP route add default via $NEW_GATEWAY"
		result=`$IP route add default via $NEW_GATEWAY`
		if [ "$?" != "0" ] ; then
			log_error "adding gateway '$NEW_GATEWAY' '$result'"
			return 2
		fi
		log_info "added gateway '$NEW_GATEWAY'"
	fi
	
	return 0
}

function replace_gateway() {
	NEW_GATEWAY=$1
	if [ -z "$NEW_GATEWAY" ] ; then
		log_error "must indicate the hew gateway to set"
		return 1
	else
		log_debug "$IP route replace default via $NEW_GATEWAY"
		result=`$IP route replace default via $NEW_GATEWAY`
		if [ "$?" != "0" ] ; then
			log_error "replacing gateway with '$NEW_GATEWAY' '$result'"
			return 0
		else
			log_info "replaced gateway with '$NEW_GATEWAY'"
		fi
	fi
	
	return 0
}

function find_current_gateway() {
	 log_debug "$IP route | grep -i default | cut -f3 -d' '"
	result=`$IP route | grep -i default | cut -f3 -d' '`
	if [ "$?" != "0" ] ; then 
		log_error "Determining current gateway '$result'"
		echo ""
	else
		echo $result
	fi
}

function delete_gateway() {
	GATEWAY=$1
	if [ -z "$GATEWAY" ] ; then
		log_error "must specify gateway to delete"
		return 1
	else
		log_debug "$IP route delete default via $GATEWAY"
		$IP route delete default via $GATEWAY
		if [ "$?" != "0" ] ; then 
			log_error "deleting gateway '$GATEWAY'"
			return 2
		else
			log_info "deleted gateway '$GATEWAY'"
			return 0
		fi
	fi
}

function execute_cmd() {
	CMD="$*"
	if [ -z "$CMD" ] ; then
		return 0
	fi
	
	log_debug "attempting to execute  cmd  '$CMD'"
	result=`$CMD`
	if [ "$?" != "0" ] ; then 
		log_error "executing $WHEN switch cmd  '$CMD' '$result'"
		return 1
	else
		log_debug "execute $WHEN switch cmd  '$CMD'"
		return 0
	fi
}

function check_gateway() {
	GATEWAY=$1
	if [ -z "$GATEWAY" ] ; then
		log_error "must specify gateway to check"
		return 1
	fi
	
	CURRENT_GATEWAY=`find_current_gateway`
	if [ "$CURRENT_GATEWAY" == $GATEWAY ] ; then
		log_debug "skipping check of current gateway"
		return 2
	fi
	
	log_info "checking gateway '$GATEWAY'"
	
	replace_gateway $GATEWAY
	down=`check_targets $TARGETS`
	if [ "$down" -lt "$TARGET_THRESHOLD" ] ; then
		let result=0
	else
		let result=3
	fi
	
	replace_gateway $CURRENT_GATEWAY
	
	return $result
}

function restore_gateway() {
	GATEWAY=$1
	if [ -z "$GATEWAY" ] ; then
		log_error "must specify gateway to restore"
		return 1
	fi
	
	CURRENT_GATEWAY=`find_current_gateway`
	if [ "$CURRENT_GATEWAY" == $GATEWAY ] ; then
		log_debug "skipping restore of gateway $GATEWAY because is current"
		return 2
	fi
	
	let currentTime=`$DATE +%s`
	let "elapsed=$currentTime - $startTime"
	if [ "$elapsed" -lt $RECHECK_PRIMARY ] ; then
		log_debug "skipping restore of gateway elapsed time $elapsed secs, minimum $RECHECK_PRIMARY secs"
		return 3
	fi
	
	check_gateway $GATEWAY
	if [ "$?" != "0" ] ; then 
		log_info "gateway $GATEWAY is DOWN"
		return 4
	else
		log_info "gateway $GATEWAY is UP"
		log_info "restoring gateway $GATEWAY"
		replace_gateway $GATEWAY
		let startTime=0
		return 0
	fi
}

function switch_gateway() {
	CURRENT_GATEWAY=`find_current_gateway`
	if [ "$CURRENT_GATEWAY" == "$PRIMARY_GATEWAY" ] ; then
		replace_gateway $SECONDARY_GATEWAY
	fi
	if [ "$CURRENT_GATEWAY" == "$SECONDARY_GATEWAY" ] ; then
		replace_gateway $PRIMARY_GATEWAY
	fi
}

function restart_vpn() {
	service openvpn restart
}


echo "$PID" > $PIDFILE
let errors=0
let startTime=0
while [ 0 ] ; do
	let targetsDown=0
	targetsDown=`check_targets $TARGETS`
	log_debug "Targets down: $targetsDown of max allowed: $TARGET_THRESHOLD"
	if [ "$targetsDown" -ge "$TARGET_THRESHOLD" ] ; then
		let "errors=$errors + 1"
		log_debug "$errors error(s) found of max allowed: $MAX_ERRORS"
	fi
	
	if [ "$errors" -ge "$MAX_ERRORS" ] ; then
		execute_cmd $BEFORE_SWITCH_CMD
		restart_vpn
		execute_cmd $AFTER_SWITCH_CMD
		mail_log "Restarting VPN"
		log_debug "Cooling down $COOL_DOWN seconds"
		sleep $COOL_DOWN
		let errors=0
		let startTime=`$DATE +%s`
	else
		log_debug "Waiting for $INTERVAL seconds"
		sleep $INTERVAL
	fi
done

exit 0
