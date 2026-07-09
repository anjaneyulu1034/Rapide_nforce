import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class DocumentDownloadService {
  DocumentDownloadService._();
  static final instance = DocumentDownloadService._();

  final _dio = Dio();

  Map<String, String> get _authHeaders {
    final token = AuthService.instance.currentUser?.token;
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  /// Downloads a single document from the API and opens it locally.
  /// Shows a snackbar/dialog on the given [context] for progress feedback.
  Future<void> downloadAndOpen({
    required BuildContext context,
    required int truckId,
    required int documentId,
    required String displayFileName,
    String? companyId,
  }) async {
    late OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (_) => const _DownloadingOverlay(),
    );
    Overlay.of(context).insert(overlay);

    try {
      final tempDir = await getTemporaryDirectory();

      // Derive a safe filename
      String safeName = displayFileName
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
          .trim();
      if (safeName.isEmpty) safeName = 'document_$documentId';

      // Ensure the name has an extension — default to .pdf
      if (!safeName.contains('.')) safeName = '$safeName.pdf';

      final savePath = '${tempDir.path}/$safeName';

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.trucks}/$truckId/documents/$documentId/download';

      final headers = <String, String>{..._authHeaders};
      if (companyId != null && companyId.isNotEmpty) {
        headers['X-Company-Id'] = companyId;
      }

      await _dio.download(
        url,
        savePath,
        options: Options(headers: headers),
      );

      overlay.remove();

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          _showError(context, 'Could not open file: ${result.message}');
        }
      }
    } catch (e) {
      overlay.remove();
      if (context.mounted) {
        _showError(context, 'Download failed: ${_readableError(e)}');
      }
    }
  }

  /// Downloads a file from an already-signed URL (e.g. work order attachments,
  /// which come back from the API with a ready-to-use S3 URL — no auth header
  /// or per-file endpoint needed).
  Future<void> downloadAndOpenDirect({
    required BuildContext context,
    required String url,
    required String displayFileName,
  }) async {
    late OverlayEntry overlay;
    overlay = OverlayEntry(builder: (_) => const _DownloadingOverlay());
    Overlay.of(context).insert(overlay);

    try {
      final tempDir = await getTemporaryDirectory();
      String safeName =
          displayFileName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
      if (safeName.isEmpty) safeName = 'attachment';
      if (!safeName.contains('.')) safeName = '$safeName.pdf';

      final savePath = '${tempDir.path}/$safeName';
      await _dio.download(url, savePath);

      overlay.remove();

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          _showError(context, 'Could not open file: ${result.message}');
        }
      }
    } catch (e) {
      overlay.remove();
      if (context.mounted) {
        _showError(context, 'Download failed: ${_readableError(e)}');
      }
    }
  }

  /// Downloads the combined PDF packet for a truck (all non-expired documents).
  ///
  /// Pass [hasDocuments] = false when the unit has no documents at all, so we
  /// can show a clear message instead of a misleading 404 "file not found".
  Future<void> downloadPdfPacket({
    required BuildContext context,
    required int truckId,
    String scope = 'compliance',
    bool hasDocuments = true,
  }) async {
    if (!hasDocuments) {
      _showError(context, 'No documents available to download');
      return;
    }
    late OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (_) => const _DownloadingOverlay(),
    );
    Overlay.of(context).insert(overlay);

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath =
          '${tempDir.path}/truck-$truckId-roadside-packet-${DateTime.now().millisecondsSinceEpoch}.pdf';

      final url =
          '${ApiConstants.baseUrl}${ApiConstants.trucks}/$truckId/documents/packet?scope=$scope';

      await _dio.download(
        url,
        savePath,
        options: Options(headers: _authHeaders),
      );

      overlay.remove();

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          _showError(context, 'Could not open PDF: ${result.message}');
        }
      }
    } catch (e) {
      overlay.remove();
      if (context.mounted) {
        _showError(context, 'Download failed: ${_readableError(e)}');
      }
    }
  }

  String _readableError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 404) return 'File not found on server';
      if (status == 401) return 'Session expired — please log in again';
      return e.message ?? 'Network error';
    }
    if (e is FileSystemException) return 'Could not save file locally';
    return e.toString();
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFBA1A1A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DownloadingOverlay extends StatelessWidget {
  const _DownloadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black26,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF1A1A1A),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Downloading…',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
