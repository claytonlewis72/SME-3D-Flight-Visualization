#|----------------------------------------------------------------------------
#|                                UNCLASSIFIED                                
#|----------------------------------------------------------------------------
#|
#|                             SME Solutions, Inc.
#|          Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|                 SME Solutions Proprietary Information
#|
#|----------------------------------------------------------------------------
#| File Name  : sender.py
#|
#| Target     : Python
#|
#| Description: Formats and sends flight data.
#|
#| Notes      : None.
#|
#| POC        : M. Megivern
#|----------------------------------------------------------------------------
import socket
import time
from config import *
from generator import *

HOST = "127.0.0.1"
PORT = 5000
TARGET = "resume"

def wait_for_signal():
    print("Waiting for signal...")

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.bind((HOST, PORT))
        server.listen(1)

        conn, addr = server.accept()
        with conn:
            data = conn.recv(1024).decode().strip()
            if data == TARGET:
                print("Resuming execution")

wait_for_signal()
print("Code continues...")

class UdpStreamer:
    def __init__(self, host: str, port: int):
        self.addr = (host, port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def send(self, msg: str):
        self.sock.sendto(msg.encode("utf-8"), self.addr)

# Main loop
def run_stream(rate_hz=DEFAULT_RATE_HZ):
    gen = Figure8PathGenerator(Figure8Params())
    streamer = UdpStreamer(UDP_HOST, UDP_PORT)

    period = 1.0 / rate_hz
    t0 = time.monotonic()
    frame = 0 # initialize frame
    next_tick = t0

    header = "# fields=frame,t,lat_deg,lon_deg,alt_m,roll_rad,pitch_rad,yaw_rad"
    streamer.send(header)

    while True:
        now = time.monotonic()
        t = now - t0
        frame = frame + 1

        (east, north, up), euler = gen.sample(t)
        lat_deg, lon_deg, alt_m = enu_to_lla_simple(ORIGIN_LAT, ORIGIN_LON, ORIGIN_ALT,
                                                    east, north, up)
        msg = format_csv(frame, t, (lat_deg, lon_deg, alt_m), euler)
        streamer.send(msg)

        # Sleep until next tick
        next_tick += period
        sleep_time = next_tick - time.monotonic()
        if sleep_time > 0:
            time.sleep(sleep_time)
        else:
            next_tick = time.monotonic()

if __name__ == "__main__":
    run_stream(rate_hz=DEFAULT_RATE_HZ)