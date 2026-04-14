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

@dataclass
class SpiralClimbParams:
    radius_m: float = 20.0      # circle radius
    omega: float = 0.8          # rad/s, speed around circle
    climb_rate_mps: float = 0.2  # meters per second upward
    bank_gain: float = 2.5       # roll amount during turn
    pitch_gain: float = 0.08     # pitch based on climb rate
    u_bias: float = 100.0        # starting altitude offset

@dataclass
class SquarePathParams:
    side_m: float = 150.0      # length of each side in meters
    speed_mps: float = 25.0    # constant speed along edges
    u_bias: float = 100.0      # altitude offset
    yaw_bias: float = 0.0      # optional yaw offset if needed

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

class SpiralClimbPathGenerator:
    def __init__(self, params: SpiralClimbParams):
        self.p = params

    def sample(self, t: float):
        """Return local ENU pos (m) and Euler angles (rad) at time t."""
        p = self.p

        # Circular motion in ENU with steady climb
        east = p.radius_m * math.cos(p.omega * t)
        north = p.radius_m * math.sin(p.omega * t)
        up = p.u_bias + p.climb_rate_mps * t

        # First derivatives (velocity)
        ve = -p.radius_m * p.omega * math.sin(p.omega * t)
        vn =  p.radius_m * p.omega * math.cos(p.omega * t)
        vu = p.climb_rate_mps

        # Second derivatives (acceleration)
        ae = -p.radius_m * (p.omega**2) * math.cos(p.omega * t)
        an = -p.radius_m * (p.omega**2) * math.sin(p.omega * t)

        # Heading from tangent direction
        yaw = math.atan2(vn, ve)

        # Turn rate approximation
        denom = ve*ve + vn*vn
        turn_rate = (ve * an - vn * ae) / denom if denom > 1e-6 else 0.0

        # Roll into the turn
        roll = p.bank_gain * turn_rate

        # Pitch based on climb rate
        pitch = p.pitch_gain * vu

        # Wrap angles to [-pi, pi]
        roll = (roll + math.pi) % (2 * math.pi) - math.pi
        pitch = (pitch + math.pi) % (2 * math.pi) - math.pi
        yaw = (yaw + math.pi) % (2 * math.pi) - math.pi

        return (east, north, up), (roll, pitch, yaw)    

class SquarePathGenerator:
    def __init__(self, params: SquarePathParams):
        self.p = params

    def sample(self, t: float):
        """Return local ENU pos (m) and Euler angles (rad) at time t."""
        p = self.p

        side_time = p.side_m / p.speed_mps
        lap_time = 4.0 * side_time
        tau = t % lap_time

        half = p.side_m / 2.0

        # Segment 1: move east along bottom edge
        if tau < side_time:
            s = tau / side_time
            east = -half + s * p.side_m
            north = -half
            yaw = 0.0 + p.yaw_bias
            ve = p.speed_mps
            vn = 0.0

        # Segment 2: move north along right edge
        elif tau < 2.0 * side_time:
            s = (tau - side_time) / side_time
            east = half
            north = -half + s * p.side_m
            yaw = math.pi / 2.0 + p.yaw_bias
            ve = 0.0
            vn = p.speed_mps

        # Segment 3: move west along top edge
        elif tau < 3.0 * side_time:
            s = (tau - 2.0 * side_time) / side_time
            east = half - s * p.side_m
            north = half
            yaw = math.pi + p.yaw_bias
            ve = -p.speed_mps
            vn = 0.0

        # Segment 4: move south along left edge
        else:
            s = (tau - 3.0 * side_time) / side_time
            east = -half
            north = half - s * p.side_m
            yaw = -math.pi / 2.0 + p.yaw_bias
            ve = 0.0
            vn = -p.speed_mps

        up = p.u_bias

        # Sharp corners = no smoothing, no banking
        roll = 0.0
        pitch = 0.0

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