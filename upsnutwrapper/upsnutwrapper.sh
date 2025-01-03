#!/usr/bin/env bash

# Script: 	upsnutwrapper.sh
# Author:	Martin (Machtl) Lang
# E-Mail:	martin@martinlang.at

SCRIPT_VERSION="1.12 (27.10.2024)"

#
# History:
#
#			1.0:	First working version "yeah"
#			1.1:	Changed the "apcaccess" call and added the option "-u"
#			1.2:	Added many parameters, First "release" version (15.02.2019)
#			1.3:	Pushed onto the github repo, little typo corrections (06.01.2022)
#			1.4:	Added logging and QNAP support, cleaned up code
#			1.5:	Better connection error handling, added some parameters
#			1.6:	Added command "GET UPSDESC <upsname>"
#			1.7:	Added command "GET DESC <upsname> <varname>" and all the descriptions for the variables
#			1.8:	Added commands "VER", "NETVER", "PROTVER", "LIST CLIENT", "LIST RW", "LIST CMD", "LIST ENUM"
#			1.9:	Added power and apntpower calculation, removed timer variables
#			1.10:   Better WinNUT support. WinNUT does not like empty input.frequency
#			1.11:	Limit apcaccess poll interval to 10 seconds. Some clients request single parameters, which could stress apcaccess.
#			1.12:	Optimized output for the "LIST VAR <upsname>" command. Switched from multiple echo statements to a "cat <<- EOF" statement
#
# Description:
#
#	This little non-optimized script emulates a NUT-Server together with the tinytool "tcpserver"
#	from the ucspi-tcp package. It needs an installed and working 'apcupsd' deamon running on the machine
#	or on a remote machine. It is working fine with Synology and QNNAP NAS for example (my usecase).
#	The script is simple and small and solves some problems having 'apcupsd' and a NUT-Server on the
#	same machine. If you wanna make the script better, Pull-Requests on the Github repo are welcomed! :-)
#
#
# Install / Running: (please also check the README.md on Github)
#
#	1.) You need an installed and running 'apcupsd' on the same machine or on a remote machine. You also need
#		'apcaccess' on this machine. Should be all fine if you installed apcupsd like "apt-get install apcupsd".
#		If you're not sure, please run the command "apcaccess" in the shell and see if you get your ups data.
#		Or run "apcaccess -h <remoteip>" to get the data of 'apcupsd' running on a remotemachine with ip <remoteip>.
#
#	2.) Install the small ucspi-tcp package via "apt-get install ucspi-tcp"
#
#	3.) Copy this script into /usr/local/bin/ and make it executable. You can simply run these commands to copy
# 		the script to the right location:
#
#		wget https://github.com/gitmachtl/various/raw/main/upsnutwrapper/upsnutwrapper.sh -O /usr/local/bin/upsnutwrapper.sh
#		chmod +x /usr/local/bin/upsnutwrapper.sh
#
#	4.) Start the NUT-Server-Wrapper by executing the following command via shell or a script:
#		tcpserver -q -c 10 -HR 0.0.0.0 3493 /usr/local/bin/upsnutwrapper.sh &
#
#		This starts a listening tcp server on port 3493 (nut) with no binding (0.0.0.0), max. 10 simultanious connections.
#
#	Enjoy your apcupsd and "nut server" side by side on the same machine :-)
#
#

# Here you can set the apcupsd server address
APCUPSDSERVER="localhost"		#apcupsd is running on the same machine
#APCUPSDSERVER="127.0.0.1"		#apcupsd is running on the same machine
#APCUPSDSERVER="remoteip:3551"		#apcupsd is running on a remote machine with ip "remoteip" on the port "3551"

#Enable/Disable the logging to a logfile. Logging is turned off by default.
LOGGING=false	#set to 'true' to see incoming commands
LOG_FILE=/tmp/upsnutwrapper.log		#the location where logs are written to

# List of available ups names presented to the NUT client. Only remove/change names here if needed!
# Synology NAS devices need the name 'ups' in the list, QNAP NAS devices need the name 'qnapups' in the list. Default setting works for both.
UPS_NAMES=("ups" "qnapups")



# 
# ----- ONLY EDIT BELOW THIS LINE IF YOU KNOW WHAT YOU'RE DOING -------------------------------------------------------------------
#

# ---------------------------------------
# define default values
# ---------------------------------------
setdefaultvalues() {

#-- battery values / description

 UPS_battery_charge="0"
DESC_battery_charge="Battery charge (percent)"

 UPS_battery_charge_low="10"
DESC_battery_charge_low="Remaining battery level when UPS switches to LB (percent)"

 UPS_battery_charge_warning="50"
DESC_battery_charge_warning="Battery level when UPS switches to Warning state (percent)"

 UPS_battery_date=""
DESC_battery_date="Battery manufacturing date (opaque string)"

 UPS_battery_mfr_date=""
DESC_battery_mfr_date="Battery manufacturing date (opaque string)"

 UPS_battery_runtime="0"
DESC_battery_runtime="Battery runtime (seconds)"

 UPS_battery_runtime_low="10"
DESC_battery_runtime_low="Remaining battery runtime when UPS switches to LB (seconds)"

 UPS_battery_temperature=""
DESC_battery_temperature="Battery temperature (degrees C)"

 UPS_battery_type="PbAc"
DESC_battery_type="Battery chemistry (opaque string)"

 UPS_battery_voltage="0"
DESC_battery_voltage="Battery voltage (V)"

 UPS_battery_voltage_nominal="0"
DESC_battery_voltage_nominal="Nominal battery voltage (V)"

#-- device values / description

 UPS_device_description="UPS NUT Apcupsd Wrapper"
DESC_device_description="Description of the device (opaque string)"

 UPS_device_mfr="UPS NUT Apcupsd Wrapper"
DESC_device_mfr="Device manufacturer"

 UPS_device_model="NO MODEL"
DESC_device_model="UPS model"

 UPS_device_serial=""
DESC_device_serial="Device serial number (opaque string)"

 UPS_device_type="ups"
DESC_device_type="Device type (ups, pdu, scd, psu, ats)"

#-- driver values / description

 UPS_driver_name="usbhid-ups"
DESC_driver_name="Driver name"

 UPS_driver_parameter_pollfreq="60"
DESC_driver_parameter_pollfreq="Driver poll frequency (seconds)"

 UPS_driver_parameter_pollinterval="10"
DESC_driver_parameter_pollinterval="Driver poll interval (seconds)"

 UPS_driver_version_data=""
DESC_driver_version_data="Version of the internal data mapping, for generic drivers"

 UPS_driver_version_internal="apcupsd"
DESC_driver_version_internal="Internal driver version"

#-- input values / description

 UPS_input_frequency="0"
DESC_input_frequency="Input line frequency (Hz)"

 UPS_input_frequency_nominal="50"
DESC_input_frequency_nominal="Nominal input line frequency (Hz)"

 UPS_input_sensitivity=""
DESC_input_sensitivity="Input power sensitivity"

 UPS_input_transfer_high=""
DESC_input_transfer_high="High voltage transfer point (V)"

 UPS_input_transfer_low=""
DESC_input_transfer_low="Low voltage transfer point (V)"

 UPS_input_transfer_reason=""
DESC_input_transfer_reason="Reason for last transfer to battery"

 UPS_input_voltage="0"
DESC_input_voltage="Input voltage (V)"

 UPS_input_voltage_nominal="230"
DESC_input_voltage_nominal="Nominal input voltage (V)"

 UPS_input_voltage_minimum="0"
DESC_input_voltage_minimum="Minimum incoming voltage seen (V)"

 UPS_input_voltage_maximum="0"
DESC_input_voltage_maximum="Maximum incoming voltage seen (V)"

#-- mfr values / description

 UPS_mfr_date=""
DESC_mfr_date="UPS manufacturing date (opaque string)"

#-- output values / description

 UPS_output_current="0"
DESC_output_current="Output current (A)"

 UPS_output_voltage="0"
DESC_output_voltage="Output voltage (V)"

 UPS_output_voltage_nominal="0"
DESC_output_voltage_nominal="Nominal output voltage (V)"

#-- server values / description

 UPS_server_info=$HOSTNAME
DESC_server_info="Server information"

#-- ups values / description

 UPS_ups_status=""
DESC_ups_status="UPS status"

 UPS_ups_delay_start="0"
DESC_ups_delay_start="Interval to wait before restarting the load (seconds)"

 UPS_ups_delay_shutdown="0"
DESC_ups_delay_shutdown="Interval to wait after shutdown with delay command (seconds)"

 UPS_ups_firmware=""
DESC_ups_firmware="UPS firmware (opaque string)"

 UPS_ups_firmware_aux=""
DESC_ups_firmware_aux="Auxiliary device firmware"

 UPS_ups_id="NO NAME"
DESC_ups_id="UPS system identifier (opaque string)"

 UPS_ups_vendorid="051d"
DESC_ups_vendorid="Vendor ID for USB devices (opaque string)"

 UPS_ups_load="0"
DESC_ups_load="Load on UPS (percent)"

 UPS_ups_load_apnt="0"
DESC_ups_load_apnt="Apparent load on UPS (percent)"

 UPS_ups_mfr=${UPS_device_mfr}
DESC_ups_mfr="UPS manufacturer"

 UPS_ups_mfr_date=""
DESC_ups_mfr_date="UPS manufacturing date (opaque string)"

 UPS_ups_model="NO MODEL"
DESC_ups_model="UPS model"

 UPS_ups_productid=""
DESC_ups_productid="Product ID for USB devices"

 UPS_ups_power="0"
DESC_ups_power="Currentvalue of apparent power (Volt-Amps)"

 UPS_ups_power_nominal="0"
DESC_ups_power_nominal="Nominal value of apparent power (Volt-Amps)"

 UPS_ups_realpower="0"
DESC_ups_realpower="Current value of real power (Watts)"

 UPS_ups_realpower_nominal="0"
DESC_ups_realpower_nominal="Nominal value of real power (Watts)"

 UPS_ups_serial=""
DESC_ups_serial="UPS serial number (opaque string)"

 UPS_ups_temperature=""
DESC_ups_temperature="UPS temperature (degrees C)"

 UPS_ups_test_date=""
DESC_ups_test_date="Date of last self test (opaque string)"

 UPS_ups_test_result=""
DESC_ups_test_result="Results of last self test (opaque string)"

 UPS_ups_beeper_status=""
DESC_ups_beeper_status="UPS beeper status (enabled, disabled or muted)"

}

# ---------------------------------------
# get all the values from apcaccess
# ---------------------------------------
getfulldata() {

#Do a check about the last time a successful was done and limit the poll interval to 10 seconds
let APCACCESS_poll_interval=${SECONDS}-${APCACCESS_last_poll_time};
if [ ${APCACCESS_poll_interval} -lt 10 ]; then return 0; fi #poll was made within 10 seconds from the last time, so don't update the parameters, exit function

setdefaultvalues	#load default values

log ">>> Poll parameters via apcaccess (interval ${APCACCESS_poll_interval}s)"
APCACCESS="$(apcaccess -h $APCUPSDSERVER -u 2> /dev/null)"	#get data from acpaccess
if [ $? -ne 0 ]; then log ">>> FAILED to poll parameters: ${APCACCESS}"; return 1; fi #exit with errorcode 1 if something with the connection is wrong
APCACCESS_last_poll_time=${SECONDS} #save current seconds for the successfull data poll

APCACCESS=$(sort <<< "${APCACCESS}") #sort it so for example BCHARGE will be processed before STATUS

IFS_BAK=$IFS					# change delimiter (IFS) to new line.
IFS=$'\n'

for LINE in $APCACCESS; do

 PARAM=${LINE:0:9}						#first 9 chars as parameter
 PARAM="$(echo -e "${PARAM}" | sed -e 's/[[:space:]]*$//')"  	#delete trailing spaces

 VALUE=${LINE:11}   						#chars starting at 11 as value
 VALUE="$(echo -e "${VALUE}" | sed -e 's/[[:space:]]*$//')" 	#delete trailing spaces

 case "$PARAM" in

	BCHARGE) 	UPS_battery_charge=$VALUE; #battery charge in [%]
			if [[ "${VALUE%%.*}" == "100" ]]; then BATTNOTFULL=0; else BATTNOTFULL=1; fi
			;;

	STATUS)
			UPS_ups_status=""
			case "${VALUE}" in
				*"ONLINE"*) 		UPS_ups_status+="OL "
							if [ $BATTNOTFULL = 1 ]; then UPS_ups_status+="CHRG "; fi #if battery is not at 100%, add charging flag
							;;&
				*"ONBATT"*)		UPS_ups_status+="OB DISCHRG " ;;& #onbattery with discharge flag
				*"LOWBATT"*)		UPS_ups_status+="LB " ;;&
				*"CAL"*)		UPS_ups_status+="CAL " ;;&
				*"OVERLOAD"*)		UPS_ups_status+="OVER " ;;&
				*"TRIM"*)		UPS_ups_status+="TRIM " ;;&
				*"BOOST"*)		UPS_ups_status+="BOOST " ;;&
				*"REPLACEBATT"*)	UPS_ups_status+="RB " ;;&
				*"SHUTTING DOWN"*)	UPS_ups_status+="SD " ;;&
				*"COMMLOST"*)		UPS_ups_status+="OFF " ;;
			esac
			UPS_ups_status="$(echo -e "${UPS_ups_status}" | sed -e 's/[[:space:]]*$//')"
			;;

	UPSNAME) 	UPS_ups_id=$VALUE;;

	MODEL) 		UPS_device_model=$VALUE; UPS_ups_model=$VALUE; UPS_device_description=$VALUE;;

	SELFTEST)
			case "${VALUE}" in
				*"OK"*) UPS_ups_test_result="OK - Battery GOOD";;
				*"BT"*) UPS_ups_test_result="FAILED - Battery Capacity LOW";;
				*"NG"*) UPS_ups_test_result="FAILED - Overload";;
				*"NO"*) UPS_ups_test_result="No Test in the last 5mins";;
			esac
			;;

	LASTSTEST)	UPS_ups_test_date=$(date --date="$VALUE" --iso-8601=minutes);; #set last testdate in iso8601 format (YYYY-MM-DDThh:mm+00:00)
	TIMELEFT)	let UPS_battery_runtime=${VALUE%%.*}*60;;	#only use string before ".", multiply with 60 for value in seconds
	BATTV) 		UPS_battery_voltage=$VALUE;;  			#battery voltage [V]
	NOMBATTV) 	UPS_battery_voltage_nominal=$VALUE;;  			#battery voltage nominal [V]
	SERIALNO)	UPS_device_serial=$VALUE; UPS_ups_serial=$VALUE;; #serialnumber of the ups
	BATTDATE)	UPS_battery_date=$VALUE; UPS_battery_mfr_date=$VALUE;; #battery date
	MANDATE)	UPS_mfr_date=$VALUE; UPS_ups_mfr_date=$VALUE;;			#mfr date
	FIRMWARE)	UPS_ups_firmware=$VALUE; UPS_ups_firmware_aux=$VALUE;; #firmwareversion
	LOADPCT)	UPS_ups_load=$VALUE;;			#current load [%]
	LOADAPNT)	UPS_ups_load_apnt=$VALUE;;			#current apparent load [%]
	LINEV)		UPS_input_voltage=$VALUE; UPS_input_voltage_minimum=$VALUE; UPS_input_voltage_maximum=$VALUE;;	#input voltage [V], also set min/max voltage in case there is no separate data for that
	MINLINEV)	UPS_input_voltage_minimum=$VALUE;;		#input voltage [V]
	MAXLINEV)	UPS_input_voltage_maximum=$VALUE;;		#input voltage [V]
	NOMINV)		UPS_input_voltage_nominal=$VALUE;;		#input voltage nominal [V]
	OUTPUTV)	UPS_output_voltage=$VALUE;;			#output voltage [V]
	OUTCURNT)	UPS_output_current=${VALUE%%\ *};;		#output current [A]
	NOMOUTV)	UPS_output_voltage_nominal=$VALUE;;		#output voltage nominal [V]
	NOMAPNT) 	UPS_ups_power_nominal=${VALUE%%\ *};;  		#nominal apparent power [VA]
	MBATTCHG)	UPS_battery_charge_low=$VALUE;;			#minimum battery charge [%]
	SENSE)		UPS_input_sensitivity=$VALUE;;			#input sensitivity
	DLOWBATT)	let UPS_battery_runtime_low=${VALUE%%.*}*60;;	#low battery runtime [min] * 60 for seconds
	APC)		UPS_ups_productid=$VALUE;;			#internal apc id
	VERSION)	UPS_driver_version_internal="apcupsd $VALUE";; #driver version
	DRIVER)		UPS_driver_version_data=$VALUE;;			#driver name
	ITEMP)		UPS_ups_temperature=$VALUE; UPS_battery_temperature=$VALUE;; #internal temperature [°C]
	HITRANS)	UPS_input_transfer_high=$VALUE;;			#input high-voltage transition to battery [V]
	LOTRANS)	UPS_input_transfer_low=$VALUE;;			#input low-voltage transition to battery [V]
	LINEFREQ)	UPS_input_frequency=$VALUE;;			#input line frequency
	NOMPOWER)	UPS_ups_realpower_nominal=$VALUE;;			#output power nominal [W]
	DSHUTD)		UPS_ups_delay_shutdown=$VALUE;;			#delay ups shutdown time [s]
	LASTXFER)	UPS_input_transfer_reason=$VALUE;;			#reason for the last battery transfer
	DWAKE)		UPS_ups_delay_start=$VALUE;;			#delay ups start time [s]

 esac

done  #for

#substitute battery date and ups mfr date with each other if the other does not exist
if [ "$UPS_battery_date" = "" ]; then UPS_battery_date=$UPS_mfr_date; UPS_battery_mfr_date=$UPS_mfr_date; fi
if [ "$UPS_mfr_date" = "" ]; then UPS_mfr_date=$UPS_battery_date; fi

#small ups database to also have nominal power values if not reported back via apcaccess
case "${UPS_device_model}" in
	*"Back-UPS XS 700U"*)	UPS_ups_realpower_nominal="390"; UPS_ups_power_nominal="700";;
	*"SMART-UPS 700"*)		UPS_ups_realpower_nominal="450"; UPS_ups_power_nominal="700";;
	*"Smart-UPS C 1500"*)	UPS_ups_realpower_nominal="900"; UPS_ups_power_nominal="1500";;
	*"Back-UPS RS 1500"*)	UPS_ups_realpower_nominal="865"; UPS_ups_power_nominal="1500";;
esac

#if there is a value for the nominal output power, include it into the ups model name. also calculate the current realpower
if ! [ "$UPS_ups_realpower_nominal" = "0" ]; then 
	UPS_device_model="$UPS_device_model ($UPS_ups_realpower_nominal W)";
	UPS_ups_model=${UPS_device_model};
fi

#calculate the current power
let UPS_ups_realpower=(${UPS_ups_load%%.*}*${UPS_ups_realpower_nominal})/100; #use the LOADPCT without decimals
let UPS_ups_power=(${UPS_ups_load_apnt%%.*}*${UPS_ups_power_nominal})/100; #use the LOADAPNT without decimals

IFS=$IFS_BAK
}

# ---------------------------------------------------
# get the data for the STATUS variable via apcaccess
# ---------------------------------------------------
getstatusdata() {
APCACCESS="$(apcaccess -h $APCUPSDSERVER -p STATUS 2> /dev/null)"
if [ $? -eq 1 ]; then return 1; fi #exit with errorcode 1 if something with the connection is wrong

VALUE="${APCACCESS%%[[:cntrl:]]}"
UPS_ups_status=""
case "${VALUE}" in
	*"ONLINE"*) 		UPS_ups_status+="OL "
				if [ $BATTNOTFULL = 1 ]; then UPS_ups_status+="CHRG "; fi
				;;&
	*"ONBATT"*)		UPS_ups_status+="OB DISCHRG " ;;&
	*"LOWBATT"*)		UPS_ups_status+="LB " ;;&
	*"CAL"*)		UPS_ups_status+="CAL " ;;&
	*"OVERLOAD"*)		UPS_ups_status+="OVER " ;;&
	*"TRIM"*)		UPS_ups_status+="TRIM " ;;&
	*"BOOST"*)		UPS_ups_status+="BOOST " ;;&
	*"REPLACEBATT"*)	UPS_ups_status+="RB " ;;&
	*"SHUTTING DOWN"*)	UPS_ups_status+="SD " ;;&
	*"COMMLOST"*)		UPS_ups_status+="OFF " ;;
esac
UPS_ups_status="$(echo -e "${UPS_ups_status}" | sed -e 's/[[:space:]]*$//')"
}


# ---------------------------------------
# get the last test result status
# ---------------------------------------
gettestresult() {
APCACCESS="$(apcaccess -h $APCUPSDSERVER -p SELFTEST 2> /dev/null)"
if [ $? -eq 1 ]; then return 1; fi #exit with errorcode 1 if something with the connection is wrong

VALUE="${APCACCESS%%[[:cntrl:]]}"
case "${VALUE}" in
	*"OK"*) UPS_ups_test_result="OK - Battery GOOD";;
	*"BT"*) UPS_ups_test_result="FAILED - Battery Capacity LOW";;
	*"NG"*) UPS_ups_test_result="FAILED - Overload";;
	*"NO"*) UPS_ups_test_result="No Test in the last 5mins";;
esac
}

# ---------------------------------------
# logging to a file if enabled
# ---------------------------------------
log() {
if [ "$LOGGING" = true ] ; then
	echo -e "$(date)\tREM_IP=${TCPREMOTEIP} \tPID=$$ \t${1}" >> "$LOG_FILE"
fi
}


# -----------------------------
# ------- MAIN PROCESS --------
# -----------------------------
#

#some vars
PROTOCOL_VERSION="1.2" #currently emulated NUT procotol version
BATTNOTFULL=0	#we start the script thinking of a full battery
APCACCESS_last_poll_time=-10 #initialize last time a successful poll was made via apcaccess
unset x		#important for the check ${!local_var+x} later on

setdefaultvalues	#load default values

while : ; do

read -sr INSTRING	#read in then provided command

COMMAND="${INSTRING%%[[:cntrl:]]}" #strip any control chars like "new line", etc. from them command
COMMAND=${COMMAND//[![:print:]]/} #strip non printable chars

if [[ "${COMMAND}" != "" ]]; then log "$COMMAND"; fi #only log non empty commands

case "${COMMAND}" in

        "") echo "";; # do nothing on empty commands

	"LOGIN"*|"USERNAME"*|"PASSWORD"* ) # login, accepting all usernames and passwords
			log ">>> ${COMMAND} OK"
			echo "OK"
			;;

	"LOGOUT" ) #logout -> exit the while loop which exits the script and closes the open connection to the client
			log ">>> Logout, exiting script"
			break
			;;

	"STARTTLS" ) #this is not supported by the script, send an error so the NUT-Client requests continues without TLS
			log ">>> TLS requested, but not supported"
			echo "ERR FEATURE-NOT-SUPPORTED"
			;;

	"VER"* ) #returns the current script version and info
			log ">>> VER requested"
			echo -e "UPS NUT Apcupsd Wrapper v${SCRIPT_VERSION} - https://github.com/gitmachtl/various/tree/main/upsnutwrapper"
			;;

	"NETVER"*|"PROTVER"* ) #returns the NUT protocol version
			log ">>> NET/PROTOCOL version requested, its v${PROTOCOL_VERSION}"
			echo -e "${PROTOCOL_VERSION}"
			;;

	"LIST UPS" ) #return a list of all UPSs to the client. returns "ups" for synology and "qnapups" for qnap by default
			ALL_UPS_NAMES=${UPS_NAMES[@]}
			log ">>> Serving all the names of the UPSs (${ALL_UPS_NAMES})"
			echo -e "BEGIN LIST UPS"
			for entryname in ${UPS_NAMES[@]}
			do
				echo -e "UPS ${entryname} \"$UPS_device_mfr\""
			done
			echo -e "END LIST UPS"
			;;

	*) #continue with specific commands that include the UPSNAME and/or the VARIABLE

		if [[ "${COMMAND}" =~ "GET VAR "(.*)" "(.*)"" ]]; then #requesting a specific value for a given variable

			UPSNAME=${BASH_REMATCH[1]}
			VAR=${BASH_REMATCH[2]}

			log ">>> Requested value for VAR=${VAR} and UPSNAME=${UPSNAME}"

                        case "${VAR}" in

                                "ups.status")
                                        getstatusdata #get only the status parameter from the ups
										if [ $? -ne 0 ]; then
											log ">>> Requesting status data via apcaccess failed!"
											log ">>> Exiting script"
											echo "ERR DRIVER-NOT-CONNECTED"
											break #exiting the script
										fi
                                        log ">>> returned data for UPS_ups_status=${UPS_ups_status}"
                                        echo -e "VAR $UPSNAME ${VAR} \"$UPS_ups_status\""
                                        ;;

                                "ups.test.result")
                                        gettestresult #get only test result data
										if [ $? -ne 0 ]; then
											log ">>> Requesting test result data via apcaccess failed!"
											log ">>> Exiting script"
											echo "ERR DRIVER-NOT-CONNECTED"
											break #exiting the script
										fi
                                        log ">>> returned data for UPS_ups_test_result=${UPS_ups_test_result}"
                                        echo -e "VAR $UPSNAME ${VAR} \"$UPS_ups_test_result\""
                                        ;;

                                *) #return any specific requested VAR if it exists
                                        local_var="UPS_${VAR//./_}"; #substitute the . with _ -> example ups.status -> local_var="UPS_ups_status"
                                        if [ ! -z ${!local_var+x} ]; then
                                                getfulldata #get all values from apcaccess
												if [ $? -ne 0 ]; then
													log ">>> Requesting data via apcaccess failed!"
													log ">>> Exiting script"
													echo "ERR DRIVER-NOT-CONNECTED"
													break #exiting the script
												fi
                                                log ">>> returned data for ${local_var}=${!local_var}"
                                                echo -e "VAR $UPSNAME ${VAR} \"${!local_var}\""
                                        else
										log ">>> failed to process variable ${VAR} (${local_var})"
										echo -e "ERR VAR-NOT-SUPPORTED"
                                        fi
                                        ;;

                        esac


		elif [[ "${COMMAND}" =~ "GET DESC "(.*)" "(.*)"" ]]; then #requesting the description for a specific value

			UPSNAME=${BASH_REMATCH[1]}
			VAR=${BASH_REMATCH[2]}
			log ">>> Requested description for VAR=${VAR} for UPSNAME=${UPSNAME}"
            local_var="DESC_${VAR//./_}"; #substitute the . with _ -> example ups.status -> local_var="DESC_ups_status"
            if [ ! -z ${!local_var+x} ]; then #DESC variable exists, return it
				log ">>> returned desc for ${local_var}=${!local_var}"
				echo -e "DESC ${UPSNAME} ${VAR} \"${!local_var}\""
			else #DESC variable does not exist, return an empty string
				log ">>> no description found for variable ${VAR} (${local_var})"
				echo -e "DESC ${UPSNAME} ${VAR} \"\"" #return an empty string
            fi


		elif [[ "${COMMAND}" =~ "GET UPSDESC "(.*)"" ]]; then #requesting ups description

			UPSNAME=${BASH_REMATCH[1]}
			log ">>> Requested upsdescription for UPSNAME=${UPSNAME}"
			getfulldata #get all values from apcaccess
			if [ $? -ne 0 ]; then
				log ">>> Requesting fulldata via apcaccess failed!"
				log ">>> Exiting script"
				echo "ERR DRIVER-NOT-CONNECTED"
				break #exiting the script
			fi
			echo -e "UPSDESC ${UPSNAME} \"${UPS_device_description}\""


		elif [[ "${COMMAND}" =~ "LIST CLIENT "(.*)"" ]]; then #requesting client ip address

			UPSNAME=${BASH_REMATCH[1]}
			log ">>> Requested client IP address for UPSNAME=${UPSNAME}"
			echo -e "BEGIN LIST CLIENT ${UPSNAME}\nCLIENT ${UPSNAME} ${TCPREMOTEIP}\nEND LIST CLIENT ${UPSNAME}"


		elif [[ "${COMMAND}" =~ "LIST RW "(.*)"" ]]; then #requesting writable variable list

			UPSNAME=${BASH_REMATCH[1]}
			log ">>> Requested writable variable list for UPSNAME=${UPSNAME}"
			echo -e "BEGIN LIST RW ${UPSNAME}\nEND LIST RW ${UPSNAME}" #return an empty list, not supported in this script


		elif [[ "${COMMAND}" =~ "LIST CMD "(.*)"" ]]; then #requesting command list

			UPSNAME=${BASH_REMATCH[1]}
			log ">>> Requested executable command list for UPSNAME=${UPSNAME}"
			echo -e "BEGIN LIST CMD ${UPSNAME}\nEND LIST CMD ${UPSNAME}" #return an empty list, not supported in this script


		elif [[ "${COMMAND}" =~ "LIST ENUM "(.*)" "(.*)"" ]]; then #requesting the ENUM list for a specific value

			UPSNAME=${BASH_REMATCH[1]}
			VAR=${BASH_REMATCH[2]}
			log ">>> Requested ENUM list for VAR=${VAR} for UPSNAME=${UPSNAME}"
			echo -e "BEGIN LIST ENUM ${UPSNAME} ${VAR}\nEND LIST ENUM ${UPSNAME} ${VAR}" #return an empty list, not supported in this script


		elif [[ "${COMMAND}" =~ "LIST VAR "(.*)"" ]]; then #requesting all values

			UPSNAME=${BASH_REMATCH[1]}
			log ">>> Requested all VARs for UPSNAME=${UPSNAME}"
			getfulldata #get all values from apcaccess
			if [ $? -ne 0 ]; then
				log ">>> Requesting fulldata via apcaccess failed!"
				log ">>> Exiting script"
				echo "ERR DRIVER-NOT-CONNECTED"
				break #exiting the script
			fi

			#optimized output for the whole list of parameters (v
			cat <<- EOF
BEGIN LIST VAR $UPSNAME
VAR $UPSNAME device.description "$UPS_device_description"
VAR $UPSNAME device.mfr "$UPS_device_mfr"
VAR $UPSNAME device.model "$UPS_device_model"
VAR $UPSNAME device.serial "$UPS_device_serial"
VAR $UPSNAME device.type "$UPS_device_type"
VAR $UPSNAME ups.mfr "$UPS_device_mfr"
VAR $UPSNAME ups.mfr.date "$UPS_mfr_date"
VAR $UPSNAME ups.id "$UPS_ups_id"
VAR $UPSNAME ups.vendorid "$UPS_ups_vendorid"
VAR $UPSNAME ups.model "$UPS_ups_model"
VAR $UPSNAME ups.status "$UPS_ups_status"
VAR $UPSNAME ups.load "$UPS_ups_load"
VAR $UPSNAME ups.serial "$UPS_ups_serial"
VAR $UPSNAME ups.firmware "$UPS_ups_firmware"
VAR $UPSNAME ups.firmware.aux "$UPS_ups_firmware_aux"
VAR $UPSNAME ups.productid "$UPS_ups_productid"
VAR $UPSNAME ups.temperature "$UPS_ups_temperature"
VAR $UPSNAME ups.power "$UPS_ups_power"
VAR $UPSNAME ups.power.nominal "$UPS_ups_power_nominal"
VAR $UPSNAME ups.realpower "$UPS_ups_realpower"
VAR $UPSNAME ups.realpower.nominal "$UPS_ups_realpower_nominal"
VAR $UPSNAME ups.test.date "$UPS_ups_test_date"
VAR $UPSNAME ups.test.result "$UPS_ups_test_result"
VAR $UPSNAME ups.delay.start "$UPS_ups_delay_start"
VAR $UPSNAME ups.delay.shutdown "$UPS_ups_delay_shutdown"
VAR $UPSNAME battery.runtime "$UPS_battery_runtime"
VAR $UPSNAME battery.runtime.low "$UPS_battery_runtime_low"
VAR $UPSNAME battery.charge "$UPS_battery_charge"
VAR $UPSNAME battery.charge.low "$UPS_battery_charge_low"
VAR $UPSNAME battery.charge.warning "$UPS_battery_charge_warning"
VAR $UPSNAME battery.voltage "$UPS_battery_voltage"
VAR $UPSNAME battery.voltage.nominal "$UPS_battery_voltage_nominal"
VAR $UPSNAME battery.date "$UPS_battery_date"
VAR $UPSNAME battery.mfr.date "$UPS_battery_date"
VAR $UPSNAME battery.temperature "$UPS_battery_temperature"
VAR $UPSNAME battery.type "$UPS_battery_type"
VAR $UPSNAME driver.name "$UPS_driver_name"
VAR $UPSNAME driver.version.internal "$UPS_driver_version_internal"
VAR $UPSNAME driver.version.data "$UPS_driver_version_data"
VAR $UPSNAME driver.parameter.pollfreq "$UPS_driver_parameter_pollfreq"
VAR $UPSNAME driver.parameter.pollinterval "$UPS_driver_parameter_pollinterval"
VAR $UPSNAME input.voltage "$UPS_input_voltage"
VAR $UPSNAME input.voltage.nominal "$UPS_input_voltage_nominal"
VAR $UPSNAME input.voltage.minimum "$UPS_input_voltage_minimum"
VAR $UPSNAME input.voltage.maximum "$UPS_input_voltage_maximum"
VAR $UPSNAME input.sensitivity "$UPS_input_sensitivity"
VAR $UPSNAME input.transfer.high "$UPS_input_transfer_high"
VAR $UPSNAME input.transfer.low "$UPS_input_transfer_low"
VAR $UPSNAME input.frequency "$UPS_input_frequency"
VAR $UPSNAME input.frequency.nominal "$UPS_input_frequency_nominal"
VAR $UPSNAME input.transfer.reason "$UPS_input_transfer_reason"
VAR $UPSNAME output.voltage "$UPS_output_voltage"
VAR $UPSNAME output.voltage.nominal "$UPS_output_voltage_nominal"
VAR $UPSNAME output.current "$UPS_output_current"
VAR $UPSNAME server.info "$UPS_server_info"
VAR $UPSNAME ups.beeper.status "enabled"
END LIST VAR $UPSNAME
EOF
			log ">>> returned all VARs"

		else #not a supported command

			log ">>> failed to process command"
			echo -e "ERR UNKNOWN-COMMAND"

		fi
		;;
esac # "${COMMAND}"


done
