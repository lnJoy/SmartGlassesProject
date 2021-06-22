# SmartGlasses Socket Server
SmartGlasses is a Python-based socket program<br>that allows blind people to send their smartphones a value that recognizes the object in front of them.

## Getting Started

### Prerequisites

#### You must have raspberry pi 3B+ or 4, raspbian 32bit and Python 3.7.3 by default.

### Installing
1. Clone the repo
```bash
git clone -b detection --single-branch https://github.com/lnJoy/SmartGlassesProject.git
```
2. Install Tensorflow 2.5.0
```bash
pip3 install https://github.com/google-coral/pycoral/releases/download/release-frogfish/tflite_runtime-2.5.0-cp37-cp37m-linux_armv7l.whl
```

#### Optional ( Service )
1. Create Service
```bash
sudo nano /etc/systemd/system/sg.service

[Unit]
Description=Smart Glasses Object Detection

[Service]
Type=simple
WorkingDirectory=/home/pi/SmartGlasses
ExecStartPre=/bin/sleep 4
ExecStart=/usr/bin/python3 test.py

[Install]
WantedBy=multi-user.target
```
2. Enable and Start Service
```bash
sudo systemctl enable sg.service
sudo systemctl start sg.service
```

### Usage examples

```bash
python3 glasses.py
```
