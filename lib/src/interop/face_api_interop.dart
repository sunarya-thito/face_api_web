import 'dart:js_interop';

@JS("faceapi")
external FaceAPI? get internalFaceAPI;

extension type FaceAPI._(JSObject _) implements JSObject {
  external JSPromise loadSsdMobilenetv1Model(JSString url);
  external JSPromise loadTinyFaceDetectorModel(JSString url);
  external JSPromise loadMtcnnModel(JSString url);
  external JSPromise loadFaceLandmarkModel(JSString url);
  external JSPromise loadFaceLandmarkTinyModel(JSString url);
  external JSPromise loadFaceRecognitionModel(JSString url);
  external JSPromise loadFaceExpressionModel(JSString url);
  external JSPromise loadAgeGenderModel(JSString url);
  external JSObject get MtcnnOptions;
  external JSObject get SsdMobilenetv1Options;
  external DetectAllFaceTask detectAllFaces(JSAny input, JSObject options);
  external DetectSingleFaceTask detectSingleFace(JSAny input, JSObject options);
}

@JS("faceapi.ComposableTask")
extension type ComposableTask<T extends JSAny?>._(JSObject _)
    implements JSObject {
  external JSPromise<T> run();
  external JSPromise<T> then(JSFunction callback);
}

extension type TinyFaceDetectorOptionsParams._(JSObject _) implements JSObject {
  external factory TinyFaceDetectorOptionsParams(
      {JSNumber? inputSize, JSNumber? scoreThreshold});
}

@JS("faceapi.TinyFaceDetectorOptions")
extension type TinyFaceDetectorOptions._(JSObject _) implements JSObject {
  external factory TinyFaceDetectorOptions(
      TinyFaceDetectorOptionsParams options);
}

extension type SsdMobilenetv1OptionsParams._(JSObject _) implements JSObject {
  external factory SsdMobilenetv1OptionsParams(
      {JSNumber? minConfidence, JSNumber? maxResults});
}

@JS("faceapi.SsdMobilenetv1Options")
extension type SsdMobilenetv1Options._(JSObject _) implements JSObject {
  external factory SsdMobilenetv1Options(SsdMobilenetv1OptionsParams options);
}

extension type MtcnnOptionsParams._(JSObject _) implements JSObject {
  external factory MtcnnOptionsParams(
      {JSNumber? minFaceSize,
      JSNumber? scaleFactor,
      JSNumber? scoreThresholds,
      JSNumber? maxNumScales,
      JSNumber? scaleSteps});
}

@JS("faceapi.MtcnnOptions")
extension type MtcnnOptions._(JSObject _) implements JSObject {
  external factory MtcnnOptions(MtcnnOptionsParams options);
}

extension type DetectAllFaceTask._(JSObject _)
    implements JSObject, ComposableTask<JSArray<FaceDetection>?> {
  external DetectAllFaceTask withFaceLandmarks(JSBoolean useTinyLandmarkNet);
  external DetectAllFaceTask withFaceDescriptors();
  external DetectAllFaceTask withFaceExpressions();
  external DetectAllFaceTask withAgeAndGender();
}
extension type DetectSingleFaceTask._(JSObject _)
    implements JSObject, ComposableTask<FaceDetection?> {
  external DetectSingleFaceTask withFaceLandmarks(JSBoolean useTinyLandmarkNet);
  external DetectSingleFaceTask withFaceDescriptor();
  external DetectSingleFaceTask withFaceExpressions();
  external DetectSingleFaceTask withAgeAndGender();
}

@JS("faceapi.FaceDetection")
extension type FaceDetection._(JSObject _) implements JSObject {
  external JSNumber? get score;
  external Box? get relativeBox;
  external JSNumber get imageWidth;
  external JSNumber get imageHeight;
  external JSArray<Point>? get positions;
  external Point? get shift;

  external JSObject? get descriptor;
  external FaceExpressions? get expressions;
  external FaceDetection? get detection;
  external JSNumber? get age;
  external JSString? get gender;
}

extension type FaceExpressions._(JSObject _) implements JSObject {
  external JSNumber get neutral;
  external JSNumber get happy;
  external JSNumber get sad;
  external JSNumber get angry;
  external JSNumber get fearful;
  external JSNumber get disgusted;
  external JSNumber get surprised;
}

extension type Point._(JSObject _) implements JSObject {
  external JSNumber get x;
  external JSNumber get y;
}

@JS("faceapi.Box")
extension type Box._(JSObject _) implements JSObject {
  external JSNumber get x;
  external JSNumber get y;
  external JSNumber get width;
  external JSNumber get height;
}

@JS("faceapi.LabeledFaceDescriptors")
extension type LabeledFaceDescriptors._(JSObject _) implements JSObject {
  external factory LabeledFaceDescriptors(
      JSString label, JSArray<JSObject> descriptors);
}

@JS("faceapi.FaceMatcher")
extension type FaceMatcher._(JSObject _) implements JSObject {
  external factory FaceMatcher(JSObject input, [JSNumber distanceThreshold]);
  external JSNumber computeMeanDistance(
      JSObject queryDescriptors, JSArray<JSObject> descriptors);
}

extension type FaceMatch._(JSObject _) implements JSObject {
  external JSNumber get distance;
  external JSString get label;
}
