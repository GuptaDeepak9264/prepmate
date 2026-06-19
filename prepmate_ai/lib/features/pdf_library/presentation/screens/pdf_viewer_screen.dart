import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/pdf_provider.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  final String pdfId;
  final String pdfName;
  final String pdfUrl;
  final int lastPage;

  const PdfViewerScreen({
    super.key,
    required this.pdfId,
    required this.pdfName,
    required this.pdfUrl,
    required this.lastPage,
  });

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  PDFViewController? _pdfController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.lastPage;
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.pdfId}.pdf');

      if (!await file.exists()) {
        final response = await http.get(Uri.parse(widget.pdfUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download PDF (${response.statusCode})');
        }
      }

      if (mounted) {
        setState(() {
          _localPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _saveLastPage(int page) {
    ref.read(pdfUploadProvider.notifier).updateLastPage(widget.pdfId, page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.pdfName,
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: AppTextStyles.bodySmall
                    .copyWith(color: Colors.white60),
              ),
          ],
        ),
        actions: [
          if (_pdfController != null) ...[
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded,
                  color: Colors.white),
              onPressed: _currentPage > 0
                  ? () => _pdfController?.setPage(_currentPage - 1)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              onPressed: _currentPage < _totalPages - 1
                  ? () => _pdfController?.setPage(_currentPage + 1)
                  : null,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppLoadingIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading PDF...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _error != null
              ? AppErrorWidget(
                  message: 'Could not load PDF.\n$_error',
                  onRetry: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _downloadPdf();
                  },
                )
              : _localPath != null
                  ? Stack(
                      children: [
                        PDFView(
                          filePath: _localPath!,
                          defaultPage: widget.lastPage,
                          swipeHorizontal: false,
                          autoSpacing: true,
                          pageFling: true,
                          pageSnap: true,
                          fitPolicy: FitPolicy.BOTH,
                          onRender: (pages) {
                            if (pages != null) {
                              setState(() => _totalPages = pages);
                              _saveLastPage(widget.lastPage);
                              ref
                                  .read(pdfUploadProvider.notifier)
                                  .updatePageCount(widget.pdfId, pages);
                            }
                          },
                          onViewCreated: (ctrl) {
                            setState(() => _pdfController = ctrl);
                          },
                          onPageChanged: (page, total) {
                            if (page != null) {
                              setState(() => _currentPage = page);
                              _saveLastPage(page);
                            }
                          },
                          onError: (e) {
                            setState(() => _error = e.toString());
                          },
                        ),

                        // Progress bar at bottom
                        if (_totalPages > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                                enabledThumbRadius: 6),
                                      ),
                                      child: Slider(
                                        value:
                                            _currentPage.toDouble(),
                                        min: 0,
                                        max: (_totalPages - 1)
                                            .toDouble(),
                                        activeColor: AppColors.primary,
                                        inactiveColor: Colors.white30,
                                        onChanged: (v) {
                                          _pdfController
                                              ?.setPage(v.toInt());
                                        },
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_currentPage + 1}/$_totalPages',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox(),
    );
  }
}
