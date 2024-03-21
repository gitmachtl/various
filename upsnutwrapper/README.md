## Apcupsd NUT Wrapper Script (Apcupsd and NUT on the same machine)

&nbsp;<p>

### Why this little script?

Hi,

I had a problem. I have a Debian based Linux machine (works for Ubuntu or a Raspberry too) with an APC ups connected via USB cable (works also via ethernet client) running the lovely,
small and simple **apcupsd**. Also other PCs (running Windows) are connected to the same ups, so I installed **apcupsd** on Windows too and connected
it to the apcupsd on the Linux machine, fine. Then I needed an additional **NUT server** so I can hook up my **Synology/QNAP NAS** also to the same ups.
But, trying to install the complicated NUT-Server alongside **apcupsd** on the same linux machine was a pain. 

So, I wrote this little script that emulates a **NUT Server** and gets the values from `apcupsd/apcaccess`.

It is working great for me here and also in my company and for my friends, should work with other NUT Clients too not only Synology. Maybe someone finds it useful... 😄

Ciao Martin

&nbsp;<br>

### Description:

This little script emulates a **NUT-Server** together with the tiny tool "tcpserver"
from the ucspi-tcp package. It **needs** an installed and working **apcupsd** running on the machine
or on a remote machine. It is working fine with Synology/QNAP NAS for example (my usecase).

The script is simple and small and solves some problems having **apcupsd and a NUT-Server** on the
same machine. Use it if you like, but don't scream at me if it's doing something wrong.
Please feel free to make this script better, patches/pull requests are welcome if you're done. :-)

&nbsp;<br>

### Install / Running:

  1. You need an installed and running apcupsd on the same machine or on a remote machine.
     You also need apcaccess on this machine. Should be all fine if you installed apcupsd like:
     ``` console
     apt-get update && apt-get install apcupsd
     ```
     If you're not sure, please run the command
     ``` console
     apcaccess
     ```
     in the shell and see if you get your ups data. Or run
     ```console
     apcaccess -h <remoteip>
     ```
     to get the data of apcupsd running on a remotemachine with the IP `<remoteip>` (f.e. 192.168.1.10).

     &nbsp;<br>
  
  1. Copy the script `upsnutwrapper.sh` into the directory `/usr/local/bin/` and make it executable.
     You can simply run these commands to copy the script to the right location:
     ``` console
     wget https://raw.githubusercontent.com/gitmachtl/various/main/upsnutwrapper/upsnutwrapper.sh -O /usr/local/bin/upsnutwrapper.sh
     chmod +x /usr/local/bin/upsnutwrapper.sh
     ```
     &nbsp;<br>
  
  1. Install the ucspi-tcp package via
     ``` console
     apt-get update && apt-get install ucspi-tcp -y
     ```

  1. Start the NUT-Server-Wrapper by executing the following command via shell or a script:
     ``` console   
     tcpserver -q -c 10 -HR 0.0.0.0 3493 /usr/local/bin/upsnutwrapper.sh &
     ```

     This starts a listening tcp server on port 3493 (nut) with no binding (0.0.0.0), max. 10 simultanious connections.
     
     Another method is to simply put it into the `/etc/crontab` file so it starts with the system, just add an entry like:
     ```
     @reboot  <user>  tcpserver -q -c 10 -HR 0.0.0.0 3493 /usr/local/bin/upsnutwrapper.sh &
     ```
     Replace `<user>` with root or the user you want to run the script in the background.

&nbsp;<br>

### Config

There is not much configuration needed, it is working out of the box if `apcupsd/apcaccess` is running on the **localhost**.
However there are three lines in the script below the intro section where you can simply specify where `apcaccess` should get 
the information from the ups:
``` ini
APCUPSDSERVER="localhost"		#apcupsd is running on the same machine
#APCUPSDSERVER="127.0.0.1"		#apcupsd is running on the same machine
#APCUPSDSERVER="remoteip:3551"		#apcupsd is running on a remote machine with ip "remoteip" on the port "3551"
```

Also you can enable logging to a logfile via the following lines
``` ini
LOGGING=true				#set to 'true' to see incoming commands
LOG_FILE=/tmp/upsnutwrapper.log		#the location where logs are written to
```

Simply comment/uncomment what fits your installation. 

&nbsp;<br>

## ❤️ **Enjoy your apcupsd and "Nut Server" side by side on the same machine 😄**

&nbsp;<br>

### Details:
```
Script:       upsnutwrapper.sh
Author:       Martin (Machtl) Lang
E-Mail:       martin@martinlang.at
Github:       https://github.com/gitmachtl/various
Version:      1.8 (21.03.2024)
```
  
### History:
```
  1.0:	First working version "yeah"
  1.1:	Changed the "apcaccess" call and added the option "-u"
  1.2:	Added many parameters, First "release" version (15.02.2019)
  1.3:	Pushed onto the github repo, little typo corrections (06.01.2022)
  1.4:	Added logging and QNAP support, cleaned up code
  1.5:  Better connection error handling, added some parameters
  1.6:  Added command "GET UPSDESC <upsname>"
  1.7:  Added command "GET DESC <upsname> <varname>" and all the descriptions for the variables
  1.8:  Added commands "VER", "NETVER", "PROTVER", "LIST CLIENT", "LIST RW", "LIST CMD", "LIST ENUM"
```
