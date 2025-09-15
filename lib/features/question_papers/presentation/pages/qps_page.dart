import 'package:flutter/material.dart';

class QpsCreatePage extends StatelessWidget {
  const QpsCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Question Paper Creation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This will integrate with your existing QPS system'),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('QPS integration coming soon'),
                  ),
                );
              },
              child: Text('Create Question Paper'),
            ),
          ],
        ),
      ),
    );
  }
}
