from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import io
import re
import time

import os
import sys
import fcntl
import struct

from annotation import Annotator

import numpy as np
import picamera

from PIL import Image
from tflite_runtime.interpreter import Interpreter

import socket

CAMERA_WIDTH = 640
CAMERA_HEIGHT = 480

HOST = "192.168.10.1"
PORT = 65439

def load_labels(path):
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        labels = {}
        for row_number, content in enumerate(lines):
            pair = re.split(r'[:\s]+', content.strip(), maxsplit=1)
            if len(pair) == 2 and pair[0].strip().isdigit():
                labels[int(pair[0])] = pair[1].strip()
            else:
                labels[row_number] = pair[0].strip()
    return labels

def set_input_tensor(interpreter, image):
    tensor_index = interpreter.get_input_details()[0]['index']
    input_tensor = interpreter.tensor(tensor_index)()[0]
    input_tensor[:, :] = image

def get_output_tensor(interpreter, index):
    output_details = interpreter.get_output_details()[index]
    tensor = np.squeeze(interpreter.get_tensor(output_details['index']))
    return tensor

def detect_objects(interpreter, image, threshold):
    set_input_tensor(interpreter, image)
    interpreter.invoke()

    boxes = get_output_tensor(interpreter, 0)
    classes = get_output_tensor(interpreter, 1)
    scores = get_output_tensor(interpreter, 2)
    count = int(get_output_tensor(interpreter, 3))

    results = []
    for i in range(count):
        if scores[i] >= threshold:
            result = {
                'bounding_box': boxes[i],
                'class_id': classes[i],
                'score': scores[i]
            }
            results.append(result)
    return results

def annotate_objects(annotator, results, labels, conn):
    for obj in results:
        ymin, xmin, ymax, xmax = obj['bounding_box']
        xmin = int(xmin * CAMERA_WIDTH)
        xmax = int(xmax * CAMERA_WIDTH)
        ymin = int(ymin * CAMERA_HEIGHT)
        ymax = int(ymax * CAMERA_HEIGHT)

        annotator.bounding_box([xmin, ymin, xmax, ymax])
        annotator.text([xmin, ymin], '%s\n%.2f' % (labels[obj['class_id']], obj['score']))

        sendTextViaSocket(labels[obj['class_id']], conn)

def sendTextViaSocket(message, sock):
    if message:
        encodedMessage = bytes((message), encoding='utf8')
        sock.send(encodedMessage)

def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    print('socket instantiated')

    sock.bind((HOST, PORT))
    print('socket binded')

    sock.listen(1)
    print('socket now listening')

    conn, addr = sock.accept()
    conn.setblocking(0)
    print('socket accepted, got connection object')

    labels = load_labels("./models/coco_labels.txt")
    interpreter = Interpreter("./models/detect.tflite")
    threshold = 0.4
    interpreter.allocate_tensors()
    _, input_height, input_width, _ = interpreter.get_input_details()[0]['shape']
    data = True

    with picamera.PiCamera(resolution=(CAMERA_WIDTH, CAMERA_HEIGHT), framerate=30) as camera:
        camera.start_preview()
        try:
            while True:
                stream = io.BytesIO()
                annotator = Annotator(camera)
                for _ in camera.capture_continuous(stream, format='jpeg', use_video_port=True):

                    try:
                        demsg = conn.recv(1024).decode('utf-8')
                        print(f"recv : {demsg}")
                        print(f"data : {data}")
                        if demsg == '1':
                            data = True
                        elif demsg == '0':
                            data = False
                    except:
                        pass
                    if not data:
                        break

                    stream.seek(0)
                    image = Image.open(stream).convert('RGB').resize(
                        (input_width, input_height), Image.ANTIALIAS)
                    start_time = time.monotonic()
                    results = detect_objects(interpreter, image, 0.4)
                    elapsed_ms = (time.monotonic() - start_time) * 1000

                    annotator.clear()
                    annotate_objects(annotator, results, labels, conn)
                    annotator.text([5, 0], '%.1fms' % (elapsed_ms))
                    annotator.update()

                    stream.seek(0)
                    stream.truncate()

        except:
            print("hello")
            pass

        finally:
            print("error")
            camera.stop_preview()
            sock.close()
            conn.close()

if __name__ == '__main__':
    main()
