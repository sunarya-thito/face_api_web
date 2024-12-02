import 'package:example/face_list.dart';
import 'package:face_api_web/face_api_web.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<CameraInfo>> _cameras;
  CameraInfo? _selectedCamera;
  FacesRef? _reference;
  final ValueNotifier<List<FaceScore>> faces = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    _cameras = getAvailableCameras().then(
      (value) async {
        return value;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face API Web Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) {
                  return FaceListPage(faces: _reference ?? FacesRef([]));
                },
              )).then((value) {
                if (value is FacesRef) {
                  setState(() {
                    _reference = value;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<List<CameraInfo>>(
            future: _cameras,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return DropdownButton<CameraInfo>(
                  value: null,
                  onChanged: null,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Loading...'),
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return DropdownButton<CameraInfo>(
                  value: null,
                  onChanged: null,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  ],
                );
              }
              final cameras = snapshot.data!;
              return DropdownButton<CameraInfo>(
                value: _selectedCamera,
                isExpanded: true,
                onChanged: (value) {
                  setState(() {
                    _selectedCamera = value;
                  });
                },
                items: cameras.map((camera) {
                  return DropdownMenuItem<CameraInfo>(
                    value: camera,
                    child: Text(camera.label),
                  );
                }).toList(),
              );
            },
          ),
          if (_selectedCamera != null)
            Expanded(
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  FaceCameraDetector(
                    selectedCamera: _selectedCamera!,
                    captureMode: const MultipleFacesCaptureMode(
                        FaceDetectionModel.ssdMobilenetv1,
                        features: [
                          FaceDetectionFeature.faceLandmark,
                          FaceDetectionFeature.faceDescriptor,
                          FaceDetectionFeature.faceAgeAndGender,
                          FaceDetectionFeature.faceExpression,
                        ]),
                    references: _reference == null
                        ? null
                        : FaceReferences([
                            for (var face in _reference!.faces)
                              FaceReference(
                                [face.face],
                                label: face.name,
                              ),
                          ]),
                    onFaceDetected: (faces) {
                      this.faces.value = faces;
                    },
                  ),
                  ValueListenableBuilder<List<FaceScore>>(
                    valueListenable: faces,
                    builder: (context, value, child) {
                      return FaceBoundingBoxOverlay(
                        faces: value,
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
