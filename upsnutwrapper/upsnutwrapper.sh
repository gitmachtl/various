#!/usr/bin/env bash

# Script: 	upsnutwrapper.sh
# Author:	Martin (Machtl) Lang
# E-Mail:	martin@martinlang.at
# Version:	1.4 (10.12.2022)
#
# History:
#
#			1.0:	First working version "yeah"
#			1.1:	Changed the "apcaccess" call and added the option "-u"
#			1.2:	Added many parameters, First "release" version (15.02.2019)
#			1.3:	Pushed onto the github repo, little typo corrections (06.01.2022)
#			1.4:	Added logging and QNAP support, cleaned up code
#
# Description:
#
#	This little non-optimized script emulates a NUT-Server together with the tinytool "tcpserver"
#	from the ucspi-tcp package. It needs an installed and working apcupsd running on the machine
#	or on a remote machine. It is working fine with Synology NAS for example (my usecase).
#	The script is simple and small and solves some problems having apcupsd and a NUT-Server on the
#	same machine. Use it if you like, but don't scream at me if it's doing something wrong.
#	Please feel free to make this script better, but send me a copy (email above) if you're done. :-)
#
#
# Install / Running:
#
#	1.) You need an installed and running apcupsd on the same machine or on a remote machine. You also need
#		apcaccess on this machine. Should be all fine if you installed apcupsd like "apt-get install apcupsd".
#		If you're not sure, please run the command "apcaccess" in the shell and see if you get your ups data.
#		Or run "apcaccess -h remoteip" to get the data of apcupsd running on a remotemachine with ip 'remoteip'.
#
#	2.) Copy this script into /usr/local/bin/ and make it executable. You can simply run these commands to copy
# 		the script to the right location:
#
#		wget https://github.com/gitmachtl/various/raw/main/upsnutwrapper/upsnutwrapper.sh -O /usr/local/bin/upsnutwrapper.sh
#		chmod +x /usr/local/bin/upsnutwrapper.sh
#
#	3.) Install the ucspi-tcp package via "apt-get install ucspi-tcp"
#
#	4.) Start the NUT-Server-Wrapper by executing the following command via shell or a script:
#		tcpserver -q -c 10 -HR 0.0.0.0 3493 /usr/local/bin/upsnutwrapper.sh &
#
#	This starts a listening tcp server on port 3493 (nut) with no binding (0.0.0.0), max. 10 simultanious connections.
#	Enjoy your apcupsd and "nut server" side by side on the same machine :-)
#
#

# Here you can set the apcupsd server address

APCUPSDSERVER="localhost"		#apcupsd is running on the same machine
#APCUPSDSERVER="127.0.0.1"		#apcupsd is running on the same machine
#APCUPSDSERVER="remoteip:3551"		#apcupsd is running on a remote machine with ip "remoteip" on the port "3551"

LOGGING=false				#set to 'true' to see incoming commands
LOG_FILE=/tmp/upsnutwrapper.log		#the location where logs are written to


#
# ------------------------------------------------------------------------------------------------------------------------
#
#

#define default values
setdefaultvalues() {
UPS_MFR="UPS NUT Apcupsd Wrapper"
UPS_UPSNAME="NO NAME"
UPS_MODEL="NO MODEL"
UPS_BCHARGE="0"
UPS_TIMELEFT="0"
UPS_BATTV="0"
UPS_NOMBATTV="0"
UPS_SERIALNO=""
UPS_BATTDATE=""
UPS_MANDATE=""
UPS_FIRMWARE=""
UPS_LOADPCT="0"
UPS_LINEV="0"
UPS_OUTPUTV="0"
UPS_NOMOUTV="0"
UPS_MBATTCHG="10"
UPS_DLOWBATT="10"
UPS_SENSE=""
UPS_APC=""
UPS_VERSION=""
UPS_DRIVER=""
UPS_ITEMP=""
UPS_HITRANS=""
UPS_LOTRANS=""
UPS_LINEFREQ=""
UPS_NOMINV="230"
UPS_SELFTEST=""
UPS_DSHUTD="0"
UPS_NOMPOWER=$NOMPOWER
UPS_LASTXFER=""
}

getfulldata() {

setdefaultvalues				#load default values

APCACCESS="$(apcaccess -h $APCUPSDSERVER -u | sort)"	#get data from acpaccess, sort it so for example BCHARGE will be processed before STATUS

IFS_BAK=$IFS					# change delimiter (IFS) to new line.
IFS=$'\n'

for LINE in $APCACCESS; do

 PARAM=${LINE:0:9}						#first 9 chars as parameter
 PARAM="$(echo -e "${PARAM}" | sed -e 's/[[:space:]]*$//')"  	#delete trailing spaces

 VALUE=${LINE:11}   						#chars starting at 11 as value
 VALUE="$(echo -e "${VALUE}" | sed -e 's/[[:space:]]*$//')" 	#delete trailing spaces

 case "$PARAM" in

	BCHARGE) 	UPS_BCHARGE=$VALUE; #battery charge in [%]
			if [[ "${VALUE%%.*}" == "100" ]]; then BATTNOTFULL=0; else BATTNOTFULL=1; fi
			;;

	STATUS)
			UPS_STATUS=""
			case "${VALUE}" in
				*"ONLINE"*) 		UPS_STATUS+="OL "
							if [ $BATTNOTFULL = 1 ]; then UPS_STATUS+="CHRG "; fi #if battery is not at 100%, add charging flag
							;;&
				*"ONBATT"*)		UPS_STATUS+="OB DISCHRG " ;;& #onbattery with discharge flag
				*"LOWBATT"*)		UPS_STATUS+="LB " ;;&
				*"CAL"*)		UPS_STATUS+="CAL " ;;&
				*"OVERLOAD"*)		UPS_STATUS+="OVER " ;;&
				*"TRIM"*)		UPS_STATUS+="TRIM " ;;&
				*"BOOST"*)		UPS_STATUS+="BOOST " ;;&
				*"REPLACEBATT"*)	UPS_STATUS+="RB " ;;&
				*"SHUTTING DOWN"*)	UPS_STATUS+="SD " ;;&
				*"COMMLOST"*)		UPS_STATUS+="OFF " ;;
			esac
			UPS_STATUS="$(echo -e "${UPS_STATUS}" | sed -e 's/[[:space:]]*$//')"
			;;

	UPSNAME) 	UPS_UPSNAME=$VALUE;;

	MODEL) 		UPS_MODEL=$VALUE
			case "${VALUE}" in
				*"Back-UPS XS 700U"*)	NOMPOWER="390";;
				*"SMART-UPS 700"*)	NOMPOWER="450";;
				*"Smart-UPS C 1500"*)	NOMPOWER="900";;
			esac
			UPS_NOMPOWER=$NOMPOWER;
			;;

	SELFTEST)
			case "${VALUE}" in
				*"OK"*) UPS_SELFTEST="OK - Battery GOOD";;
				*"BT"*) UPS_SELFTEST="FAILED - Battery Capacity LOW";;
				*"NG"*) UPS_SELFTEST="FAILED - Overload";;
				*"NO"*) UPS_SELFTEST="No Test in the last 5mins";;
			esac
			;;

	TIMELEFT)	let UPS_TIMELEFT=${VALUE%%.*}*60;;	#only use string before ".", multiply with 60 for value in seconds
	BATTV) 		UPS_BATTV=$VALUE;;  			#battery voltage [V]
	NOMBATTV) 	UPS_NOMBATTV=$VALUE;;  			#battery voltage nominal [V]
	SERIALNO)	UPS_SERIALNO=$VALUE;;			#serialnumber of the ups
	BATTDATE)	UPS_BATTDATE=$VALUE;;			#battery date
	MANDATE)	UPS_MANDATE=$VALUE;;			#mfr date
	FIRMWARE)	UPS_FIRMWARE=$VALUE;;			#firmwareversion
	LOADPCT)	UPS_LOADPCT=$VALUE;;			#current load [%]
	LINEV)		UPS_LINEV=$VALUE;;			#input voltage [V]
	NOMINV)		UPS_NOMINV=$VALUE;;			#input voltage nominal [V]
	OUTPUTV)	UPS_OUTPUTV=$VALUE;;			#output voltage [V]
	NOMOUTV)	UPS_NOMOUTV=$VALUE;;			#output voltage nominal [V]
	MBATTCHG)	UPS_MBATTCHG=$VALUE;;			#minimum battery charge [%]
	SENSE)		UPS_SENSE=$VALUE;;			#input sensitivity
	DLOWBATT)	let UPS_DLOWBATT=${VALUE%%.*}*60;;	#low battery runtime [min] * 60 for seconds
	APC)		UPS_APC=$VALUE;;			#internal apc id
	VERSION)	UPS_VERSION=$VALUE;;			#driver version
	DRIVER)		UPS_DRIVER=$VALUE;;			#driver name
	ITEMP)		UPS_ITEMP=$VALUE;;			#internal temperature [°C]
	HITRANS)	UPS_HITRANS=$VALUE;;			#input high-voltage transition to battery [V]
	LOTRANS)	UPS_LOTRANS=$VALUE;;			#input low-voltage transition to battery [V]
	LINEFREQ)	UPS_LINEFREQ=$VALUE;;			#input line frequency
	NOMPOWER)	UPS_NOMPOWER=$VALUE;;			#output power nominal [W]
	DSHUTD)		UPS_DSHUTD=$VALUE;;			#delay ups shutdown time [s]
	LASTXFER)	UPS_LASTXFER=$VALUE;;			#reason for the last battery transfer

 esac

done  #for

#substitute battery date and ups mfr date with each other if the other does not exist
if [ "$UPS_BATTDATE" = "" ]; then UPS_BATTDATE=$UPS_MANDATE; fi
if [ "$UPS_MANDATE" = "" ]; then UPS_MANDATE=$UPS_BATTDATE; fi

#if there is a value for the nominal output power, include it into the ups model name
if ! [ "$UPS_NOMPOWER" = "-1" ]; then UPS_MODEL="$UPS_MODEL ($UPS_NOMPOWER W)"; fi

IFS=$IFS_BAK
}

getstatusdata() {
APCACCESS="$(apcaccess -h $APCUPSDSERVER -p STATUS)"
VALUE="${APCACCESS%%[[:cntrl:]]}"
UPS_STATUS=""
case "${VALUE}" in
	*"ONLINE"*) 		UPS_STATUS+="OL "
				if [ $BATTNOTFULL = 1 ]; then UPS_STATUS+="CHRG "; fi
				;;&
	*"ONBATT"*)		UPS_STATUS+="OB DISCHRG " ;;&
	*"LOWBATT"*)		UPS_STATUS+="LB " ;;&
	*"CAL"*)		UPS_STATUS+="CAL " ;;&
	*"OVERLOAD"*)		UPS_STATUS+="OVER " ;;&
	*"TRIM"*)		UPS_STATUS+="TRIM " ;;&
	*"BOOST"*)		UPS_STATUS+="BOOST " ;;&
	*"REPLACEBATT"*)	UPS_STATUS+="RB " ;;&
	*"SHUTTING DOWN"*)	UPS_STATUS+="SD " ;;&
	*"COMMLOST"*)		UPS_STATUS+="OFF " ;;
esac
UPS_STATUS="$(echo -e "${UPS_STATUS}" | sed -e 's/[[:space:]]*$//')"
}

gettestresult() {
APCACCESS="$(apcaccess -h $APCUPSDSERVER -p SELFTEST)"
VALUE="${APCACCESS%%[[:cntrl:]]}"
case "${VALUE}" in
	*"OK"*) UPS_SELFTEST="OK - Battery GOOD";;
	*"BT"*) UPS_SELFTEST="FAILED - Battery Capacity LOW";;
	*"NG"*) UPS_SELFTEST="FAILED - Overload";;
	*"NO"*) UPS_SELFTEST="No Test in the last 5mins";;
esac
}

log() {
if [ "$LOGGING" = true ] ; then
	echo -e "$(date)\t${TCPREMOTEIP}   \t${1}" >> "$LOG_FILE"
fi
}

# MAIN
#
#

#some vars
BATTNOTFULL=0	#we start the script thinking of a full battery
NOMPOWER="-1"	#no nominal power value present

setdefaultvalues	#load default values

while : ; do

read -sr INSTRING

COMMAND="${INSTRING%%[[:cntrl:]]}"
log "$COMMAND"

case "${COMMAND}" in

	"LOGIN"*|"USERNAME"*|"PASSWORD"* ) # login, accepting all usernames and passwords
			log ">>> ${COMMAND} OK"
			echo "OK"
			;;

	"LOGOUT" ) #logout -> exit the while and exit the script
			log ">>> Logout, exiting script"
			break
			;;

	"STARTTLS" ) #this is not supported by the script, send an error so the NUT-Client requests continues without TLS
			log ">>> TLS requested, but not supported. Sending an ERR message"
			echo "ERR FEATURE-NOT-SUPPORTED"
			;;

	"LIST UPS" ) #return a list of all UPSs to the client, in our case return the names "ups" for synology and "qnapups" for qnap
			log ">>> Serving all the names of the UPSs"
			echo -en "BEGIN LIST UPS\nUPS ups \"$UPS_MFR\"\nUPS qnapups \"$UPS_MFR\"\nEND LIST UPS\n"
			;;

	*) #continue with specific commands

		if [[ "${COMMAND}" =~ "GET VAR "(.*)" "(.*)"" ]]; then #requesting a specific value

			UPSNAME=${BASH_REMATCH[1]}
			VAR=${BASH_REMATCH[2]}

			log ">>> Requested VAR=${VAR} for UPSNAME=${UPSNAME}"

			case "${VAR}" in

				"ups.status")
					getstatusdata #get only the status parameter from the ups
					echo -en "VAR $UPSNAME ups.status \"$UPS_STATUS\"\n"
					;;

				"ups.test.result")
					gettestresult #get only test result data
					echo -en "VAR $UPSNAME ups.test.result \"$UPS_SELFTEST\"\n"
					;;

				*)
					log ">>> failed to process variable ${VAR}"
					;;
			esac

		elif [[ "${COMMAND}" =~ "LIST VAR "(.*)"" ]]; then #requesting all values

			UPSNAME=${BASH_REMATCH[1]}

			log ">>> Requested all VARs for UPSNAME=${UPSNAME}"

			getfulldata #get all values from apcaccess
			echo -en "BEGIN LIST VAR $UPSNAME\n"

			echo -en "VAR $UPSNAME device.mfr \"$UPS_MFR\"\n"
			echo -en "VAR $UPSNAME device.model \"$UPS_MODEL\"\n"
			echo -en "VAR $UPSNAME device.serial \"$UPS_SERIALNO\"\n"
			echo -en "VAR $UPSNAME device.type \"ups\"\n"

			echo -en "VAR $UPSNAME ups.mfr \"$UPS_MFR\"\n"
			echo -en "VAR $UPSNAME ups.mfr.date \"$UPS_MANDATE\"\n"
			echo -en "VAR $UPSNAME ups.id \"APC\"\n"
			echo -en "VAR $UPSNAME ups.vendorid \"051d\"\n"
			echo -en "VAR $UPSNAME ups.model \"$UPS_MODEL\"\n"
			echo -en "VAR $UPSNAME ups.status \"$UPS_STATUS\"\n"
			echo -en "VAR $UPSNAME ups.load \"$UPS_LOADPCT\"\n"
			echo -en "VAR $UPSNAME ups.serial \"$UPS_SERIALNO\"\n"
			echo -en "VAR $UPSNAME ups.firmware \"$UPS_FIRMWARE\"\n"
			echo -en "VAR $UPSNAME ups.firmware.aux \"$UPS_FIRMWARE\"\n"
			echo -en "VAR $UPSNAME ups.productid \"$UPS_APC\"\n"
			echo -en "VAR $UPSNAME ups.temperature \"$UPS_ITEMP\"\n"
			echo -en "VAR $UPSNAME ups.realpower.nominal \"$UPS_NOMPOWER\"\n"
			echo -en "VAR $UPSNAME ups.test.result \"$UPS_SELFTEST\"\n"
			echo -en "VAR $UPSNAME ups.delay.start \"0\"\n"
			echo -en "VAR $UPSNAME ups.delay.shutdown \"$UPS_DSHUTD\"\n"
			echo -en "VAR $UPSNAME ups.timer.reboot \"-1\"\n"
			echo -en "VAR $UPSNAME ups.timer.start \"-1\"\n"
			echo -en "VAR $UPSNAME ups.timer.shutdown \"-1\"\n"

			echo -en "VAR $UPSNAME battery.runtime \"$UPS_TIMELEFT\"\n"
			echo -en "VAR $UPSNAME battery.runtime.low \"$UPS_DLOWBATT\"\n"
			echo -en "VAR $UPSNAME battery.charge \"$UPS_BCHARGE\"\n"
			echo -en "VAR $UPSNAME battery.charge.low \"$UPS_MBATTCHG\"\n"
			echo -en "VAR $UPSNAME battery.charge.warning \"50\"\n"
			echo -en "VAR $UPSNAME battery.voltage \"$UPS_BATTV\"\n"
			echo -en "VAR $UPSNAME battery.voltage.nominal \"$UPS_NOMBATTV\"\n"
			echo -en "VAR $UPSNAME battery.date \"$UPS_BATTDATE\"\n"
			echo -en "VAR $UPSNAME battery.mfr.date \"$UPS_BATTDATE\"\n"
			echo -en "VAR $UPSNAME battery.temperature \"$UPS_ITEMP\"\n"
			echo -en "VAR $UPSNAME battery.type \"PbAc\"\n"

			echo -en "VAR $UPSNAME driver.name \"usbhid-ups\"\n"
			echo -en "VAR $UPSNAME driver.version.internal \"apcupsd $UPS_VERSION\"\n"
			echo -en "VAR $UPSNAME driver.version.data \"$UPS_DRIVER\"\n"
			echo -en "VAR $UPSNAME driver.parameter.pollfreq \"60\"\n"
			echo -en "VAR $UPSNAME driver.parameter.pollinterval \"10\"\n"

			echo -en "VAR $UPSNAME input.voltage \"$UPS_LINEV\"\n"
			echo -en "VAR $UPSNAME input.voltage.nominal \"$UPS_NOMINV\"\n"
			echo -en "VAR $UPSNAME input.sensitivity \"$UPS_SENSE\"\n"
			echo -en "VAR $UPSNAME input.transfer.high \"$UPS_HITRANS\"\n"
			echo -en "VAR $UPSNAME input.transfer.low \"$UPS_LOTRANS\"\n"
			echo -en "VAR $UPSNAME input.frequency \"$UPS_LINEFREQ\"\n"
			echo -en "VAR $UPSNAME input.frequency.nominal \"50\"\n"
			echo -en "VAR $UPSNAME input.transfer.reason \"$UPS_LASTXFER\"\n"

			echo -en "VAR $UPSNAME output.voltage \"$UPS_OUTPUTV\"\n"
			echo -en "VAR $UPSNAME output.voltage.nominal \"$UPS_NOMOUTV\"\n"

			echo -en "VAR $UPSNAME server.info \"$HOSTNAME\"\n"

			echo -en "VAR $UPSNAME ups.beeper.status \"enabled\"\n"

			echo -en "END LIST VAR $UPSNAME\n"
		else
			log "failed to process command"
			echo -en "ERR UNKNOWN-COMMAND\n"
		fi
		;;
esac # "${COMMAND}"


done
