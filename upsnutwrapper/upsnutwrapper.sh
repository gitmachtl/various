#!/usr/bin/env bash

# Script: 	upsnutwrapper.sh
# Author:	Martin (Machtl) Lang
# E-Mail:	martin@martinlang.at
# Version:	1.2 (15.02.2019)
#
# History:
#
#			1.0:	First working version "yeah"
#			1.1:	Changed the "apcaccess" call and added the option "-u"
#			1.2:	Added many parameters
#
# Description:
#
#	This little quiet non-optimized script emulates a NUT-Server together with "tcpserver"
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
#		wget https://machtl.com/linux/nutwrapper/upsnutwrapper.sh -O /usr/local/bin/upsnutwrapper.sh
#		chmod +x /usr/local/bin/nutwrapper.sh"
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

#
# ------------------------------------------------------------------------------------------------------------------------
#
#

#Standardwerte definieren
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

setdefaultvalues									#load default values

APCACCESS="$(apcaccess -h $APCUPSDSERVER -u)"		#get data from acpaccess

IFS_BAK=$IFS										# change delimiter (IFS) to new line.
IFS=$'\n'

for LINE in $APCACCESS; do

 PARAM=${LINE:0:9}	#first 9 chars as parameter
 PARAM="$(echo -e "${PARAM}" | sed -e 's/[[:space:]]*$//')"  #delete trailing spaces

 VALUE=${LINE:11}   #chars starting at 11 as value
 VALUE="$(echo -e "${VALUE}" | sed -e 's/[[:space:]]*$//')" #delete trailing spaces

 case "$PARAM" in

	STATUS)			if [[ $VALUE == *"ONLINE"* ]]; then
								UPS_STATUS="OL $UPS_STATUS";
								if [ $BATTNOTFULL = 1 ]; then UPS_STATUS="CHRG $UPS_STATUS"; fi	#if battery is not at 100%, add charging flag
			        fi
				if [[ $VALUE == *"ONBATT"* ]]; then UPS_STATUS="OB DISCHRG $UPS_STATUS"; fi #onbattery with discharge flag
				if [[ $VALUE == *"LOWBATT"* ]]; then UPS_STATUS="LB $UPS_STATUS"; fi
				if [[ $VALUE == *"CAL"* ]]; then UPS_STATUS="CAL $UPS_STATUS"; fi
				if [[ $VALUE == *"OVERLOAD"* ]]; then UPS_STATUS="OVER $UPS_STATUS"; fi
				if [[ $VALUE == *"TRIM"* ]]; then UPS_STATUS="TRIM $UPS_STATUS"; fi
				if [[ $VALUE == *"BOOST"* ]]; then UPS_STATUS="BOOST $UPS_STATUS"; fi
				if [[ $VALUE == *"REPLACEBATT"* ]]; then UPS_STATUS="RB $UPS_STATUS"; fi
				if [[ $VALUE == *"SHUTTING DOWN"* ]]; then UPS_STATUS="SD $UPS_STATUS"; fi
				if [[ $VALUE == *"COMMLOST"* ]]; then UPS_STATUS="OFF $UPS_STATUS"; fi
				UPS_STATUS="$(echo -e "${UPS_STATUS}" | sed -e 's/[[:space:]]*$//')"
				;;

	UPSNAME) 	UPS_UPSNAME=$VALUE;;
	MODEL) 		UPS_MODEL=$VALUE
				if [[ $VALUE == *"Back-UPS XS 700U"* ]]; then NOMPOWER="390";
				elif [[ $VALUE == *"SMART-UPS 700"* ]]; then NOMPOWER="450";
				elif [[ $VALUE == *"Smart-UPS C 1500"* ]]; then NOMPOWER="900";
				fi
				UPS_NOMPOWER=$NOMPOWER;
				;;
	BCHARGE) 	UPS_BCHARGE=$VALUE;				#battery charge in [%]
				if [ "$(echo -e "${VALUE}" | cut -d'.' -f1)" = "100" ]; then BATTNOTFULL=0; else BATTNOTFULL=1; fi
				;;

	SELFTEST)	if [[ $VALUE == *"OK"* ]]; then UPS_SELFTEST="OK - Battery GOOD";
				elif [[ $VALUE == *"BT"* ]]; then UPS_SELFTEST="FAILED - Battery Capacity LOW";
				elif [[ $VALUE == *"NG"* ]]; then UPS_SELFTEST="FAILED - Overload";
				elif [[ $VALUE == *"NO"* ]]; then UPS_SELFTEST="No Test in the last 5mins";
				fi;;

	TIMELEFT)	let UPS_TIMELEFT="$(echo -e "${VALUE}" | cut -d'.' -f1)"*60;;	#only use string before ".", multiply with 60 for value in seconds
	BATTV) 		UPS_BATTV=$VALUE;;  			#battery voltage [V]
	NOMBATTV) 	UPS_NOMBATTV=$VALUE;;  			#battery voltage nominal [V]
	SERIALNO)	UPS_SERIALNO=$VALUE;;			#serialnumber of the ups
	BATTDATE)	UPS_BATTDATE=$VALUE;;			#battery date
	MANDATE)	UPS_MANDATE=$VALUE;;			#mfr date
	FIRMWARE)	UPS_FIRMWARE=$VALUE;;			#firmwareversion
	LOADPCT)	UPS_LOADPCT=$VALUE;;			#current load [%]
	LINEV)		UPS_LINEV=$VALUE;;				#input voltage [V]
	NOMINV)		UPS_NOMINV=$VALUE;;				#input voltage nominal [V]
	OUTPUTV)	UPS_OUTPUTV=$VALUE;;			#output voltage [V]
	NOMOUTV)	UPS_NOMOUTV=$VALUE;;			#output voltage nominal [V]
	MBATTCHG)	UPS_MBATTCHG=$VALUE;;			#minimum battery charge [%]
	SENSE)		UPS_SENSE=$VALUE;;				#input sensitivity
	DLOWBATT)	let UPS_DLOWBATT="$(echo -e "${VALUE}" | cut -d'.' -f1)"*60;;	#low battery runtime [min] * 60 for seconds
	APC)		UPS_APC=$VALUE;;				#internal apc id
	VERSION)	UPS_VERSION=$VALUE;;			#driver version
	DRIVER)		UPS_DRIVER=$VALUE;;				#driver name
	ITEMP)		UPS_ITEMP=$VALUE;;				#internal temperature [°C]
	HITRANS)	UPS_HITRANS=$VALUE;;			#input high-voltage transition to battery [V]
	LOTRANS)	UPS_LOTRANS=$VALUE;;			#input low-voltage transition to battery [V]
	LINEFREQ)	UPS_LINEFREQ=$VALUE;;			#input line frequency
	NOMPOWER)	UPS_NOMPOWER=$VALUE;;			#output power nominal [W]
	DSHUTD)		UPS_DSHUTD=$VALUE;;				#delay ups shutdown time [s]
	LASTXFER)	UPS_LASTXFER=$VALUR;;			#reason for the last battery transfer

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

				if [[ $VALUE == *"ONLINE"* ]]; then 
												UPS_STATUS="OL $UPS_STATUS";
												if [ $BATTNOTFULL = 1 ]; then UPS_STATUS="CHRG $UPS_STATUS"; fi
											   fi
				if [[ $VALUE == *"ONBATT"* ]]; then UPS_STATUS="OB DISCHRG $UPS_STATUS"; fi
				if [[ $VALUE == *"LOWBATT"* ]]; then UPS_STATUS="LB $UPS_STATUS"; fi
				if [[ $VALUE == *"CAL"* ]]; then UPS_STATUS="CAL $UPS_STATUS"; fi
				if [[ $VALUE == *"OVERLOAD"* ]]; then UPS_STATUS="OVER $UPS_STATUS"; fi
				if [[ $VALUE == *"TRIM"* ]]; then UPS_STATUS="TRIM $UPS_STATUS"; fi
				if [[ $VALUE == *"BOOST"* ]]; then UPS_STATUS="BOOST $UPS_STATUS"; fi
				if [[ $VALUE == *"REPLACEBATT"* ]]; then UPS_STATUS="RB $UPS_STATUS"; fi
				if [[ $VALUE == *"SHUTTING DOWN"* ]]; then UPS_STATUS="SD $UPS_STATUS"; fi
				if [[ $VALUE == *"COMMLOST"* ]]; then UPS_STATUS="OFF $UPS_STATUS"; fi
				UPS_STATUS="$(echo -e "${UPS_STATUS}" | sed -e 's/[[:space:]]*$//')"

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

if [ "${COMMAND:0:5}" = "LOGIN" ]; then echo "OK"

elif [ "$COMMAND" = "LOGOUT" ]; then break;

elif [ "$COMMAND" = "STARTTLS" ]; then echo "ERR FEATURE-NOT-CONFIGURED"

elif [ "${COMMAND:0:8}" = "USERNAME" ]; then echo "OK" 		#accepting all usernames

elif [ "${COMMAND:0:8}" = "PASSWORD" ]; then echo "OK" 		#accepting all passwords

elif [ "$COMMAND" = "LIST UPS" ]; then echo -en "BEGIN LIST UPS\nUPS ups \"$UPS_MFR\"\nEND LIST UPS\n"


elif [ "${COMMAND:0:12}" = "GET VAR ups " ]; then
		if [ "${COMMAND:12}" = "ups.status" ]; then
			getstatusdata #just get only the status parameter from the ups
			echo -en "VAR ups ${COMMAND:12} \"$UPS_STATUS\"\n"
		fi

elif [ "$COMMAND" = "LIST VAR ups" ]; then
		getfulldata #get all values from apcaccess
		echo -en "BEGIN LIST VAR ups\n"

		echo -en "VAR ups device.mfr \"$UPS_MFR\"\n"
		echo -en "VAR ups device.model \"$UPS_MODEL\"\n"
		echo -en "VAR ups device.serial \"$UPS_SERIALNO\"\n"
		echo -en "VAR ups device.type \"ups\"\n"

		echo -en "VAR ups ups.mfr \"$UPS_MFR\"\n"
		echo -en "VAR ups ups.mfr.date \"$UPS_MANDATE\"\n"
		echo -en "VAR ups ups.id \"APC\"\n"
		echo -en "VAR ups ups.vendorid \"051d\"\n"
		echo -en "VAR ups ups.model \"$UPS_MODEL\"\n"
		echo -en "VAR ups ups.status \"$UPS_STATUS\"\n"
		echo -en "VAR ups ups.load \"$UPS_LOADPCT\"\n"
		echo -en "VAR ups ups.serial \"$UPS_SERIALNO\"\n"
		echo -en "VAR ups ups.firmware \"$UPS_FIRMWARE\"\n"
		echo -en "VAR ups ups.firmware.aux \"$UPS_FIRMWARE\"\n"
		echo -en "VAR ups ups.productid \"$UPS_APC\"\n"
		echo -en "VAR ups ups.temperature \"$UPS_ITEMP\"\n"
		echo -en "VAR ups ups.realpower.nominal \"$UPS_NOMPOWER\"\n"
		echo -en "VAR ups ups.test.result \"$UPS_SELFTEST\"\n"
		echo -en "VAR ups ups.delay.start \"0\"\n"
		echo -en "VAR ups ups.delay.shutdown \"$UPS_DSHUTD\"\n"
		echo -en "VAR ups ups.timer.reboot \"-1\"\n"
		echo -en "VAR ups ups.timer.start \"-1\"\n"
		echo -en "VAR ups ups.timer.shutdown \"-1\"\n"

		echo -en "VAR ups battery.runtime \"$UPS_TIMELEFT\"\n"
		echo -en "VAR ups battery.runtime.low \"$UPS_DLOWBATT\"\n"
		echo -en "VAR ups battery.charge \"$UPS_BCHARGE\"\n"
		echo -en "VAR ups battery.charge.low \"$UPS_MBATTCHG\"\n"
		echo -en "VAR ups battery.charge.warning \"50\"\n"
		echo -en "VAR ups battery.voltage \"$UPS_BATTV\"\n"
		echo -en "VAR ups battery.voltage.nominal \"$UPS_NOMBATTV\"\n"
		echo -en "VAR ups battery.date \"$UPS_BATTDATE\"\n"
		echo -en "VAR ups battery.mfr.date \"$UPS_BATTDATE\"\n"
		echo -en "VAR ups battery.temperature \"$UPS_ITEMP\"\n"
		echo -en "VAR ups battery.type \"PbAc\"\n"

		echo -en "VAR ups driver.name \"usbhid-ups\"\n" 
		echo -en "VAR ups driver.version.internal \"apcupsd $UPS_VERSION\"\n"
		echo -en "VAR ups driver.version.data \"$UPS_DRIVER\"\n"
		echo -en "VAR ups driver.parameter.pollfreq \"60\"\n"
		echo -en "VAR ups driver.parameter.pollinterval \"10\"\n"

		echo -en "VAR ups input.voltage \"$UPS_LINEV\"\n"
		echo -en "VAR ups input.voltage.nominal \"$UPS_NOMINV\"\n"
		echo -en "VAR ups input.sensitivity \"$UPS_SENSE\"\n"
		echo -en "VAR ups input.transfer.high \"$UPS_HITRANS\"\n"
		echo -en "VAR ups input.transfer.low \"$UPS_LOTRANS\"\n"
		echo -en "VAR ups input.frequency \"$UPS_LINEFREQ\"\n"
		echo -en "VAR ups input.frequency.nominal \"50\"\n"
		echo -en "VAR ups input.transfer.reason \"$UPS_LASTXFER\"\n"

		echo -en "VAR ups output.voltage \"$UPS_OUTPUTV\"\n"
		echo -en "VAR ups output.voltage.nominal \"$UPS_NOMOUTV\"\n"

		echo -en "VAR ups server.info \"$HOSTNAME\"\n"

		echo -en "VAR ups ups.beeper.status \"enabled\"\n"

		echo -en "END LIST VAR ups\n"

else
		echo -en "ERR UNKNOWN-COMMAND\n"
fi

done
