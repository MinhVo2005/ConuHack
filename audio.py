#!/usr/bin/env python3
"""
WAV File Receiver for ESP32-S3
Receives WAV files from ESP32 over USB Serial

Usage:
    python wav_receiver.py COM3        # Windows
    python wav_receiver.py /dev/ttyUSB0  # Linux
    python wav_receiver.py /dev/tty.usbserial  # Mac
"""

import serial
import sys
import base64
import time

def receive_base64_wav(ser, output_file="recording.wav"):
    """Receive base64-encoded WAV file"""
    print("Waiting for WAV data...")
    print("(Send 'd' command from ESP32 Serial Monitor)\n")
    
    in_data = False
    base64_data = ""
    
    while True:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            
            if "---BEGIN WAV FILE---" in line:
                print("✓ Receiving data...")
                in_data = True
                base64_data = ""
                continue
            
            if "---END WAV FILE---" in line:
                print("✓ Data received, decoding...")
                break
            
            if in_data:
                base64_data += line
    
    # Decode base64
    try:
        wav_data = base64.b64decode(base64_data)
        
        # Save to file
        with open(output_file, 'wb') as f:
            f.write(wav_data)
        
        print(f"✓ WAV file saved: {output_file}")
        print(f"  Size: {len(wav_data)} bytes")
        print(f"\nYou can now play it with any media player!")
        
    except Exception as e:
        print(f"✗ Error decoding: {e}")

def receive_binary_wav(ser, output_file="recording.wav"):
    """Receive binary WAV file"""
    print("Waiting for binary data...")
    print("(Send 's' command from ESP32 Serial Monitor)\n")
    
    in_data = False
    wav_data = bytearray()
    
    while True:
        if ser.in_waiting > 0:
            line = ser.readline()
            
            if b"BINARY_START" in line:
                print("✓ Receiving binary data...")
                in_data = True
                time.sleep(0.2)  # Wait for data to start flowing
                continue
            
            if b"BINARY_END" in line:
                print("✓ Binary data received")
                break
            
            if in_data:
                wav_data.extend(line)
    
    # Save to file
    try:
        with open(output_file, 'wb') as f:
            f.write(wav_data)
        
        print(f"✓ WAV file saved: {output_file}")
        print(f"  Size: {len(wav_data)} bytes")
        print(f"\nYou can now play it with any media player!")
        
    except Exception as e:
        print(f"✗ Error saving: {e}")

def interactive_mode(ser):
    """Interactive command mode"""
    print("\n=================================")
    print("ESP32-S3 WAV Recorder - Receiver")
    print("=================================\n")
    print("Commands:")
    print("  r = Tell ESP32 to record")
    print("  d = Download WAV (base64)")
    print("  s = Download WAV (binary - faster)")
    print("  q = Quit\n")
    
    while True:
        cmd = input("Command: ").strip().lower()
        
        if cmd == 'q':
            print("Goodbye!")
            break
        
        if cmd == 'r':
            ser.write(b'r')
            print("Recording command sent to ESP32...")
            # Show ESP32 output
            time.sleep(6)  # Wait for recording to complete
            while ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                print(f"  ESP32: {line}")
        
        elif cmd == 'd':
            ser.write(b'd')
            receive_base64_wav(ser)
        
        elif cmd == 's':
            ser.write(b's')
            receive_binary_wav(ser)
        
        else:
            print("Unknown command")

def main():
    if len(sys.argv) < 2:
        print("Usage: python wav_receiver.py <serial_port>")
        print("\nExamples:")
        print("  Windows: python wav_receiver.py COM3")
        print("  Linux:   python wav_receiver.py /dev/ttyUSB0")
        print("  Mac:     python wav_receiver.py /dev/tty.usbserial")
        sys.exit(1)
    
    port = sys.argv[1]
    
    try:
        print(f"Connecting to {port}...")
        ser = serial.Serial(port, 115200, timeout=1)
        time.sleep(2)  # Wait for connection to stabilize
        print("✓ Connected!\n")
        
        interactive_mode(ser)
        
        ser.close()
        
    except serial.SerialException as e:
        print(f"✗ Error: {e}")
        print("\nTip: Make sure:")
        print("  - ESP32 is connected via USB")
        print("  - Serial Monitor is CLOSED (only one program can use the port)")
        print("  - You have the correct port name")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        ser.close()

if __name__ == "__main__":
    main()