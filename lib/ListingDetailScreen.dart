import 'package:flutter/material.dart';
import 'constants.dart';

class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: amazonNavy,
        elevation: 0,
        title: const Text('Item Detail', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 280,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Icon(Icons.phone_iphone, size: 120, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'iPhone 13 Pro - 128GB',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$499.00',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textPrimary),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            Row(
                              children: [
                                Icon(Icons.health_and_safety, color: amazonNavy),
                                const SizedBox(width: 8),
                                Text(
                                  'Product Health Card',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: amazonNavy,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Score 0.92',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 24, thickness: 1),
                        Text(
                          'Issues Noted',
                          style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• Minor scratch on left aluminum side\n• Box packaging slightly dented',
                          style: TextStyle(color: Colors.black87, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amazonOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Item successfully reserved!')),
                        );
                      },
                      child: const Text(
                        'Reserve / Buy Now',
                        style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}