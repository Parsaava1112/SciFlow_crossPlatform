import 'package:flutter/material.dart';

class ElementCard extends StatelessWidget {
  final Map<String, dynamic> element;
  const ElementCard({Key? key, required this.element}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade800,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(element['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('نماد: ${element['symbol']}', style: const TextStyle(color: Colors.white70)),
            Text('عدد اتمی: ${element['atomic_number']}', style: const TextStyle(color: Colors.white70)),
            Text('جرم اتمی: ${element['atomic_mass']}', style: const TextStyle(color: Colors.white70)),
            Text('گروه: ${element['group']}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(element['description'], style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}