import matplotlib.pyplot as plt
from config import *
from generator import *

def main():
    # Sampling settings
    duration_s = 90.0   # collect 90 seconds to see full loops
    period     = 1.0 / DEFAULT_RATE_HZ

    # Create generator
    gen = Figure8PathGenerator(Figure8Params)

    # Buffers
    ts = []
    east_list, north_list, up_list = [], [], []
    lat_list, lon_list, alt_list = [], [], []
    roll_list, pitch_list, yaw_list = [], [], []

    # Sample deterministically
    t = 0.0
    samples = int(duration_s * DEFAULT_RATE_HZ)
    for _ in range(samples):
        (e, n, u), (roll, pitch, yaw) = gen.sample(t)
        lat, lon, alt = enu_to_lla_simple(ORIGIN_LAT, ORIGIN_LON, ORIGIN_ALT, e, n, u)

        ts.append(t)
        east_list.append(e); north_list.append(n); up_list.append(u)
        lat_list.append(lat); lon_list.append(lon); alt_list.append(alt)
        roll_list.append(roll); pitch_list.append(pitch); yaw_list.append(yaw)

        t += period

    # Diagnostics
    print(f"Samples: {len(ts)}")
    print(f"East range (m):  {min(east_list):.2f} .. {max(east_list):.2f}")
    print(f"North range (m): {min(north_list):.2f} .. {max(north_list):.2f}")
    print(f"Alt range (m):   {min(alt_list):.2f} .. {max(alt_list):.2f}")
    print(f"Lat range (deg): {min(lat_list):.8f} .. {max(lat_list):.8f}")
    print(f"Lon range (deg): {min(lon_list):.8f} .. {max(lon_list):.8f}")

    # Plot
    fig, axs = plt.subplots(2, 2, figsize=(11, 9))

    # Local XY (meters)
    axs[0,0].plot(east_list, north_list, 'b-')
    axs[0,0].set_title("Local XY path (East vs North) — meters")
    axs[0,0].set_xlabel("East (m)")
    axs[0,0].set_ylabel("North (m)")
    axs[0,0].axis('equal')
    axs[0,0].grid(True)

    # Geodetic ground track (degrees) — lon vs lat with equal aspect
    axs[0,1].plot(lon_list, lat_list, 'g-')
    axs[0,1].set_title("Ground track (Longitude vs Latitude) — degrees")
    axs[0,1].set_xlabel("Longitude (deg)")
    axs[0,1].set_ylabel("Latitude (deg)")
    axs[0,1].axis('equal')
    axs[0,1].grid(True)

    # Altitude vs time (meters)
    axs[1,0].plot(ts, alt_list, 'm-')
    axs[1,0].set_title("Altitude vs time")
    axs[1,0].set_xlabel("t (s)")
    axs[1,0].set_ylabel("Altitude (m)")
    axs[1,0].grid(True)

    # Euler angles vs time (radians)
    axs[1,1].plot(ts, roll_list, label='roll')
    axs[1,1].plot(ts, pitch_list, label='pitch')
    axs[1,1].plot(ts, yaw_list, label='yaw')
    axs[1,1].set_title("Euler angles vs time (rad)")
    axs[1,1].set_xlabel("t (s)")
    axs[1,1].legend()
    axs[1,1].grid(True)

    plt.tight_layout()
    plt.show()

if __name__ == "__main__":
    main()