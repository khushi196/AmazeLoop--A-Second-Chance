import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'grading_result_view.dart';

class SubmitItemView extends StatefulWidget {
  final Function(Widget)? onNavigate;
  const SubmitItemView({super.key, this.onNavigate});

  @override
  State<SubmitItemView> createState() => _SubmitItemViewState();
}

class _SubmitItemViewState extends State<SubmitItemView> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

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
                const Text('Give this product a second life', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F1111), letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('Enter the product details and upload condition photos to generate an accurate AI-driven grading assessment.', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
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
                      onPressed: () async {
                        if (_selectedImages.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least one photo!')));
                          return;
                        }
                        
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFFFF9900)),
                                    SizedBox(height: 16),
                                    Text("Running AWS Vision AI...", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        await Future.delayed(const Duration(seconds: 2));
                        if (context.mounted) Navigator.pop(context);

                        // MAGIC ROUTING HAPPENS HERE
                        if (widget.onNavigate != null) {
                          widget.onNavigate!(GradingResultView(onNavigate: widget.onNavigate));
                        }
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('GRADE ITEM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.info_outline, color: Color(0xFF0F1111)), SizedBox(width: 8), Text('Item Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F1111)))]),
          const SizedBox(height: 16), const Divider(), const SizedBox(height: 16),
          _buildLabel('PRODUCT NAME'),
          const TextField(decoration: InputDecoration(hintText: 'e.g., Apple iPad Pro 11-inch (3rd Gen)')),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('CATEGORY'), DropdownButtonFormField<String>(isExpanded: true, items: const [DropdownMenuItem(value: 'electronics', child: Text('Electronics'))], onChanged: (val) {}, hint: const Text('Select...'))])),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('REASON FOR RETURN'), DropdownButtonFormField<String>(isExpanded: true, items: const [DropdownMenuItem(value: 'return', child: Text('Returned order'))], onChanged: (val) {}, hint: const Text('Select...'))])),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('ORDER ID / COST (₹)'), const TextField(decoration: InputDecoration(hintText: 'e.g., 403-1234567'))])),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('PINCODE / LOCATION'), const TextField(decoration: InputDecoration(hintText: 'e.g., 560001'))])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionPhotosCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Icon(Icons.photo_camera_outlined, color: Color(0xFF0F1111)), SizedBox(width: 8), Text('Condition Photos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F1111)))]), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)), child: const Text('Required', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 16), const Divider(), const SizedBox(height: 16),
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 48),
              decoration: BoxDecoration(color: _selectedImages.isNotEmpty ? const Color(0xFFFF9900).withOpacity(0.05) : const Color(0xFFF9F9F9), border: Border.all(color: _selectedImages.isNotEmpty ? const Color(0xFFFF9900) : Colors.grey.shade400, width: 2), borderRadius: BorderRadius.circular(8)),
              child: Column(children: [CircleAvatar(radius: 24, backgroundColor: _selectedImages.isNotEmpty ? const Color(0xFFFF9900) : Colors.grey.shade200, child: Icon(_selectedImages.isNotEmpty ? Icons.check : Icons.upload, color: _selectedImages.isNotEmpty ? Colors.white : const Color(0xFF0F1111))), const SizedBox(height: 16), Text(_selectedImages.isNotEmpty ? '${_selectedImages.length} Photo(s) Attached' : 'Click to upload high-res photos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Text(_selectedImages.isNotEmpty ? 'Click again to add more' : 'Supports JPG, PNG', style: TextStyle(color: Colors.grey.shade600, fontSize: 14))]),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [Expanded(child: _buildThumbnail('Front', 0)), const SizedBox(width: 16), Expanded(child: _buildThumbnail('Side', 1)), const SizedBox(width: 16), Expanded(child: _buildThumbnail('Back', 2))])
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800, letterSpacing: 1.0)));

  Widget _buildThumbnail(String label, int index) {
    final bool hasImage = _selectedImages.length > index;
    return Column(
      children: [
        AspectRatio(aspectRatio: 1, child: Container(decoration: BoxDecoration(color: hasImage ? const Color(0xFFFF9900).withOpacity(0.1) : Colors.white, border: Border.all(color: hasImage ? const Color(0xFFFF9900) : Colors.grey.shade300), borderRadius: BorderRadius.circular(4)), child: Center(child: Icon(hasImage ? Icons.image : Icons.add_photo_alternate_outlined, color: hasImage ? const Color(0xFFFF9900) : Colors.grey)))),
        const SizedBox(height: 8), Text(hasImage ? "ATTACHED" : label.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: hasImage ? const Color(0xFFFF9900) : Colors.black)),
      ],
    );
  }
}