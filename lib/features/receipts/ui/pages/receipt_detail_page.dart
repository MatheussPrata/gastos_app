import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/provider/receipts_provider.dart';
import 'package:gastos_app/features/receipts/services/nfce_pr_parser_service.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

class ReceiptDetailPage extends ConsumerStatefulWidget {
  final String? receiptId;
  final String? transactionId;

  const ReceiptDetailPage({
    super.key,
    this.receiptId,
    this.transactionId,
  });

  @override
  ConsumerState<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends ConsumerState<ReceiptDetailPage> {
  bool _reconsulting = false;

  Future<void> _reconsultSefaz(Receipt currentReceipt) async {
    final url = currentReceipt.rawUrl?.trim();
    if (_reconsulting || url == null || url.isEmpty) return;

    setState(() => _reconsulting = true);
    try {
      final parsed = await ref.read(nfceParserServiceProvider).parseFromUrl(url);
      if (!mounted) return;

      final merged = parsed.copyWith(
        id: currentReceipt.id,
        transactionId: currentReceipt.transactionId,
        createdAt: currentReceipt.createdAt,
        updatedAt: DateTime.now(),
        items: [
          for (var i = 0; i < parsed.items.length; i++)
            parsed.items[i].copyWith(receiptId: currentReceipt.id),
        ],
      );

      await context.push(RouteNames.receiptReview, extra: merged);
      if (!mounted) return;
      if (currentReceipt.id.isNotEmpty) {
        ref.invalidate(receiptDetailsProvider(currentReceipt.id));
      }
      final currentTxId =
          (widget.transactionId != null && widget.transactionId!.isNotEmpty)
              ? widget.transactionId!
              : currentReceipt.transactionId;
      if (currentTxId.isNotEmpty) {
        ref.invalidate(receiptByTransactionProvider(currentTxId));
        ref.invalidate(transactionByIdProvider(currentTxId));
      }
    } on NfceParseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.expense),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao reconsultar SEFAZ: $e'),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _reconsulting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Receipt?> receiptAsync;
    if (widget.receiptId != null && widget.receiptId!.isNotEmpty) {
      receiptAsync = ref.watch(receiptDetailsProvider(widget.receiptId!));
    } else if (widget.transactionId != null &&
        widget.transactionId!.isNotEmpty) {
      receiptAsync =
          ref.watch(receiptByTransactionProvider(widget.transactionId!));
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes da Compra')),
        body: const Center(child: Text('Cupom fiscal não especificado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Compra'),
        actions: [
          receiptAsync.when(
            data: (receipt) {
              if (receipt == null) return const SizedBox.shrink();
              final currentTxId =
                  (widget.transactionId != null &&
                          widget.transactionId!.isNotEmpty)
                      ? widget.transactionId!
                      : receipt.transactionId;
              final hasRawUrl =
                  receipt.rawUrl != null && receipt.rawUrl!.trim().isNotEmpty;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRawUrl)
                    IconButton(
                      icon: _reconsulting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      tooltip: 'Reconsultar itens na SEFAZ',
                      onPressed:
                          _reconsulting ? null : () => _reconsultSefaz(receipt),
                    ),
                  if (currentTxId.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.edit_note),
                      tooltip: 'Editar Transação',
                      onPressed: () async {
                        await context.push(
                          RouteNames.transactionForm,
                          extra: {'id': currentTxId, 'isEditing': true},
                        );
                        ref.invalidate(transactionByIdProvider(currentTxId));
                        if (receipt.id.isNotEmpty) {
                          ref.invalidate(receiptDetailsProvider(receipt.id));
                        }
                        ref.invalidate(
                            receiptByTransactionProvider(currentTxId));
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar Cupom e Itens',
                    onPressed: () async {
                      await context.push(
                        RouteNames.receiptReview,
                        extra: receipt,
                      );
                      if (receipt.id.isNotEmpty) {
                        ref.invalidate(receiptDetailsProvider(receipt.id));
                      }
                      if (currentTxId.isNotEmpty) {
                        ref.invalidate(
                            receiptByTransactionProvider(currentTxId));
                        ref.invalidate(transactionByIdProvider(currentTxId));
                      }
                    },
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: receiptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar cupom: $e')),
        data: (receipt) {
          if (receipt == null) {
            return const Center(
              child: Text('Cupom fiscal não encontrado para esta compra.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _buildDigitalDanfeCoupon(context, receipt),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDigitalDanfeCoupon(BuildContext context, Receipt receipt) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final couponBg = isDark ? const Color(0xFF141D2E) : scheme.surface;
    final couponFooterBg = isDark
        ? const Color(0xFF0E1624)
        : scheme.surfaceContainerHighest.withOpacity(0.45);
    final couponBorder = isDark
        ? Colors.white.withOpacity(0.10)
        : scheme.outlineVariant.withOpacity(0.6);
    final mutedText = scheme.onSurface.withOpacity(0.65);

    final currentTxId =
        (widget.transactionId != null && widget.transactionId!.isNotEmpty)
            ? widget.transactionId!
            : receipt.transactionId;
    final tx = currentTxId.isNotEmpty
        ? ref.watch(transactionByIdProvider(currentTxId)).valueOrNull
        : null;

    final cards = ref.watch(creditCardsProvider).valueOrNull ?? [];
    final card = (tx?.creditCardId != null && tx!.creditCardId!.isNotEmpty)
        ? cards.where((c) => c.id == tx.creditCardId).firstOrNull
        : null;

    final itemCount = receipt.items.length;
    final countBadgeText = '$itemCount ${itemCount == 1 ? "item" : "itens"}';
    final hasAnyDiscount = receipt.discountTotal > 0.005;

    return Container(
      decoration: BoxDecoration(
        color: couponBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couponBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.32 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -------------------------------------------------- 1. Cabeçalho DANFE
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_2, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'DANFE NFC-e • CUPOM FISCAL DIGITAL',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  receipt.establishmentName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                if (receipt.establishmentCnpj.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'CNPJ: ${receipt.establishmentCnpj}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: mutedText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _CouponMetaChip(
                      icon: Icons.schedule,
                      label: DateFormatter.formatDateTime(receipt.issueDate),
                    ),
                    if (receipt.paymentMethod.isNotEmpty)
                      _CouponMetaChip(
                        icon: Icons.credit_card,
                        label: receipt.paymentMethod,
                      ),
                    if (card != null)
                      _CouponMetaChip(
                        icon: Icons.account_balance_wallet_outlined,
                        label:
                            '${card.name}${card.lastFourDigits.isNotEmpty ? " •${card.lastFourDigits}" : ""}',
                      ),
                  ],
                ),
                if (tx != null &&
                    tx.isInstallment &&
                    tx.totalInstallments > 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: scheme.primary.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.splitscreen,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Parcelado em ${tx.totalInstallments}x '
                            '(${tx.installmentNumber}ª parcela de ${CurrencyFormatter.format(tx.amount)})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DashedDivider(color: mutedText.withOpacity(0.35)),
          ),

          // -------------------------------------------------- 2. Itens Comprados
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXTRATO DOS ITENS',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: mutedText,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    countBadgeText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (receipt.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Text(
                'Nenhum item individual registrado neste cupom.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: mutedText),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
              child: Row(
                children: [
                  Text(
                    '#  DESCRIÇÃO / QTD × UNIT.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: mutedText.withOpacity(0.8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'VALOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: mutedText.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: receipt.items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: couponBorder,
              ),
              itemBuilder: (context, index) => _ReceiptCouponItemRow(
                index: index,
                item: receipt.items[index],
              ),
            ),
          ],

          // -------------------------------------------------- 3. Resumo Cupom
          Container(
            decoration: BoxDecoration(
              color: couponFooterBg,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              children: [
                _DashedDivider(color: mutedText.withOpacity(0.45)),
                const SizedBox(height: 14),
                _CouponFooterRow(
                  label: 'Qtd. Total de Itens',
                  value: '${receipt.items.length}',
                  labelStyle: TextStyle(fontSize: 13, color: mutedText),
                  valueStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _CouponFooterRow(
                  label: 'Subtotal (Valor Bruto)',
                  value: CurrencyFormatter.format(receipt.effectiveSubtotal),
                  labelStyle: TextStyle(fontSize: 13, color: mutedText),
                  valueStyle: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _CouponFooterRow(
                  label: 'Descontos',
                  value: hasAnyDiscount
                      ? '- ${CurrencyFormatter.format(receipt.discountTotal)}'
                      : CurrencyFormatter.format(0),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        hasAnyDiscount ? FontWeight.w600 : FontWeight.normal,
                    color: hasAnyDiscount ? AppColors.income : mutedText,
                  ),
                  valueStyle: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: hasAnyDiscount ? AppColors.income : mutedText,
                  ),
                ),
                const SizedBox(height: 14),
                _DashedDivider(color: mutedText.withOpacity(0.5)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'VALOR TOTAL PAGO',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(receipt.finalAmount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
                if (receipt.accessKey != null &&
                    receipt.accessKey!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DashedDivider(color: mutedText.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'CHAVE DE ACESSO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _formatAccessKey(receipt.accessKey!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: mutedText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAccessKey(String raw) {
    final digits = raw.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _CouponMetaChip extends StatelessWidget {
  const _CouponMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : scheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurface.withOpacity(0.7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCouponItemRow extends StatelessWidget {
  const _ReceiptCouponItemRow({
    required this.index,
    required this.item,
  });

  final int index;
  final ReceiptItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = scheme.onSurface.withOpacity(0.62);

    final unit = item.unit.isNotEmpty ? item.unit.toUpperCase() : 'UN';
    final qtyFormatted = item.quantity == item.quantity.truncateToDouble()
        ? item.quantity.toInt().toString()
        : (unit == 'KG'
            ? item.quantity.toStringAsFixed(3)
            : item.quantity.toStringAsFixed(2));
    final hasDiscount = item.discount > 0.005;
    final grossTotal = item.effectiveGrossTotal;
    final netTotal = item.netTotal;

    final badgeLabel = (index + 1).toString().padLeft(2, '0');
    final unitDetail = item.unitPrice > 0
        ? '$qtyFormatted $unit × ${CurrencyFormatter.format(item.unitPrice)}'
        : '$qtyFormatted $unit';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.primary.withOpacity(0.18)
                  : scheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.code != null && item.code!.isNotEmpty
                      ? '$unitDetail • Cód. ${item.code}'
                      : unitDetail,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasDiscount) ...[
                Text(
                  CurrencyFormatter.format(grossTotal),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  '- ${CurrencyFormatter.format(item.discount)} desc.',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.income,
                  ),
                ),
                const SizedBox(height: 1),
              ],
              Text(
                CurrencyFormatter.format(netTotal),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponFooterRow extends StatelessWidget {
  const _CouponFooterRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dashWidth).clamp(0.0, size.width), 0),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
