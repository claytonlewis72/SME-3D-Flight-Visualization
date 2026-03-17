#|----------------------------------------------------------------------------
#|                                UNCLASSIFIED                                
#|----------------------------------------------------------------------------
#|
#|                             SME Solutions, Inc.
#|          Copyright 2026 SME Solutions, Inc. All Rights Reserved
#|                 SME Solutions Proprietary Information
#|
#|----------------------------------------------------------------------------
#| File Name  : generator.py
#|
#| Target     : Python
#|
#| Description: Generates figure 8 flight data over lat/lon.
#|
#| Notes      : None.
#|
#| POC        : M. Megivern
#|----------------------------------------------------------------------------
import math
from dataclasses import dataclass
from config import *

@dataclass
class Figure8Params:
    amp_e: float = 100.0     # meters East
    amp_n: float = 50.0      # meters North
    amp_u: float = 10.0      # meters Up
    omega: float = 0.08      # rad/s (path speed)
    bank_gain: float = 0.8   # roll gain (rad per rad/s of turn rate)
    pitch_gain: float = 0.05 # pitch gain (rad per m/s vertical speed)
    u_bias: float = 0.0      # base Up offset (meters)

class Figure8PathGenerator:
    def __init__(self, params: Figure8Params):
        self.p = params

    def sample(self, t: float):
        """Return local ENU pos (m) and Euler angles (rad) at time t."""
        p = self.p
        # Lissajous figure-8 in local ENU: East (x), North (y), Up (z)
        east = p.amp_e * math.sin(p.omega * t)
        north = p.amp_n * math.sin(2 * p.omega * t)
        up = p.u_bias + p.amp_u * math.sin(0.5 * p.omega * t)

        # First derivatives (velocity components)
        ve = p.amp_e * p.omega * math.cos(p.omega * t)
        vn = 2 * p.amp_n * p.omega * math.cos(2 * p.omega * t)
        vu = 0.5 * p.amp_u * p.omega * math.cos(0.5 * p.omega * t)

        # Heading (yaw) from path tangent; ENU convention
        yaw = math.atan2(vn, ve)

        # Approximate turn rate via curvature
        ae = -p.amp_e * (p.omega**2) * math.sin(p.omega * t)
        an = -4 * p.amp_n * (p.omega**2) * math.sin(2 * p.omega * t)
        denom = ve*ve + vn*vn
        turn_rate = (ve * an - vn * ae) / denom if denom > 1e-6 else 0.0

        # Bank (roll) proportional to turn rate
        roll = p.bank_gain * turn_rate

        # Pitch tied to vertical speed
        pitch = p.pitch_gain * vu

        # Wrap yaw to [-pi, pi]
        yaw = (yaw + math.pi) % (2 * math.pi) - math.pi

        return (east, north, up), (roll, pitch, yaw)

def enu_to_lla_simple(origin_lat_deg: float, origin_lon_deg: float, origin_alt_m: float,
                      east_m: float, north_m: float, up_m: float):
    """
    Convert small ENU offsets (meters) to lat/lon (degrees) and altitude (meters)
    using small-angle flat-Earth approx around the origin.
    """
    lat_rad = math.radians(origin_lat_deg)
    dlat_deg = (north_m / EARTH_RADIUS_M) * (180.0 / math.pi)
    dlon_deg = (east_m / (EARTH_RADIUS_M * math.cos(lat_rad))) * (180.0 / math.pi)
    lat = origin_lat_deg + dlat_deg
    lon = origin_lon_deg + dlon_deg
    alt = origin_alt_m + up_m
    return lat, lon, alt

def format_csv(frame, timestamp: float, lla, euler):
    lat_deg, lon_deg, alt_m = lla
    roll, pitch, yaw = euler
    # frame, timestamp(s), lat(deg), lon(deg), alt(m), roll(rad), pitch(rad), yaw(rad)
    return f"{frame},{timestamp:.6f},{lat_deg:.8f},{lon_deg:.8f},{alt_m:.3f},{roll:.6f},{pitch:.6f},{yaw:.6f}"