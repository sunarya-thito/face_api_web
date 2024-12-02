import 'dart:typed_data';

import 'package:example/rename_picture_dialog.dart';
import 'package:face_api_web/face_api_web.dart';
import 'package:flutter/material.dart';

class TakePictureResult {
  final Face face;
  final Uint8List picture;
  final String name;

  TakePictureResult(this.face, this.picture, this.name);
}

class TakePicturePage extends StatefulWidget {
  @override
  State<TakePicturePage> createState() => _TakePicturePageState();
}

class _TakePicturePageState extends State<TakePicturePage> {
  CameraInfo? _selectedCamera;
  late Future<List<CameraInfo>> _availableCameras;
  CameraSession? _session;
  FaceScore? _detectedFace;

  @override
  void initState() {
    super.initState();
    _availableCameras = getAvailableCameras();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Picture'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 640,
              height: 480,
              child: _selectedCamera == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        FaceCameraDetector(
                          captureMode: const SingleFaceCaptureMode(
                              FaceDetectionModel.tinyFace,
                              features: [
                                FaceDetectionFeature.faceLandmark,
                                FaceDetectionFeature.faceDescriptor,
                              ]),
                          onFaceDetected: (faces) {
                            if (faces.isEmpty) {
                              setState(() {
                                _detectedFace = null;
                              });
                              return;
                            }
                            setState(() {
                              _detectedFace = faces.first;
                            });
                          },
                          selectedCamera: _selectedCamera!,
                          onCameraCreated: (session) {
                            setState(() {
                              _session = session;
                            });
                          },
                        ),
                        FaceBoundingBoxOverlay(faces: [
                          if (_detectedFace != null) _detectedFace!,
                        ]),
                      ],
                    ),
            ),
            FutureBuilder<List<CameraInfo>>(
              future: _availableCameras,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                return DropdownButton<CameraInfo>(
                  value: _selectedCamera,
                  onChanged: (value) {
                    setState(() {
                      _selectedCamera = value;
                    });
                  },
                  items: snapshot.data!.map((camera) {
                    return DropdownMenuItem(
                      value: camera,
                      child: Text(camera.label),
                    );
                  }).toList(),
                );
              },
            ),
            ElevatedButton(
              onPressed: () async {
                if (_session == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Camera not ready')));
                  return;
                }
                final picture = _session!.capture();
                final face = _detectedFace;
                if (face == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No face detected')));
                  return;
                }
                if (face.reference.references.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No face detected')));
                  return;
                }
                var firstFace = face.reference.references.first;
                showDialog(
                  context: context,
                  builder: (context) {
                    return RenamePictureDialog(
                        picture: picture, name: 'New Picture');
                  },
                ).then(
                  (result) {
                    if (result is String && context.mounted) {
                      Navigator.of(context)
                          .pop(TakePictureResult(firstFace, picture, result));
                    }
                  },
                );
              },
              child: const Text('Take Picture'),
            ),
          ],
        ),
      ),
    );
  }
}
