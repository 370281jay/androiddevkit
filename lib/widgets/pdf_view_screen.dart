import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PDFViewScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const PDFViewScreen({
    Key? key,
    required this.title,
    required this.assetPath,
  }) : super(key: key);

  @override
  State<PDFViewScreen> createState() => _PDFViewScreenState();
}

class _PDFViewScreenState extends State<PDFViewScreen> {
  String? localPath;
  bool isLoading = true;
  String? errorMessage;
  int currentPage = 0;
  int totalPages = 0;
  PDFViewController? pdfController;

  @override
  void initState() {
    super.initState();
    _loadPDFFromAssets();
  }

  Future<void> _loadPDFFromAssets() async {
    try {
      // 从assets加载PDF并保存到临时文件
      final byteData = await rootBundle.load(widget.assetPath);
      final bytes = byteData.buffer.asUint8List();
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_report.pdf');
      await file.writeAsBytes(bytes);
      
      setState(() {
        localPath = file.path;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '加载PDF失败: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        actions: [
          if (totalPages > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentPage + 1} / $totalPages',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomControls(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载PDF...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadPDFFromAssets();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (localPath == null) {
      return const Center(child: Text('PDF文件路径为空'));
    }

    return PDFView(
      filePath: localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: currentPage,
      fitPolicy: FitPolicy.WIDTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        setState(() {
          totalPages = pages ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          errorMessage = '渲染PDF失败: $error';
        });
      },
      onPageError: (page, error) {
        setState(() {
          errorMessage = '页面 $page 渲染失败: $error';
        });
      },
      onViewCreated: (PDFViewController controller) {
        pdfController = controller;
      },
      onLinkHandler: (uri) {
        // 处理PDF中的链接点击
        debugPrint('PDF链接点击: $uri');
      },
      onPageChanged: (page, total) {
        setState(() {
          currentPage = page ?? 0;
          totalPages = total ?? 0;
        });
      },
    );
  }

  Widget _buildBottomControls() {
    if (totalPages <= 1) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 上一页
          IconButton(
            onPressed: currentPage > 0 ? _goToPreviousPage : null,
            icon: const Icon(Icons.navigate_before),
            iconSize: 32,
            tooltip: '上一页',
          ),
          
          // 页面指示器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              '${currentPage + 1} / $totalPages',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          
          // 下一页
          IconButton(
            onPressed: currentPage < totalPages - 1 ? _goToNextPage : null,
            icon: const Icon(Icons.navigate_next),
            iconSize: 32,
            tooltip: '下一页',
          ),
        ],
      ),
    );
  }

  void _goToPreviousPage() {
    if (currentPage > 0) {
      pdfController?.setPage(currentPage - 1);
    }
  }

  void _goToNextPage() {
    if (currentPage < totalPages - 1) {
      pdfController?.setPage(currentPage + 1);
    }
  }

  @override
  void dispose() {
    // 清理临时文件
    if (localPath != null) {
      try {
        File(localPath!).deleteSync();
      } catch (e) {
        debugPrint('删除临时PDF文件失败: $e');
      }
    }
    super.dispose();
  }
}