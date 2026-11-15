// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_non_null_assertion, depend_on_referenced_packages, deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:app_diem_danh/services/face_service.dart';
import 'package:permission_handler/permission_handler.dart';

const List<_Guide> _kGuides = [
  _Guide(
    step: 1,
    label: 'Nhìn thẳng',
    icon: Icons.face,
    desc: 'Nhìn thẳng vào camera, giữ mặt ở giữa khung hình',
  ),
  _Guide(
    step: 2,
    label: 'Xoay trái nhẹ',
    icon: Icons.rotate_right,
    desc: 'Xoay đầu sang trái nhẹ (khoảng 15-20°)',
  ),
  _Guide(
    step: 3,
    label: 'Xoay phải nhẹ',
    icon: Icons.rotate_left,
    desc: 'Xoay đầu sang phải nhẹ (khoảng 15-20°)',
  ),
  _Guide(
    step: 4,
    label: 'Ngẩng nhẹ',
    icon: Icons.arrow_upward,
    desc: 'Ngẩng đầu lên nhẹ (khoảng 10-15°)',
  ),
  _Guide(
    step: 5,
    label: 'Cúi nhẹ',
    icon: Icons.arrow_downward,
    desc: 'Cúi đầu xuống nhẹ (khoảng 10-15°)',
  ),
];

class _Guide {
  final int step;
  final String label;
  final String desc;
  final IconData icon;
  const _Guide({
    required this.step,
    required this.label,
    required this.icon,
    required this.desc,
  });
}

class _PoseEval {
  final bool matched;
  final String hint;
  const _PoseEval(this.matched, this.hint);
}

class FaceEnrollmentScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const FaceEnrollmentScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with WidgetsBindingObserver {
  CameraController? _cam;
  CameraDescription? _desc;
  bool _camError = false;
  String _camErrorMsg = '';

  FaceDetector? _detector;
  bool _streaming = false;
  bool _detecting = false;
  DateTime _lastProcess = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _throttleMs = 120;

  final List<File> _photos = [];
  int _step = 0;

  final Set<int> _softRetryUsed = {};
  bool _capturing = false;
  bool _uploading = false;
  String _status = '';

  int _stableHits = 0;
  static const int _requiredStableHits = 6;
  bool _poseMatched = false;
  String _hint = 'Đưa khuôn mặt vào khung hình';

  bool _armed = false;
  bool _wrongAction = false;
  static const int _neutralArmHits = 3;
  int _neutralHits = 0;

  static const double _yawSign = 1.0;
  static const double _pitchSign = 1.0;
  static const double _rollSign = -1.0;

  static const double _frontTol = 8;
  static const double _yawAcceptMin = 10;
  static const double _yawAcceptMax = 22;
  static const double _pitchAcceptMin = 8;
  static const double _pitchAcceptMax = 16;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopDetection();
    _detector?.close();
    _cam?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cam;
    if (state == AppLifecycleState.resumed) {
      if (cam == null || !cam.value.isInitialized) _initCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopDetection();
      cam?.dispose();
      if (mounted) setState(() => _cam = null);
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _camError = true;
          _camErrorMsg = status.isPermanentlyDenied
              ? 'Quyền camera đang bị tắt. Vào Cài đặt để bật lại.'
              : 'Cần cấp quyền camera để đăng ký khuôn mặt.';
        });
      }
      return;
    }
    final cams = await availableCameras();
    if (cams.isEmpty) {
      if (mounted) {
        setState(() {
          _camError = true;
          _camErrorMsg = 'Không tìm thấy camera trên thiết bị.';
        });
      }
      return;
    }
    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    _desc = front;

    for (final preset in [ResolutionPreset.medium, ResolutionPreset.low]) {
      CameraController? controller;
      try {
        controller = CameraController(
          front,
          preset,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() {
          _cam = controller;
          _camError = false;
          _camErrorMsg = '';
        });
        await _startDetection();
        return;
      } catch (_) {
        await controller?.dispose();
      }
    }

    if (mounted) {
      setState(() {
        _camError = true;
        _camErrorMsg = 'Không khởi tạo được camera. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _startDetection() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    if (_streaming) return;
    if (_step >= _kGuides.length) return;

    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
    try {
      await cam.startImageStream(_onFrame);
      _streaming = true;
    } catch (_) {}
  }

  Future<void> _stopDetection() async {
    if (!_streaming) return;
    try {
      await _cam?.stopImageStream();
    } catch (_) {}
    _streaming = false;
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_detecting || _capturing || _uploading) return;
    final now = DateTime.now();
    if (now.difference(_lastProcess).inMilliseconds < _throttleMs) return;
    _lastProcess = now;
    _detecting = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector!.processImage(input);
      if (!mounted) return;
      _handleFaces(faces, image);
    } catch (_) {
    } finally {
      _detecting = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final desc = _desc;
    final cam = _cam;
    if (desc == null || cam == null) return null;

    final sensor = desc.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      final devRot = _orientations[cam.value.deviceOrientation] ?? 0;
      int comp;
      if (desc.lensDirection == CameraLensDirection.front) {
        comp = (sensor + devRot) % 360;
      } else {
        comp = (sensor - devRot + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _handleFaces(List<Face> faces, CameraImage image) {
    if (_step >= _kGuides.length || _capturing) return;

    if (faces.isEmpty) {
      _resetStable('Đưa khuôn mặt vào khung hình');
      return;
    }
    Face f = faces.first;
    double maxArea = 0, secondArea = 0;
    for (final c in faces) {
      final area = c.boundingBox.width * c.boundingBox.height;
      if (area > maxArea) {
        secondArea = maxArea;
        maxArea = area;
        f = c;
      } else if (area > secondArea) {
        secondArea = area;
      }
    }
    if (faces.length > 1 &&
        secondArea >= maxArea * OnDeviceFaceConfig.enrollDominanceMaxRatio) {
      _resetStable('Chỉ một người đứng gần camera');
      return;
    }
    final shortSide = math.min(image.width, image.height).toDouble();
    final faceMin = math.min(f.boundingBox.width, f.boundingBox.height);
    if (faceMin < shortSide * 0.28) {
      _resetStable('Lại gần camera hơn');
      return;
    }

    final yaw = (f.headEulerAngleY ?? 0) * _yawSign;
    final pitch = (f.headEulerAngleX ?? 0) * _pitchSign;
    final roll = (f.headEulerAngleZ ?? 0) * _rollSign;

    final neutral =
        yaw.abs() < _frontTol &&
        pitch.abs() < _frontTol &&
        roll.abs() < _frontTol;
    final isFrontalStep = _step == 0;

    if (isFrontalStep) {
      final res = _evaluatePose(_step, yaw, pitch, roll);
      if (res.matched) {
        _stableHits++;
        if (_stableHits >= _requiredStableHits) {
          _autoCapture();
        } else {
          _setMatched('Giữ yên… đang chụp');
        }
      } else {
        _resetStable(res.hint);
      }
      return;
    }

    if (!_armed) {
      if (neutral) {
        _neutralHits++;
        if (_neutralHits >= _neutralArmHits) {
          if (mounted) {
            setState(() {
              _armed = true;
              _wrongAction = false;
              _neutralHits = 0;
              _stableHits = 0;
              _poseMatched = false;
              _hint = 'Bây giờ: ${_kGuides[_step].label.toLowerCase()}';
            });
          }
        } else {
          _resetStable(
            _wrongAction
                ? 'Sai động tác — nhìn thẳng để làm lại'
                : 'Nhìn thẳng để bắt đầu động tác',
          );
        }
      } else {
        _neutralHits = 0;
        _resetStable(
          _wrongAction
              ? 'Sai động tác — nhìn thẳng để làm lại'
              : 'Nhìn thẳng để bắt đầu động tác',
        );
      }
      return;
    }

    final res = _evaluatePose(_step, yaw, pitch, roll);
    if (res.matched) {
      _stableHits++;
      if (_stableHits >= _requiredStableHits) {
        _autoCapture();
      } else {
        _setMatched('Giữ yên… đang chụp');
      }
    } else if (_isWrongAction(_step, yaw, pitch, roll)) {
      if (mounted) {
        setState(() {
          _armed = false;
          _wrongAction = true;
          _stableHits = 0;
          _neutralHits = 0;
          _poseMatched = false;
          _hint = 'Sai động tác — nhìn thẳng để làm lại';
        });
      }
    } else {
      _resetStable(res.hint);
    }
  }

  bool _isWrongAction(int step, double yaw, double pitch, double roll) {
    switch (step) {
      case 1:
        return yaw <= -_yawAcceptMin;
      case 2:
        return yaw >= _yawAcceptMin;
      case 3:
        return pitch <= -_pitchAcceptMin;
      case 4:
        return pitch >= _pitchAcceptMin;
      default:
        return false;
    }
  }

  _PoseEval _evaluatePose(int step, double yaw, double pitch, double roll) {
    bool frontal() =>
        yaw.abs() <= _frontTol &&
        pitch.abs() <= _frontTol &&
        roll.abs() <= _frontTol;

    String frontalHint() {
      if (yaw > _frontTol) return 'Quay mặt sang phải một chút';
      if (yaw < -_frontTol) return 'Quay mặt sang trái một chút';
      if (pitch > _frontTol) return 'Hạ cằm xuống một chút';
      if (pitch < -_frontTol) return 'Ngẩng cằm lên một chút';
      if (roll.abs() > _frontTol) return 'Giữ đầu thẳng, đừng nghiêng';
      return 'Nhìn thẳng vào camera';
    }

    switch (step) {
      case 0:
        return _PoseEval(frontal(), frontalHint());

      case 1:
        if (yaw >= _yawAcceptMin && yaw <= _yawAcceptMax) {
          return const _PoseEval(true, '');
        }
        return _PoseEval(
          false,
          yaw < _yawAcceptMin
              ? 'Xoay trái thêm (hiện ${yaw.toStringAsFixed(0)}°, cần 10-22°)'
              : 'Xoay trái ít lại (hiện ${yaw.toStringAsFixed(0)}°, cần 10-22°)',
        );

      case 2:
        if (yaw <= -_yawAcceptMin && yaw >= -_yawAcceptMax) {
          return const _PoseEval(true, '');
        }
        return _PoseEval(
          false,
          yaw > -_yawAcceptMin
              ? 'Xoay phải thêm (hiện ${yaw.abs().toStringAsFixed(0)}°, cần 10-22°)'
              : 'Xoay phải ít lại (hiện ${yaw.abs().toStringAsFixed(0)}°, cần 10-22°)',
        );

      case 3:
        if (pitch >= _pitchAcceptMin && pitch <= _pitchAcceptMax) {
          return const _PoseEval(true, '');
        }
        return _PoseEval(
          false,
          pitch < _pitchAcceptMin
              ? 'Ngẩng thêm (hiện ${pitch.toStringAsFixed(0)}°, cần 8-16°)'
              : 'Ngẩng ít lại (hiện ${pitch.toStringAsFixed(0)}°, cần 8-16°)',
        );

      case 4:
        if (pitch <= -_pitchAcceptMin && pitch >= -_pitchAcceptMax) {
          return const _PoseEval(true, '');
        }
        return _PoseEval(
          false,
          pitch > -_pitchAcceptMin
              ? 'Cúi thêm (hiện ${pitch.abs().toStringAsFixed(0)}°, cần 8-16°)'
              : 'Cúi ít lại (hiện ${pitch.abs().toStringAsFixed(0)}°, cần 8-16°)',
        );

      default:
        return const _PoseEval(false, '');
    }
  }

  void _resetStable(String hint) {
    if (!mounted) return;
    if (_stableHits == 0 && _hint == hint && !_poseMatched)
      return;
    setState(() {
      _stableHits = 0;
      _poseMatched = false;
      _hint = hint;
    });
  }

  void _setMatched(String hint) {
    if (!mounted) return;
    setState(() {
      _poseMatched = true;
      _hint = hint;
    });
  }

  Future<void> _autoCapture() async {
    if (_capturing || _step >= _kGuides.length) return;
    setState(() {
      _capturing = true;
      _poseMatched = true;
      _stableHits = 0;
      _status = '';
      _hint = 'Đang chụp…';
    });

    await _stopDetection();

    File? saved;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final xFile = await _cam!.takePicture();
        final tmpDir = await getTemporaryDirectory();
        final dest = p.join(
          tmpDir.path,
          'enroll_${widget.studentId}_${_step + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        saved = await File(xFile.path).copy(dest);
        try {
          await File(xFile.path).delete();
        } catch (_) {}
        break;
      } catch (_) {
        if (attempt == 2) {
          if (mounted) {
            setState(() {
              _status = '❌ Lỗi chụp ảnh, thử lại.';
              _capturing = false;
            });
          }
          await _startDetection();
          return;
        }
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }

    if (saved == null) {
      if (mounted) setState(() => _capturing = false);
      await _startDetection();
      return;
    }

    final qc = await ApiFaceService.checkPhotoQuality(saved!);
    if (qc.tier == 'fail' ||
        (qc.tier == 'soft' && !_softRetryUsed.contains(_step))) {
      if (qc.tier == 'soft') _softRetryUsed.add(_step);
      try {
        await saved!.delete();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _capturing = false;
          _poseMatched = false;
          _armed = false;
          _neutralHits = 0;
          _wrongAction = false;
          _status = '❌ ${qc.reason} — chụp lại bước này';
          _hint = _step == 0
              ? '${qc.reason} — nhìn thẳng lại'
              : '${qc.reason} — nhìn thẳng để làm lại';
        });
      }
      await _startDetection();
      return;
    }

    if (!mounted) return;
    setState(() {
      _photos.add(saved!);
      _step++;
      _capturing = false;
      _poseMatched = false;
      _armed = false;
      _neutralHits = 0;
      _wrongAction = false;
      _status = _step < _kGuides.length
          ? '✅ Đã chụp góc $_step/${_kGuides.length}'
          : '✅ Đủ ${_photos.length} ảnh — bấm Xác nhận để đăng ký!';
      _hint = _step < _kGuides.length ? 'Chuẩn bị động tác tiếp theo…' : '';
    });

    if (_step < _kGuides.length) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) await _startDetection();
    }
  }

  Future<void> _submit() async {
    if (_photos.length < 5) {
      setState(() => _status = '⚠️ Cần đủ 5 ảnh (làm theo 5 bước hướng dẫn).');
      return;
    }
    setState(() {
      _uploading = true;
      _status = '⏳ Đang xử lý & đăng ký...';
    });
    try {
      final result = await ApiFaceService.enroll(
        studentId: widget.studentId,
        name: widget.studentName,
        photos: _photos,
      );
      if (!result.success) {
        setState(() {
          _status = '❌ ${result.message}';
          _uploading = false;
        });
        return;
      }
      setState(() {
        _status = '🎉 ${result.message}';
        _uploading = false;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _status = '❌ $e';
        _uploading = false;
      });
    }
  }

  void _restart() {
    setState(() {
      _photos.clear();
      _step = 0;
      _softRetryUsed.clear();
      _stableHits = 0;
      _neutralHits = 0;
      _armed = false;
      _wrongAction = false;
      _poseMatched = false;
      _status = '';
      _hint = 'Đưa khuôn mặt vào khung hình';
    });
    _startDetection();
  }

  @override
  Widget build(BuildContext context) {
    final done = _step >= _kGuides.length;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    Color ovalColor = const Color(0xFF58A6FF);
    if (_poseMatched) ovalColor = Colors.greenAccent;
    if (_capturing) ovalColor = Colors.green;
    if (_uploading) ovalColor = Colors.orange;
    if (done) ovalColor = Colors.green;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Đăng ký khuôn mặt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: _cam != null && _cam!.value.isInitialized
                ? Builder(
                    builder: (context) {
                      double cameraRatio = _cam!.value.aspectRatio;
                      if (cameraRatio > 1.0) cameraRatio = 1.0 / cameraRatio;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: cameraRatio,
                                  height: 1.0,
                                  child: CameraPreview(_cam!),
                                ),
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: Size.infinite,
                            painter: _OvalOverlayPainter(
                              borderColor: ovalColor,
                              isProcessing: _capturing || _uploading,
                            ),
                          ),

                          if (!done)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _kGuides[_step].icon,
                                      color: const Color(0xFF58A6FF),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${_kGuides[_step].label} — Bước '
                                        '${_kGuides[_step].step}/${_kGuides.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (!done)
                            Positioned(
                              bottom: 80,
                              left: 24,
                              right: 24,
                              child: _buildLiveHint(),
                            ),

                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _photos
                                    .map(
                                      (f) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.file(
                                            f,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : _camError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _camErrorMsg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                            onPressed: () {
                              setState(() {
                                _camError = false;
                                _camErrorMsg = '';
                              });
                              _initCamera();
                            },
                          ),
                          if (_camErrorMsg.contains('Cài đặt')) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: openAppSettings,
                              child: const Text('Mở Cài đặt'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                  ),
          ),

          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF161B22),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 16, 20, 10 + bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!done) _buildGuideRow(),
                    const SizedBox(height: 12),
                    _buildProgress(),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _status.startsWith('❌')
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!done)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _poseMatched
                                    ? Colors.greenAccent
                                    : const Color(0xFF58A6FF),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _capturing
                                  ? 'Đang chụp…'
                                  : 'Tự động chụp khi đúng động tác',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Chụp lại từ đầu'),
                        onPressed: _uploading ? null : _restart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _btn(
                        label: _uploading
                            ? 'Đang gửi...'
                            : 'Xác nhận đăng ký (${_photos.length} ảnh)',
                        icon: _uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        color: Colors.green.shade700,
                        onPressed: _uploading ? null : _submit,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveHint() {
    if (_hint.isEmpty) return const SizedBox.shrink();
    final matched = _poseMatched || _capturing;
    final wrong = _wrongAction && !matched;

    Color bg;
    IconData icon;
    if (matched) {
      bg = Colors.green.withOpacity(0.85);
      icon = Icons.check_circle;
    } else if (wrong) {
      bg = Colors.red.withOpacity(0.85);
      icon = Icons.close_rounded;
    } else {
      bg = Colors.black.withOpacity(0.6);
      icon = Icons.arrow_forward_ios;
    }

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideRow() {
    final guide = _kGuides[_step.clamp(0, _kGuides.length - 1)];
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF58A6FF).withOpacity(0.15),
          child: Icon(guide.icon, color: const Color(0xFF58A6FF), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guide.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                guide.desc,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Row(
      children: List.generate(_kGuides.length, (i) {
        final color = i < _photos.length
            ? Colors.greenAccent
            : i == _step
            ? const Color(0xFF58A6FF)
            : Colors.white12;
        return Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _btn({
    required String label,
    required Widget icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _OvalOverlayPainter extends CustomPainter {
  final Color borderColor;
  final bool isProcessing;

  const _OvalOverlayPainter({
    required this.borderColor,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ovalW = size.width * 0.72;
    final ovalH = ovalW * 1.25;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalW,
      height: ovalH,
    );
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.55));

    canvas.drawOval(
      rect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isProcessing ? 4 : 3,
    );
  }

  @override
  bool shouldRepaint(_OvalOverlayPainter old) =>
      old.borderColor != borderColor || old.isProcessing != isProcessing;
}
