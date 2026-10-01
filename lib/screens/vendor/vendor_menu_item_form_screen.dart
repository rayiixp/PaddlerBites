import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/errors.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';
import '../../services/catalog_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/custom_dialogs.dart';

/// Add a menu item, or edit/delete [existing]. Saved items appear on the
/// customer menu screens immediately through their Firestore streams.
class VendorMenuItemFormScreen extends StatefulWidget {
  final FoodModel? existing;
  const VendorMenuItemFormScreen({super.key, this.existing});

  @override
  State<VendorMenuItemFormScreen> createState() => _VendorMenuItemFormScreenState();
}

class _VendorMenuItemFormScreenState extends State<VendorMenuItemFormScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _category = kMenuCategories.first;
  bool _isAvailable = true;
  XFile? _image;
  Uint8List? _imageBytes;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    if (item != null) {
      _nameController.text = item.name;
      _descriptionController.text = item.description;
      _priceController.text = item.price.toStringAsFixed(2);
      if (kMenuCategories.contains(item.category)) _category = item.category;
      _isAvailable = item.isAvailable;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await StorageService.pickImage();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = file;
      _imageBytes = bytes;
    });
  }

  /// Returns an error message, or null when the form can be submitted.
  String? _validate() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    if (name.isEmpty) return 'Please enter the item name';
    if (name.length > 60) return 'Item name must be 60 characters or fewer';
    if (_descriptionController.text.trim().length > 300) return 'Description must be 300 characters or fewer';
    if (price == null || price <= 0) return 'Please enter a valid price';
    if (price > 10000) return 'Price looks too high. Please check it';
    if (!kMenuCategories.contains(_category)) return 'Please choose a category';
    return null;
  }

  /// Uploads the photo (if a new one was picked), waits for it to finish,
  /// then saves the complete item to Firestore. Customers see it immediately.
  Future<void> _save() async {
    if (_isSaving) return; // no double submissions
    final problem = _validate();
    if (problem != null) {
      showAppSnackBar(context, problem, isError: true);
      return;
    }
    final name = _nameController.text.trim();

    setState(() => _isSaving = true);
    try {
      final stall = await CatalogService.getStall(UserService.uid);
      if (stall == null) throw StateError('Set up your stall before adding menu items.');
      await CatalogService.saveMenuItem(
        existing: widget.existing,
        stallId: stall.id,
        stallName: stall.name,
        name: name,
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        category: _category,
        isAvailable: _isAvailable,
        image: _image,
      );
      if (!mounted) return;
      showAppSnackBar(context, _isEditing ? '$name updated' : '$name added to your menu');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not save item. ${friendlyError(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final item = widget.existing!;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${item.name}?',
      message: 'Customers will no longer see this item. This can\'t be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _isSaving = true);
    try {
      await CatalogService.deleteMenuItem(item);
      if (!mounted) return;
      showAppSnackBar(context, '${item.name} deleted');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not delete item. ${friendlyError(e)}', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: _isSaving ? null : () => Navigator.pop(context)),
        title: Text(_isEditing ? 'Edit menu item' : 'Add menu item',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _isSaving ? null : _pickImage,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImagePreview(),
                      if (_imageBytes != null || (widget.existing?.imageUrl.isNotEmpty ?? false))
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: const Row(
                              children: [
                                Icon(Icons.photo_camera_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('Change photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField('Item name', 'Cheese Burger', _nameController),
            const SizedBox(height: 20),
            _buildTextField(
              'Description',
              'What makes it good? Ingredients, serving size...',
              _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              'Price',
              '30.00',
              _priceController,
              prefix: '₱ ',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            ),
            const SizedBox(height: 20),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kMenuCategories.map((cat) {
                final isActive = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? Colors.black : Colors.grey.shade200),
                    ),
                    child: Text(cat,
                        style: TextStyle(color: isActive ? Colors.white : Colors.black, fontWeight: FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Turn off to show it as sold out', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(_isEditing ? 'Save changes' : 'Add to menu',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _isSaving ? null : _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Delete item', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageBytes != null) return Image.memory(_imageBytes!, fit: BoxFit.cover);
    final url = widget.existing?.imageUrl ?? '';
    if (url.isNotEmpty) return AppNetworkImage(url: url);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade400, size: 40),
        const SizedBox(height: 12),
        Text('Upload item photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    String? prefix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
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
