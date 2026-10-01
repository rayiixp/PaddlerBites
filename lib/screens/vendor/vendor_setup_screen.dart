import '../../core/errors.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/campus_geofence.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/campus_map.dart';
import '../../widgets/custom_dialogs.dart';
import '../pending_approval_screen.dart';

/// Vendor application ([isApplication]: first submission or resubmission
/// after a rejection, prefilled from [existing]) and "Edit stall info" for
/// approved vendors.
class VendorSetupScreen extends StatefulWidget {
  final StallModel? existing;
  final bool isApplication;
  const VendorSetupScreen({super.key, this.existing, this.isApplication = false});

  @override
  State<VendorSetupScreen> createState() => _VendorSetupScreenState();
}

class _VendorSetupScreenState extends State<VendorSetupScreen> {
  final _nameController = TextEditingController();
  final _programController = TextEditingController();
  final _categoryController = TextEditingController();
  final _hoursController = TextEditingController();

  XFile? _logo;
  Uint8List? _logoBytes;
  String _existingLogoUrl = '';
  String _existingLogoPath = '';
  LatLng? _pickupPoint;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null && !widget.isApplication;

  @override
  void initState() {
    super.initState();
    final stall = widget.existing;
    if (stall != null) {
      _fill(stall);
    } else if (!widget.isApplication) {
      // Shown by the router without a stall: resume a saved setup.
      CatalogService.getStall(UserService.uid).then((stall) {
        if (stall != null && mounted) setState(() => _fill(stall));
      });
    }
  }

  void _fill(StallModel stall) {
    _nameController.text = stall.name;
    _programController.text = stall.program;
    _categoryController.text = stall.category;
    _hoursController.text = stall.operatingHours;
    _existingLogoUrl = stall.imageUrl;
    _existingLogoPath = stall.imagePath;
    _pickupPoint = CampusGeofence.fromGeoPoint(stall.pickupPoint);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _programController.dispose();
    _categoryController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await StorageService.pickImage();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logo = file;
      _logoBytes = bytes;
    });
  }

  Future<void> _pickLocation() async {
    final point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => CampusLocationPicker(title: 'Pin your stall', initial: _pickupPoint, isPickup: true),
      ),
    );
    if (point != null) setState(() => _pickupPoint = point);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppSnackBar(context, 'Please enter your stall name', isError: true);
      return;
    }
    if (_pickupPoint == null) {
      showAppSnackBar(context, 'Please pin your stall location on the campus map', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final stallId = UserService.uid;
      await CatalogService.saveStall(
        stallId: stallId,
        submitForReview: !_isEditing,
        name: name,
        program: _programController.text.trim(),
        category: _categoryController.text.trim(),
        operatingHours: _hoursController.text.trim(),
        pickupPoint: CampusGeofence.toGeoPoint(_pickupPoint!),
        logo: _logo,
        previousLogoPath: _existingLogoPath,
      );
      if (!mounted) return;

      if (_isEditing) {
        showAppSnackBar(context, 'Stall info updated');
        Navigator.pop(context);
        return;
      }

      // vendorStatus: 'pending' — the Vendor dashboard stays locked until an admin approves.
      await AuthService.submitVendorApplication(uid: stallId, stallId: stallId);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => SuccessDialog(
          title: 'Stall Submitted!',
          message: 'Your stall registration is under review. We\'ll notify you once it\'s approved.',
          buttonText: 'View Status',
          onDismiss: () {},
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PendingApprovalScreen(role: UserRole.vendor)),
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not save stall. ${friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          // As the router's root there is nothing to go back to, so sign out instead.
          onPressed: () async {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              await AuthService.signOut();
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Text('1', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
            ],
            Text(_isEditing ? 'Edit stall info' : 'Stall setup',
                style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEditing ? 'Update your stall' : 'Set up your stall',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This will be shown to customers browsing stalls', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildLogoPreview(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField('Stall name', 'Snackpreneurs', _nameController),
            const SizedBox(height: 20),
            _buildTextField('Program / organization', 'BSEntrep', _programController),
            const SizedBox(height: 20),
            _buildTextField('Category', 'Snacks & drinks', _categoryController),
            const SizedBox(height: 20),
            _buildTextField('Operating hours', '7:00 AM - 5:00 PM', _hoursController),
            const SizedBox(height: 20),
            const Text('Pickup location on campus map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _pickupPoint == null ? Colors.grey.shade200 : AppTheme.primaryColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      _pickupPoint == null ? Icons.location_on_outlined : Icons.location_on,
                      color: _pickupPoint == null ? Colors.grey.shade400 : AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pickupPoint == null ? 'Tap to pin stall location' : 'Stall pinned inside campus · tap to change',
                        style: TextStyle(color: _pickupPoint == null ? Colors.grey : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(_isEditing ? 'Save changes' : 'Submit for approval',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPreview() {
    if (_logoBytes != null) return Image.memory(_logoBytes!, fit: BoxFit.cover, width: double.infinity);
    if (_existingLogoUrl.isNotEmpty) {
      return AppNetworkImage(url: _existingLogoUrl, width: double.infinity, placeholderIcon: Icons.storefront_outlined);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 40),
        const SizedBox(height: 12),
        Text('Upload stall logo', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ],
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
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
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ],
    );
  }
}
