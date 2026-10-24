"""Writes assets/donate/upi-qr.svg: the QR code of the project's UPI payment link.

    pip install segno
    python tools/make_donate_qr.py

The code is drawn here, once, and bundled, so the app asks no service to make it. The payee
and the UPI ID are the ones in lib/donate.dart; change both together.
"""
import segno

UPI_ID = "das.arani@pingpay"
NAME = "Arani Das"

link = f"upi://pay?pa={UPI_ID}&pn={NAME.replace(' ', '%20')}&cu=INR"
qr = segno.make(link, error="m")
qr.save("assets/donate/upi-qr.svg", scale=8, border=2, dark="#000000", light="#ffffff", xmldecl=False, svgns=True)
print(link)
