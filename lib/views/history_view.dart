import 'package:flutter/material.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Processing History',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F1111),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'View all previously graded items and their routing dispositions.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Filter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F1111),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.download),
                          label: const Text('Export CSV'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF232F3E),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- Data Table ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.resolveWith<Color>((states) => const Color(0xFFF3F3F3)),
                        dataRowMinHeight: 70,
                        dataRowMaxHeight: 70,
                        columns: const [
                          DataColumn(label: Text('DATE/TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ITEM ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('GRADE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ROUTED TO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: [
                          _buildRow('Just Now', 'AMZ-403-123', 'Apple iPad Pro 11"', 'Grade A+', 'Amazon Renewed', const Color(0xFF00687A)),
                          _buildRow('2 hrs ago', 'AMZ-992-001', 'Sony WH-1000XM4', 'Grade B', 'Refurbishment Center', const Color(0xFFFF9900)),
                          _buildRow('4 hrs ago', 'AMZ-112-948', 'Generic Blender', 'Grade D', 'E-Waste Recycling', Colors.red.shade700),
                          _buildRow('Yesterday', 'AMZ-554-222', 'Nike Air Max 270', 'Grade A', 'Resell (Used-Like New)', const Color(0xFF00687A)),
                          _buildRow('Yesterday', 'AMZ-883-111', 'Dell XPS 15', 'Grade C', 'Parts Harvesting', Colors.purple.shade700),
                        ],
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

  DataRow _buildRow(String date, String id, String product, String grade, String route, Color routeColor) {
    return DataRow(
      cells: [
        DataCell(Text(date, style: TextStyle(color: Colors.grey.shade600))),
        DataCell(Text(id, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(product)),
        DataCell(Text(grade, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: routeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: routeColor.withOpacity(0.3)),
            ),
            child: Text(route, style: TextStyle(color: routeColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        DataCell(
          TextButton(
            onPressed: () {},
            child: const Text('View Card'),
          ),
        ),
      ],
    );
  }
}