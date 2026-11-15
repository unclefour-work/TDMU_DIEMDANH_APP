// ignore_for_file: no_leading_underscores_for_local_identifiers, unintended_html_in_doc_comment, duplicate_ignore, unused_element, curly_braces_in_flow_control_structures, avoid_print, depend_on_referenced_packages

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

import 'package:app_diem_danh/services/face_quality_filter.dart';

class OnDeviceFaceConfig {
  static const String recognitionModelPath =
      'assets/models/mbf_sa_kd_fp32.onnx';
  static const String antispoofV2Path =
      'assets/models/2_7_80x80_MiniFASNetV2.onnx';
  static const String antispoofV1SEPath =
      'assets/models/4_0_0_80x80_MiniFASNetV1SE.onnx';

  static const double threshold = 0.40;
  static const double marginWarningThreshold = 0.05;
  static const int minPhotosForEnroll = 3;
  static const int maxPhotosForEnroll = 10;
  static const double minMargin = 0.05;
  static const double antispoofScaleV2 = 2.7;
  static const double antispoofScaleV1SE = 4.0;
  static const double antispoofRealThreshold = 0.0;
  static const bool antispoofForScan = true;
  static const bool useAlignment = true;
  static const bool antispoofForEnroll = false;
  static const double minEnrollIntra = 0.70;

  static const double enrollMaskProbMax = 0.35;

  static const double enrollNormHardMin = 30.0;

  static const double enrollNormSoftMin = 33.5;

  static const double scanHintMaskProb = 0.5;

  static const bool enrollGateShadowMode = true;

  static const bool logQualityGate = false;

  static const double enrollDominanceMaxRatio = 0.5;
}

class FaceTopEntry {
  final String name;
  final double confidence;
  final String? studentId;
  const FaceTopEntry({
    required this.name,
    required this.confidence,
    this.studentId,
  });
}

class FaceTiming {
  final int detect;
  final int spoof;
  final int quality;
  final int embed;
  final int match;
  final int total;

  const FaceTiming({
    required this.detect,
    required this.spoof,
    required this.quality,
    required this.embed,
    required this.match,
    required this.total,
  });

  @override
  String toString() =>
      'detect=${detect}ms spoof=${spoof}ms quality=${quality}ms '
      'embed=${embed}ms match=${match}ms TOTAL=${total}ms';
}

class FaceRecognizeResult {
  final String name;
  final double confidence;
  final bool isKnown;
  final List<FaceTopEntry> top3;
  final double margin;
  final bool warning;
  final String message;
  final String? errorMsg;

  final String? hint;

  final FaceTiming? timing;

  const FaceRecognizeResult({
    required this.name,
    required this.confidence,
    required this.isKnown,
    required this.top3,
    required this.margin,
    required this.warning,
    required this.message,
    this.errorMsg,
    this.hint,
    this.timing,
  });

  factory FaceRecognizeResult.error(String msg) => FaceRecognizeResult(
    name: 'Unknown',
    confidence: 0,
    isKnown: false,
    top3: const [],
    margin: 0,
    warning: false,
    message: msg,
    errorMsg: msg,
  );
}

class FaceVerifyResult {
  final bool isMatch;
  final String recognizedAs;
  final double confidence;
  final List<FaceTopEntry> top3;
  final double margin;
  final bool warning;
  final String message;

  final String? hint;

  const FaceVerifyResult({
    required this.isMatch,
    required this.recognizedAs,
    required this.confidence,
    required this.top3,
    required this.margin,
    required this.warning,
    required this.message,
    this.hint,
  });
}

class EnrollResult {
  final bool success;
  final String studentId;
  final String name;
  final int photosUsed;
  final List<int> photosFailed;
  final String message;
  final double? intraSimilarity;

  const EnrollResult({
    required this.success,
    required this.studentId,
    required this.name,
    required this.photosUsed,
    required this.photosFailed,
    required this.message,
    this.intraSimilarity,
  });
}

class FaceNotFoundException implements Exception {
  final String message;
  const FaceNotFoundException([
    this.message = 'Không tìm thấy khuôn mặt trong ảnh',
  ]);
  @override
  String toString() => message;
}

class AntiSpoofResult {
  final bool isReal;

  final double realScore;

  final List<double> probEnsemble;

  const AntiSpoofResult({
    required this.isReal,
    required this.realScore,
    required this.probEnsemble,
  });

  String get label => isReal ? 'REAL' : 'SPOOF';

  @override
  String toString() =>
      '${isReal ? "✅REAL" : "❌SPOOF"} score=${realScore.toStringAsFixed(3)} '
      '[${probEnsemble.map((p) => p.toStringAsFixed(3)).join(",")}]';
}

class _RecognitionEngine {
  static _RecognitionEngine? _instance;
  OrtSession? _session;
  bool _initialized = false;

  _RecognitionEngine._();
  static _RecognitionEngine get instance {
    _instance ??= _RecognitionEngine._();
    return _instance!;
  }

  Future<void> init() async {
    if (_initialized) return;
    OrtEnv.instance.init();
    final file = await _loadAsset(
      OnDeviceFaceConfig.recognitionModelPath,
      'mbf_sa_kd_fp32.onnx',
    );
    final opts = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    _session = OrtSession.fromFile(file, opts);
    _initialized = true;
  }

  Future<({List<double> emb, double rawNorm})> runInference(
    img.Image face112,
  ) async {
    await init();

    const H = 112, W = 112, C = 3;
    final data = Float32List(C * H * W);

    for (int h = 0; h < H; h++) {
      for (int w = 0; w < W; w++) {
        final px = face112.getPixel(w, h);
        data[0 * H * W + h * W + w] = (px.r.toDouble() - 127.5) / 128.0;
        data[1 * H * W + h * W + w] = (px.g.toDouble() - 127.5) / 128.0;
        data[2 * H * W + h * W + w] = (px.b.toDouble() - 127.5) / 128.0;
      }
    }
    final tensor = OrtValueTensor.createTensorWithDataList(data, [1, C, H, W]);
    final outputs = await _session!.runAsync(OrtRunOptions(), {
      _session!.inputNames.first: tensor,
    });
    tensor.release();

    final raw = outputs?.first?.value;
    outputs?.forEach((e) => e?.release());

    final flat = _flattenOutput(raw);
    double n = 0;
    for (final v in flat) {
      n += v * v;
    }
    final rawNorm = math.sqrt(n);
    return (emb: _l2Normalize(flat), rawNorm: rawNorm);
  }

  void dispose() {
    _session?.release();
    _initialized = false;
    _instance = null;
  }
}

class _AntiSpoofEngine {
  static _AntiSpoofEngine? _instance;
  OrtSession? _sessV2;
  OrtSession? _sessV1SE;
  bool _initialized = false;

  _AntiSpoofEngine._();
  static _AntiSpoofEngine get instance {
    _instance ??= _AntiSpoofEngine._();
    return _instance!;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      OrtEnv.instance.init();
    } catch (_) {}

    final fileV2 = await _loadAsset(
      OnDeviceFaceConfig.antispoofV2Path,
      '2_7_80x80_MiniFASNetV2.onnx',
    );
    final fileV1SE = await _loadAsset(
      OnDeviceFaceConfig.antispoofV1SEPath,
      '4_0_0_80x80_MiniFASNetV1SE.onnx',
    );

    _sessV2 = OrtSession.fromFile(fileV2, OrtSessionOptions());
    _sessV1SE = OrtSession.fromFile(fileV1SE, OrtSessionOptions());
    _initialized = true;
  }

  Future<AntiSpoofResult> predict(img.Image srcImage, Rect bbox) async {
    await init();

    final probEnsemble = List<double>.filled(3, 0.0);

    for (final entry in [
      (_sessV2!, OnDeviceFaceConfig.antispoofScaleV2),
      (_sessV1SE!, OnDeviceFaceConfig.antispoofScaleV1SE),
    ]) {
      final sess = entry.$1;
      final scale = entry.$2;

      final patch = _cropByScale(srcImage, bbox, scale);

      final patch80 = img.copyResize(
        patch,
        width: 80,
        height: 80,
        interpolation: img.Interpolation.linear,
      );

      const H = 80, W = 80, C = 3;
      final data = Float32List(C * H * W);
      for (int h = 0; h < H; h++) {
        for (int w = 0; w < W; w++) {
          final px = patch80.getPixel(w, h);
          data[0 * H * W + h * W + w] = px.b.toDouble();
          data[1 * H * W + h * W + w] = px.g.toDouble();
          data[2 * H * W + h * W + w] = px.r.toDouble();
        }
      }

      final tensor = OrtValueTensor.createTensorWithDataList(data, [
        1,
        C,
        H,
        W,
      ]);
      final outputs = await sess.runAsync(OrtRunOptions(), {
        sess.inputNames.first: tensor,
      });
      tensor.release();

      final logitsRaw = outputs?.first?.value;
      outputs?.forEach((e) => e?.release());

      final logits = _flattenOutput(logitsRaw);
      final softmax = _softmax(logits);

      for (int i = 0; i < 3; i++) {
        probEnsemble[i] += softmax[i];
      }
    }

    int argmax = 0;
    for (int i = 1; i < 3; i++) {
      if (probEnsemble[i] > probEnsemble[argmax]) argmax = i;
    }
    final isReal = argmax == 1;
    final realScore = probEnsemble[1] / 2.0;

    final pass =
        isReal &&
        (OnDeviceFaceConfig.antispoofRealThreshold <= 0 ||
            realScore >= OnDeviceFaceConfig.antispoofRealThreshold);

    final avg = probEnsemble.map((p) => p / 2.0).toList();
    final result = AntiSpoofResult(
      isReal: pass,
      realScore: realScore,
      probEnsemble: avg,
    );
    return result;
  }

  static img.Image _cropByScale(img.Image src, Rect bbox, double scale) {
    final srcH = src.height.toDouble();
    final srcW = src.width.toDouble();
    final x = bbox.left;
    final y = bbox.top;
    final w = bbox.width;
    final h = bbox.height;

    double s = scale;
    if (h > 0) s = math.min(s, (srcH - 1) / h);
    if (w > 0) s = math.min(s, (srcW - 1) / w);

    final nw = w * s;
    final nh = h * s;
    final cx = x + w / 2;
    final cy = y + h / 2;

    double lx = cx - nw / 2;
    double ly = cy - nh / 2;
    double rx = cx + nw / 2;
    double ry = cy + nh / 2;

    if (lx < 0) {
      rx -= lx;
      lx = 0;
    }
    if (ly < 0) {
      ry -= ly;
      ly = 0;
    }
    if (rx > srcW - 1) {
      lx -= rx - srcW + 1;
      rx = srcW - 1;
    }
    if (ry > srcH - 1) {
      ly -= ry - srcH + 1;
      ry = srcH - 1;
    }

    final x0 = lx.clamp(0, srcW - 1).toInt();
    final y0 = ly.clamp(0, srcH - 1).toInt();
    final x1 = rx.clamp(0, srcW - 1).toInt();
    final y1 = ry.clamp(0, srcH - 1).toInt();
    final cropW = (x1 - x0).clamp(1, srcW.toInt() - x0);
    final cropH = (y1 - y0).clamp(1, srcH.toInt() - y0);

    return img.copyCrop(src, x: x0, y: y0, width: cropW, height: cropH);
  }

  void dispose() {
    _sessV2?.release();
    _sessV1SE?.release();
    _initialized = false;
    _instance = null;
  }
}

class _MaskEngine {
  static _MaskEngine? _instance;
  static _MaskEngine get instance => _instance ??= _MaskEngine._();
  _MaskEngine._();
  OrtSession? _session;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final raw = await rootBundle.load('assets/models/mask_detector.onnx');
    _session = OrtSession.fromBuffer(
      raw.buffer.asUint8List(),
      OrtSessionOptions(),
    );
    _initialized = true;
  }

  Future<double> maskProb(img.Image face112) async {
    await init();
    final im224 = img.copyResize(
      face112,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );
    final data = Float32List(224 * 224 * 3);
    int i = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final p = im224.getPixel(x, y);
        data[i++] = p.r / 127.5 - 1.0;
        data[i++] = p.g / 127.5 - 1.0;
        data[i++] = p.b / 127.5 - 1.0;
      }
    }
    final tensor = OrtValueTensor.createTensorWithDataList(data, [
      1,
      224,
      224,
      3,
    ]);
    final out = await _session!.runAsync(OrtRunOptions(), {
      _session!.inputNames.first: tensor,
    });
    tensor.release();
    final probs = _flattenOutput(out?.first?.value);
    out?.forEach((e) => e?.release());
    return probs[0];
  }
}

class _FaceDetector {
  static _FaceDetector? _instance;
  late final FaceDetector _detector;

  _FaceDetector._() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableClassification: true,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.15,
      ),
    );
  }

  static _FaceDetector get instance {
    _instance ??= _FaceDetector._();
    return _instance!;
  }

  Future<List<Face>> detect(File imageFile) async {
    return await _detector.processImage(
      InputImage.fromFilePath(imageFile.path),
    );
  }

  void dispose() {
    _detector.close();
    _instance = null;
  }
}

class _PrepResult {
  final Face face;
  final img.Image srcImage;
  final img.Image face112;
  final int faceCount;

  final double dominanceRatio;

  const _PrepResult({
    required this.face,
    required this.srcImage,
    required this.face112,
    required this.faceCount,
    required this.dominanceRatio,
  });
}

class _FaceAligner {
  static const List<List<double>> _ref = [
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [41.5493, 92.3655],
    [70.7299, 92.2041],
  ];

  static img.Image? align(img.Image src, Face face) {
    final lm = face.landmarks;
    final le = lm[FaceLandmarkType.leftEye]?.position;
    final re = lm[FaceLandmarkType.rightEye]?.position;
    final no = lm[FaceLandmarkType.noseBase]?.position;
    final ml = lm[FaceLandmarkType.leftMouth]?.position;
    final mr = lm[FaceLandmarkType.rightMouth]?.position;
    if (le == null || re == null || no == null || ml == null || mr == null) {
      return null;
    }
    final src5 = [
      [le.x.toDouble(), le.y.toDouble()],
      [re.x.toDouble(), re.y.toDouble()],
      [no.x.toDouble(), no.y.toDouble()],
      [ml.x.toDouble(), ml.y.toDouble()],
      [mr.x.toDouble(), mr.y.toDouble()],
    ];

    final n = src5.length;
    double sxM = 0, syM = 0, dxM = 0, dyM = 0;
    for (int i = 0; i < n; i++) {
      sxM += src5[i][0];
      syM += src5[i][1];
      dxM += _ref[i][0];
      dyM += _ref[i][1];
    }
    sxM /= n;
    syM /= n;
    dxM /= n;
    dyM /= n;

    double a = 0, b = 0, varSrc = 0;
    for (int i = 0; i < n; i++) {
      final sx = src5[i][0] - sxM;
      final sy = src5[i][1] - syM;
      final dx = _ref[i][0] - dxM;
      final dy = _ref[i][1] - dyM;
      a += dx * sx + dy * sy;
      b += dy * sx - dx * sy;
      varSrc += sx * sx + sy * sy;
    }
    if (varSrc < 1e-9) return null;
    final scCos = a / varSrc;
    final scSin = b / varSrc;
    final tx = dxM - (scCos * sxM - scSin * syM);
    final ty = dyM - (scSin * sxM + scCos * syM);
    final det = scCos * scCos + scSin * scSin;
    if (det < 1e-9) return null;

    final out = img.Image(width: 112, height: 112);
    for (int v = 0; v < 112; v++) {
      for (int u = 0; u < 112; u++) {
        final ddx = u - tx;
        final ddy = v - ty;
        final x = (scCos * ddx + scSin * ddy) / det;
        final y = (-scSin * ddx + scCos * ddy) / det;
        final px = _bilinear(src, x, y);
        out.setPixelRgb(u, v, px[0], px[1], px[2]);
      }
    }
    return out;
  }

  static List<int> _bilinear(img.Image im, double x, double y) {
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x > im.width - 1) x = (im.width - 1).toDouble();
    if (y > im.height - 1) y = (im.height - 1).toDouble();
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = (x0 + 1).clamp(0, im.width - 1);
    final y1 = (y0 + 1).clamp(0, im.height - 1);
    final fx = x - x0;
    final fy = y - y0;
    final p00 = im.getPixel(x0, y0);
    final p10 = im.getPixel(x1, y0);
    final p01 = im.getPixel(x0, y1);
    final p11 = im.getPixel(x1, y1);
    int lerp(num c00, num c10, num c01, num c11) {
      final top = c00 + (c10 - c00) * fx;
      final bot = c01 + (c11 - c01) * fx;
      return (top + (bot - top) * fy).round().clamp(0, 255);
    }

    return [
      lerp(p00.r, p10.r, p01.r, p11.r),
      lerp(p00.g, p10.g, p01.g, p11.g),
      lerp(p00.b, p10.b, p01.b, p11.b),
    ];
  }
}

class _FacePreprocessor {
  static Future<_PrepResult?> preprocessFromFile(File imageFile) async {
    final faces = await _FaceDetector.instance.detect(imageFile);
    if (faces.isEmpty) return null;

    Face face = faces.first;
    double maxArea = 0, secondArea = 0;
    for (final c in faces) {
      final area = c.boundingBox.width * c.boundingBox.height;
      if (area > maxArea) {
        secondArea = maxArea;
        maxArea = area;
        face = c;
      } else if (area > secondArea) {
        secondArea = area;
      }
    }
    final dominanceRatio = maxArea > 0 ? secondArea / maxArea : 0.0;

    final bytes = await imageFile.readAsBytes();
    img.Image? srcImage = img.decodeImage(bytes);
    if (srcImage == null) return null;

    srcImage = img.bakeOrientation(srcImage);

    img.Image face112;
    final aligned = OnDeviceFaceConfig.useAlignment
        ? _FaceAligner.align(srcImage, face)
        : null;
    if (aligned != null) {
      face112 = aligned;
    } else {
      final bb = face.boundingBox;
      final padX = (bb.width * 0.20).round();
      final padY = (bb.height * 0.20).round();
      final x = (bb.left - padX).clamp(0, srcImage.width - 1).toInt();
      final y = (bb.top - padY).clamp(0, srcImage.height - 1).toInt();
      final w = (bb.width + padX * 2).clamp(1, srcImage.width - x).toInt();
      final h = (bb.height + padY * 2).clamp(1, srcImage.height - y).toInt();
      final cropped = img.copyCrop(srcImage, x: x, y: y, width: w, height: h);
      face112 = img.copyResize(
        cropped,
        width: 112,
        height: 112,
        interpolation: img.Interpolation.linear,
      );
    }

    return _PrepResult(
      face: face,
      srcImage: srcImage,
      face112: face112,
      faceCount: faces.length,
      dominanceRatio: dominanceRatio,
    );
  }
}

class _GalleryManager {
  static final _db = FirebaseFirestore.instance;

  static List<_GalleryEntry>? _cache;
  static int? _cachedVersion;

  static DateTime? _lastVersionCheck;
  static const Duration _versionTtl = Duration(seconds: 30);

  static DocumentReference<Map<String, dynamic>> get _versionRef =>
      _db.collection('face_gallery_meta').doc('version');

  static Future<List<_GalleryEntry>> loadGallery() async {
    if (_cache != null &&
        _lastVersionCheck != null &&
        DateTime.now().difference(_lastVersionCheck!) < _versionTtl) {
      return _cache!;
    }
    try {
      final meta = await _versionRef.get();
      _lastVersionCheck = DateTime.now();
      final currentVersion = (meta.data()?['v'] as num?)?.toInt() ?? 0;

      if (_cache != null && _cachedVersion == currentVersion) {
        return _cache!;
      }

      final snap = await _db.collection('face_gallery').get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        final raw = data['embedding'] as List<dynamic>;
        return _GalleryEntry(
          studentId: doc.id,
          name: (data['name'] as String?) ?? '',
          embedding: raw.cast<double>(),
        );
      }).toList();

      _cache = list;
      _cachedVersion = currentVersion;
      return list;
    } catch (_) {
      return _cache ?? [];
    }
  }

  static final Map<String, List<_GalleryEntry>> _classCache = {};
  static int? _classCacheVersion;

  static Future<List<_GalleryEntry>> loadGalleryForClass(String classId) async {
    if (_lastVersionCheck != null &&
        DateTime.now().difference(_lastVersionCheck!) < _versionTtl &&
        _classCache.containsKey(classId)) {
      return _classCache[classId]!;
    }
    try {
      final meta = await _versionRef.get();
      _lastVersionCheck = DateTime.now();
      final currentVersion = (meta.data()?['v'] as num?)?.toInt() ?? 0;

      if (_classCacheVersion == currentVersion &&
          _classCache.containsKey(classId)) {
        return _classCache[classId]!;
      }

      if (_classCacheVersion != currentVersion) {
        _classCache.clear();
        _classCacheVersion = currentVersion;
      }

      final studentSnap = await _db
          .collection('classes')
          .doc(classId)
          .collection('students')
          .get();


      if (studentSnap.docs.isEmpty) {
        return [];
      }

      final masos = studentSnap.docs.map((d) => d.id).toList();

      final List<String> uids = [];
      for (int i = 0; i < masos.length; i += 10) {
        final chunk = masos.sublist(
          i,
          i + 10 > masos.length ? masos.length : i + 10,
        );
        final userSnap = await _db
            .collection('users')
            .where('maSo', whereIn: chunk)
            .get();
        uids.addAll(userSnap.docs.map((d) => d.id));
      }

      final List<_GalleryEntry> entries = [];
      for (int i = 0; i < uids.length; i += 30) {
        final chunk = uids.sublist(
          i,
          i + 30 > uids.length ? uids.length : i + 30,
        );
        final docs = await Future.wait(
          chunk.map((uid) => _db.collection('face_gallery').doc(uid).get()),
        );
        for (final doc in docs) {
          if (!doc.exists) continue;
          final data = doc.data()!;
          final raw = data['embedding'] as List<dynamic>?;
          if (raw == null) continue;
          entries.add(
            _GalleryEntry(
              studentId: doc.id,
              name: (data['name'] as String?) ?? '',
              embedding: raw.cast<double>(),
            ),
          );
        }
      }

      _classCache[classId] = entries;
      return entries;
    } catch (_) {
      return _classCache[classId] ?? await loadGallery();
    }
  }

  static Future<void> saveEmbedding({
    required String studentId,
    required String name,
    required List<double> avgEmbedding,
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection('face_gallery').doc(studentId), {
      'name': name,
      'embedding': avgEmbedding,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_versionRef, {
      'v': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
    _invalidate();
  }

  static Future<void> deleteEmbedding(String studentId) async {
    final batch = _db.batch();
    batch.delete(_db.collection('face_gallery').doc(studentId));
    batch.set(_versionRef, {
      'v': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
    _invalidate();
  }

  static Future<bool> hasEmbedding(String studentId) async {
    final doc = await _db.collection('face_gallery').doc(studentId).get();
    return doc.exists;
  }

  static void _invalidate() {
    _cache = null;
    _cachedVersion = null;
    _lastVersionCheck = null;
  }
}

class _GalleryEntry {
  final String studentId;
  final String name;

  final Float32List embedding;
  _GalleryEntry({
    required this.studentId,
    required this.name,
    required List<double> embedding,
  }) : embedding = Float32List.fromList(embedding);
}

class _Matcher {
  static double cosine(Float32List a, Float32List b) {
    double dot = 0;
    final n = a.length;
    for (int i = 0; i < n; i++) dot += a[i] * b[i];
    return dot.clamp(-1.0, 1.0);
  }

  static double cosineList(List<double> a, List<double> b) =>
      cosine(Float32List.fromList(a), Float32List.fromList(b));

  static List<_MatchResult> match(
    List<double> query,
    List<_GalleryEntry> gallery, {
    int topK = 3,
  }) {
    final q = Float32List.fromList(query);
    final results =
        gallery
            .map(
              (e) => _MatchResult(entry: e, similarity: cosine(q, e.embedding)),
            )
            .toList()
          ..sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(topK).toList();
  }
}

class _MatchResult {
  final _GalleryEntry entry;
  final double similarity;
  const _MatchResult({required this.entry, required this.similarity});
}

Future<File> _loadAsset(String assetPath, String filename) async {
  final byteData = await rootBundle.load(assetPath);
  final bytes = byteData.buffer.asUint8List();
  final tmpDir = await getTemporaryDirectory();
  final file = File('${tmpDir.path}/$filename');
  if (!file.existsSync() || file.lengthSync() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file;
}

List<double> _flattenOutput(dynamic raw) {
  if (raw is List) {
    final inner = raw.first;
    if (inner is List) return inner.cast<double>();
    return (raw).cast<double>();
  }
  throw Exception('Unexpected ONNX output type: ${raw.runtimeType}');
}

List<double> _softmax(List<double> logits) {
  final maxV = logits.reduce(math.max);
  final exp = logits.map((x) => math.exp(x - maxV)).toList();
  final sum = exp.reduce((a, b) => a + b);
  return exp.map((x) => x / sum).toList();
}

List<double> _l2Normalize(List<double> vec) {
  double norm = 0;
  for (final v in vec) norm += v * v;
  norm = math.sqrt(norm);
  if (norm < 1e-10) return vec;
  return vec.map((v) => v / norm).toList();
}

class _QualityException implements Exception {
  final String message;
  const _QualityException(this.message);
  @override
  String toString() => message;
}

class _SpoofException implements Exception {
  final String message;
  final AntiSpoofResult result;
  const _SpoofException(this.message, this.result);
  @override
  String toString() => message;
}

class ApiFaceService {
  static Future<bool> checkHealth() async {
    try {
      await _RecognitionEngine.instance.init();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> warmUp() async {
    await Future.wait([
      _RecognitionEngine.instance.init(),
      _AntiSpoofEngine.instance.init(),
      _MaskEngine.instance.init().catchError((_) {}),
    ]);
  }

  static Future<({String tier, String reason})> checkPhotoQuality(
    File photo,
  ) async {
    try {
      final prep = await _FacePreprocessor.preprocessFromFile(photo);
      if (prep == null) {
        return (
          tier: 'fail',
          reason: 'Không thấy khuôn mặt — chụp lại bước này',
        );
      }
      if (prep.dominanceRatio >= OnDeviceFaceConfig.enrollDominanceMaxRatio) {
        return (
          tier: 'fail',
          reason: 'Có người khác đứng quá gần — chỉ một người trước camera',
        );
      }
      final qr = FaceQualityFilter.check(
        face: prep.face,
        face112: prep.face112,
        checkLiveness: false,
        faceCount: 1,
      );
      if (!qr.ok) return (tier: 'fail', reason: qr.reason);

      double? mp;
      try {
        mp = await _MaskEngine.instance.maskProb(prep.face112);
      } catch (_) {
      }
      final r = await _RecognitionEngine.instance.runInference(prep.face112);

      String tier = 'pass';
      String reason = '';
      if (mp != null && mp >= OnDeviceFaceConfig.enrollMaskProbMax) {
        tier = 'fail';
        reason = 'Vui lòng bỏ khẩu trang';
      } else if (r.rawNorm < OnDeviceFaceConfig.enrollNormHardMin) {
        tier = 'fail';
        reason = 'Khuôn mặt không rõ hoặc bị che — chụp lại';
      } else if (r.rawNorm < OnDeviceFaceConfig.enrollNormSoftMin) {
        tier = 'soft';
        reason = 'Khuôn mặt chưa rõ — thử chụp lại cho nét hơn';
      }

      if (tier != 'pass' && OnDeviceFaceConfig.enrollGateShadowMode) {
        return (tier: 'pass', reason: '');
      }

      return (tier: tier, reason: reason);
    } catch (e) {
      return (tier: 'fail', reason: 'Lỗi kiểm tra ảnh: $e');
    }
  }

  static Future<FaceRecognizeResult> recognize(
    File imageFile, {
    double? threshold,
    bool checkLiveness = true,
    String? classId,
  }) async {
    final thr = threshold ?? OnDeviceFaceConfig.threshold;

    final _swTotal = Stopwatch()..start();
    int _msDetect = 0, _msSpoof = 0, _msQuality = 0, _msEmbed = 0, _msMatch = 0;

    try {
      final _sw1 = Stopwatch()..start();
      final prep = await _FacePreprocessor.preprocessFromFile(imageFile);
      _msDetect = _sw1.elapsedMilliseconds;
      if (prep == null) throw const FaceNotFoundException();

      final _sw2 = Stopwatch()..start();
      if (checkLiveness && OnDeviceFaceConfig.antispoofForScan) {
        final spoof = await _AntiSpoofEngine.instance.predict(
          prep.srcImage,
          prep.face.boundingBox,
        );
        _msSpoof = _sw2.elapsedMilliseconds;
        if (!spoof.isReal) {
          throw _SpoofException('Không thể nhận diện được', spoof);
        }
      } else {
        _msSpoof = _sw2.elapsedMilliseconds;
      }

      final _sw3 = Stopwatch()..start();
      final qr = FaceQualityFilter.check(
        face: prep.face,
        face112: prep.face112,
        checkLiveness: false,
        faceCount: 1,
      );
      _msQuality = _sw3.elapsedMilliseconds;
      if (!qr.ok) throw _QualityException(qr.reason);

      final _sw4 = Stopwatch()..start();
      final r = await _RecognitionEngine.instance.runInference(prep.face112);
      _msEmbed = _sw4.elapsedMilliseconds;
      final queryEmb = r.emb;

      final _sw5 = Stopwatch()..start();
      final gallery = classId != null
          ? await _GalleryManager.loadGalleryForClass(classId)
          : await _GalleryManager.loadGallery();
      if (gallery.isEmpty) {
        _msMatch = _sw5.elapsedMilliseconds;
        return FaceRecognizeResult.error(
          'Gallery trống — chưa có ai đăng ký khuôn mặt',
        );
      }

      final top = _Matcher.match(queryEmb, gallery, topK: 3);
      _msMatch = _sw5.elapsedMilliseconds;
      final top1 = top.first;
      final margin = top.length > 1
          ? top1.similarity - top[1].similarity
          : top1.similarity;
      final isKnown =
          top1.similarity >= thr && margin >= OnDeviceFaceConfig.minMargin;
      final warning = margin < OnDeviceFaceConfig.marginWarningThreshold;

      final top3 = top
          .map(
            (t) => FaceTopEntry(
              name: t.entry.name,
              confidence: t.similarity,
              studentId: t.entry.studentId,
            ),
          )
          .toList();

      String? hint;
      if (!isKnown) {
        if (r.rawNorm < OnDeviceFaceConfig.enrollNormHardMin) {
          hint = 'Khuôn mặt không rõ — lại gần camera và đủ sáng';
        } else {
          try {
            final mp = await _MaskEngine.instance.maskProb(prep.face112);
            if (mp >= OnDeviceFaceConfig.scanHintMaskProb) {
              hint = 'Vui lòng bỏ khẩu trang để điểm danh';
            }
          } catch (_) {
          }
        }
      }

      final _msTotal = _swTotal.elapsedMilliseconds;
      return FaceRecognizeResult(
        name: isKnown ? top1.entry.name : 'Unknown',
        confidence: top1.similarity,
        isKnown: isKnown,
        top3: top3,
        margin: margin,
        warning: warning,
        hint: hint,
        message: isKnown
            ? 'Nhận diện: ${top1.entry.name} (${(top1.similarity * 100).toStringAsFixed(1)}%)'
            : 'Không nhận ra khuôn mặt (${(top1.similarity * 100).toStringAsFixed(1)}%)',
        timing: FaceTiming(
          detect: _msDetect,
          spoof: _msSpoof,
          quality: _msQuality,
          embed: _msEmbed,
          match: _msMatch,
          total: _msTotal,
        ),
      );
    } on FaceNotFoundException {
      rethrow;
    } on _SpoofException catch (e) {
      return FaceRecognizeResult.error(e.message);
    } on _QualityException catch (e) {
      return FaceRecognizeResult.error(e.message);
    } catch (e) {
      return FaceRecognizeResult.error('Lỗi nhận diện: $e');
    }
  }

  static Future<FaceVerifyResult> recognizeAndVerify({
    required File capturedImage,
    required String expectedName,
    String? expectedUid,
    String? classId,
  }) async {
    FaceRecognizeResult result;
    try {
      result = await recognize(capturedImage, classId: classId);
    } on FaceNotFoundException catch (e) {
      return FaceVerifyResult(
        isMatch: false,
        recognizedAs: 'Unknown',
        confidence: 0,
        top3: const [],
        margin: 0,
        warning: false,
        message: e.message,
      );
    }

    if (result.errorMsg != null) {
      return FaceVerifyResult(
        isMatch: false,
        recognizedAs: result.name,
        confidence: result.confidence,
        top3: result.top3,
        margin: result.margin,
        warning: result.warning,
        message: result.message,
      );
    }

    final top1Id = result.top3.isNotEmpty ? result.top3.first.studentId : null;
    final expectedId =
        expectedUid ?? fb_auth.FirebaseAuth.instance.currentUser?.uid;

    final bool isMatch;
    if (expectedId != null) {
      isMatch = result.isKnown && top1Id != null && top1Id == expectedId;
    } else {
      isMatch = result.isKnown && top1Id == expectedUid;
    }

    return FaceVerifyResult(
      isMatch: isMatch,
      recognizedAs: result.name,
      confidence: result.confidence,
      top3: result.top3,
      margin: result.margin,
      warning: result.warning,
      hint: result.hint,
      message: isMatch
          ? 'Đã nhận diện được khuôn mặt'
          : result.isKnown
          ? 'Không đúng người. Vui lòng dùng tài khoản của bạn.'
          : 'Không nhận ra khuôn mặt. Vui lòng thử lại.',
    );
  }

  static Future<EnrollResult> enroll({
    required String studentId,
    required String name,
    required List<File> photos,
  }) async {
    if (photos.length < OnDeviceFaceConfig.minPhotosForEnroll) {
      throw ArgumentError(
        'Cần ít nhất ${OnDeviceFaceConfig.minPhotosForEnroll} ảnh',
      );
    }

    final embeddings = <List<double>>[];
    final failedIdxs = <int>[];
    final failReasons = <String>[];

    for (int i = 0; i < photos.length; i++) {
      try {
        final prep = await _FacePreprocessor.preprocessFromFile(photos[i]);
        if (prep == null) {
          failedIdxs.add(i);
          failReasons.add('Không detect được mặt');
          continue;
        }

        if (OnDeviceFaceConfig.antispoofForEnroll) {
          final spoof = await _AntiSpoofEngine.instance.predict(
            prep.srcImage,
            prep.face.boundingBox,
          );
          if (!spoof.isReal) {
            failedIdxs.add(i);
            failReasons.add('Không nhận diện được');
            continue;
          }
        }

        if (prep.dominanceRatio >= OnDeviceFaceConfig.enrollDominanceMaxRatio) {
          failedIdxs.add(i);
          failReasons.add('Có người khác đứng quá gần');
          continue;
        }
        final qr = FaceQualityFilter.check(
          face: prep.face,
          face112: prep.face112,
          checkLiveness: false,
          faceCount: 1,
        );
        if (!qr.ok) {
          failedIdxs.add(i);
          failReasons.add(qr.reason);
          continue;
        }

        final r = await _RecognitionEngine.instance.runInference(prep.face112);
        embeddings.add(r.emb);
      } catch (e) {
        failedIdxs.add(i);
        failReasons.add('$e');
      }
    }

    if (embeddings.length < OnDeviceFaceConfig.minPhotosForEnroll) {
      return EnrollResult(
        success: false,
        studentId: studentId,
        name: name,
        photosUsed: embeddings.length,
        photosFailed: failedIdxs,
        message:
            'Chỉ ${embeddings.length}/${photos.length} ảnh hợp lệ. '
            'Lý do: ${failReasons.toSet().join("; ")}',
      );
    }
    var cleaned = List<List<double>>.from(embeddings);
    if (embeddings.length >= 5) {
      final dim = embeddings.first.length;
      final median = List<double>.filled(dim, 0.0);
      for (int d = 0; d < dim; d++) {
        final col = embeddings.map((e) => e[d]).toList()..sort();
        median[d] = col[col.length ~/ 2];
      }
      final normMedian = _l2Normalize(median);
      final sims = embeddings
          .map((e) => _Matcher.cosineList(e, normMedian))
          .toList();
      final mean = sims.reduce((a, b) => a + b) / sims.length;
      double std = 0;
      for (final s in sims) std += (s - mean) * (s - mean);
      std = math.sqrt(std / sims.length);
      final thr2 = mean - std;

      final filtered = <List<double>>[];
      for (int i = 0; i < embeddings.length; i++) {
        if (sims[i] >= thr2) {
          filtered.add(embeddings[i]);
        } else {}
      }
      if (filtered.length >= OnDeviceFaceConfig.minPhotosForEnroll) {
        cleaned = filtered;
      }
    }

    if (cleaned.length < 4) {
      return EnrollResult(
        success: false,
        studentId: studentId,
        name: name,
        photosUsed: cleaned.length,
        photosFailed: failedIdxs,
        message: 'Ảnh đăng ký chưa đủ đồng nhất — vui lòng chụp lại',
      );
    }

    final dim = cleaned.first.length;
    final avg = List<double>.filled(dim, 0.0);
    for (final e in cleaned) {
      for (int i = 0; i < dim; i++) avg[i] += e[i] / cleaned.length;
    }
    final template = _l2Normalize(avg);

    double intra = 0;
    int pairs = 0;
    for (int i = 0; i < cleaned.length; i++) {
      for (int j = i + 1; j < cleaned.length; j++) {
        intra += _Matcher.cosineList(cleaned[i], cleaned[j]);
        pairs++;
      }
    }

    if (pairs > 0) intra /= pairs;

    if (intra < OnDeviceFaceConfig.minEnrollIntra) {
      return EnrollResult(
        success: false,
        studentId: studentId,
        name: name,
        photosUsed: embeddings.length,
        photosFailed: failedIdxs,
        message:
            'Ảnh đăng ký không nhất quán. Chụp lại với mặt đầy đủ, đủ sáng.',
      );
    }
    await _GalleryManager.saveEmbedding(
      studentId: studentId,
      name: name,
      avgEmbedding: template,
    );

    return EnrollResult(
      success: true,
      studentId: studentId,
      name: name,
      photosUsed: cleaned.length,
      photosFailed: failedIdxs,
      message:
          'Đăng ký thành công ${cleaned.length} ảnh '
          '(intra-sim=${intra.toStringAsFixed(2)})',
      intraSimilarity: intra,
    );
  }

  static Future<List<Map<String, dynamic>>> listStudents() async {
    final snap = await FirebaseFirestore.instance
        .collection('face_gallery')
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'student_id': doc.id,
        'name': data['name'] ?? '',
        'updatedAt': data['updatedAt'],
      };
    }).toList();
  }

  static Future<int> countStudents() async =>
      (await FirebaseFirestore.instance.collection('face_gallery').get())
          .docs
          .length;

  static Future<void> deleteStudent(String studentId) async =>
      _GalleryManager.deleteEmbedding(studentId);

  static Future<String?> getCroppedFaceBase64(File imageFile) async => null;
  static Future<void> updateThreshold(double value) async {}
  static Future<Map<String, dynamic>> getStats() async => {};
  static Future<int> syncDatabase() async => countStudents();

  static String _normalizeName(String name) {
    String n = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return n
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'[đ]'), 'd');
  }
}

class EnrollmentCheckResult {
  final bool hasFace;
  final String source;
  final bool synced;
  final String message;

  const EnrollmentCheckResult({
    required this.hasFace,
    required this.source,
    this.synced = false,
    this.message = '',
  });
}

class FaceEnrollmentCheckService {
  static Future<EnrollmentCheckResult> checkStatus({
    required String uid,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!userDoc.exists) {
        return const EnrollmentCheckResult(
          hasFace: false,
          source: 'default',
          message: 'Tài khoản chưa tồn tại',
        );
      }
      final hasFaceData = userDoc.data()?['hasFaceData'] ?? false;
      if (hasFaceData == true) {
        return const EnrollmentCheckResult(
          hasFace: true,
          source: 'firestore',
          message: 'Đã đăng ký khuôn mặt',
        );
      }
      final hasEmb = await _GalleryManager.hasEmbedding(uid);
      if (hasEmb) {
        await _syncFirestore(uid, hasFace: true);
        return const EnrollmentCheckResult(
          hasFace: true,
          source: 'face_gallery',
          synced: true,
          message: 'Đã đăng ký (đồng bộ từ gallery)',
        );
      }
      return const EnrollmentCheckResult(
        hasFace: false,
        source: 'face_gallery',
        message: 'Chưa đăng ký khuôn mặt',
      );
    } catch (e) {
      return EnrollmentCheckResult(
        hasFace: false,
        source: 'default',
        message: 'Lỗi kiểm tra: $e',
      );
    }
  }

  static Future<void> _syncFirestore(
    String uid, {
    required bool hasFace,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasFaceData': hasFace,
        'faceDataSyncedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> markAsEnrolled(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasFaceData': true,
        'faceEnrolledAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
