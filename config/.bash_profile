# Check if the link exists in /tmp/gentoo
if [ ! -L /tmp/gentoo ]; then
  echo "Softlink to this Gentoo Prefix in /tmp/gentoo does not exist, creating it..."
  cd /tmp
  ln -s /home/nao/gentoo gentoo
fi

alias tree="tree -L 2"

MACHINE_IP=$(ifconfig eth0 2>/dev/null | grep 'inet ' | cut -d: -f3 | awk '{ print $2}')
if [ -z "$MACHINE_IP" ]
then
    MACHINE_IP=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | cut -d: -f3 | awk '{ print $2}')
    MACHINE_INTERFACE="wlan0"
else
    MACHINE_INTERFACE="eth0"
fi
export ROS_IP=$MACHINE_IP
export ROS_NETWORK_INTERFACE=$MACHINE_INTERFACE
export ROBOT_IP=$MACHINE_IP
export PEPPER_IP=$MACHINE_IP
export NAO_IP=$MACHINE_IP

# Detect robot model (nao vs pepper)
ROBOT_TYPE=$(qicli call ALMemory.getData "RobotConfig/Body/Type" 2>/dev/null | tr -d '"' | tr '[:upper:]' '[:lower:]' || echo "robot")
export ROBOT_TYPE

case $- in
    *i*) ;;
      *) return;;
esac

if grep -q /tmp/gentoo/bin/bash /proc/$$/cmdline ; then
    :
else
    EPREFIX=/tmp/gentoo
    SHELL=/tmp/gentoo/bin/bash
    echo "Entering ROS 2 Jazzy Prefix ${EPREFIX}"
    RETAIN="HOME=$HOME TERM=$TERM USER=$USER SHELL=$SHELL XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    [[ -n ${PROFILEREAD} ]] && RETAIN+=" PROFILEREAD=$PROFILEREAD"
    [[ -n ${SSH_AUTH_SOCK} ]] && RETAIN+=" SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
    [[ -n ${DISPLAY} ]] && RETAIN+=" DISPLAY=$DISPLAY"
    env -i $RETAIN $SHELL -l
fi

# SinfonIA Bringup and Driver aliases for both NAO and Pepper
alias nao_bringup="ros2 launch naoqi_bringup2_sinfonIA naoqi_full_bringup.launch.py nao_ip:=127.0.0.1"
alias pepper_bringup="ros2 launch naoqi_bringup2_sinfonIA naoqi_pepper_bringup.launch.py nao_ip:=127.0.0.1"
alias robot_bringup="if [ \"\$ROBOT_TYPE\" = \"nao\" ]; then nao_bringup; else pepper_bringup; fi"
alias naoqi_demo="ros2 run naoqi_bringup2_sinfonIA naoqi_capabilities_demo.py"

# Backward compatible driver aliases
alias nao_driver="nao_bringup"
alias pepper_driver="pepper_bringup"
alias robot_driver="robot_bringup"
alias raw_driver="ros2 launch naoqi_driver naoqi_driver.launch.py nao_ip:=127.0.0.1 network_interface:=$MACHINE_INTERFACE"

# Web services: WebSocket bridge (:9090 for roslibjs) and Video Streamer (:8080)
alias rosbridge="ros2 launch rosbridge_server rosbridge_websocket_launch.xml"
alias web_video="ros2 run web_video_server web_video_server"

alias web_services="ros2 launch rosbridge_server rosbridge_websocket_launch.xml & ros2 run web_video_server web_video_server"

alias pip='pip3'

# Commands for both NAO and Pepper
alias wake="qicli call ALMotion.wakeUp"
alias rest="qicli call ALMotion.rest"
alias straight="sh ~/.local/share/scripts/set_robot_straight.sh"
alias straight_pepper="sh ~/.local/share/scripts/set_my_pepper_straight.sh"
alias straight_nao="sh ~/.local/share/scripts/set_my_nao_straight.sh"
alias say="sh ~/.local/share/scripts/ALsay.sh"

# Source ROS 2 Jazzy (with fallback to Humble)
function jazzy(){
    if [ -f ~/ros2_jazzy/install/local_setup.bash ]; then
        . ~/ros2_jazzy/install/local_setup.bash
    elif [ -f ~/ros2_humble/install/local_setup.bash ]; then
        . ~/ros2_humble/install/local_setup.bash
    fi
    if [ -f ~/catkin_ros2/install/local_setup.bash ]; then
        . ~/catkin_ros2/install/local_setup.bash # naoqi_driver
    fi
}

jazzy

# Resolve shared library precedence between Python and ROS 2 libqi
export LD_LIBRARY_PATH=/tmp/gentoo/usr/lib/python3.11/site-packages/qi:$LD_LIBRARY_PATH

# Middleware (RMW) selection helpers
use_cyclone() {
    export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
    echo "Active ROS 2 Middleware: Eclipse CycloneDDS ($RMW_IMPLEMENTATION)"
}
use_fastrtps() {
    export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
    echo "Active ROS 2 Middleware: eProsima Fast DDS ($RMW_IMPLEMENTATION)"
}
