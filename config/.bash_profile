# Check if the link exists in /tmp/gentoo
if [ ! -L /tmp/gentoo ]; then
  echo "Softlink to this Gentoo Prefix in /tmp/gentoo does not exist, creating it..."
  cd /tmp
  ln -s /home/nao/gentoo gentoo
fi

alias tree="tree -L 2"
alias ..="cd .."
alias ll="ls -l"
alias cdws="cd ~/robobreizh_pepper_ws/"

splan(){
    rostopic pub /pnp/planToExec std_msgs/String \"data:\'$1\'\" -1
}

export ROS_LANG_DISABLE=genlisp:geneus

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

# Driver aliases for both NAO and Pepper
alias nao_driver="ros2 launch naoqi_driver naoqi_driver.launch.py nao_ip:=$ROS_IP network_interface:=$MACHINE_INTERFACE"
alias pepper_driver="ros2 launch naoqi_driver naoqi_driver.launch.py nao_ip:=$ROS_IP network_interface:=$MACHINE_INTERFACE"
alias robot_driver="ros2 launch naoqi_driver naoqi_driver.launch.py nao_ip:=$ROS_IP network_interface:=$MACHINE_INTERFACE"

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
alias vision_services="sh ~/.local/share/scripts/vision_services.sh"
alias say="sh ~/.local/share/scripts/ALsay.sh"

export PNP_LIBRARY=/home/nao/.local/bin/usr/local/lib/

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

# Backward compatibility alias
function humble(){
    jazzy
}

jazzy

# Resolve shared library precedence between Python and ROS 2 libqi
export LD_LIBRARY_PATH=/tmp/gentoo/usr/lib/python3.11/site-packages/qi:$LD_LIBRARY_PATH
