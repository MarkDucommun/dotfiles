#!/usr/bin/env python3
"""
Switch Logitech MX Master 3 host channel via HID++ 2.0 over Bluetooth.

Uses macOS IOKit directly to access the HID device, which works alongside
Logi Options+ (unlike hidapi which gets blocked by exclusive access).

Usage:
    switch_mouse.py 1    # Switch to host slot 1
    switch_mouse.py 2    # Switch to host slot 2
    switch_mouse.py 3    # Switch to host slot 3
    switch_mouse.py --detect  # List all Logitech HID devices

macOS: Grant Input Monitoring permission to your terminal app.
"""

import ctypes
import sys
import time
from ctypes import (
    POINTER,
    byref,
    c_char_p,
    c_int32,
    c_uint8,
    c_uint32,
    c_uint64,
    c_void_p,
)

# --- IOKit / CoreFoundation bindings ---

_iokit = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/IOKit.framework/IOKit")
_cf = ctypes.cdll.LoadLibrary(
    "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
)

_CF_UTF8 = 0x08000100
_CF_SINT32 = 3

_iokit.IOServiceMatching.restype = c_void_p
_iokit.IOServiceMatching.argtypes = [c_char_p]
_iokit.IOServiceGetMatchingServices.restype = c_int32
_iokit.IOServiceGetMatchingServices.argtypes = [c_uint32, c_void_p, POINTER(c_uint32)]
_iokit.IOIteratorNext.restype = c_uint32
_iokit.IOIteratorNext.argtypes = [c_uint32]
_iokit.IOHIDDeviceCreate.restype = c_void_p
_iokit.IOHIDDeviceCreate.argtypes = [c_void_p, c_uint32]
_iokit.IOHIDDeviceOpen.restype = c_int32
_iokit.IOHIDDeviceOpen.argtypes = [c_void_p, c_uint32]
_iokit.IOHIDDeviceClose.restype = c_int32
_iokit.IOHIDDeviceClose.argtypes = [c_void_p, c_uint32]
_iokit.IOHIDDeviceGetProperty.restype = c_void_p
_iokit.IOHIDDeviceGetProperty.argtypes = [c_void_p, c_void_p]
_iokit.IOHIDDeviceSetReport.restype = c_int32
_iokit.IOHIDDeviceSetReport.argtypes = [c_void_p, c_uint32, c_uint32, c_void_p, c_uint64]
_iokit.IOHIDDeviceGetReport.restype = c_int32
_iokit.IOHIDDeviceGetReport.argtypes = [
    c_void_p, c_uint32, c_uint32, c_void_p, POINTER(c_uint64),
]
_iokit.IOObjectRelease.restype = c_int32
_iokit.IOObjectRelease.argtypes = [c_uint32]

_cf.CFStringCreateWithCString.restype = c_void_p
_cf.CFStringCreateWithCString.argtypes = [c_void_p, c_char_p, c_uint32]
_cf.CFNumberGetValue.restype = c_int32
_cf.CFNumberGetValue.argtypes = [c_void_p, c_uint32, c_void_p]
_cf.CFStringGetCStringPtr.restype = c_char_p
_cf.CFStringGetCStringPtr.argtypes = [c_void_p, c_uint32]


def _cfstr(s):
    return _cf.CFStringCreateWithCString(None, s.encode(), _CF_UTF8)


def _get_int_prop(dev, key):
    val = _iokit.IOHIDDeviceGetProperty(dev, _cfstr(key))
    if val:
        num = c_int32(0)
        _cf.CFNumberGetValue(val, _CF_SINT32, byref(num))
        return num.value
    return None


def _get_str_prop(dev, key):
    val = _iokit.IOHIDDeviceGetProperty(dev, _cfstr(key))
    if val:
        s = _cf.CFStringGetCStringPtr(val, _CF_UTF8)
        return s.decode() if s else None
    return None


# --- HID++ constants ---

LOGITECH_VID = 0x046D
BT_PIDS = [0xB023, 0xB028, 0xB034]

HIDPP_LONG_REPORT_ID = 0x11
HIDPP_LONG_LEN = 20
BT_DEVICE_INDEX = 0xFF
SW_ID = 0x01

CHANGE_HOST_FEATURE = 0x1814

_REPORT_TYPE_INPUT = 0
_REPORT_TYPE_OUTPUT = 1


# --- Device discovery ---

def _iter_iokit_hid_devices():
    """Yield (IOHIDDevice, service) tuples for all IOHIDDevice services."""
    matching = _iokit.IOServiceMatching(b"IOHIDDevice")
    iterator = c_uint32(0)
    kr = _iokit.IOServiceGetMatchingServices(0, matching, byref(iterator))
    if kr != 0:
        return

    while True:
        service = _iokit.IOIteratorNext(iterator.value)
        if not service:
            break
        dev = _iokit.IOHIDDeviceCreate(None, service)
        if dev:
            yield dev, service
        else:
            _iokit.IOObjectRelease(service)


def find_device():
    """Find the MX Master 3 IOHIDDevice."""
    for dev, service in _iter_iokit_hid_devices():
        vid = _get_int_prop(dev, "VendorID")
        pid = _get_int_prop(dev, "ProductID")
        if vid == LOGITECH_VID and pid in BT_PIDS:
            product = _get_str_prop(dev, "Product") or "Unknown"
            return dev, product, pid
        _iokit.IOObjectRelease(service)
    return None, None, None


def detect_devices():
    """Print all Logitech HID devices for debugging."""
    found = []
    for dev, service in _iter_iokit_hid_devices():
        vid = _get_int_prop(dev, "VendorID")
        if vid == LOGITECH_VID:
            product = _get_str_prop(dev, "Product") or "Unknown"
            pid = _get_int_prop(dev, "ProductID")
            usage_page = _get_int_prop(dev, "PrimaryUsagePage")
            usage = _get_int_prop(dev, "PrimaryUsage")
            found.append((product, pid, usage_page, usage))
        _iokit.IOObjectRelease(service)

    if not found:
        print("No Logitech HID devices found.")
        return
    print(f"Found {len(found)} Logitech HID device(s):\n")
    for product, pid, usage_page, usage in found:
        print(f"  Product: {product}")
        print(f"  PID:     0x{pid:04X}")
        print(f"  Usage:   page=0x{usage_page or 0:04X} id=0x{usage or 0:04X}")
        print()


# --- HID++ communication ---

def _send_report(device, feature_idx, func_id, *params):
    """Send an HID++ long report via IOKit."""
    msg = [HIDPP_LONG_REPORT_ID, BT_DEVICE_INDEX, feature_idx,
           (func_id << 4) | SW_ID] + list(params)
    msg += [0x00] * (HIDPP_LONG_LEN - len(msg))
    buf = (c_uint8 * HIDPP_LONG_LEN)(*msg)
    return _iokit.IOHIDDeviceSetReport(
        device, _REPORT_TYPE_OUTPUT, HIDPP_LONG_REPORT_ID, buf, HIDPP_LONG_LEN
    )


def _read_report(device):
    """Read an HID++ long report via IOKit."""
    buf = (c_uint8 * HIDPP_LONG_LEN)()
    length = c_uint64(HIDPP_LONG_LEN)
    kr = _iokit.IOHIDDeviceGetReport(
        device, _REPORT_TYPE_INPUT, HIDPP_LONG_REPORT_ID, buf, byref(length)
    )
    return kr, list(buf[: length.value])


def switch_host(target: int):
    if target not in (1, 2, 3):
        print(f"Error: host must be 1, 2, or 3 (got {target})", file=sys.stderr)
        sys.exit(1)

    device, product, pid = find_device()
    if device is None:
        print("Error: MX Master 3 not found over Bluetooth.", file=sys.stderr)
        print("Run with --detect to see all Logitech HID devices.", file=sys.stderr)
        sys.exit(1)

    print(f"Found: {product} (PID=0x{pid:04X})")

    kr = _iokit.IOHIDDeviceOpen(device, 0)
    if kr != 0:
        print(f"Error: Failed to open device (code {kr})", file=sys.stderr)
        sys.exit(1)

    try:
        # Query IRoot for ChangeHost feature index
        _send_report(device, 0x00, 0x00,
                     (CHANGE_HOST_FEATURE >> 8) & 0xFF,
                     CHANGE_HOST_FEATURE & 0xFF)
        time.sleep(0.2)
        kr, resp = _read_report(device)
        if len(resp) < 5 or resp[4] == 0:
            print("Error: ChangeHost feature not supported.", file=sys.stderr)
            sys.exit(1)

        change_host_idx = resp[4]

        # setCurrentHost (function 1) with 0-indexed host
        print(f"Switching to host {target}...")
        kr = _send_report(device, change_host_idx, 0x01, target - 1)
        if kr != 0:
            print(f"Error: Switch command failed (code {kr})", file=sys.stderr)
            sys.exit(1)

        print(f"Done. Mouse → host {target}.")
    finally:
        _iokit.IOHIDDeviceClose(device, 0)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--detect":
        detect_devices()
    elif len(sys.argv) == 2 and sys.argv[1] in ("1", "2", "3"):
        switch_host(int(sys.argv[1]))
    else:
        print("Usage: switch_mouse.py {1|2|3}")
        print("       switch_mouse.py --detect")
        sys.exit(1)
