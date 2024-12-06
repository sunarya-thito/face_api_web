import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final Map<String, Future<void>> _pending = {};

class CameraInfo {
  final web.MediaDeviceInfo _device;

  CameraInfo(this._device);

  String get label => _device.label;
  String get deviceId => _device.deviceId;

  @override
  bool operator ==(Object other) {
    return other is CameraInfo && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;
}

Future<List<CameraInfo>> getAvailableCameras() async {
  final devices =
      await web.window.navigator.mediaDevices.enumerateDevices().toDart;
  return devices.toDart
      .where((device) => device.kind == 'videoinput')
      .map((device) => CameraInfo(device))
      .toList();
}

Future<web.MediaStream> _createCameraSession(
    web.MediaDeviceInfo selectedCamera) async {
  web.MediaStream mediaStream = await web.window.navigator.mediaDevices
      .getUserMedia(web.MediaStreamConstraints(
        video: web.MediaTrackConstraints(
          deviceId: selectedCamera.deviceId.toJS,
        ),
      ))
      .toDart;
  return mediaStream;
}

typedef CameraCallback = void Function(CameraSession session);

class CameraWidget extends StatefulWidget {
  final CameraInfo selectedCamera;
  final CameraCallback? onCameraCreated;

  const CameraWidget(
      {super.key, required this.selectedCamera, this.onCameraCreated});

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class CameraSession {
  final web.MediaStream stream;
  final web.HTMLVideoElement videoElement;

  CameraSession(this.stream, this.videoElement);

  Uint8List capture({Rect? relativeRect, Rect? expand}) {
    var canvas = web.HTMLCanvasElement();
    if (relativeRect != null) {
      canvas.width = (relativeRect.width * videoElement.videoWidth).toInt();
      canvas.height = (relativeRect.height * videoElement.videoHeight).toInt();
    } else {
      canvas.width = videoElement.videoWidth;
      canvas.height = videoElement.videoHeight;
    }
    var context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    double x;
    double y;
    double width;
    double height;
    if (relativeRect != null) {
      x = relativeRect.left * videoElement.videoWidth;
      y = relativeRect.top * videoElement.videoHeight;
      width = relativeRect.width * videoElement.videoWidth;
      height = relativeRect.height * videoElement.videoHeight;
    } else {
      x = 0;
      y = 0;
      width = videoElement.videoWidth.toDouble();
      height = videoElement.videoHeight.toDouble();
    }
    if (expand != null) {
      x -= expand.left;
      y -= expand.top;
      width += expand.width;
      height += expand.height;
    }
    context.drawImage(
        videoElement, x, y, width, height, 0, 0, canvas.width, canvas.height);
    var dataUrl = canvas.toDataUrl('image/jpeg');
    var base64 = dataUrl.split(',').last;
    return Uint8List.fromList(base64Decode(base64));
  }
}

class _CameraWidgetState extends State<CameraWidget> {
  late Future<web.MediaStream> _cameraStream;
  web.HTMLVideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _cameraStream = _create();
  }

  Future<web.MediaStream> _create() async {
    var pendingSession = _pending[widget.selectedCamera.deviceId];
    if (pendingSession != null) {
      await pendingSession;
    }
    var futureSession = _createCameraSession(widget.selectedCamera._device);
    _pending[widget.selectedCamera.deviceId] = futureSession;
    try {
      var session = await futureSession;
      if (_videoElement != null) {
        _videoElement!.srcObject = session;
        widget.onCameraCreated?.call(CameraSession(session, _videoElement!));
      }
      _pending.remove(widget.selectedCamera.deviceId);
      return session;
    } catch (e) {
      _pending.remove(widget.selectedCamera.deviceId);
      rethrow;
    }
  }

  @override
  void didUpdateWidget(covariant CameraWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCamera != widget.selectedCamera) {
      _cameraStream.then((value) {
        value.getTracks().toDart.forEach((track) {
          track.stop();
        });
      });
      _cameraStream = _create();
    }
  }

  @override
  void dispose() {
    _cameraStream.then((value) {
      value.getTracks().toDart.forEach((track) {
        track.stop();
      });
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _cameraStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        return HtmlElementView.fromTagName(
          tagName: 'video',
          onElementCreated: (element) {
            var videoElement = element as web.HTMLVideoElement;
            _videoElement = videoElement;
            videoElement.srcObject = snapshot.requireData;
            videoElement.autoplay = true;
            videoElement.style.width = '100%';
            videoElement.style.height = '100%';
            videoElement.style.objectFit = 'fill';
            widget.onCameraCreated
                ?.call(CameraSession(snapshot.requireData, videoElement));
          },
        );
      },
    );
  }
}
