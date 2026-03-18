# TM to VisualSim Message Converter

## Description
This flight data generator simulates a figure 8 over the WCUPA campus. This data is sent via UDP at a configurable rate. 

## Installation
Clone the repo or download the zip file. 

## Usage
In scripts/config.py, configure your settings to be accurate, including desired hz rate, host, and port.

To run sender, use command "python scripts/sender.py" 

If receiver is run, ensure "python scripts/receiver.py" is executed in a separate terminal.
Output should resemble the following:
![Screenshot of Terminal with output](<ExampleStream.png>)

This operation can be cancelled from terminal with ctrl+c. 

To ensure data is plotting full figure-8 path, you can run the plotpath.py code.
It should output something similar to this plot:
![Screenshot of Graph showing figure-8](<60hzGraph.png>)

## Support
Contact mmegivern@smexpertsolutions.com for support