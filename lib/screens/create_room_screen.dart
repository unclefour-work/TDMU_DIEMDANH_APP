// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'pick_location_screen.dart';

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  Position? _currentPosition;
  LatLng? _selectedLatLng;
  bool _isLoading = false;

  Future<String?> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data()?['role'];
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMsg("Vui lòng bật GPS");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMsg("Bạn đã từ chối quyền vị trí");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMsg(
          "Quyền vị trí bị từ chối vĩnh viễn. Hãy vào cài đặt để cấp lại.",
        );
        if (!kIsWeb) await Geolocator.openAppSettings();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _selectedLatLng = null;
      });

      _showMsg("Đã lấy vị trí hiện tại");
    } catch (e) {
      _showMsg("Không thể lấy vị trí");
    }
  }

  Future<void> _createRoom() async {
    if (_classNameController.text.trim().isEmpty ||
        _radiusController.text.trim().isEmpty) {
      _showMsg("Vui lòng nhập đầy đủ thông tin");
      return;
    }

    if (_currentPosition == null && _selectedLatLng == null) {
      _showMsg("Vui lòng chọn vị trí");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final role = await _getUserRole();

      final latitude = _selectedLatLng?.latitude ?? _currentPosition!.latitude;
      final longitude =
          _selectedLatLng?.longitude ?? _currentPosition!.longitude;

      final data = {
        'name': _classNameController.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'radius': double.parse(_radiusController.text.trim()),
        'ownerId': user?.uid,
        'createdAt': Timestamp.now(),
        'isOpen': true,
      };

      if (role == "teacher") {
        await FirebaseFirestore.instance.collection('classes').add(data);
      } else if (role == "institute") {
        await FirebaseFirestore.instance.collection('events').add(data);
      } else {
        _showMsg("Bạn không có quyền tạo");
        setState(() => _isLoading = false);
        return;
      }

      _showMsg("Tạo thành công");
      Navigator.pop(context);
    } catch (e) {
      _showMsg("Lỗi tạo");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo Phòng Điểm Danh"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/backgroud1.jpg", fit: BoxFit.cover),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  TextField(
                    controller: _classNameController,
                    decoration: InputDecoration(
                      labelText: "Tên phòng / sự kiện",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _radiusController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Bán kính (m)",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _buildButton(
                    text: "Lấy vị trí hiện tại",
                    onTap: _getCurrentLocation,
                  ),

                  const SizedBox(height: 15),

                  _buildButton(
                    text: kIsWeb
                        ? "Chọn vị trí trên bản đồ"
                        : "Chọn vị trí trên Google Map",
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PickLocationScreen(),
                        ),
                      );

                      if (result != null && result is LatLng) {
                        setState(() {
                          _selectedLatLng = result;
                          _currentPosition = null;
                        });
                        _showMsg("Đã chọn vị trí từ bản đồ");
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  if (_selectedLatLng != null)
                    Text(
                      "Map: ${_selectedLatLng!.latitude}, ${_selectedLatLng!.longitude}",
                      style: const TextStyle(fontSize: 14),
                    )
                  else if (_currentPosition != null)
                    Text(
                      "GPS: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}",
                      style: const TextStyle(fontSize: 14),
                    ),

                  const SizedBox(height: 30),

                  _buildButton(
                    text: _isLoading ? "Đang tạo..." : "Tạo",
                    onTap: _isLoading ? () {} : _createRoom,
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required String text, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
