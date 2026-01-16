import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/gestures.dart';

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
  bool isReady = false;

  @override
  void initState() {
    super.initState();
    _loadPDFFromAssets();
  }

  Future<void> _loadPDFFromAssets() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // 从assets加载PDF并保存到临时文件
      final byteData = await rootBundle.load(widget.assetPath);
      final bytes = byteData.buffer.asUint8List();
      
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/temp_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      
      debugPrint('PDF文件大小: ${file.lengthSync()} bytes');
      
      // 验证文件是否成功写入
      if (await file.exists() && await file.length() > 0) {
        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      } else {
        throw Exception('PDF文件写入失败');
      }
    } catch (e) {
      setState(() {
        errorMessage = '加载PDF失败: $e';
        isLoading = false;
      });
      debugPrint('❌ PDF加载错误: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
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
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                '${currentPage + 1} / $totalPages',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
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
            Text(
              '正在加载PDF...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadPDFFromAssets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (localPath == null) {
      return const Center(
        child: Text(
          'PDF文件路径为空',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PDFView(
          filePath: localPath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          fitPolicy: FitPolicy.BOTH,
          defaultPage: currentPage,
          preventLinkNavigation: false,
          backgroundColor: Colors.white,
          nightMode: false,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          onRender: (pages) {
            setState(() {
              totalPages = pages ?? 0;
              isReady = true;
            });
            debugPrint('✅ PDF渲染完成，总页数: $totalPages');
          },
          onError: (error) {
            setState(() {
              errorMessage = '渲染PDF失败: $error';
            });
            debugPrint('❌ PDF渲染错误: $error');
          },
          onPageError: (page, error) {
            debugPrint('❌ PDF页面错误: page=$page, error=$error');
          },
          onViewCreated: (PDFViewController controller) {
            pdfController = controller;
            debugPrint('✅ PDF视图控制器创建完成');
          },
          onLinkHandler: (uri) {
            debugPrint('📎 PDF链接点击: $uri');
          },
          onPageChanged: (page, total) {
            setState(() {
              currentPage = page ?? 0;
              totalPages = total ?? 0;
            });
            debugPrint('📄 PDF页面变化: ${page ?? 0} / ${total ?? 0}');
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 清理临时文件
    if (localPath != null) {
      try {
        File(localPath!).deleteSync();
        debugPrint('✅ 临时PDF文件已删除');
      } catch (e) {
        debugPrint('⚠️ 删除临时PDF文件失败: $e');
      }
    }
    super.dispose();
  }
}