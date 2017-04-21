#!/bin/sh
#This script represents the part 2 of 2 in accesscore's configuration process

#Execute as root
ROOTUID="0"

if [ "$(id -u)" -ne "$ROOTUID" ] ; then
    echo "This script must be executed with root privileges."
    exit 1
fi

clear
echo "Welcome to Accesscore's configuration part 2 of 2, press enter to continue"
read x

#Verify internet connection
wget -q --spider http://google.com
if ! [ $? -eq 0 ]; then
      echo "###\nIt was not possible to reach an internet connection"
      echo "Please review your network configuration\n###\n"
      exit
else
      echo "###\nInternet connection reached, allowed to continue...\n###\n"
fi

###Some Configurations###

#Configuring monit
echo '###\nConfiguring monit to monitoring...\n###\n'
if [ -f /etc/monit/monitrc]; then
        mv /etc/monit/monitrc /etc/monit/monitrc-ORING
fi 
echo '# monit rules
set daemon 30
set logfile /var/log/monit.log
# e-mail alerts
#set alert email@domain.com
set httpd
        port 2812
        use address 172.16.17.47        # only accept connection from localhost
        allow 172.16.0.0/0.0.0.0        # allow localhost to connect to the server
        allow pi:raspberry              # require user : password
# check mono
check process mono with pidfile /home/pi/deploy/accesscore.pid
        start program = "/bin/sh -c "'"/home/pi/deploy/start.sh"'""
        stop program = "/bin/sh -c "'"/home/pi/deploy/stop.sh"'""
# check monit
check process monit with pidfile /var/run/monit.pid
        start program = "/etc/init.d/monit start"
        stop program = "/etc/init.d/monit stop"
# include files for individual sites
#Include /etc/monit/monitrc.d/*.cfg' > /etc/monit/monitrc
chmod 600 /etc/monit/monitrc

#Create start and stop sh
echo '###\nCreating start...\n###\n'
echo '#!/bin/sh -e
#This script must end with exit 0
#Start Accesscore
mono /home/pi/deploy/Unosquare.AccessCore.Client.exe &
echo $! > /home/pi/deploy/accesscore.pid &
#Reload monit
monit reload
exit 0' > /home/pi/deploy/start.sh
chmod +x /home/pi/deploy/start.sh

echo '###\nCreating stop...\n###\n'
echo '#!/bin/sh -e
#This script must end with exit 0
#Stop Accesscore
pkill -f  mono
exit 0' > /home/pi/deploy/stop.sh
chmod +x /home/pi/deploy/stop.sh

#Start monit at boot
#Monit will start mono and keep monitoring it
echo '###\nConfiguring system to start application automatically...\n###\n'
if [ -f /etc/rc.local ]; then
        cp /etc/rc.local /etc/rc.local.copy
        > /etc/rc.local
fi
echo '#!/bin/sh -e\n#This script must end with exit 0\n\n#Start Monit\nmonit\nexit 0' >> /etc/rc.local
echo '###\nMonit successfully configured\n###\n'

#Open chromium automatically
echo '###\nConfiguring system to open chromium automatically and removing unnecessary desktop elements...\n###\n'
if [ -f /home/pi/.config/lxsession/LXDE/autostart ]; then
        cp /home/pi/.config/lxsession/LXDE/autostart /home/pi/.config/lxsession/LXDE/autostart.copy
        echo '@chromium-browser --kiosk --incognito http://localhost:9898 &' > /home/pi/.config/lxsession/LXDE/autostart &&
        echo '###\nSuccessfully configured\n###\n'
else
        echo "###\nIt was not possible to configure autostart of chromium, please fix this before continue\n###\n"
        exit
fi

#Configure display settings
echo  '###\nConfiguring touchscreen...\n###\n'
if grep --quiet hdmi_cvt /boot/config.txt; then
        echo '###\nDisplay settings already detected\n###\n'
else
        echo '\n#Touchscreen Configurations\nmax_usb_current=1\nhdmi_group=2\nhdmi_mode=87\nhdmi_cvt 1024 600 60 6 0 0 0' >> /boot/config.txt
        echo '###\nSuccessful display configuration\n###\n'
fi

#Move cursor to avoid button hovering
echo '###\nConfiguring cursor...\n###\n'
if grep --quiet moveCursor.sh /home/pi/.config/lxsession/LXDE/autostart; then
        echo '###\nCursor settings already detected\n###\n'
else
        apt-get install -qq -y xdotool
        echo "#!/bin/sh
export DISPLAY=':0.0'
while [ true ]
do
        xdotool mousemove 1024 0
        sleep 1
done
" > /home/pi/Documents/moveCursor.sh && chmod o+x /home/pi/Documents/moveCursor.sh
        echo '@/home/pi/Documents/moveCursor.sh &' >> /home/pi/.config/lxsession/LXDE/autostart
        echo '###\nSuccessful cursor configuration\n###\n'
fi

#Animation during boot
URL="https://github.com/edmundormz/TestingRaspDocumentation/blob/master/accesscore_mp4.mp4?raw=true"
Animation_Route="/home/pi/Pictures/boot_animation.mp4"
if ! [ -f $Animation_Route ]; then
        wget -O $Animation_Route $URL
fi
if ! [ -f $Animation_Route ]; then
        echo '###\n[WARNING] Could not get animation from $URL\n###\n'
fi
apt-get install -qq -y omxplayer
echo '#!/bin/sh
### BEGIN INIT INFO
# Provides:             asplashscreen
# Required-Start:
# Required-Stop:
# Should-Start:
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    Show custom splashscreen
# Description:          Show custom splashscreen
### END INIT INFO
do_start(){
        omxplayer -b /home/pi/Pictures/boot_animation.mp4 &
        exit 0
}
case "$1" in
        start|"")
        do_start
        ;;
        restart|reload|force-reload)
        echo "Error: argument "$1" not supported" >&2
        exit 3
        ;;
        stop)
        # No-op
        ;;
        status)
        exit 0
        ;;
        *)
        echo "Usage: asplashscreen [start|stop]" >$2
        exit 3
        ;;
esac' > /etc/init.d/asplashscreen
chmod a+x /etc/init.d/asplashscreen
cd /etc/init.d/
insserv asplashscreen
cd
echo "###\nBoot animation successfully configured\n###"

#Clean up boot process commands
cp /boot/cmdline.txt /boot/cmdline.txt.copy
content=`cat /boot/cmdline.txt.copy`
echo "$content logo.nologo consoleblank=0 loglevel=1 quiet" > /boot/cmdline.txt

###Some tweaks###

echo "###\nWe're about to finish, just some tweaks before\n###\n"

#Set Unosquare Labs logo as desktop background
URL2="https://raw.githubusercontent.com/edmundormz/TestingRaspDocumentation/master/unolabs_1024x600.png"
ImageRoute2="/home/pi/Pictures/desktop_wallpaper.png"
if ! [ -f $ImageRoute2 ]; then
        wget -O $ImageRoute2 $URL2
fi
if ! [ -f $ImageRoute ]; then
        echo '###\n[WARNING] Could not get image from $URL\n###\n'
        exit
else
        cp /home/pi/.config/pcmanfm/LXDE/desktop-items-0.conf /home/pi/.config/pcmanfm/LXDE/desktop-items-0.conf.copy
        sed -i '4 d' /home/pi/.config/pcmanfm/LXDE/desktop-items-0.conf
        sed -i 's/show_trash=1/show_trash=0/g' /home/pi/.config/pcmanfm/LXDE/desktop-items-0.conf
        echo "wallpaper=$ImageRoute2" >> /home/pi/.config/pcmanfm/LXDE/desktop-items-0.conf
        echo '@pcmanfm --desktop --profile LXDE' >> /home/pi/.config/lxsession/LXDE/autostart
        echo "###\nDesktop wallpaper configured\n###\n"
fi

#Hide cursor and configure autologin
if ! [ -f /etc/lightdm/lightdm.conf ]; then
        echo '###\n[WARNING]There is no /etc/lightdm/lightdm.conf file, please fix this\n###\n'
        exit
else
        sed -i 's/#xserver-command=X/xserver-command=X -nocursor -s 0/g' /etc/lightdm/lightdm.conf
        sed -i 's/#autologin-user=/autologin-user=pi/g' /etc/lightdm/lightdm.conf
fi

#Remove undervoltage signal
echo '###\nRemoving undervoltage signal...\n###\n'
if grep --quiet avoid_warnings=1 /boot/config.txt; then
        echo '###\nUndervoltage signal already removed\n###\n'
else
        echo '\n#Remove undervoltage warning\navoid_warnings=1' >> /boot/config.txt &&
        echo '###\nWarning removed\n###\n'
fi

#enable serial comunication
echo '###\nEnabling serial comunication...\n###\n'
if grep --quiet enable_uart=1 /boot/config.txt; then
        echo '###\nSerial comunication already enabled\n###\n'
else
        echo '\n#Enable serial comunication\nenable_uart=1' >> /boot/config.txt &&
        echo '###\nSerial comunication enabled\n###\n'
fi

#Make available serial port for fingerprint
sed -i 's/console=serial0,115200//g' "/boot/cmdline.txt"

#Enable camera interface
echo "###\nEnabling camera...\n###"
if grep --quiet start_x=1 /boot/config.txt; then
        echo '###\nCamera already configured\n###'
else
        echo '\n#Enable camera\nstart_x=1\ngpu_mem=128' >> /boot/config.txt
        echo '###\nCamera enabled\n###'
fi

#Creating Sentinel script
echo '#! /bin/bash
#Centinela script check if mono and chromium are running...
case "$(pidof mono | wc -w)" in
0) echo "Restatarting AccessCore:        $(date)" >> /home/pi/centinelaLog.txt
   mono /home/pi/deploy/Unosquare.AccessCore.Client.exe &
   ;;
1) # all Ok
   ;;
*) echo "Removed multiple AccessCore instances: $(date)" >> /home/pi/centinelaLog.txt
   while [ $(pidof mono | wc -w) -ne 1 ]
   do
       kill -kill $(pidof mono | awk "{print $1}")
   done
   ;;
esac
case "$(pidof chromium-browser | wc -w)" in
0) echo "Restatarting chromium-browser instances: $(date)" >> /home/pi/centinelaLog.txt
   chromium-browser --kiosk --incognito http://localhost:9898 &
   ;;
1) # all Ok
   ;;
*)  echo "Removed multiple Chrome: $(date)" >> /home/pi/centinelaLog.txt
    while [ $(pidof chromium-browser | wc -w) -ne 1 ]
    do
        kill -kill $(pidof chromium-browser | awk "{print $1}")
    done
    ;;
esac' >> /etc/cron.hourly/Sentinel.sh
chmod a+x /etc/cron.hourly/Sentinel.sh
#Configuring cron

sed -i 's | 17 *   * * *   root    cd / && run-parts --report /etc/cron.hourl | */1 *   * * *   root    cd / && run-parts --report /etc/cron.hourly |g' "/etc/crontab"

echo "###System successfuly configured to operate as an Accesscore's Access Control Point"
echo "Connect the touchscreen, fingerprint reader and relay-board after the system turns off"
echo "Then turn on the system and meet the Unosquare's innovation\n###\n"

echo "Press enter to turn off the system"
read x
echo "Shutting down system"
sleep 5
halt
