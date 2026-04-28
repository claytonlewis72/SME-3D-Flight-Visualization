# SME-3D-Flight-Visualization




## Overview

This is the WCU Capstone Project GitHub repository for creating a **3D Flight Visualization System** for the client SME. 

The **SME 3D Flight Visualization System** is a real-time visualization platform designed to display, record and replay drone flight data in a 3D environmnet. 

The system ingests live telemetry data, renders a vechile and its motion in the game engine godot, and provides tools for playback and analysis of recorded flights.

## Key Features
* Real-time drone flight visualization
* Telemetry ingestion (position, motion, 6 DOF data)
* Flight recording and replay systems
* Multiple camera views (chase, fixed, free cam)
* Interactive GUI controls
* Configurable Telemetry Info
* Performance optimization for embedded deployment (NVIDIA orin Jetson nano)
 
## System Architecture

## Usage


## Documentation & Deliverables

## Testing

## Contributors

# Handoff Notes





**Collaborators:**
Clayton Lewis, Carson Wood, Nicholas Tran, Evan Visalli, Aramis Hernandez, David Shodipe, Clinton U

# Project Breakdown
### **Foundation:** <br>
FVS-14 → GitHub Setup <br>
FVS-13 → Modular Architecture Design (Break large system into small, independent building blocks) <br>
FVS-1 → Telemetry Ingest (Position Data, 6 DOF, Motion Data) <br>
FVS-3 → Vehicle logic and position updating <br>
### **Visual Layer:** <br>
FVS-2 → Choose a game engine to work with (Unreal, Unity, etc.) <br>
Game Engine Setup <br>
FVS-4 → Load in first vehicle model <br>
Connect the vehicle state to the real-time render in the game engine <br>
### **Functional Layer:** <br>
FVS-8 → Develop camera system (Chase, Fixed, Free Cam) <br>
FVS-9 → Develop GUI Controls <br>
FVS-6 → Develop Record/Replay system <br>
### **Performance Layer:** <br>
FVS-5 → FPS and performance optimization <br>
FVS-7 → Deploy to NVIDIA Jetson Board <br>
### **Completion:** <br>
FVS-11 → Produce final documentation (User Guide, Code Explanation) <br>
FVS-12 → Coding Standard <br>
FVS-15 → Testing with Agile Methodologies <br>
