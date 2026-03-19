#|----------------------------------------------------------------------------
#|                                UNCLASSIFIED                                
#|----------------------------------------------------------------------------
#|
#|                             SME Solutions, Inc.
#|          Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|                 SME Solutions Proprietary Information
#|
#|----------------------------------------------------------------------------
#| File Name  : receiver.py
#|
#| Target     : Python
#|
#| Description: Receives data stream.
#|
#| Notes      : None.
#|
#| POC        : M. Megivern
#|----------------------------------------------------------------------------
import socket
from config import *

def udp_receiver(host=UDP_HOST, port=UDP_PORT, buffer_size=1024):
    """Starts a UDP server that listens for incoming messages."""
    try:
        # Create UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind((host, port))
        print(f"UDP Receiver started on {host}:{port}")

        while True:
            data, addr = sock.recvfrom(buffer_size)  # Receive data
            print(f"Received from {addr}: {data.decode(errors='replace')}")
    except KeyboardInterrupt:
        print("\nReceiver stopped by user.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        sock.close()

if __name__ == "__main__":
    udp_receiver()