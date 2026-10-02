#!/bin/bash
# Reset NAO posture and alignment
qicli call ALRobotPosture.goToPosture "StandInit" 0.5 2>/dev/null || true
qicli call ALMotion.setAngles "HeadPitch" 0.0 0.1 2>/dev/null || true
qicli call ALMotion.setAngles "HeadYaw" 0.0 0.1 2>/dev/null || true
qicli call ALMotion.setBreathEnabled "Body" 0 2>/dev/null || true
