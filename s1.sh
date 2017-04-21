#!/bin/sh
#This script represents the part 1 of 2 in accesscore's configuration process

#Execute as root
ROOTUID="0"

if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    echo "This script must be executed with root privileges."
    exit 1
fi

clear
echo "Welcome to Accesscore's configuration part 1 of 2, press enter to continue"
read x

#Set rasp's hostname according to the Access Control Point location
hostname=`cat /etc/hostname`
if [ "$hostname" = "raspberrypi" ]; then
        echo "###\nWould you like to set the name of this Access Control Point? (y/n)\n###\n"
        read a
        if [ "$a" = "y" ]; then
                echo "Type the name of this ACP"
                read hostname
                cp /etc/hostname /etc/hostname.copy
                echo "$hostname" > /etc/hostname
                echo "Now this Access Control Point will be identified as '$hostname'\n###\n"
        else
                continue
        fi
fi

#Function to set a new password
change_password () {
echo "###\nFor security reasons, it's recommended to set a new password, you will be asked for this credentials upon next boot\n###\n"
p1="password"
p2="password"
echo "Type the new password"
read p1
echo "Confirm the new password"
read p2

while ! [ "$p1" = "$p2" ]
do
        echo "###\n[WARNING]Passwords don't match, retype passwords\n###\n"
        read p1
        echo "Confirm password"
        read p2
done
echo "pi:$p2" | chpasswd
echo "###\nPassword has changed, remember it\n###\n"
}

#Function to check if still using default user and password
check_credentials ()
{
   if ! id -u pi > /dev/null 2>&1 ; then return 0 ; fi
   if grep -q "^PasswordAuthentication\s*no" /etc/ssh/sshd_config ; then return 0 ; fi
   test -x /usr/bin/mkpasswd || return 0
   SHADOW="$(sudo -n grep -E '^pi:' /etc/shadow 2>/dev/null)"
   test -n "${SHADOW}" || return 0
   if echo $SHADOW | grep -q "pi:!" ; then return 0 ; fi
   SALT=$(echo "${SHADOW}" | sed -n 's/pi:\$6\$//;s/\$.*//p')
   HASH=$(mkpasswd -msha-512 raspberry "$SALT")
   test -n "${HASH}" || return 0

   if echo "${SHADOW}" | grep -q "${HASH}"; then
		change_password
                unset change_password
   fi
}

#Check for credentials status and change password if required
if service ssh status | grep -q running; then
	check_credentials
        unset check_credentials
fi


#Configure WiFi connection
#Works for WPA2 networks

if ! grep --quiet network /etc/wpa_supplicant/wpa_supplicant.conf; then
        echo "###\nThis Access Control Point requires wireless internet access"
        flag=0
        while ! [ $flag = 1 ]
        do
                echo "Type the name of the wireless network you want to connect this device to:"
                read ssid
                echo "Type the password for $ssid:"
                read psk
                echo "Is this information correct?: (y/n)"
                echo "Wireless Network: $ssid \nPassword: $psk\n###"
                read c
                if [ "$c" = "y" -o "$c" = "" ]; then
                        flag=1
                fi
        done
        echo "\n###\nConfiguring WiFi connection...\n###\n"
        if ! [ -f /etc/wpa_supplicant/wpa_supplicant.conf.copy ]; then
                cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf.copy
        fi
        echo 'network={\n\tssid="'$ssid'"\n\tpsk="'$psk'"\n\t}' >> /etc/wpa_supplicant/wpa_supplicant.conf &&
        echo '###\nWireless network configured\n###\n'
fi

#Turn off eth0 interface, then test wireless internet connection.
echo "###\nIn order to verify wireless internet access, ethernet connection will be disabled. If you have a wired network connetion
to the device, the connection will be lost. Would you like to execute this test? (y/n)\n###\n"
read w
way="ethernet"
if [ "$w" = "y" -o "$w" = ""]; then
        echo "Ethernet connection disabled\n"
        ifconfig eth0 down
        way="wireless"
else
        echo "Ethernet connection is still active\n"
fi
echo '###\nTesting internet connection...\n###\n'

for i in 1 2 3
do
        wget -q --spider http://google.com
        if ! [ $? -eq 0 ]; then 
                ifdown wlan0
                sleep 1
                ifup wlan0
                sleep 3
        else
                echo "###\nInternet access detected on $way connection\n###\n"
                break
        fi
done

wget -q --spider http://google.com
if ! [ $? -eq 0 ]; then
      echo "###\nIt was not possible to reach an internet connection"
      echo "Please review your network configuration\n###\n"
      exit
fi

#Print ip and ask for deploy
_IP=$(hostname -I) || true
if [ "$_IP" ]; then
  echo "###\nInternet access detected"
  echo "My IP address is " "$_IP"
fi

echo 'Please deploy Accesscore files to /home/pi/deploy directory'
echo 'May I continue with the process? (type "y")\n###\n'
read response
if [ "$response" = "y" -o "$response" = "" ]; then
        #Verify Accesscore's files are already deployed in the system
        if ! [ -f /home/pi/deploy/Unosquare.AccessCore.Client.exe ]; then
                echo '###\n[WARNING] There is no /home/pi/deploy/Unosquare.AccessCore.Client.exe file'
                echo 'Please deploy Accesscore files and then re-run this script\n###'
                exit
        fi
else
        echo '###\nInvalid answer, please re-run the process\n###'
        exit
fi

#System update required
echo "###\nNow a system update will be applied, this may take a while, get some coffee"
echo "Press enter to continue\n###"
read x
apt-get update -y && apt-get upgrade -y

echo "###\nSystem has been updated, next several packages will be installed"
echo "Press enter to continue\n###"
read x

#Monit Installation
echo "###\nInstalling monit...\n###"
apt-get install -qq -y monit
echo "###\nVerifying monit...\n"
monit --version

#Mono instalation
echo "###\nInstalling mono...\n###"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
echo "deb http://download.mono-project.com/repo/debian beta main" | sudo tee /etc/apt/sources.list.d/mono-xamarin-beta.list
apt-get update
apt-get install -qq -y mono-runtime libmono-system-core4.0-cil libmono-system-data-linq4.0-cil libmono-system-componentmodel-dataannotations4.0-cil libmono-system-servicemodel-discovery4.0-cil libmono-http4.0-cil libmono-system-net-http4.0-cil
echo "###\nVerifying mono version...\n"
mono --version
echo "###\n"

#Chromium instalation
echo "###\nInstalling chromium-browser...\n###"
apt-get install -qq -y chromium-browser
echo "###\nVerifying chromium...\n"
chromium-browser --version
echo "###\n"

#Install graphical enviroment
echo "###\nInstalling Graphical User Interface components...\n###"
#Install Xorg Server Display
apt-get install -qq -y xserver-xorg
# Install LXDE Desktop
sudo apt-get install -qq -y lxde-core
#Install lightdm session manager
apt-get install -qq -y lightdm

echo "\n###\nThe first part of the process has been completed, now a reboot is required"
echo "The system will start in graphical mode so you may connect a screen, you need to open a terminal and execute accesscore_2.sh script to complete the process"
echo "Press enter to reboot the system\n###"
read x
echo "Rebooting..."
sleep 5
reboot
