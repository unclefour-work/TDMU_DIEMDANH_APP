// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceQualityConfig {
  static const double minFaceSize = 80.0;

  static const double maxYaw = 30.0;
  static const double maxPitch = 20.0;
  static const double maxRoll = 15.0;

  static const bool blockClosedEyes = false;
  static const double minEyeOpenProb = 0.4;

  static const bool blockOcclusion = false;

  static const int maxMissingLowerLandmarks = 1;

  static const double occludedEyeProb = 0.2;

  static const double minBlur = 80.0;

  static const double minBrightness = 40.0;
  static const double maxBrightness = 220.0;

  static const bool livenessEnabledForScan = true;
  static const bool livenessEnabledForEnroll = false;
  static const double minLbpVariance = 18.0;
  static const double maxSpecularRatio = 0.08;
  static const double minGradientEntropy = 3.5;
  static const double minLivenessScore = 0.50;
}

class LivenessMetrics {
  final double lbpVariance;
  final double specularRatio;
  final double gradientEntropy;
  final double score;
  final bool isLive;
  const LivenessMetrics({
    required this.lbpVariance,
    required this.specularRatio,
    required this.gradientEntropy,
    required this.score,
    required this.isLive,
  });
  @override
  String toString() =>
      'lbp=${lbpVariance.toStringAsFixed(1)} '
      'spec=${(specularRatio * 100).toStringAsFixed(1)}% '
      'entropy=${gradientEntropy.toStringAsFixed(2)} '
      'score=${score.toStringAsFixed(2)} ${isLive ? "✅LIVE" : "❌SPOOF"}';
}

class FaceMetrics {
  final double faceSize;
  final double yaw, pitch, roll;
  final double blur, brightness;
  final double? leftEyeOpen, rightEyeOpen;
  final bool? hasMask;
  final bool? hasGlasses;
  final LivenessMetrics? liveness;
  const FaceMetrics({
    required this.faceSize,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.blur,
    required this.brightness,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.hasMask,
    this.hasGlasses,
    this.liveness,
  });
  @override
  String toString() =>
      'size=${faceSize.toStringAsFixed(0)}px '
      'yaw=${yaw.toStringAsFixed(1)}° '
      'blur=${blur.toStringAsFixed(0)} bright=${brightness.toStringAsFixed(0)}'
      '${hasMask == true ? " 😷MASK" : ""}'
      '${hasGlasses == true ? " 🕶GLASSES" : ""}'
      '${liveness != null ? " live=${liveness!.score.toStringAsFixed(2)}" : ""}';
}

class QualityCheckResult {
  final bool ok;
  final String reason;
  final FaceMetrics? metrics;
  final img.Image? face112;
  const QualityCheckResult._({
    required this.ok,
    this.reason = '',
    this.metrics,
    this.face112,
  });
  factory QualityCheckResult.fail(String reason, {FaceMetrics? metrics}) =>
      QualityCheckResult._(ok: false, reason: reason, metrics: metrics);
  factory QualityCheckResult.pass(img.Image face112, FaceMetrics metrics) =>
      QualityCheckResult._(ok: true, face112: face112, metrics: metrics);
}

class FaceOcclusionDetector {
  static const _lowerLandmarks = [
    FaceLandmarkType.noseBase,
    FaceLandmarkType.leftMouth,
    FaceLandmarkType.rightMouth,
  ];

  static bool detect(Face face) {
    final eyesMissing =
        face.landmarks[FaceLandmarkType.leftEye] == null ||
        face.landmarks[FaceLandmarkType.rightEye] == null;

    int lowerMissing = 0;
    for (final lm in _lowerLandmarks) {
      if (face.landmarks[lm] == null) lowerMissing++;
    }
    final lowerCovered =
        lowerMissing >= FaceQualityConfig.maxMissingLowerLandmarks;

    final le = face.leftEyeOpenProbability;
    final re = face.rightEyeOpenProbability;
    final eyesCovered =
        le != null &&
        re != null &&
        le < FaceQualityConfig.occludedEyeProb &&
        re < FaceQualityConfig.occludedEyeProb;

    final occluded = eyesMissing || lowerCovered || eyesCovered;
    return occluded;
  }
}

class LivenessDetector {
  static LivenessMetrics analyze(img.Image face112) {
    final gray = _toGray(face112);
    final lbpVar = _lbpVariance(gray);
    final specRatio = _specularRatio(face112);
    final gradEnt = _gradientEntropy(gray);

    final scoreLbp = _sigmoid(lbpVar, FaceQualityConfig.minLbpVariance, 8.0);
    final scoreSpec =
        1.0 - _sigmoid(specRatio, FaceQualityConfig.maxSpecularRatio, 0.03);
    final scoreEnt = _sigmoid(
      gradEnt,
      FaceQualityConfig.minGradientEntropy,
      0.5,
    );
    final score = scoreLbp * 0.40 + scoreSpec * 0.30 + scoreEnt * 0.30;
    final isLive = score >= FaceQualityConfig.minLivenessScore;

    return LivenessMetrics(
      lbpVariance: lbpVar,
      specularRatio: specRatio,
      gradientEntropy: gradEnt,
      score: score,
      isLive: isLive,
    );
  }

  static double _lbpVariance(List<List<double>> gray) {
    const cx = 56, cy = 56, r = 24;
    final vals = <int>[];
    final h = gray.length, w = gray[0].length;
    for (int y = cy - r; y < cy + r; y++) {
      for (int x = cx - r; x < cx + r; x++) {
        if (y < 1 || y >= h - 1 || x < 1 || x >= w - 1) continue;
        final c = gray[y][x];
        final nb = [
          gray[y - 1][x - 1],
          gray[y - 1][x],
          gray[y - 1][x + 1],
          gray[y][x + 1],
          gray[y + 1][x + 1],
          gray[y + 1][x],
          gray[y + 1][x - 1],
          gray[y][x - 1],
        ];
        int lbp = 0;
        for (int i = 0; i < 8; i++) {
          if (nb[i] >= c) lbp |= (1 << i);
        }
        vals.add(lbp);
      }
    }
    if (vals.isEmpty) return 0;
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    double v = 0;
    for (final x in vals) {
      v += (x - mean) * (x - mean);
    }
    return math.sqrt(v / vals.length);
  }

  static double _specularRatio(img.Image face112) {
    int spec = 0, total = 0;
    for (int y = 10; y < 90; y++) {
      for (int x = 20; x < 92; x++) {
        final p = face112.getPixel(x, y);
        if (p.r >= 245 && p.g >= 245 && p.b >= 245) spec++;
        total++;
      }
    }
    return total > 0 ? spec / total : 0;
  }

  static double _gradientEntropy(List<List<double>> gray) {
    final h = gray.length, w = gray[0].length;
    final hist = List<int>.filled(32, 0);
    int total = 0;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final gx = gray[y][x + 1] - gray[y][x - 1];
        final gy = gray[y + 1][x] - gray[y - 1][x];
        hist[(math.sqrt(gx * gx + gy * gy) / 8).floor().clamp(0, 31)]++;
        total++;
      }
    }
    if (total == 0) return 0;
    double e = 0;
    for (final h in hist) {
      if (h == 0) continue;
      final p = h / total;
      e -= p * math.log(p) / math.ln2;
    }
    return e;
  }

  static List<List<double>> _toGray(img.Image image) => List.generate(
    image.height,
    (y) => List.generate(image.width, (x) {
      final p = image.getPixel(x, y);
      return p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
    }),
  );

  static double _sigmoid(double v, double thr, double scale) =>
      1.0 / (1.0 + math.exp(-((v - thr) / scale).clamp(-20.0, 20.0)));
}

class FaceQualityFilter {
  static QualityCheckResult check({
    required Face face,
    required img.Image face112,
    bool checkLiveness = false,
    int faceCount = 1,
  }) {
    if (faceCount > 1) {
      return QualityCheckResult.fail('Chỉ một người đứng trước camera');
    }

    final hasEyes =
        face.landmarks[FaceLandmarkType.leftEye] != null &&
        face.landmarks[FaceLandmarkType.rightEye] != null;
    if (!hasEyes) {
      return QualityCheckResult.fail(
        'Không nhận ra khuôn mặt — hướng mặt vào camera',
      );
    }

    final bb = face.boundingBox;
    final faceSize = math.min(bb.width, bb.height).toDouble();
    if (faceSize < FaceQualityConfig.minFaceSize) {
      return QualityCheckResult.fail('Lại gần camera hơn');
    }

    final yaw = face.headEulerAngleY ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;
    final roll = face.headEulerAngleZ ?? 0.0;

    if (yaw.abs() > FaceQualityConfig.maxYaw) {
      return QualityCheckResult.fail(
        'Nhìn thẳng vào camera',
        metrics: _m(faceSize, yaw, pitch, roll, 0, 0),
      );
    }
    if (pitch.abs() > FaceQualityConfig.maxPitch) {
      return QualityCheckResult.fail(
        'Giữ đầu thẳng',
        metrics: _m(faceSize, yaw, pitch, roll, 0, 0),
      );
    }
    if (roll.abs() > FaceQualityConfig.maxRoll) {
      return QualityCheckResult.fail(
        'Giữ đầu thẳng',
        metrics: _m(faceSize, yaw, pitch, roll, 0, 0),
      );
    }

    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if (FaceQualityConfig.blockClosedEyes) {
      if (leftEye != null && leftEye < FaceQualityConfig.minEyeOpenProb) {
        return QualityCheckResult.fail(
          'Mở mắt ra',
          metrics: _m(
            faceSize,
            yaw,
            pitch,
            roll,
            0,
            0,
            le: leftEye,
            re: rightEye,
          ),
        );
      }
      if (rightEye != null && rightEye < FaceQualityConfig.minEyeOpenProb) {
        return QualityCheckResult.fail(
          'Mở mắt ra',
          metrics: _m(
            faceSize,
            yaw,
            pitch,
            roll,
            0,
            0,
            le: leftEye,
            re: rightEye,
          ),
        );
      }
    }

    bool? hasOcclusion;
    if (FaceQualityConfig.blockOcclusion) {
      hasOcclusion = FaceOcclusionDetector.detect(face);
      if (hasOcclusion) {
        return QualityCheckResult.fail(
          'Khuôn mặt bị che — để lộ toàn bộ khuôn mặt',
          metrics: _m(
            faceSize,
            yaw,
            pitch,
            roll,
            0,
            0,
            le: leftEye,
            re: rightEye,
            mask: true,
          ),
        );
      }
    }
    final bool? hasMask = hasOcclusion;
    final bool? hasGlasses = hasOcclusion;

    final blur = _laplacianVariance(face112);
    if (blur < FaceQualityConfig.minBlur) {
      return QualityCheckResult.fail(
        'Ảnh chưa đủ nét — giữ yên điện thoại',
        metrics: _m(
          faceSize,
          yaw,
          pitch,
          roll,
          blur,
          0,
          le: leftEye,
          re: rightEye,
          mask: hasMask,
          glasses: hasGlasses,
        ),
      );
    }

    final brightness = _meanBrightness(face112);
    if (brightness < FaceQualityConfig.minBrightness) {
      return QualityCheckResult.fail(
        'Thiếu sáng — chụp ở nơi có đủ ánh sáng',
        metrics: _m(
          faceSize,
          yaw,
          pitch,
          roll,
          blur,
          brightness,
          le: leftEye,
          re: rightEye,
          mask: hasMask,
          glasses: hasGlasses,
        ),
      );
    }
    if (brightness > FaceQualityConfig.maxBrightness) {
      return QualityCheckResult.fail(
        'Quá sáng — tránh đèn chiếu thẳng vào mặt',
        metrics: _m(
          faceSize,
          yaw,
          pitch,
          roll,
          blur,
          brightness,
          le: leftEye,
          re: rightEye,
          mask: hasMask,
          glasses: hasGlasses,
        ),
      );
    }

    LivenessMetrics? live;
    if (checkLiveness) {
      live = LivenessDetector.analyze(face112);
      if (!live.isLive) {
        return QualityCheckResult.fail(
          'Không xác thực được khuôn mặt — vui lòng thử lại',
          metrics: _m(
            faceSize,
            yaw,
            pitch,
            roll,
            blur,
            brightness,
            le: leftEye,
            re: rightEye,
            mask: hasMask,
            glasses: hasGlasses,
            liveness: live,
          ),
        );
      }
    }

    final m = _m(
      faceSize,
      yaw,
      pitch,
      roll,
      blur,
      brightness,
      le: leftEye,
      re: rightEye,
      mask: hasMask,
      glasses: hasGlasses,
      liveness: live,
    );
    return QualityCheckResult.pass(face112, m);
  }

  static double _laplacianVariance(img.Image image) {
    final h = image.height, w = image.width;
    final gray = List.generate(
      h,
      (y) => List.generate(w, (x) {
        final p = image.getPixel(x, y);
        return p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
      }),
    );
    final vals = <double>[];
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        vals.add(
          gray[y - 1][x] +
              gray[y + 1][x] +
              gray[y][x - 1] +
              gray[y][x + 1] -
              4 * gray[y][x],
        );
      }
    }
    if (vals.isEmpty) return 0;
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    double v = 0;
    for (final x in vals) {
      v += (x - mean) * (x - mean);
    }
    return v / vals.length;
  }

  static double _meanBrightness(img.Image image) {
    double sum = 0;
    int count = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        sum += p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
        count++;
      }
    }
    return count > 0 ? sum / count : 0;
  }

  static FaceMetrics _m(
    double sz,
    double yaw,
    double pitch,
    double roll,
    double blur,
    double bright, {
    double? le,
    double? re,
    bool? mask,
    bool? glasses,
    LivenessMetrics? liveness,
  }) => FaceMetrics(
    faceSize: sz,
    yaw: yaw,
    pitch: pitch,
    roll: roll,
    blur: blur,
    brightness: bright,
    leftEyeOpen: le,
    rightEyeOpen: re,
    hasMask: mask,
    hasGlasses: glasses,
    liveness: liveness,
  );
}

enum QualityHintType { success, warning, error, scanning }

class QualityHint {
  final String message;
  final QualityHintType type;
  const QualityHint({required this.message, required this.type});

  factory QualityHint.scanning() => const QualityHint(
    message: 'Đưa khuôn mặt vào khung...',
    type: QualityHintType.scanning,
  );

  factory QualityHint.fromResult(QualityCheckResult result) {
    if (result.ok) {
      return const QualityHint(
        message: '✅ Khuôn mặt hợp lệ',
        type: QualityHintType.success,
      );
    }
    final r = result.reason;
    if (r.contains('nhiều khuôn mặt') ||
        r.contains('Phát hiện') && r.contains('khuôn mặt')) {
      return const QualityHint(
        message: '👥 Chỉ 1 người trước camera',
        type: QualityHintType.error,
      );
    }
    if (r.contains('khẩu trang') || r.contains('😷')) {
      return const QualityHint(
        message: '😷 Tháo khẩu trang ra',
        type: QualityHintType.error,
      );
    }
    if (r.contains('kính đen') || r.contains('🕶')) {
      return const QualityHint(
        message: '🕶 Tháo kính đen ra',
        type: QualityHintType.error,
      );
    }
    if (r.contains('kính mắt') || r.contains('👓')) {
      return const QualityHint(
        message: '👓 Tháo kính ra',
        type: QualityHintType.error,
      );
    }
    if (r.contains('giả') || r.contains('màn hình') || r.contains('liveness')) {
      return const QualityHint(
        message: 'Không nhận diện được khuôn mặt',
        type: QualityHintType.error,
      );
    }
    if (r.contains('nhỏ') || r.contains('gần')) {
      return const QualityHint(
        message: '↔ Lại gần camera hơn',
        type: QualityHintType.warning,
      );
    }
    if (r.contains('xoay') || r.contains('phải') || r.contains('trái')) {
      return const QualityHint(
        message: '↕ Nhìn thẳng vào camera',
        type: QualityHintType.warning,
      );
    }
    if (r.contains('cúi') || r.contains('ngẩng') || r.contains('nghiêng')) {
      return const QualityHint(
        message: '↕ Giữ đầu thẳng',
        type: QualityHintType.warning,
      );
    }
    if (r.contains('mờ')) {
      return const QualityHint(
        message: '📷 Giữ yên tay',
        type: QualityHintType.warning,
      );
    }
    if (r.contains('tối')) {
      return const QualityHint(
        message: '💡 Cần thêm ánh sáng',
        type: QualityHintType.warning,
      );
    }
    if (r.contains('sáng')) {
      return const QualityHint(
        message: '☀ Tránh đèn chiếu thẳng',
        type: QualityHintType.warning,
      );
    }
    if (r.contains('nhắm')) {
      return const QualityHint(
        message: '👁 Mở mắt ra',
        type: QualityHintType.warning,
      );
    }
    return QualityHint(message: r, type: QualityHintType.warning);
  }
}
