#!/bin/bash
# Auto-detect robot model and straighten posture for NAO or Pepper
ROBOT_TYPE=$(qicli call ALMemory.getData "RobotConfig/Body/Type" 2>/dev/null | tr -d '"' | tr '[:upper:]' '[:lower:]')

if [ "$ROBOT_TYPE" = "nao" ]; then
    echo "Straightening posture for NAO..."
    qicli call ALRobotPosture.goToPosture "StandInit" 0.5 2>/dev/null || true
    qicli call ALMotion.setAngles "HeadPitch" 0.0 0.1 2>/dev/null || true
    qicli call ALMotion.setAngles "HeadYaw" 0.0 0.1 2>/dev/null || true
    qicli call ALMotion.setBreathEnabled "Body" 0 2>/dev/null || true
else
    echo "Straightening posture for Pepper..."
    qicli call ALMotion.setAngles "HeadPitch" 0.0 0.1 2>/dev/null || true
    qicli call ALMotion.setAngles "HeadYaw" 0.0 0.1 2>/dev/null || true
    qicli call ALMotion.setAngles "KneePitch" 0.0 0.1 2>/dev/null || true
    qicli call ALMotion.setAngles "HipPitch" -0.1 0.1 2>/dev/null || true
    qicli call ALMotion.setAngles "HipRoll" 0.0 0.1 2>/dev/null || true
    qicli call ALMotion.setBreathEnabled "Body" 0 2>/dev/null || true
fi
