import 'package:flutter/material.dart';
import 'constants.dart';

class PurchasesTab extends StatelessWidget {
  const PurchasesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text('My Purchases', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.inventory_2, color: Colors.grey, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'iPhone 13 Pro - 256GB',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text('Condition: Excellent', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 2),
                        const Text('Ordered on Oct 12', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(
                    '\$649.00',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}