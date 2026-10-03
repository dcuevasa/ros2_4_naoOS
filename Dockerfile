ARG BASE_IMAGE=awesomebytes/pepper_2.5.5.5
FROM ${BASE_IMAGE}

USER nao
WORKDIR /home/nao

# Loading the base prefix archive
COPY --chown=nao:nao gentoo_prefix_base.tar.lzma ./gentoo_prefix_base.tar.lzma
RUN (tar -J -xf gentoo_prefix_base.tar.lzma 2>/dev/null || tar --lzma -xf gentoo_prefix_base.tar.lzma 2>/dev/null || tar -xf gentoo_prefix_base.tar.lzma) && \
    rm -f gentoo_prefix_base.tar.lzma

# Fix permissions of tmp
USER root
RUN chmod a=rwx,o+t /tmp
USER nao

# Prepare environment to run everything in the prefixed shell
RUN cd /tmp && ln -sf /home/nao/gentoo gentoo && \
    cp /etc/group /tmp/gentoo/etc/group || true && \
    cp /etc/passwd /tmp/gentoo/etc/passwd || true

# To allow the use of the $EPREFIX variable
RUN sed -i 's/SHELL=$SHELL"/SHELL=$SHELL EPREFIX=$EPREFIX"/' /tmp/gentoo/executeonprefix

# Switch shell so subsequent RUN commands execute inside prefix
SHELL ["/tmp/gentoo/executeonprefix"]

# Configure compilation parallelism based on host cores
RUN sed -i -e 's/j1/j'"$((`grep -c \^processor \/proc\/cpuinfo` / 2))"'/g' $EPREFIX/etc/portage/make.conf 2>/dev/null || true
RUN sed -i 's/EMERGE_DEFAULT_OPTS=.*//' $EPREFIX/etc/portage/make.conf 2>/dev/null || true && \
    echo "EMERGE_DEFAULT_OPTS=\"--jobs $((`grep -c \^processor \/proc\/cpuinfo` / 2)) --load-average `grep -c \^processor \/proc\/cpuinfo`\"" >> $EPREFIX/etc/portage/make.conf

# Clean up any conflicting python3.12 binaries
RUN rm -rf /tmp/gentoo/usr/bin/python3.12 /tmp/gentoo/usr/bin/python3.12-config 2>/dev/null || true

# Clean up any old ROS 1 / Humble workspaces if present from base archive
RUN rm -rf /home/nao/ros2_humble /home/nao/catkin_ros2 2>/dev/null || true

# Purge any heavy AI packages from base image to keep image lean and fast
RUN pip uninstall -y onnxruntime tflite_runtime spacy transformers torch vosk kaldi 2>/dev/null || true
RUN rm -rf /home/nao/.local/kaldi /home/nao/.local/vosk-api 2>/dev/null || true

# Install qibuild if not already present
RUN if [ ! -d /home/nao/.local/qibuild ]; then \
        mkdir -p /home/nao/.local && \
        cd /home/nao/.local && \
        git clone https://github.com/aldebaran/qibuild.git && \
        cd qibuild && \
        python -m pip install -e . ; \
    fi

# Build and install libqi (C++17) if not already installed
RUN if [ ! -f /tmp/gentoo/usr/lib/libqi.so ]; then \
        mkdir -p /home/nao/.local && \
        cd /home/nao/.local && \
        git clone https://github.com/aldebaran/libqi.git -b qi-framework-v3.0.0 && \
        cd libqi && \
        mkdir -p build && cd build && \
        cmake .. -DQI_WITH_TESTS=OFF -DCMAKE_PREFIX_PATH=/home/nao/.local/qibuild/cmake/qibuild -DCMAKE_INSTALL_PREFIX=/tmp/gentoo/usr -DCMAKE_CXX_FLAGS='-std=c++17' && \
        make -j$((`grep -c \^processor \/proc\/cpuinfo` / 2 + 1)) && \
        make install ; \
    fi

# Install libqi-python from wheel
ADD wheels/qi-3.1.0-cp311-cp311-linux_i686.whl /tmp/gentoo/qi-3.1.0-cp311-cp311-linux_i686.whl
RUN pip install /tmp/gentoo/qi-3.1.0-cp311-cp311-linux_i686.whl && rm -f /tmp/gentoo/qi-3.1.0-cp311-cp311-linux_i686.whl

# Install psutil and tornado required by ros2cli and rosbridge_server
ADD wheels/psutil-7.1.1-cp36-abi3-manylinux_2_12_i686.manylinux2010_i686.manylinux_2_17_i686.manylinux2014_i686.whl /tmp/gentoo/
ADD wheels/tornado-6.5.4-cp39-abi3-manylinux_2_5_i686.manylinux1_i686.manylinux_2_17_i686.manylinux2014_i686.whl /tmp/gentoo/
RUN pip install /tmp/gentoo/psutil-*.whl /tmp/gentoo/tornado-*.whl && rm -f /tmp/gentoo/psutil-*.whl /tmp/gentoo/tornado-*.whl

# Ensure core scientific/kinematic library orocos_kdl and media dependencies (ffmpeg, tmux, tree) are present
RUN emerge sci-libs/orocos_kdl media-libs/dav1d media-video/ffmpeg app-misc/tmux app-text/tree

# Download and compile ROS 2 Jazzy Jalisco
RUN mkdir -p ~/ros2_jazzy/src && \
    cd ~/ros2_jazzy && \
    vcs import --input https://raw.githubusercontent.com/ros2/ros2/jazzy/ros2.repos src && \
    # Remove packages that do not support 32-bit (Iceoryx, GUI tools, visualization, tests, Connext)
    rm -rf src/eclipse-iceoryx src/ros-visualization src/ros2/rviz \
           src/ros/ros_tutorials/turtlesim src/ros2/geometry2/tf2_bullet src/ros2/geometry2/test_tf2 \
           src/ros2/mimick_vendor src/ros2/ros2_tracing/lttngpy src/ros2-rust \
           src/ros2/demos src/ros2/examples src/ros2/system_tests src/ros2/performance_test_fixture \
           src/ros2/rmw_connextdds src/ros2/tlsf \
           src/gazebo-release src/ros2/orocos_kdl_vendor/python_orocos_kdl_vendor \
           src/ros2/realtime_support && \
    # Strip Iceoryx 64-bit shm dependency from rmw_cyclonedds_cpp for 32-bit x86 compatibility
    sed -i '/iceoryx_binding_c/d' src/ros2/rmw_cyclonedds/rmw_cyclonedds_cpp/package.xml && \
    cd src && git clone https://github.com/ptrmu/ros2_shared.git 2>/dev/null || true && cd .. && \
    colcon build --symlink-install --cmake-args \
        -DBUILD_TESTING=OFF \
        -DENABLE_SHM=OFF \
        -DCMAKE_SHARED_LINKER_FLAGS="-latomic" \
        -DTRACETOOLS_DISABLED=ON \
        -DTRACETOOLS_STATUS_CHECKING_TOOL=OFF \
        -DLTTNGPY_DISABLED=ON

# Download and build naoqi_bringup2_sinfonIA stack, rosbridge_suite (WebSocket), and web_video_server (HTTP video stream)
RUN . ~/ros2_jazzy/install/local_setup.bash && \
    mkdir -p ~/catkin_ros2/src && \
    cd ~/catkin_ros2/src/ && \
    git clone https://github.com/SinfonIAUniandes/naoqi_driver2_sinfonIA.git && \
    git clone --branch ros2 https://github.com/ros-drivers/audio_common.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_utilities_msgs.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_manipulation.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_miscellaneous.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_navigation.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_perception.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_speech.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_interface.git && \
    git clone https://github.com/SinfonIAUniandes/naoqi_bringup2_SinfonIA.git && \
    git clone --branch rolling https://github.com/ros-perception/vision_opencv && \
    git clone --branch release/jazzy/naoqi_libqi https://github.com/ros-naoqi/libqi-release && \
    git clone --branch release/jazzy/naoqi_libqicore https://github.com/ros-naoqi/libqicore-release && \
    git clone https://github.com/ros-naoqi/naoqi_bridge_msgs2 && \
    git clone --branch ros2-jazzy https://github.com/ros/diagnostics && \
    git clone --branch jazzy https://github.com/RobotWebTools/rosbridge_suite.git && \
    git clone --branch ros2-develop https://github.com/fkie/async_web_server_cpp.git && \
    git clone --branch ros2 https://github.com/RobotWebTools/web_video_server.git && \
    cd .. && colcon build --symlink-install --cmake-args -DBUILD_TESTING=OFF

# Git config to avoid SSL verification on robots with unsynced RTC clocks
RUN git config --global http.sslVerify false

# Shell initialization for NAO and Pepper
COPY --chown=nao:nao config/.bash_profile /home/nao/.bash_profile

# Helper scripts
COPY --chown=nao:nao scripts /home/nao/.local/share/scripts

# Cleanup build artifacts to minimize image footprint
SHELL ["/bin/sh", "-c"]
USER root
RUN cd /home/nao/.local && rm -rf libqi libqi-python qibuild pybind11 2>/dev/null || true
RUN rm -rf /tmp/gentoo/var/cache/binpkgs/* /tmp/gentoo/var/tmp/* /home/nao/.cache/* /home/nao/gentoo/var/cache/distfiles/* 2>/dev/null || true
RUN find / -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
RUN rm -rf /opt 2>/dev/null || true
USER nao

SHELL ["/tmp/gentoo/executeonprefix"]

# Parallel LZMA compression with pxz
RUN emerge app-arch/pxz app-arch/tar 2>/dev/null || true

RUN cd /home/nao && tar -I pxz -c -f ./nao_os_jazzy.tar.lzma \
    -C /home/nao gentoo \
    -C /home/nao ros2_jazzy \
    -C /home/nao .local/share/scripts \
    -C /home/nao .bash_profile \
    -C /home/nao catkin_ros2 || true && \
    ln -sf nao_os_jazzy.tar.lzma pepper_os.tar.lzma && \
    ln -sf nao_os_jazzy.tar.lzma pepper_os_jazzy.tar.lzma

ENTRYPOINT ["/bin/bash"]