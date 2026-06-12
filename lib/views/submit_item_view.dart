import 'package:flutter/material.dart';

class SubmitItemView extends StatelessWidget {
  const SubmitItemView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
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

              // Content Grid: 50/50 Layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Item Details
                  Expanded(child: _buildItemDetailsCard()),
                  const SizedBox(width: 32),
                  // Right Column: Condition Photos
                  Expanded(child: _buildConditionPhotosCard()),
                ],
              ),
              const SizedBox(height: 32),

              // Primary Action
              const Divider(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // We will wire this to the AI grading mock later!
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text(
                      'GRADE ITEM',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    ),
                  ),
                ],
              ),
            ],
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F1111)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          _buildLabel('PRODUCT NAME'),
          const TextField(
            decoration: InputDecoration(hintText: 'e.g., Apple iPad Pro 11-inch (3rd Gen)'),
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
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      items: const [
                        DropdownMenuItem(value: 'electronics', child: Text('Electronics')),
                        DropdownMenuItem(value: 'apparel', child: Text('Apparel')),
                        DropdownMenuItem(value: 'home', child: Text('Home Goods')),
                        DropdownMenuItem(value: 'toys', child: Text('Toys & Games')),
                      ],
                      onChanged: (val) {},
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
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      items: const [
                        DropdownMenuItem(value: 'return', child: Text('Returned Amazon order')),
                        DropdownMenuItem(value: 'unused', child: Text('Unused at home')),
                      ],
                      onChanged: (val) {},
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
                    const TextField(decoration: InputDecoration(hintText: 'e.g., 403-1234567')),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('PINCODE / LOCATION'),
                    const TextField(decoration: InputDecoration(hintText: 'e.g., 560001')),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F1111)),
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
                child: const Text('Required', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Main Upload Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              border: Border.all(color: Colors.grey.shade400, width: 2), // Simulating the dashed border
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.upload, color: Color(0xFF0F1111)),
                ),
                const SizedBox(height: 16),
                const Text('Drag & Drop high-res photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('or click to browse files', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Thumbnails
          Row(
            children: [
              Expanded(child: _buildThumbnail('Front')),
              const SizedBox(width: 16),
              Expanded(child: _buildThumbnail('Side')),
              const SizedBox(width: 16),
              Expanded(child: _buildThumbnail('Back')),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildThumbnail(String label) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}