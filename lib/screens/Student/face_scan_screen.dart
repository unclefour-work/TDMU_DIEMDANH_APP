// ignore_for_file: unused_field, curly_braces_in_flow_control_structures, use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:app_diem_danh/services/face_service.dart';
import 'package:permission_handler/permission_handler.dart';

class FaceScanScreen extends StatefulWidget {
  final String expectedName;
  final List<double> savedEmbedding;

  final String? classId;

  const FaceScanScreen({
    super.key,
    required this.expectedName,
    this.savedEmbedding = const [],
    this.classId,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _frontCamera;
  bool _isInitialized = false;
  bool _isCameraError = false;
  String _cameraErrMsg = '';

  static const Duration _scanGap = Duration(milliseconds: 150);
  Timer? _scanTimer;

  bool _isProcessing = false;
  bool _isDone = false;
  bool _isSuccess = false;
  bool _isError = false;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scanTimer?.cancel();
      _controller?.dispose();
      if (mounted) setState(() => _isInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      if (!_isInitialized) _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted)
        setState(() {
          _isCameraError = true;
          _cameraErrMsg = status.isPermanentlyDenied
              ? 'Quyền camera bị tắt. Vào Cài đặt để bật lại.'
              : 'Cần cấp quyền camera để điểm danh.';
        });
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted)
        setState(() {
          _isCameraError = true;
          _cameraErrMsg = 'Không tìm thấy camera';
        });
      return;
    }

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _frontCamera = front;

    Object? lastErr;
    for (final preset in [ResolutionPreset.medium, ResolutionPreset.low]) {
      try {
        await _controller?.dispose();
        _controller = CameraController(front, preset, enableAudio: false);
        await _controller!.initialize();
        if (!mounted) return;

        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        setState(() {
          _isInitialized = true;
          _isCameraError = false;
          _statusMsg = 'Đưa khuôn mặt vào khung để điểm danh';
        });
        _startScanLoop();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ApiFaceService.warmUp();
        });
        return;
      } catch (e) {
        lastErr = e;
      }
    }

    if (mounted) {
      setState(() {
        _isCameraError = true;
        _cameraErrMsg = 'Lỗi khởi tạo camera: $lastErr';
      });
    }
  }

  void _startScanLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 400), _scanTick);
  }

  Future<void> _scanTick() async {
    if (!mounted || _isDone) return;
    await _captureAndVerify();
    if (mounted && !_isDone) {
      _scanTimer = Timer(_scanGap, _scanTick);
    }
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing || _isDone) return;
    setState(() => _isProcessing = true);

    File? imageFile;
    try {
      final photo = await _controller!.takePicture();
      imageFile = File(photo.path);
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    await _verifyWithFile(imageFile);
  }

  Future<void> _verifyWithFile(File imageFile) async {
    if (!mounted) {
      try {
        imageFile.delete();
      } catch (_) {}
      return;
    }
    try {
      final result = await ApiFaceService.recognizeAndVerify(
        capturedImage: imageFile,
        expectedName: widget.expectedName,
        classId: widget.classId,
      );
      try {
        imageFile.delete();
      } catch (_) {}

      if (!mounted) return;

      if (result.isMatch) {
        _scanTimer?.cancel();
        setState(() {
          _isProcessing = false;
          _isDone = true;
          _isSuccess = true;
          _isError = false;
          _statusMsg = 'Khuôn mặt đã được nhận diện';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true);
        return;
      }

      setState(() {
        _isProcessing = false;
        _isError = true;
        _statusMsg = result.hint ?? 'Không thể nhận diện được khuôn mặt';
      });
    } catch (e) {
      try {
        imageFile.delete();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isError = true;
          _statusMsg = 'Không thể nhận diện được khuôn mặt';
        });
      }
    }
  }

  Color get _ovalColor {
    if (_isSuccess) return Colors.green;
    if (_isProcessing) return Colors.orange;
    if (_isError) return Colors.red;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Xác thực khuôn mặt'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(child: CameraPreview(_controller!)),

                      CustomPaint(
                        size: Size.infinite,
                        painter: _OvalOverlayPainter(
                          borderColor: _ovalColor,
                          isProcessing: _isProcessing,
                        ),
                      ),

                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _isSuccess
                                ? Colors.green[800]!.withOpacity(0.92)
                                : _isError
                                ? Colors.red[900]!.withOpacity(0.92)
                                : Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _statusMsg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      if (_isProcessing)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                    ],
                  )
                : _isCameraError
                ? _buildCameraError()
                : const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
          ),

          Container(
            color: Colors.black,
            padding: const EdgeInsets.only(
              top: 12,
              bottom: 36,
              left: 20,
              right: 20,
            ),
            child: Column(
              children: [
                Text(
                  'Xin chào, ${widget.expectedName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _buildChecklist(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CheckIcon(
          icon: Icons.face_rounded,
          label: 'Nhận diện',
          state: _isSuccess
              ? _CheckState.ok
              : _isDone && !_isSuccess
              ? _CheckState.fail
              : _CheckState.neutral,
        ),
      ],
    );
  }

  Widget _buildCameraError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _cameraErrMsg,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
            onPressed: () {
              setState(() {
                _isCameraError = false;
              });
              _initCamera();
            },
          ),
        ],
      ),
    ),
  );
}

enum _CheckState { neutral, ok, fail }

class _CheckIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final _CheckState state;
  const _CheckIcon({
    required this.icon,
    required this.label,
    required this.state,
  });

  Color get _color {
    switch (state) {
      case _CheckState.ok:
        return Colors.green;
      case _CheckState.fail:
        return Colors.red;
      case _CheckState.neutral:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: _color.withOpacity(0.85), size: 22),
      const SizedBox(height: 3),
      Text(
        label,
        style: TextStyle(
          color: _color.withOpacity(0.8),
          fontSize: 10,
          fontWeight: state == _CheckState.fail
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    ],
  );
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
        ..strokeWidth = isProcessing ? 4.5 : 3.0,
    );
  }

  @override
  bool shouldRepaint(_OvalOverlayPainter old) =>
      old.borderColor != borderColor || old.isProcessing != isProcessing;
}
