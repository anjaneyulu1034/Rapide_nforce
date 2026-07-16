import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';

/// Bottom sheet showing a generated compliance QR code, with a shortcut to
/// download the same PDF packet it links to. Shared by Power Unit and
/// Trailer detail screens.
class QrCodeSheet extends StatelessWidget {
  const QrCodeSheet({
    super.key,
    required this.imageBytes,
    required this.unitNumber,
    required this.onDownloadPacket,
  });

  final Uint8List? imageBytes;
  final String unitNumber;
  final VoidCallback onDownloadPacket;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Compliance QR Code',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unitNumber,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (imageBytes != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Image.memory(imageBytes!, width: 220, height: 220),
              )
            else
              Text(
                'Could not render QR code',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 8),
            Text(
              "Scan to instantly access this vehicle's compliance documents.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDownloadPacket,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4B633D),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download PDF Packet'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
