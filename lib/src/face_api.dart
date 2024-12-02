import 'dart:async';
import 'dart:js_interop';

import 'package:face_api_web/face_api_web.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

final FaceAPIService faceapi = FaceAPIService();

class FaceAPIService {
  static const defaultModelUrl =
      'https://raw.githubusercontent.com/justadudewhohacks/face-api.js/refs/heads/master/weights/';
  final Map<FaceDetectionModel, FutureOr> _models = {};
  final Map<FaceDetectionFeature, FutureOr> _features = {};

  FaceAPIService();

  Future<bool> loadModel(FaceDetectionModel model) async {
    var api = internalFaceAPI;
    assert(api != null, 'FaceAPI is not available');
    if (!_models.containsKey(model)) {
      var future = model.load(api!);
      _models[model] = future;
      await future;
      _models[model] = true;
      return true;
    }
    return false;
  }

  Future<bool> loadFeature(FaceDetectionFeature feature) async {
    var api = internalFaceAPI;
    assert(api != null, 'FaceAPI is not available');
    if (!_features.containsKey(feature)) {
      var future = feature.load(api!);
      _features[feature] = future;
      await future;
      _features[feature] = true;
      return true;
    }
    return false;
  }

  Future<bool> isModelLoaded(FaceDetectionModel model) async {
    var future = _models[model];
    if (future != null) {
      if (future is Future) {
        await future;
      }
      return true;
    }
    return false;
  }

  Future<bool> isFeatureLoaded(FaceDetectionFeature feature) async {
    var future = _features[feature];
    if (future != null) {
      if (future is Future) {
        await future;
      }
      return true;
    }
    return false;
  }
}

class FaceScore {
  final FaceReference reference;
  final double score;

  const FaceScore(this.reference, this.score);
}

class FaceRecognition {
  final FaceReferences references;

  const FaceRecognition(this.references);

  FaceScore? findBestMatch(Face queryFace, double distanceThreshold) {
    if (queryFace.descriptor == null) {
      return null;
    }
    LabeledFaceDescriptors descriptors =
        LabeledFaceDescriptors('?'.toJS, <JSObject>[].toJS);
    var faceMatcher = FaceMatcher([descriptors].toJS, distanceThreshold.toJS);
    var bestMatch = references.references.map(
      (reference) {
        List<JSObject> descriptors = reference.references
            .where((face) => face.descriptor != null)
            .map((face) => face.descriptor!._descriptor)
            .toList();
        double score = faceMatcher
            .computeMeanDistance(
                queryFace.descriptor!._descriptor, descriptors.toJS)
            .toDartDouble;
        return FaceScore(
            FaceReference([queryFace], label: reference.label), score);
      },
    ).toList();
    if (bestMatch.isEmpty) {
      return null;
    }
    var best = bestMatch.reduce(
        (value, element) => value.score < element.score ? value : element);
    if (best.score < distanceThreshold) {
      return best;
    }
    return null;
  }
}

class FaceDescriptor {
  final JSObject _descriptor;

  FaceDescriptor(this._descriptor);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FaceDescriptor && other._descriptor == _descriptor;
  }

  @override
  int get hashCode => _descriptor.hashCode;
}

enum Gender {
  male('MALE'),
  female('FEMALE');

  final String value;

  const Gender(this.value);
}

class Face {
  final double score;
  final Rect boundingBox;
  final FaceDescriptor? descriptor;
  final Gender? gender;
  final double? age;
  final Map<FaceExpression, double>? expressions;

  const Face(this.score, this.boundingBox, this.descriptor, this.expressions,
      this.gender, this.age);

  @override
  String toString() {
    return 'Face{score: $score, boundingBox: $boundingBox, descriptor: $descriptor}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Face &&
        other.score == score &&
        other.boundingBox == boundingBox &&
        other.descriptor == descriptor;
  }

  @override
  int get hashCode => Object.hash(score, boundingBox, descriptor);
}

class DetectionResult {
  final DateTime timestamp;
  final List<Face> faces;

  const DetectionResult(this.timestamp, this.faces);

  @override
  String toString() {
    return 'DetectionResult{faces: $faces}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DetectionResult && listEquals(other.faces, faces);
  }

  @override
  int get hashCode => faces.hashCode;
}

abstract class CaptureMode {
  const CaptureMode();
  Future<CaptureSession> createSession(FaceAPI api, CameraSession session);
}

abstract class CaptureSession {
  CaptureMode get mode;
  CameraSession get cameraSession;
  Future<DetectionResult> detect();
}

class SingleFaceCaptureMode extends CaptureMode {
  final FaceDetectionModel model;
  final List<FaceDetectionFeature> features;
  const SingleFaceCaptureMode(this.model, {this.features = const []});

  @override
  Future<CaptureSession> createSession(
      FaceAPI api, CameraSession session) async {
    var isModelLoaded = await faceapi.isModelLoaded(model);
    assert(isModelLoaded, 'Model is not loaded');
    var task = api.detectSingleFace(
        session.videoElement, model.createOptions(api) as JSObject);
    return SingleFaceCaptureSession(this, session, task, features);
  }
}

List<FaceDetectionFeature> getFeatures({
  bool faceLandmark = false,
  bool faceDescriptor = false,
  bool faceExpression = false,
  bool faceAgeAndGender = false,
}) {
  List<FaceDetectionFeature> features = [];
  if (faceLandmark) {
    features.add(FaceDetectionFeature.faceLandmark);
  }
  if (faceDescriptor) {
    if (!faceLandmark) {
      // Face descriptor requires face landmark
      features.add(FaceDetectionFeature.faceLandmark);
    }
    features.add(FaceDetectionFeature.faceDescriptor);
  }
  if (faceExpression) {
    features.add(FaceDetectionFeature.faceExpression);
  }
  if (faceAgeAndGender) {
    features.add(FaceDetectionFeature.faceAgeAndGender);
  }
  return features;
}

enum FaceExpression {
  angry,
  disgusted,
  fearful,
  happy,
  neutral,
  sad,
  surprised,
}

class SingleFaceCaptureSession extends CaptureSession {
  @override
  final SingleFaceCaptureMode mode;
  final DetectSingleFaceTask _task;
  final List<FaceDetectionFeature> features;
  @override
  final CameraSession cameraSession;

  SingleFaceCaptureSession(
      this.mode, this.cameraSession, this._task, this.features);

  @override
  Future<DetectionResult> detect() async {
    var task = _task;
    for (int i = 0; i < features.length; i++) {
      var feature = features[i];
      var isFeatureLoaded = await faceapi.isFeatureLoaded(feature);
      assert(isFeatureLoaded, 'Feature is not loaded');
      task = feature.runSingleFace(internalFaceAPI!, task);
    }
    try {
      var result = await task.run().toDart;
      if (result == null) {
        return DetectionResult(DateTime.now(), []);
      } else {
        var resultScore = result.detection?.score ?? result.score;
        var resultBox = result.detection?.relativeBox ?? result.relativeBox;
        var expressions = result.expressions;
        Map<FaceExpression, double>? faceExpressions;
        if (expressions != null) {
          faceExpressions = {
            FaceExpression.angry: expressions.angry.toDartDouble,
            FaceExpression.disgusted: expressions.disgusted.toDartDouble,
            FaceExpression.fearful: expressions.fearful.toDartDouble,
            FaceExpression.happy: expressions.happy.toDartDouble,
            FaceExpression.neutral: expressions.neutral.toDartDouble,
            FaceExpression.sad: expressions.sad.toDartDouble,
            FaceExpression.surprised: expressions.surprised.toDartDouble,
          };
        }
        var descriptor = result.descriptor;
        FaceDescriptor? faceDescriptor;
        if (descriptor != null) {
          faceDescriptor = FaceDescriptor(descriptor);
        }
        var age = result.age?.toDartDouble;
        var genderString = result.gender?.toDart;
        var gender = switch (genderString) {
          'male' => Gender.male,
          'female' => Gender.female,
          _ => null,
        };
        return DetectionResult(
          DateTime.now(),
          [
            if (resultBox != null)
              Face(
                resultScore?.toDartDouble ?? 0,
                Rect.fromLTWH(
                  resultBox.x.toDartDouble,
                  resultBox.y.toDartDouble,
                  resultBox.width.toDartDouble,
                  resultBox.height.toDartDouble,
                ),
                faceDescriptor,
                faceExpressions,
                gender,
                age,
              ),
          ],
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error: $error');
        print(stackTrace);
      }
    }
    return DetectionResult(DateTime.now(), []);
  }
}

class MultipleFacesCaptureMode extends CaptureMode {
  final FaceDetectionModel model;
  final List<FaceDetectionFeature> features;
  const MultipleFacesCaptureMode(this.model, {this.features = const []});

  @override
  Future<CaptureSession> createSession(
      FaceAPI api, CameraSession session) async {
    var isModelLoaded = await faceapi.isModelLoaded(model);
    assert(isModelLoaded, 'Model is not loaded');
    var task = api.detectAllFaces(
        session.videoElement, model.createOptions(api) as JSObject);

    return MultipleFacesCaptureSession(this, session, task, features);
  }
}

class MultipleFacesCaptureSession extends CaptureSession {
  @override
  final MultipleFacesCaptureMode mode;
  final DetectAllFaceTask _task;
  final List<FaceDetectionFeature> features;
  @override
  final CameraSession cameraSession;

  MultipleFacesCaptureSession(
      this.mode, this.cameraSession, this._task, this.features);

  @override
  Future<DetectionResult> detect() async {
    var task = _task;
    for (int i = 0; i < features.length; i++) {
      var feature = features[i];
      var isFeatureLoaded = await faceapi.isFeatureLoaded(feature);
      assert(isFeatureLoaded, 'Feature is not loaded');
      task = feature.runMultipleFaces(internalFaceAPI!, task);
    }
    var result = await task.run().toDart;
    try {
      if (result == null) {
        return DetectionResult(DateTime.now(), []);
      } else {
        return DetectionResult(
          DateTime.now(),
          result.toDart
              .map(
                (face) {
                  var faceScore = face.detection?.score ?? face.score;
                  var box = face.detection?.relativeBox ?? face.relativeBox;
                  if (box == null) {
                    return null;
                  }
                  var descriptor = face.descriptor;
                  FaceDescriptor? faceDescriptor;
                  if (descriptor != null) {
                    faceDescriptor = FaceDescriptor(descriptor);
                  }
                  var expressions = face.expressions;
                  Map<FaceExpression, double>? faceExpressions;
                  if (expressions != null) {
                    faceExpressions = {
                      FaceExpression.angry: expressions.angry.toDartDouble,
                      FaceExpression.disgusted:
                          expressions.disgusted.toDartDouble,
                      FaceExpression.fearful: expressions.fearful.toDartDouble,
                      FaceExpression.happy: expressions.happy.toDartDouble,
                      FaceExpression.neutral: expressions.neutral.toDartDouble,
                      FaceExpression.sad: expressions.sad.toDartDouble,
                      FaceExpression.surprised:
                          expressions.surprised.toDartDouble,
                    };
                  }
                  var age = face.age?.toDartDouble;
                  var genderString = face.gender?.toDart;
                  var gender = switch (genderString) {
                    'male' => Gender.male,
                    'female' => Gender.female,
                    _ => null,
                  };
                  return Face(
                    faceScore?.toDartDouble ?? 0,
                    Rect.fromLTWH(
                      box.x.toDartDouble,
                      box.y.toDartDouble,
                      box.width.toDartDouble,
                      box.height.toDartDouble,
                    ),
                    faceDescriptor,
                    faceExpressions,
                    gender,
                    age,
                  );
                },
              )
              .whereType<Face>()
              .toList(),
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error: $error');
        print(stackTrace);
      }
    }
    return DetectionResult(DateTime.now(), []);
  }
}

class FaceDetectionController extends ValueNotifier<DetectionResult?> {
  late Ticker _ticker;
  CaptureSession? _session;

  bool get isRunning => _ticker.isActive;

  FaceDetectionController(TickerProvider vsync) : super(null) {
    _ticker = vsync.createTicker(_tick);
  }

  void stop() {
    assert(_session != null, 'Controller is not started');
    _ticker.stop();
    _session = null;
    value = null;
  }

  Future<void> start(CameraSession session, CaptureMode mode) async {
    assert(_session == null, 'Controller is already started');
    _session = await mode.createSession(internalFaceAPI!, session);
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    if (_session != null) {
      _session!.detect().then((result) {
        if (!_ticker.isActive) {
          // disposed
          return;
        }
        if (value == null || result.timestamp.isAfter(value!.timestamp)) {
          value = result;
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

typedef FaceDetectionCallback = void Function(List<FaceScore> faces);

class FaceReferences {
  final List<FaceReference> references;

  const FaceReferences(this.references);
}

class FaceReference {
  final String? label;
  final List<Face> references;

  const FaceReference(this.references, {this.label});
}

class FaceCameraDetector extends StatefulWidget {
  final CameraInfo selectedCamera;
  final CaptureMode captureMode;
  final CameraCallback? onCameraCreated;
  final FaceReferences? references;
  final FaceDetectionCallback? onFaceDetected;
  final double distanceThreshold;
  const FaceCameraDetector(
      {super.key,
      required this.selectedCamera,
      required this.captureMode,
      this.references,
      this.onCameraCreated,
      this.onFaceDetected,
      this.distanceThreshold = 0.5});

  @override
  State<FaceCameraDetector> createState() => _FaceCameraDetectorState();
}

class _FaceCameraDetectorState extends State<FaceCameraDetector>
    with SingleTickerProviderStateMixin {
  late FaceDetectionController controller;
  Future<void>? _initialization;

  @override
  void initState() {
    super.initState();
    controller = FaceDetectionController(this);
    controller.addListener(() {
      var result = controller.value;
      if (result != null) {
        if (widget.references != null) {
          var faceDistance = FaceRecognition(widget.references!);
          List<FaceScore> scores = result.faces.map(
            (face) {
              var findBestMatch =
                  faceDistance.findBestMatch(face, widget.distanceThreshold);
              if (findBestMatch == null) {
                return FaceScore(FaceReference([face]), face.score);
              }
              return findBestMatch;
            },
          ).toList();
          widget.onFaceDetected?.call(scores);
        } else {
          widget.onFaceDetected?.call(result.faces.map((face) {
            return FaceScore(FaceReference([face]), face.score);
          }).toList());
        }
      } else {
        widget.onFaceDetected?.call([]);
      }
    });
  }

  void _onCameraCreated(CameraSession session) async {
    var current = _initialization;
    if (current != null) {
      await current;
    }
    if (controller.isRunning) {
      controller.stop();
    }
    _initialization = controller.start(
      session,
      widget.captureMode,
    );
    widget.onCameraCreated?.call(session);
    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CameraWidget(
      selectedCamera: widget.selectedCamera,
      onCameraCreated: _onCameraCreated,
    );
  }
}

class FaceBoundingBoxOverlay extends StatelessWidget {
  final List<FaceScore> faces;

  const FaceBoundingBoxOverlay({super.key, required this.faces});

  String _getLabel(FaceScore face) {
    String? label = face.reference.label;
    List<String> extras = [];
    Map<FaceExpression, double> combinedExpressions = {};
    for (var face in face.reference.references) {
      if (face.expressions != null) {
        face.expressions!.forEach((key, value) {
          combinedExpressions[key] = (combinedExpressions[key] ?? 0) + value;
        });
      }
    }
    if (combinedExpressions.isNotEmpty) {
      var maxExpression = combinedExpressions.entries.reduce(
          (value, element) => value.value > element.value ? value : element);
      extras.add(maxExpression.key.name);
    }
    Map<Gender, int> genderCount = {};
    double averageAge = 0;
    for (var face in face.reference.references) {
      var gender = face.gender;
      if (gender != null) {
        var count = genderCount[gender] ?? 0;
        genderCount[gender] = count + 1;
      }
      if (face.age != null) {
        averageAge += face.age!;
      }
    }
    if (face.reference.references.isNotEmpty) {
      averageAge /= face.reference.references.length;
    }
    if (averageAge > 0) {
      extras.add('${averageAge.toStringAsFixed(0)} years old');
    }
    // find most max gender
    if (genderCount.isNotEmpty) {
      var maxGender = genderCount.entries.reduce(
          (value, element) => value.value > element.value ? value : element);
      extras.add(maxGender.key.value);
    }
    if (label == null) {
      if (extras.isNotEmpty) {
        return extras.join(', ');
      }
      return '';
    }
    if (extras.isNotEmpty) {
      return '$label (${extras.join(', ')})';
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var width = constraints.maxWidth;
      var height = constraints.maxHeight;
      if (width == 0 || height == 0 || faces.isEmpty) {
        return const SizedBox();
      }
      return Stack(
        children: [
          for (var face in faces)
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                face.reference.references.first.boundingBox.left * width,
                face.reference.references.first.boundingBox.top * height,
                face.reference.references.first.boundingBox.width * width,
                face.reference.references.first.boundingBox.height * height,
              ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF00FF00),
                    width: 2,
                  ),
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        _getLabel(face),
                        style: const TextStyle(
                          color: Color(0xFF00FF00),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        face.score.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Color(0xFF00FF00),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

abstract class FaceDetectionModel {
  static const tinyFace = TinyFaceModel();
  static const mtcnn = MtcnnModel();
  static const ssdMobilenetv1 = SsdMobilenetv1Model();

  const FaceDetectionModel();
  Future<void> load(FaceAPI api);
  Object createOptions(FaceAPI api);
}

abstract class FaceDetectionFeature {
  static const faceLandmark = FaceLandmarkModel();
  static const faceLandmarkTiny = FaceLandmarkTinyModel();
  static const faceDescriptor = FaceDescriptorModel();
  static const faceExpression = FaceExpressionModel();
  static const faceAgeAndGender = FaceAgeAndGenderModel();

  const FaceDetectionFeature();
  Future<void> load(FaceAPI api);
  DetectSingleFaceTask runSingleFace(FaceAPI api, DetectSingleFaceTask task);
  DetectAllFaceTask runMultipleFaces(FaceAPI api, DetectAllFaceTask task);
}

class TinyFaceModel extends FaceDetectionModel {
  final String modelUrl;
  final double? inputSize;
  final double? scoreThreshold;

  const TinyFaceModel(
      {this.modelUrl = FaceAPIService.defaultModelUrl,
      this.inputSize,
      this.scoreThreshold});

  @override
  Future<void> load(FaceAPI api) {
    return api.loadTinyFaceDetectorModel(modelUrl.toJS).toDart;
  }

  @override
  Object createOptions(FaceAPI api) {
    return TinyFaceDetectorOptions(TinyFaceDetectorOptionsParams(
      inputSize: inputSize?.toJS,
      scoreThreshold: scoreThreshold?.toJS,
    ));
  }
}

class MtcnnModel extends FaceDetectionModel {
  final String modelUrl;
  final double? minFaceSize;
  final double? scaleFactor;
  final double? scoreThresholds;
  final double? maxNumScales;
  final double? scaleSteps;

  const MtcnnModel(
      {this.modelUrl = FaceAPIService.defaultModelUrl,
      this.minFaceSize,
      this.scaleFactor,
      this.scoreThresholds,
      this.maxNumScales,
      this.scaleSteps});
  @override
  Future<void> load(FaceAPI api) {
    return api.loadMtcnnModel(modelUrl.toJS).toDart;
  }

  @override
  Object createOptions(FaceAPI api) {
    return MtcnnOptions(MtcnnOptionsParams(
      minFaceSize: minFaceSize?.toJS,
      scaleFactor: scaleFactor?.toJS,
      scoreThresholds: scoreThresholds?.toJS,
      maxNumScales: maxNumScales?.toJS,
      scaleSteps: scaleSteps?.toJS,
    ));
  }
}

class SsdMobilenetv1Model extends FaceDetectionModel {
  final String modelUrl;
  final double? minConfidence;
  final double? maxResults;
  const SsdMobilenetv1Model(
      {this.modelUrl = FaceAPIService.defaultModelUrl,
      this.minConfidence,
      this.maxResults});

  @override
  Future<void> load(FaceAPI api) {
    return api.loadSsdMobilenetv1Model(modelUrl.toJS).toDart;
  }

  @override
  Object createOptions(FaceAPI api) {
    return SsdMobilenetv1Options(SsdMobilenetv1OptionsParams(
      minConfidence: minConfidence?.toJS,
      maxResults: maxResults?.toJS,
    ));
  }
}

class FaceLandmarkModel extends FaceDetectionFeature {
  final String _modelUrl;
  const FaceLandmarkModel([this._modelUrl = FaceAPIService.defaultModelUrl]);
  @override
  Future<void> load(FaceAPI api) {
    return api.loadFaceLandmarkModel(_modelUrl.toJS).toDart;
  }

  @override
  DetectAllFaceTask runMultipleFaces(FaceAPI api, DetectAllFaceTask task) {
    return task.withFaceLandmarks(false.toJS);
  }

  @override
  DetectSingleFaceTask runSingleFace(FaceAPI api, DetectSingleFaceTask task) {
    return task.withFaceLandmarks(false.toJS);
  }
}

class FaceLandmarkTinyModel extends FaceDetectionFeature {
  final String _modelUrl;
  const FaceLandmarkTinyModel(
      [this._modelUrl = FaceAPIService.defaultModelUrl]);
  @override
  Future<void> load(FaceAPI api) {
    return api.loadFaceLandmarkTinyModel(_modelUrl.toJS).toDart;
  }

  @override
  DetectAllFaceTask runMultipleFaces(FaceAPI api, DetectAllFaceTask task) {
    return task.withFaceLandmarks(true.toJS);
  }

  @override
  DetectSingleFaceTask runSingleFace(FaceAPI api, DetectSingleFaceTask task) {
    return task.withFaceLandmarks(true.toJS);
  }
}

class FaceExpressionModel extends FaceDetectionFeature {
  final String _modelUrl;
  const FaceExpressionModel([this._modelUrl = FaceAPIService.defaultModelUrl]);
  @override
  Future<void> load(FaceAPI api) {
    return api.loadFaceExpressionModel(_modelUrl.toJS).toDart;
  }

  @override
  DetectAllFaceTask runMultipleFaces(FaceAPI api, DetectAllFaceTask task) {
    return task.withFaceExpressions();
  }

  @override
  DetectSingleFaceTask runSingleFace(FaceAPI api, DetectSingleFaceTask task) {
    return task.withFaceExpressions();
  }
}

class FaceAgeAndGenderModel extends FaceDetectionFeature {
  final String _modelUrl;
  const FaceAgeAndGenderModel(
      [this._modelUrl = FaceAPIService.defaultModelUrl]);
  @override
  Future<void> load(FaceAPI api) {
    return api.loadAgeGenderModel(_modelUrl.toJS).toDart;
  }

  @override
  DetectAllFaceTask runMultipleFaces(FaceAPI api, DetectAllFaceTask task) {
    return task.withAgeAndGender();
  }

  @override
  DetectSingleFaceTask runSingleFace(FaceAPI api, DetectSingleFaceTask task) {
    return task.withAgeAndGender();
  }
}

class FaceDescriptorModel extends FaceDetectionFeature {
  final String _modelUrl;
  const FaceDescriptorModel([this._modelUrl = FaceAPIService.defaultModelUrl]);
  @override
  Future<void> load(FaceAPI api) {
    return api.loadFaceRecognitionModel(_modelUrl.toJS).toDart;
  }

  @override
  DetectAllFaceTask runMultipleFaces(FaceAPI api, DetectAllFaceTask task) {
    return task.withFaceDescriptors();
  }

  @override
  DetectSingleFaceTask runSingleFace(FaceAPI api, DetectSingleFaceTask task) {
    return task.withFaceDescriptor();
  }
}
