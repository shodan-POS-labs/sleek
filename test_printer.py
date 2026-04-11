import socket
import sys

# Printer details from the provided screenshot
printer_address = "86:67:7A:D0:DA:B4"
# Port for RFCOMM (SPP) is typically 1
printer_port = 1

def test_printer():
    print(f"Connecting to Bluetooth printer: {printer_address}")
    
    # Create the RFCOMM socket
    sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
    
    try:
        sock.connect((printer_address, printer_port))
        print("Connected successfully!")
        
        # ESC/POS Commands
        # ----------------
        
        # Initialize printer
        sock.send(b'\x1b\x40')
        
        # Center alignment
        sock.send(b'\x1b\x61\x01')
        
        # Double height and width for title
        sock.send(b'\x1d\x21\x11')
        sock.send(b"Sleek POS\n")
        
        # Back to normal style
        sock.send(b'\x1d\x21\x00')
        sock.send(b"Bluetooth Print Test\n")
        sock.send(b"--------------------------------\n")
        
        # Left alignment
        sock.send(b'\x1b\x61\x00')
        sock.send(b"Date: 2026-04-11\n")
        sock.send(b"Time: 16:15\n")
        sock.send(b"\n")
        
        sock.send(b"Item 1        1 x 1500.00\n")
        sock.send(b"Item 2        2 x  250.00\n")
        
        sock.send(b"--------------------------------\n")
        
        # Right alignment for total
        sock.send(b'\x1b\x61\x02')
        sock.send(b"TOTAL: 2000.00 LKR\n")
        
        # Center alignment for footer
        sock.send(b'\x1b\x61\x01')
        sock.send(b"\n")
        sock.send(b"Thank you for using Sleek!\n")
        sock.send(b"--------------------------------\n")
        
        # Feed and cut
        sock.send(b'\n' * 5)
        
        print("Receipt data sent successfully!")
        
    except Exception as e:
        print(f"Error: {e}")
        print("\nCommon issues:")
        print("1. Ensure the printer is ON and paired with Linux.")
        print("2. Ensure bluetooth-daemon is running.")
        print("3. Try running with 'sudo' if you have permission issues.")
        
    finally:
        sock.close()
        print("Socket closed.")

if __name__ == "__main__":
    test_printer()
