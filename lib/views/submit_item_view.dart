import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../data/models/evaluation_input.dart';
import '../data/repositories/grade_repository.dart';

class SubmitItemView extends StatefulWidget {
  const SubmitItemView({super.key});

  @override
  State<SubmitItemView> createState() => _SubmitItemViewState();
}

class _SubmitItemViewState extends State<SubmitItemView> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  final GradeRepository _gradeRepository = GradeRepository();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _orderOrPriceController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  String? _selectedCategory;
  String? _selectedReason;
  bool _isGrading = false;

  @override
  void dispose() {
    _productNameController.dispose();
    _orderOrPriceController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      debugPrint("Error picking images: $e");
    }
  }

  Future<void> _gradeItem() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one photo!')),
      );
      return;
    }
    if (_productNameController.text.trim().isEmpty ||
        _selectedCategory == null ||
        _selectedReason == null ||
        _orderOrPriceController.text.trim().isEmpty ||
        _pincodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all item details including pincode.'),
        ),
      );
      return;
    }

    setState(() => _isGrading = true);

    try {
      final List<String> photoUrls = await Future.wait(
        List.generate(_selectedImages.length, (i) async {
          final xfile = _selectedImages[i];
          final rawBytes = await xfile.readAsBytes();

          Uint8List uploadBytes;
          try {
            final decoded = img.decodeImage(rawBytes);
            if (decoded != null) {
              uploadBytes = Uint8List.fromList(
                img.encodeJpg(decoded, quality: 90),
              );
            } else {
              uploadBytes = rawBytes;
            }
          } catch (_) {
            uploadBytes = rawBytes;
          }

          return _gradeRepository.uploadPhoto(
            bytes: uploadBytes,
            fileName: 'photo_$i.jpg',
            contentType: 'image/jpeg',
          );
        }),
      );

      final EvaluationInput result = await _gradeRepository.gradeItem(
        productName: _productNameController.text.trim(),
        category: _selectedCategory!,
        reason: _selectedReason!,
        orderOrPrice: _orderOrPriceController.text.trim(),
        currentPincode: _pincodeController.text.trim(),
        photoUrls: photoUrls,
      );

      if (result.evaluationId != null) {
        try {
          final ai = await _gradeRepository.aiGrade(result.evaluationId!);
          result.condition = ai.condition;
          result.conditionReason = ai.conditionReason;
          result.estimatedResaleValue = ai.estimatedResaleValue;
          result.bestPhotoIndex = ai.bestPhotoIndex;
          result.photoUrls = photoUrls;
        } catch (e) {
          result.photoUrls = photoUrls;
          debugPrint('AI grading failed: $e');
        }
      }

      if (!mounted) return;
      setState(() => _isGrading = false);

      context.push('/seller/grade/result', extra: result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGrading = false);
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F2),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                const Text(
                  'Grade Item',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the product details and upload clear photos of its condition.\nOur AI will evaluate and suggest the best next step.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Item Details Card ───
                _buildItemDetailsCard(),
                const SizedBox(height: 24),

                // ─── Condition Photos Card ───
                _buildConditionPhotosCard(),
                const SizedBox(height: 32),

                // ─── Grade Button (centered) ───
                Center(
                  child: SizedBox(
                    width: 320,
                    child: ElevatedButton(
                      onPressed: _isGrading ? null : _gradeItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amazonOrange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: amazonOrange.withValues(
                          alpha: 0.6,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isGrading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'GRADE ITEM',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: amazonNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: amazonNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Item Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Product Name & Category row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Product Name',
                  controller: _productNameController,
                  hint: 'Enter product name',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildDropdownField(
                  label: 'Category',
                  value: _selectedCategory,
                  hint: 'Select category',
                  items: const [
                    'Electronics & Computers',
                    'Home & Kitchen',
                    'Beauty & Personal Care',
                    'Clothing, Shoes & Jewelry',
                    'Health, Household & Baby Care',
                    'Books, Music, Movies & Video Games',
                    'Toys, Kids & Baby',
                    'Sports, Outdoors & Fitness',
                    'Automotive, Tools & Industrial',
                    'Grocery',
                  ],
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Reason & Order ID row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Reason for Return',
                  value: _selectedReason,
                  hint: 'Select reason',
                  items: const ['Returned Amazon order', 'Unused at home'],
                  onChanged: (val) => setState(() => _selectedReason = val),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildTextField(
                  label: 'Order ID / Cost (₹)',
                  controller: _orderOrPriceController,
                  hint: 'e.g. ORD-101 or 15000',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pincode (full width)
          _buildTextField(
            label: 'Pincode / Location',
            controller: _pincodeController,
            hint: 'Enter pincode or location',
          ),
        ],
      ),
    );
  }

  Widget _buildConditionPhotosCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: amazonOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: amazonOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Condition Photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: amazonOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: amazonOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: amazonOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Photo upload area and thumbnails row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main upload area
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _pickImages,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: _selectedImages.isNotEmpty
                          ? amazonOrange.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      border: Border.all(
                        color: _selectedImages.isNotEmpty
                            ? amazonOrange
                            : Colors.grey.shade300,
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedImages.isNotEmpty
                              ? Icons.check_circle
                              : Icons.cloud_upload_outlined,
                          size: 32,
                          color: _selectedImages.isNotEmpty
                              ? amazonOrange
                              : amazonOrange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedImages.isNotEmpty
                              ? '${_selectedImages.length} Photo(s) Attached'
                              : 'Click to upload high-res photos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _selectedImages.isNotEmpty
                                ? amazonOrange
                                : textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedImages.isNotEmpty
                              ? 'Click to add more'
                              : 'Supports JPG, PNG',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Thumbnail slots
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(child: _buildThumbnail('Front', 0)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildThumbnail('Side', 1)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildThumbnail('Back', 2)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: amazonNavy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          style: const TextStyle(fontSize: 14, color: textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: amazonNavy, width: 1.5),
            ),
          ),
          hint: Text(
            hint,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildThumbnail(String label, int index) {
    final bool hasImage = _selectedImages.length > index;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: hasImage ? amazonOrange.withValues(alpha: 0.05) : Colors.white,
        border: Border.all(
          color: hasImage ? amazonOrange : Colors.grey.shade300,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasImage ? Icons.check_circle : Icons.camera_alt_outlined,
            size: 28,
            color: hasImage ? amazonOrange : Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: hasImage ? amazonOrange : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
