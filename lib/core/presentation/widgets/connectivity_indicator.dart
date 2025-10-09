import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/ui_constants.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  bool _isOnline = true;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      // Check if Supabase client is connected
      final client = Supabase.instance.client;
      final response = await client.from('tenants').select('id').limit(1);

      if (mounted) {
        setState(() {
          _isOnline = true;
          _showIndicator = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOnline = false;
          _showIndicator = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showIndicator) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.paddingMedium,
        vertical: UIConstants.paddingSmall,
      ),
      color: _isOnline ? AppColors.success : AppColors.warning,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Connected' : 'Working Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: UIConstants.fontSizeSmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
