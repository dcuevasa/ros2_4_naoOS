# ros2_4_naoOS: ROS 2 Jazzy for NAO & Pepper

Containerized and native environment bringing **ROS 2 Jazzy Jalisco** and **`naoqi_driver2`** directly onboard SoftBank Robotics' **NAO (V5/V6)** and **Pepper (1.8/2.5)** humanoid robots.

> [!TIP]
> **Complete Documentation Wiki**: In-depth architecture guides, build pipeline details, embedded AI walkthroughs, and troubleshooting are available in the [Project Wiki](https://github.com/dcuevasa/ros2_4_naoOS/wiki) (or in the local `ros2_4_naoOS.wiki` directory).

---

## Table of Contents

- [ros2\_4\_naoOS: ROS 2 Jazzy for NAO \& Pepper](#ros2_4_naoos-ros-2-jazzy-for-nao--pepper)
  - [Table of Contents](#table-of-contents)
  - [Overview \& Dual-Robot Support](#overview--dual-robot-support)
  - [Environment Setup \& Recommendation](#environment-setup--recommendation)
  - [Pre-compiled Release Image](#pre-compiled-release-image)
  - [Building from Source (Docker)](#building-from-source-docker)
  - [Compressing Deployment Archive](#compressing-deployment-archive)
  - [Installation on NAO / Pepper](#installation-on-nao--pepper)
  - [Testing ROS 2 Jazzy](#testing-ros-2-jazzy)
  - [Running naoqi\_driver2](#running-naoqi_driver2)
    - [Starting the Driver](#starting-the-driver)
    - [Inspecting Topics](#inspecting-topics)
    - [Remote PC Visualization (RViz2)](#remote-pc-visualization-rviz2)
  - [Robot Posture \& Control Helpers](#robot-posture--control-helpers)
  - [Acknowledgment](#acknowledgment)

---

## Overview & Dual-Robot Support

This project packages an isolated **Gentoo Prefix 32-bit sysroot** that installs into `/home/nao/gentoo` and maps to `/tmp/gentoo`. This enables running modern **ROS 2 Jazzy Jalisco**, **GCC 11.4**, **Python 3.11**, and embedded ML engines (ONNX Runtime, TensorFlow Lite, Vosk/Kaldi) on the robot's 32-bit Intel Atom CPU without altering the robot's factory NAOqi OS firmware.

### Supported Hardware:
* **SoftBank Robotics Pepper**: Versions 1.8, 1.8a, and 2.5 (NAOqi OS 2.5.5.5 / 2.5.10).
* **SoftBank Robotics NAO**: Versions V5 and V6 (NAOqi OS 2.1.4, 2.5.x, 2.8.x).

The runtime auto-detects whether it is running on a NAO or a Pepper via `ALMemory` (`RobotConfig/Body/Type`) and dynamically applies the appropriate joint configs, posture transitions, and network bindings.

---

## Environment Setup & Recommendation

Set your robot's IP on your workstation and in your shell configuration:

```bash
export ROBOT_IP=x.x.x.x     # (e.g. 192.168.1.150)
export PEPPER_IP=$ROBOT_IP  # Alias for Pepper
export NAO_IP=$ROBOT_IP     # Alias for NAO
```

Add this export to your development machine's `~/.bashrc` or `~/.zshrc`. For clarity, this documentation refers to `$ROBOT_IP`.

---

## Pre-compiled Release Image

A plug-and-play archive is hosted on Google Drive:
* **Download**: [nao_os_jazzy.tar.lzma (Google Drive)](https://drive.google.com/file/d/1pW4Q36QXR29MyWEb5wtkeABo-9eMvh5G/view?usp=sharing)
* Size: ~2.1 GB compressed (expands to ~8.0 GB on ext3).

Once downloaded, proceed directly to [Installation on NAO / Pepper](#installation-on-nao--pepper).

---

## Building from Source (Docker)

To compile the entire ROS 2 Jazzy environment using Docker:

1. Ensure the base prefix archive `gentoo_prefix_base.tar.lzma` is present (generated from `gentoo_prefix_32b/` via `Dockerfile.base_build`).
2. Build the Docker image:

```bash
# Default build (Pepper base image)
docker build -t nao_os_jazzy:latest .

# Alternatively, target a NAO-specific base container
docker build --build-arg BASE_IMAGE=awesomebytes/pepper_2.5.5.5 -t nao_os_jazzy:latest .
```

---

## Compressing Deployment Archive

The complete environment expands to ~8 GB and is compressed with parallel LZMA (`pxz`) down to ~2 GB to fit easily onto the robot's internal storage:

```bash
# Start container
docker run -it nao_os_jazzy:latest

# In a separate host terminal, extract the archive:
docker cp CONTAINER_ID:/data/home/nao/nao_os_jazzy.tar.lzma ./nao_os_jazzy.tar.lzma
```

*(Note: `pepper_os.tar.lzma` is symlinked to `nao_os_jazzy.tar.lzma` for complete backward compatibility).*

---

## Installation on NAO / Pepper

1. Check available disk space on the robot (minimum **8 GB free** required in `/home`):
   ```bash
   ssh nao@$ROBOT_IP "df -h /home"
   ```

2. Transfer and extract the archive on the robot:
   ```bash
   # Copy archive to robot
   scp nao_os_jazzy.tar.lzma nao@$ROBOT_IP:/home/nao/

   # SSH into robot
   ssh nao@$ROBOT_IP

   # Extract directly in /home/nao
   cd /home/nao
   tar -J -xvf ./nao_os_jazzy.tar.lzma

   # Remove compressed archive to recover ~2 GB space
   rm ./nao_os_jazzy.tar.lzma
   ```

3. Log out and reconnect via SSH. The updated `.bash_profile` will automatically activate the Gentoo Prefix environment and source ROS 2 Jazzy (`Entering ROS 2 Jazzy Prefix /tmp/gentoo`).

---

## Testing ROS 2 Jazzy

Verify inter-process communication using the built-in C++ demo nodes:

**Terminal 1 (Publisher):**
```bash
ssh nao@$ROBOT_IP
ros2 run demo_nodes_cpp talker
```

**Terminal 2 (Subscriber):**
```bash
ssh nao@$ROBOT_IP
ros2 run demo_nodes_cpp listener
```

You can also test Python nodes with `demo_nodes_py`.

---

## Running naoqi_driver2

### Starting the Driver
Start the hardware driver directly using the pre-configured aliases:

```bash
ssh nao@$ROBOT_IP

# Universal driver alias (auto-detects NAO vs Pepper and active network interface)
robot_driver

# Or use specific aliases
nao_driver     # For NAO
pepper_driver  # For Pepper
```

Or invoke ROS 2 launch manually:
```bash
ros2 launch naoqi_driver naoqi_driver.launch.py \
  nao_ip:=$ROBOT_IP \
  network_interface:=$ROS_NETWORK_INTERFACE
```

### Inspecting Topics
In a separate terminal on the robot:
```bash
ros2 topic list
```

Available topics include:
* `/naoqi_driver/joint_states` (50 Hz encoder readings for all joints)
* `/naoqi_driver/camera/front/image_raw` & `/camera/bottom/image_raw`
* `/naoqi_driver/laser` & `/sonar`
* `/naoqi_driver/imu/torso`
* `/cmd_vel` (omni-directional mobile base teleop on Pepper / walking on NAO)

### Remote PC Visualization (RViz2)
On an external workstation running Ubuntu 24.04 with ROS 2 Jazzy:

```bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=0  # Matches robot domain ID

# Verify robot topics are visible
ros2 topic list

# Launch RViz2
rviz2
```

In RViz2, add topic displays for cameras, laser scans, and coordinate frames (`/tf`).

---

## Robot Posture & Control Helpers

Pre-configured shell helpers available on both NAO and Pepper:

```bash
# Wake up and engage joint motors
wake

# Re-align posture to upright zero-angle configuration (auto-detects NAO vs Pepper)
straight

# Dedicated posture calibration
straight_nao     # Executes StandInit and zeros head for NAO
straight_pepper  # Zeros head, hip, and knee joints for Pepper

# Relax motors to crouching resting posture
rest

# Text-to-speech through onboard speakers
say "Hello! I am running ROS 2 Jazzy Jalisco."
```

---

## Acknowledgment

This project is heavily inspired by the pioneering work of [Sam Pfeiffer](https://github.com/awesomebytes) on [ros_overlay_on_gentoo_prefix_32b](https://github.com/awesomebytes/ros_overlay_on_gentoo_prefix_32b).