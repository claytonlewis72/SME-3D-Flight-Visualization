
# SME-3D-Flight-Visualization




## Overview

This is the WCU Capstone Project GitHub repository for creating a **3D Flight Visualization System** for the client SME. 

The **SME 3D Flight Visualization System** is a real-time visualization platform that displays, records, and replays drone flight data in a 3D environment. 

The system ingests live telemetry data, renders a vehicle and its motion in the game engine Godot, and provides tools for playback and analysis of recorded flights.

## Key Features
* Real-time drone flight visualization
   * A vehicle model with proper rotation and positioning updated based on telemetry data
    <img width="800" height="450" alt="FIGURE8-ezgif com-video-to-gif-converter" src="https://github.com/user-attachments/assets/6083e55f-3a8c-4dd5-bfc9-31bc93558301" /> <br>
   * A flight path trail showcasing the overall flight path, and coloring based on rotational axes
    <img width="800" height="450" alt="FIGURE8FLIGHTPATH-ezgif com-video-to-gif-converter" src="https://github.com/user-attachments/assets/3fc02f8e-5220-4db8-a7ea-9fccea37d723" />
* Telemetry ingestion (position, motion, 6 DOF data)
   * Ingestion of a live data stream through UDP  
* Flight recording
   * Recording of flights saved as .bin files with their own "magic number." 
* Playback of recorded flights
   * Playback of flights for review that are recorded as .bin, allowing the pausing and playback of any frame. (PICTURES/GIF OF PLAYBACK)
* Multiple camera views (chase, fixed, free cam)
* Interactive GUI controls (PICTURES OF GUI)
<img width="1915" height="999" alt="Screenshot 2026-05-01 090347" src="https://github.com/user-attachments/assets/97e6541f-bd3f-4055-a717-aabceabb0ee4" />
* Configurable Telemetry Info (PICTURES OF CONFIG)
<img width="488" height="482" alt="Screenshot 2026-04-22 094848" src="https://github.com/user-attachments/assets/444b464e-be19-457c-8f88-df4d9afe0d84" />
* Performance optimization for embedded deployment (NVIDIA Orin Jetson Nano)
 
## System Architecture



## Usage
This project's usage is determined by the project client, SME Inc. Additionally, it should be noted that the WCU Capstone team created this project with the intention of using it for debugging and visualization of real drone flight paths for analysis.


## Documentation & Deliverables

## Testing
* The testing of this project was done with GUT unit testing in the Godot engine.
* Documentation of all unit tests (https://docs.google.com/spreadsheets/d/1F-_buREbD6vNOCIg8giTjLvqOO8VzGofhoiXCvi2gLw/edit?usp=sharing)
* Documentation of project VCRM (https://docs.google.com/document/d/1XNShHOQIiT4x-S8n2T375t95kNx27imvCer-pDf_yOM/edit?usp=sharing)

## Contributors
* Aramis Hernandez
* Carson Wood
* Clayton Lewis
* Clinton U
* David Shodipe
* Evan Visalli
* Nicholas Tran

# Handoff Notes





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
