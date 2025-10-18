// features/pdf_generation/domain/usecases/download_pdf_usecase.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/domain/errors/failures.dart';

/// Use case for downloading PDF files to device storage
/// Moves file I/O operations out of presentation layer for better architecture
class DownloadPdfUseCase {
  /// Downloads PDF bytes to the appropriate directory based on platform
  ///
  /// Returns Either<Failure, File>:
  /// - Left: Failure if download fails (permissions, I/O error, etc.)
  /// - Right: File object pointing to the saved PDF
  Future<Either<Failure, File>> call({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    try {
      // Run file I/O in compute isolate to avoid blocking UI
      return await compute(_downloadPdfInIsolate, _DownloadParams(
        pdfBytes: pdfBytes,
        fileName: fileName,
      ));
    } catch (e) {
      return Left(FileOperationFailure('Failed to download PDF: ${e.toString()}'));
    }
  }

  /// Isolated function for file I/O operations
  static Future<Either<Failure, File>> _downloadPdfInIsolate(_DownloadParams params) async {
    try {
      File? savedFile;

      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          return const Left(FileOperationFailure('Unable to access external storage'));
        }

        final downloadsPath = Directory('${directory.path}/Download');
        if (!await downloadsPath.exists()) {
          await downloadsPath.create(recursive: true);
        }
        savedFile = File('${downloadsPath.path}/${params.fileName}');
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        savedFile = File('${directory.path}/${params.fileName}');
      } else {
        return const Left(FileOperationFailure('Platform not supported'));
      }

      if (savedFile == null) {
        return const Left(FileOperationFailure('Unable to create file'));
      }

      await savedFile.writeAsBytes(params.pdfBytes);
      return Right(savedFile);
    } catch (e) {
      return Left(FileOperationFailure('File write failed: ${e.toString()}'));
    }
  }
}

/// Parameters for isolate download function
class _DownloadParams {
  final Uint8List pdfBytes;
  final String fileName;

  _DownloadParams({
    required this.pdfBytes,
    required this.fileName,
  });
}
