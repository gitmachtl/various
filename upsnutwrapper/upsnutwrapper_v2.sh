#!/usr/bin/env bash
# upsnutwrapper.sh - Emulates a NUT server using apcaccess and tcpserver
# 2025.08.18

[[ "$DEBUG" == "true" ]] \
  && exec 2>/tmp/upsnutwrapper.debug \
  && set -x

set -euo pipefail

# -------------------- Config --------------------
# variables=snake_case, functions=camelCase, env vars=UPPER_CASE

script_version="2.0"
log_file=/tmp/upsnutwrapper.log
protocol_version="1.2"
batt_not_full=0

# ------------- Overridable Defaults -------------
# These default values can be overridden by environment variables (primarily for use in the Docker build: bnhf/upsnutwrapper)

apcupsd_server="${APCUPSD_SERVER:-localhost}"
logging="${LOGGING:-false}"
apcaccess_last_poll="${APCACCESS_LAST_POLL:--10}"
ups_names=( "${UPS_NAMES[@]:-"ups" "qnapups"}" )

battery_type="${BATTERY_TYPE:-PbAc}"
device_description="${DEVICE_DESCRIPTION:-UPS NUT Apcupsd Wrapper}"
input_frequency_nominal="${INPUT_FREQUENCY_NOMINAL:-50}"
input_sensitivity="${INPUT_SENSITIVITY:-low}"
input_transfer_high="${INPUT_TRANSFER_HIGH:-285}"
input_transfer_low="${INPUT_TRANSFER_LOW:-196}"
input_voltage_nominal="${INPUT_VOLTAGE_NOMINAL:-240}"
input_power_default="$( [[ ${INPUT_POWER_SUPPORTED:-true} == "true" ]] && echo 0 || echo "" )"
output_power_default="$( [[ ${OUTPUT_POWER_SUPPORTED:-true} == "true" ]] && echo 0 || echo "" )"
ups_beeper_status="${UPS_BEEPER_STATUS:-enabled}"

# -------------------- Logging --------------------

log() {
  [[ "$logging" == true ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $TCPREMOTEIP :: $*" >> "$log_file"
}

# -------------------- Helpers --------------------

parseStatus() {
  local value="$1"
  ups_status=""
  [[ $value == *"ONLINE"* ]] && ups_status+="OL " && [[ $batt_not_full -eq 1 ]] && ups_status+="CHRG "
  [[ $value == *"ONBATT"* ]] && ups_status+="OB DISCHRG "
  [[ $value == *"LOWBATT"* ]] && ups_status+="LB "
  [[ $value == *"CAL"* ]] && ups_status+="CAL "
  [[ $value == *"OVERLOAD"* ]] && ups_status+="OVER "
  [[ $value == *"TRIM"* ]] && ups_status+="TRIM "
  [[ $value == *"BOOST"* ]] && ups_status+="BOOST "
  [[ $value == *"REPLACEBATT"* ]] && ups_status+="RB "
  [[ $value == *"SHUTTING DOWN"* ]] && ups_status+="SD "
  [[ $value == *"COMMLOST"* ]] && ups_status+="OFF "
  ups_status="${ups_status%%[[:space:]]}"
}

getStatusData() {
  local output
  output="$(apcaccess -h "$apcupsd_server" -p STATUS 2>/dev/null || true)"
  [[ -z "$output" ]] && return 1
  parseStatus "$output"
}

getTestResult() {
  local output
  output="$(apcaccess -h "$apcupsd_server" -p SELFTEST 2>/dev/null || true)"
  [[ -z "$output" ]] && return 1
  case "$output" in
    *"OK"*) ups[ups.test.result]="OK - Battery GOOD";;
    *"BT"*) ups[ups.test.result]="FAILED - Battery Capacity LOW";;
    *"NG"*) ups[ups.test.result]="FAILED - Overload";;
    *"NO"*) ups[ups.test.result]="No Test in the last 5mins";;
  esac
}

getRealPowerNominal() {
  case "${ups[device.model]}" in
	  *"Back-UPS XS 700U"*)	ups[ups.realpower.nominal]="390" ;;
	  *"SMART-UPS 700"*)		ups[ups.realpower.nominal]="450" ;;
	  *"Smart-UPS C 1500"*)	ups[ups.realpower.nominal]="900" ;;
	  *"Back-UPS RS 1500"*)	ups[ups.realpower.nominal]="865" ;;
  esac
}

# -------------------- Set Default Values --------------------
declare -A ups ups_desc ups_type

ups_defaults=$(cat <<EOF
battery.charge|0|Battery charge (percent)|NUMBER
battery.charge.low|10|Low battery charge threshold|STRING:10
battery.charge.warning|50|Battery warning level|NUMBER
battery.date||Battery manufacturing date|NUMBER
battery.mfr.date||Battery manufacturing date (alternate)|STRING:10
battery.runtime|0|Battery runtime (seconds)|NUMBER
battery.runtime.low|10|Low battery runtime (seconds)|STRING:10
battery.temperature||Battery temperature (degrees C)|NUMBER
battery.type|$battery_type|Battery type|NUMBER
battery.voltage|0|Battery voltage|NUMBER
battery.voltage.nominal|0|Nominal battery voltage|NUMBER
device.description|$device_description|Description of the device (opaque string)|NUMBER
device.mfr|American Power Conversion|Device manufacturer|NUMBER
device.model|NO MODEL|Device model|NUMBER
device.serial||Device serial number|NUMBER
device.type|ups|Device type|NUMBER
driver.name|usbhid-ups|Driver name|NUMBER
driver.parameter.bus|001|USB bus number|NUMBER
driver.parameter.pollfreq|60|Polling frequency|NUMBER
driver.parameter.pollinterval|10|Polling interval|NUMBER
driver.parameter.port|auto|Driver port|NUMBER
driver.parameter.productid|0002|Product ID|NUMBER
driver.parameter.serial||Driver serial number|NUMBER
driver.parameter.synchronous|auto|Synchronous mode|NUMBER
driver.parameter.vendor|American Power Conversion|Vendor name|NUMBER
driver.parameter.vendorid|051D|Vendor ID|NUMBER
driver.version|2.8.0|Driver version|NUMBER
driver.version.data|APC HID 0.98|Data version|NUMBER
driver.version.internal|0.47|Internal version|NUMBER
driver.version.usb|libusb-1.0.26 (API: 0x1000109)|USB version|NUMBER
input.frequency|0|Input line frequency (Hz)|NUMBER
input.frequency.nominal|$input_frequency_nominal|Nominal input line frequency (Hz)|NUMBER
input.sensitivity|$input_sensitivity|Input sensitivity|STRING:10
input.transfer.high|$input_transfer_high|High transfer voltage|STRING:10
input.transfer.low|$input_transfer_low|Low transfer voltage|STRING:10
input.transfer.reason||Reason for transfer|NUMBER
input.voltage|$input_power_default|Input voltage|NUMBER
input.voltage.nominal|$input_voltage_nominal|Nominal input voltage|NUMBER
input.voltage.minimum|$input_power_default|Minimum incoming voltage seen (V)|NUMBER
input.voltage.maximum|$input_power_default|Maximum incoming voltage seen (V)|NUMBER
output.current|$output_power_default|Output current (A)|NUMBER
output.voltage|$output_power_default|Output voltage (V)|NUMBER
output.voltage.nominal|$output_power_default|Nominal output voltage (V)|NUMBER
server.info|$HOSTNAME|Server hostname|NUMBER
ups.beeper.status|$ups_beeper_status|Beeper status|NUMBER
ups.delay.start||Interval to wait before restarting the load (seconds)|STRING:10
ups.delay.shutdown|0|Interval to wait after shutdown with delay command (seconds)|STRING:10
ups.firmware||Firmware version|NUMBER
ups.firmware.aux||Auxiliary firmware|NUMBER
ups.id||UPS system identifier (opaque string)|NUMBER
ups.load|0|Load on UPS (percent)|NUMBER
ups.mfr|American Power Conversion|UPS manufacturer|NUMBER
ups.mfr.date||UPS manufacturing date|NUMBER
ups.model|NO MODEL|UPS model|NUMBER
ups.power||Current value of apparent power (Volt-Amps)|NUMBER
ups.power.nominal||Nominal value of apparent power (Volt-Amps)|NUMBER
ups.productid|0002|UPS product ID|NUMBER
ups.realpower||Current value of real power (Watts)|NUMBER
ups.realpower.nominal|0|Nominal value of real power (Watts)|NUMBER
ups.serial||UPS serial number (opaque string)|NUMBER
ups.status||UPS status|NUMBER
ups.temperature||UPS temperature (degrees C)|NUMBER
ups.test.date||Date of last self test (opaque string)|NUMBER
ups.test.result||Results of last self test (opaque string)|NUMBER
ups.timer.reboot|0|Time before the load will be rebooted (seconds)|NUMBER
ups.timer.shutdown|-1|Time before the load will be shutdown (seconds)|NUMBER
ups.vendorid|051d|Vendor ID for USB devices|NUMBER
EOF
)

setDefaultValues() {
  ups=()
  ups_desc=()
  ups_type=()
  while IFS='|' read -r key val desc type; do
    ups["$key"]="$val"
    ups_desc["$key"]="$desc"
    ups_type["$key"]="$type"
  done <<< "$ups_defaults"
}

getUpsValue() {
  local key="$1"
  echo "${ups[$key]:-}"
}

getUpsDesc() {
  local key="$1"
  echo "${ups_desc[$key]:-}"
}

getUpsType() {
  local key="$1"
  echo "${ups_type[$key]:-}"
}

setUpsValue() {
  local key="$1"
  local val="$2"
  ups["$key"]="$val"
}

# -------------------- Fetch Data from apcaccess --------------------

getFullData() {
  local interval=$((SECONDS - apcaccess_last_poll))
  [[ $interval -lt 10 ]] && return 0
  setDefaultValues
  local output
  output="$(apcaccess -h "$apcupsd_server" -u 2>/dev/null | sort || true)"
  [[ -z "$output" ]] && return 1
  apcaccess_last_poll=$SECONDS

  while IFS= read -r line; do
    param=$(cut -c1-9 <<< "$line" | sed 's/ *$//')
    value=$(cut -c12- <<< "$line" | sed 's/ *$//')
    case "$param" in
      APC)        ups[ups.productid]="$value" ;;
      BATTDATE)   ups[battery.date]="${value//-//}" ; ups[battery.mfr.date]="${value//-//}" ;;
      BATTV)      ups[battery.voltage]="$value" ;;
      BCHARGE)    ups[battery.charge]="${value%%.*}" ; [[ ${ups[battery.charge]} == "100" ]] && batt_not_full=0 || batt_not_full=1 ;;
      DLOWBATT)   ups[battery.runtime.low]="$(( ${value%%.*} * 60 ))" ;;
      DRIVER)     ups[driver.version.data]="$value" ;;
      DSHUTD)     ups[ups.delay.shutdown]="$value" ;;
      DWAKE)      ups[ups.delay.start]="$value" ;;
      FIRMWARE)   ups[ups.firmware]="${value%% USB FW:*}"; ups[ups.firmware.aux]="${value#* USB FW:}" ;;
      HITRANS)    ups[input.transfer.high]="$value" ;;
      ITEMP)      ups[ups.temperature]="$value" ; ups[battery.temperature]="$value" ;;
      LASTSTEST)  ups[ups.test.date]=$(date --date="$value" --iso-8601=minutes) ;;
      LASTXFER)   ups[input.transfer.reason]="$value" ;;
      LINEFREQ)   ups[input.frequency]="$value" ;;
      LINEV)      ups[input.voltage]="${value%% *}" ;;
      LOADAPNT)   ups[ups.load.apnt]="$value" ;;
      LOADPCT)    ups[ups.load]="${value%%.*}" ;;
      LOTRANS)    ups[input.transfer.low]="$value" ;;
      MANDATE)    ups[mfr.date]="$value" ; ups[ups.mfr.date]="$value" ;;
      MBATTCHG)   ups[battery.charge.low]="$value" ;;
      MAXLINEV)   ups[input.voltage.maximum]="$value" ;;
      MINLINEV)   ups[input.voltage.minimum]="$value" ;;
      MODEL)      ups[device.model]="$value" ; ups[ups.model]="$value" ;;
      NOMAPNT)    ups[ups.power.nominal]="${value%% *}" ;;
      NOMBATTV)   ups[battery.voltage.nominal]="${value%% *}" ;;
      NOMINV)     ups[input.voltage.nominal]="${value%% *}" ;;
      NOMOUTV)    ups[output.voltage.nominal]="$value" ;;
      NOMPOWER)   ups[ups.realpower.nominal]="$value" ;;
      OUTCURNT)   ups[output.current]="${value%% *}" ;;
      OUTPUTV)    ups[output.voltage]="$value" ;;
      SENSE)      ups[input.sensitivity]="$value" ;;
      SELFTEST)   getTestResult ;;
      SERIALNO)   ups[device.serial]="$value" ; ups[ups.serial]="$value" ; ups[driver.parameter.serial]="$value" ;;
      STATUS)     parseStatus "$value" ; ups[ups.status]="$ups_status" ;;
      TIMELEFT)   ups[battery.runtime]="$(( ${value%%.*} * 60 ))" ;;
      VERSION)    ups[driver.version.internal]="apcupsd $value" ;;
    esac
  done <<< "$output"

  [[ -z ${ups[battery.date]} ]] && ups[battery.date]="${ups[ups.mfr.date]}"
  [[ -z ${ups[ups.mfr.date]} ]] && ups[ups.mfr.date]="${ups[battery.date]}"
  getRealPowerNominal
}

# -------------------- Main Loop --------------------

main() {
#unset x
setDefaultValues

while :; do
  read -sr INSTRING || break
  nut_command="${INSTRING%%[[:cntrl:]]}"
  nut_command=${nut_command//[![:print:]]/}
  [[ -n "$nut_command" ]] && log "--> $nut_command"

  case "$nut_command" in
    "") echo ""
      ;;
    LOGIN*|USERNAME*|PASSWORD*) echo "OK" && log "<-- OK"
      ;;
    LOGOUT) log "<-- Logout received" ; break
      ;;
    STARTTLS) echo "ERR FEATURE-NOT-SUPPORTED" && log "<-- ERR FEATURE-NOT-SUPPORTED"
      ;;
    VER*) echo "UPS NUT Apcupsd Wrapper v${script_version}" && log "<-- UPS NUT Apcupsd Wrapper v${script_version}"
      ;;
    NETVER*|PROTVER*) echo "$protocol_version" && log "<-- $protocol_version"
      ;;
    "LIST UPS")
      echo "BEGIN LIST UPS" && log "<-- BEGIN LIST UPS"
      for ups_name in "${ups_names[@]}"; do
        echo "UPS $ups_name \"${ups[device.mfr]}\"" && log "<-- UPS $ups_name \"${ups[device.mfr]}\""
      done
      echo "END LIST UPS" && log "<-- END LIST UPS"
      ;;
    "LIST VAR"*)
      ups_name=$(awk '{print $3}' <<< "$nut_command")
      getFullData || { echo "ERR DRIVER-NOT-CONNECTED"; log "<-- ERR DRIVER-NOT-CONNECTED"; break; }
      echo "BEGIN LIST VAR $ups_name" && log "<-- BEGIN LIST VAR $ups_name"
      for key in $(printf '%s\n' "${!ups[@]}" | sort); do
        [[ -n "${ups[$key]}" ]] && echo "VAR $ups_name $key \"${ups[$key]}\"" && log "<-- VAR $ups_name $key \"${ups[$key]}\""
      done
      echo "END LIST VAR $ups_name" && log "<-- END LIST VAR $ups_name"
      ;;
    "GET VAR"*)
      ups_name=$(awk '{print $3}' <<< "$nut_command")
      nut_var=$(awk '{print $4}' <<< "$nut_command")
      getFullData || { echo "ERR DRIVER-NOT-CONNECTED"; break; }
      [[ "$nut_var" == "ups.status" ]] && getStatusData && ups[ups.status]="$ups_status"
      [[ "$nut_var" == "ups.test.result" ]] && getTestResult
      if [[ -v ups[$nut_var] ]]; then
        echo "VAR $ups_name $nut_var \"${ups[$nut_var]}\"" && log "<-- VAR $ups_name $nut_var \"${ups[$nut_var]}\""
      else
        echo "ERR VAR-NOT-SUPPORTED" && log "<-- ERR VAR-NOT-SUPPORTED"
      fi
      ;;
    "GET DESC"*)
      ups_name=$(awk '{print $3}' <<< "$nut_command")
      nut_var=$(awk '{print $4}' <<< "$nut_command")
      echo "DESC $ups_name $nut_var \"$(getUpsDesc "$nut_var")\"" && log "<-- DESC $ups_name $nut_var \"$(getUpsDesc "$nut_var")\""
      ;;
    "GET TYPE"*)
      ups_name=$(awk '{print $3}' <<< "$nut_command")
      nut_var=$(awk '{print $4}' <<< "$nut_command")
      echo "TYPE $ups_name $nut_var \"$(getUpsType "$nut_var")\"" && log "<-- TYPE $ups_name $nut_var \"$(getUpsType "$nut_var")\""
      ;;
    "GET UPSDESC"*)
      ups_name=$(awk '{print $3}' <<< "$nut_command")
      getFullData || { echo "ERR DRIVER-NOT-CONNECTED"; log "<-- ERR DRIVER-NOT-CONNECTED"; break; }
      echo "UPSDESC $ups_name \"${ups[device.model]}\"" && log "<-- UPSDESC $ups_name \"${ups[device.model]}\""
      ;;
    "LIST CLIENT"*)
      ups_name=$(awk '{print $3}' <<< "$nut_command")
      echo "BEGIN LIST CLIENT $ups_name" && log "<-- BEGIN LIST CLIENT $ups_name"
      echo "CLIENT $ups_name $TCPREMOTEIP" && log "<-- CLIENT $ups_name $TCPREMOTEIP"
      echo "END LIST CLIENT $ups_name" && log "<--- END LIST CLIENT $ups_name"
      ;;
    "LIST RW"*|"LIST CMD"*|"LIST ENUM"*)
      ups_name=$(awk '{print $3}' <<< "$nut_command")
      echo "BEGIN ${nut_command% *} $ups_name" && log "<-- BEGIN ${nut_command% *} $ups_name"
      echo "END ${nut_command% *} $ups_name" && log "<-- END ${nut_command% *} $ups_name"
      ;;
    *)
      echo "ERR UNKNOWN-COMMAND" && log "<-- ERR UNKNOWN-COMMAND"
      ;;
  esac
done
}

main
