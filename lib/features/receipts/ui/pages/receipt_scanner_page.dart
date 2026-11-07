import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/provider/receipts_provider.dart';
import 'package:gastos_app/features/receipts/services/nfce_pr_parser_service.dart';

class ReceiptScannerPage extends ConsumerStatefulWidget {
  const ReceiptScannerPage({super.key});

  @override
  ConsumerState<ReceiptScannerPage> createState() => _ReceiptScannerPageState();
}

class _ReceiptScannerPageState extends ConsumerState<ReceiptScannerPage> {
  MobileScannerController? _controller;
  bool _isLoading = false;
  bool _hasScanned = false;
  String _statusMessage = 'Aponte a câmera para o QR Code do Cupom Fiscal';

  bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_hasScanned || _isLoading) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    setState(() {
      _hasScanned = true;
      _isLoading = true;
      _statusMessage = 'Consultando dados na SEFAZ Paraná...';
    });

    await _processUrl(code);
  }

  Future<void> _processUrl(String url) async {
    try {
      final parser = ref.read(nfceParserServiceProvider);
      final receipt = await parser.parseFromUrl(url);

      if (!mounted) return;
      _navigateToReview(receipt);
    } on NfceParseException catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Erro ao processar cupom: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasScanned = false;
          _statusMessage = 'Aponte a câmera para o QR Code do Cupom Fiscal';
        });
      }
    }
  }

  void _navigateToReview(Receipt receipt) {
    context.push(
      RouteNames.receiptReview,
      extra: receipt,
    );
  }

  void _loadDemoReceipt() {
    final parser = ref.read(nfceParserServiceProvider);
    final demoReceipt = parser.getDemoReceipt();
    _navigateToReview(demoReceipt);
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inserir Link da Nota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole o link completo retornado pelo QR Code da SEFAZ Paraná:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'http://www.fazenda.pr.gov.br/nfce/qrcode?p=...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                setState(() {
                  _isLoading = true;
                  _statusMessage = 'Consultando dados na SEFAZ Paraná...';
                });
                _processUrl(text);
              }
            },
            child: const Text('Processar'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Atenção'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadDemoReceipt();
            },
            child: const Text('Usar Cupom Exemplo'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Cupom Fiscal'),
        actions: [
          if (_controller != null) ...[
            IconButton(
              icon: ValueListenableBuilder<TorchState>(
                valueListenable: _controller!.torchState,
                builder: (context, state, child) {
                  return Icon(
                    state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                    color: state == TorchState.on ? Colors.amber : null,
                  );
                },
              ),
              tooltip: 'Lanterna',
              onPressed: () => _controller!.toggleTorch(),
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              tooltip: 'Trocar câmera',
              onPressed: () => _controller!.switchCamera(),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          if (_isMobile && _controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _handleBarcode,
            )
          else
            _buildDesktopOrNoCameraFallback(),

          // Overlay com moldura de escaneamento
          if (_isMobile && !_isLoading) _buildScannerOverlay(),

          // Barra inferior com atalhos de entrada manual e exemplo
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.75;
        return Stack(
          children: [
            Center(
              child: Container(
                width: scanAreaSize,
                height: scanAreaSize,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 2,
                        color: AppColors.primary.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: (constraints.maxHeight / 2) + (scanAreaSize / 2) + 16,
              left: 24,
              right: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopOrNoCameraFallback() {
    return Container(
      color: Colors.grey.shade900,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            const Text(
              'Leitor de Cupom Fiscal NFC-e (Paraná)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No aparelho com câmera, aponte diretamente para o QR Code impresso no cupom do supermercado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.paste),
              label: const Text('Colar Link ou Chave da Nota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _showManualInputDialog,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('Testar com Cupom de Exemplo (PR)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _loadDemoReceipt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withAlpha(240),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('Inserir Link'),
                onPressed: _showManualInputDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('Cupom Exemplo'),
                onPressed: _loadDemoReceipt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
