import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../data/models/evaluation_input.dart';
import '../data/repositories/grade_repository.dart';
import 'grading_result_view.dart';

class SubmitItemView extends StatefulWidget {
  final Function(Widget)? onNavigate;
  final Function()? onFinishToHistory;
  const SubmitItemView({super.key, this.onNavigate, this.onFinishToHistory});

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
      // 1. Upload all selected photos to S3 in parallel and collect their URLs.
      //    We force-encode every image to JPEG before uploading because:
      //    - Browsers (Chrome) often pick AVIF/HEIC from the gallery.
      //    - Amazon Bedrock Nova only accepts jpeg, png, webp, gif.
      //    The image package decodes any format and re-encodes to JPEG.
      final List<String> photoUrls = await Future.wait(
        List.generate(_selectedImages.length, (i) async {
          final xfile = _selectedImages[i];
          final rawBytes = await xfile.readAsBytes();

          // Decode → re-encode as JPEG (lossless path if already JPEG/PNG).
          Uint8List uploadBytes;
          try {
            final decoded = img.decodeImage(rawBytes);
            if (decoded != null) {
              uploadBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
            } else {
              uploadBytes = rawBytes; // fallback: send as-is
            }
          } catch (_) {
            uploadBytes = rawBytes; // decode failure: send as-is
          }

          // Always tell S3 + Bedrock it's JPEG so the content-type matches.
          return _gradeRepository.uploadPhoto(
            bytes: uploadBytes,
            fileName: 'photo_$i.jpg',
            contentType: 'image/jpeg',
          );
        }),
      );

      // 2. Submit for price/order grading -> creates the Evaluation record
      final EvaluationInput result = await _gradeRepository.gradeItem(
        productName: _productNameController.text.trim(),
        category: _selectedCategory!,
        reason: _selectedReason!,
        orderOrPrice: _orderOrPriceController.text.trim(),
        currentPincode: _pincodeController.text.trim(),
        photoUrls: photoUrls,
      );

      // 3. Run AI vision grading (Rekognition) on the uploaded photos
      if (result.evaluationId != null) {
        try {
          final ai = await _gradeRepository.aiGrade(result.evaluationId!);
          result.condition = ai.condition;
          result.conditionReason = ai.conditionReason;
          result.estimatedResaleValue = ai.estimatedResaleValue;
          result.bestPhotoIndex = ai.bestPhotoIndex;
          result.photoUrls = photoUrls;
        } catch (e) {
          // AI grading is best-effort; proceed with price data if it fails.
          result.photoUrls = photoUrls;
          debugPrint('AI grading failed: $e');
        }
      }

      if (!mounted) return;
      setState(() => _isGrading = false);

      if (widget.onNavigate != null) {
        widget.onNavigate!(
          GradingResultView(
            onNavigate: widget.onNavigate,
            evaluation: result,
            onFinishToHistory: widget.onFinishToHistory,
          ),
        );
      }
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
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Give this product a second life',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F1111),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the product details and upload condition photos to generate an accurate AI-driven grading assessment.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 32),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildItemDetailsCard()),
                    const SizedBox(width: 32),
                    Expanded(child: _buildConditionPhotosCard()),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isGrading ? null : _gradeItem,
                      icon: _isGrading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isGrading ? 'GRADING...' : 'GRADE ITEM',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ],
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0F1111)),
              SizedBox(width: 8),
              Text(
                'Item Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F1111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildLabel('PRODUCT NAME'),
          TextField(
            controller: _productNameController,
            decoration: const InputDecoration(
              hintText: 'e.g., Apple iPad Pro 11-inch (3rd Gen)',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('CATEGORY'),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCategory,
                      items: const [
                        DropdownMenuItem(
                          value: 'Electronics & Computers',
                          child: Text('Electronics & Computers'),
                        ),
                        DropdownMenuItem(
                          value: 'Home & Kitchen',
                          child: Text('Home & Kitchen'),
                        ),
                        DropdownMenuItem(
                          value: 'Beauty & Personal Care',
                          child: Text('Beauty & Personal Care'),
                        ),
                        DropdownMenuItem(
                          value: 'Clothing, Shoes & Jewelry',
                          child: Text('Clothing, Shoes & Jewelry'),
                        ),
                        DropdownMenuItem(
                          value: 'Health, Household & Baby Care',
                          child: Text('Health, Household & Baby Care'),
                        ),
                        DropdownMenuItem(
                          value: 'Books, Music, Movies & Video Games',
                          child: Text('Books, Music, Movies & Video Games'),
                        ),
                        DropdownMenuItem(
                          value: 'Toys, Kids & Baby',
                          child: Text('Toys, Kids & Baby'),
                        ),
                        DropdownMenuItem(
                          value: 'Sports, Outdoors & Fitness',
                          child: Text('Sports, Outdoors & Fitness'),
                        ),
                        DropdownMenuItem(
                          value: 'Automotive, Tools & Industrial',
                          child: Text('Automotive, Tools & Industrial'),
                        ),
                        DropdownMenuItem(
                          value: 'Grocery',
                          child: Text('Grocery'),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val),
                      hint: const Text('Select...'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('REASON FOR RETURN'),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedReason,
                      items: const [
                        DropdownMenuItem(
                          value: 'Returned Amazon order',
                          child: Text('Returned Amazon order'),
                        ),
                        DropdownMenuItem(
                          value: 'Unused at home',
                          child: Text('Unused at home'),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedReason = val),
                      hint: const Text('Select...'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('ORDER ID / COST (₹)'),
                    TextField(
                      controller: _orderOrPriceController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., ORD-101 or 2999',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('PINCODE / LOCATION'),
                    TextField(
                      controller: _pincodeController,
                      decoration: const InputDecoration(
                        hintText: 'e.g., 560001',
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.photo_camera_outlined, color: Color(0xFF0F1111)),
                  SizedBox(width: 8),
                  Text(
                    'Condition Photos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F1111),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(
                color: _selectedImages.isNotEmpty
                    ? const Color(0xFFFF9900).withValues(alpha: 0.05)
                    : const Color(0xFFF9F9F9),
                border: Border.all(
                  color: _selectedImages.isNotEmpty
                      ? const Color(0xFFFF9900)
                      : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _selectedImages.isNotEmpty
                        ? const Color(0xFFFF9900)
                        : Colors.grey.shade200,
                    child: Icon(
                      _selectedImages.isNotEmpty ? Icons.check : Icons.upload,
                      color: _selectedImages.isNotEmpty
                          ? Colors.white
                          : const Color(0xFF0F1111),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedImages.isNotEmpty
                        ? '${_selectedImages.length} Photo(s) Attached'
                        : 'Click to upload high-res photos',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedImages.isNotEmpty
                        ? 'Click again to add more'
                        : 'Supports JPG, PNG',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildThumbnail('Front', 0)),
              const SizedBox(width: 16),
              Expanded(child: _buildThumbnail('Side', 1)),
              const SizedBox(width: 16),
              Expanded(child: _buildThumbnail('Back', 2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
        letterSpacing: 1.0,
      ),
    ),
  );

  Widget _buildThumbnail(String label, int index) {
    final bool hasImage = _selectedImages.length > index;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: hasImage
                  ? const Color(0xFFFF9900).withValues(alpha: 0.1)
                  : Colors.white,
              border: Border.all(
                color: hasImage
                    ? const Color(0xFFFF9900)
                    : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                hasImage ? Icons.image : Icons.add_photo_alternate_outlined,
                color: hasImage ? const Color(0xFFFF9900) : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasImage ? "ATTACHED" : label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: hasImage ? const Color(0xFFFF9900) : Colors.black,
          ),
        ),
      ],
    );
  }
}
