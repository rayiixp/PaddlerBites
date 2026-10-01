import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/errors.dart';
import '../../core/app_theme.dart';
import '../../models/app_user.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/custom_dialogs.dart';
import '../pending_approval_screen.dart';

/// Delivery Personnel application, opened from the profile picker. Submitting
/// sets `deliveryStatus: 'pending'` and shows [PendingApprovalScreen] until an
/// admin approves it. A rejected rider reopens it prefilled to resubmit.
class DeliveryRegistrationScreen extends StatefulWidget {
  const DeliveryRegistrationScreen({super.key});

  @override
  State<DeliveryRegistrationScreen> createState() => _DeliveryRegistrationScreenState();
}

class _DeliveryRegistrationScreenState extends State<DeliveryRegistrationScreen> {
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _contactController = TextEditingController();
  XFile? _idPhoto;
  Uint8List? _idPhotoBytes;
  String _existingIdUrl = '';
  String _existingIdPath = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill from a previous (e.g. rejected) application.
    final data = Provider.of<UserProvider>(context, listen: false).userData ?? {};
    _nameController.text = data['name'] ?? '';
    _studentIdController.text = data['studentId'] ?? '';
    _contactController.text = data['contactNumber'] ?? '';
    _existingIdUrl = data['idImageUrl'] ?? '';
    _existingIdPath = data['idImagePath'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickIdPhoto() async {
    final file = await StorageService.pickImage();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _idPhoto = file;
      _idPhotoBytes = bytes;
    });
  }

  /// Returns an error message, or null when the application is complete.
  String? _validate() {
    final name = _nameController.text.trim();
    final studentId = _studentIdController.text.trim();
    final contact = _contactController.text.replaceAll(RegExp(r'[\s-]'), '');
    if (name.isEmpty || studentId.isEmpty || contact.isEmpty) return 'Please fill in all fields';
    if (name.split(RegExp(r'\s+')).length < 2) return 'Please enter your full name (first and last name)';
    if (!RegExp(r'^[0-9][0-9-]{3,19}$').hasMatch(studentId)) return 'Enter your student ID number as printed on your ID (e.g. 2023-00456)';
    if (!RegExp(r'^09\d{9}$').hasMatch(contact)) return 'Enter an 11-digit mobile number starting with 09';
    if (_idPhoto == null && _existingIdUrl.isEmpty) return 'Please upload a photo of your student ID';
    return null;
  }

  /// Uploads the ID photo (awaited to completion), then saves the application
  /// with `deliveryStatus: 'pending'` for the admin to review.
  Future<void> _submit() async {
    if (_isSubmitting) return; // no double submissions
    final problem = _validate();
    if (problem != null) {
      showAppSnackBar(context, problem, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    String? newPhotoPath;
    try {
      final uid = UserService.uid;
      var (url, path) = (_existingIdUrl, _existingIdPath);
      if (_idPhoto != null) {
        (url, path) = await StorageService.upload(
          _idPhoto!,
          folder: 'users/$uid',
          name: 'student_id_${DateTime.now().millisecondsSinceEpoch}',
        );
        newPhotoPath = path;
      }
      await AuthService.submitDeliveryApplication(
        uid: uid,
        name: _nameController.text.trim(),
        studentId: _studentIdController.text.trim(),
        contactNumber: _contactController.text.replaceAll(RegExp(r'[\s-]'), ''),
        idImageUrl: url,
        idImagePath: path,
      );
      // Only now that the application points at the new photo, remove the old one.
      if (newPhotoPath != null && _existingIdPath.isNotEmpty) await StorageService.delete(_existingIdPath);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PendingApprovalScreen(role: UserRole.delivery)),
      );
    } catch (e) {
      // The application wasn't saved; don't leave the new photo behind.
      if (newPhotoPath != null) await StorageService.delete(newPhotoPath);
      if (mounted) {
        showAppSnackBar(context, 'Could not submit application. ${friendlyError(e)}', isError: true);
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Text('1', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            const Text('Registration', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery registration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Verified by admin before you can accept deliveries', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 32),
            _buildTextField('Full name', 'Juan Cruz', _nameController),
            const SizedBox(height: 20),
            _buildTextField('Student ID number', '2023-00456', _studentIdController),
            const SizedBox(height: 20),
            _buildTextField('Contact number', '09XX-XXX-XXXX', _contactController, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            const Text('Upload student ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isSubmitting ? null : _pickIdPhoto,
              child: Container(
                width: double.infinity,
                height: _idPhotoBytes == null && _existingIdUrl.isEmpty ? 120 : 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: _idPhotoBytes != null
                        ? Image.memory(_idPhotoBytes!, fit: BoxFit.cover, width: double.infinity)
                        : _existingIdUrl.isNotEmpty
                        ? AppNetworkImage(url: _existingIdUrl, width: double.infinity, placeholderIcon: Icons.badge_outlined)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, color: Colors.grey, size: 32),
                              SizedBox(height: 8),
                              Text('Tap to upload photo of ID', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Submit application', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}
