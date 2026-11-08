import 'package:flutter/material.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';

class CreditCardVisual extends StatelessWidget {
  const CreditCardVisual({
    super.key,
    required this.card,
    this.spent = 0.0,
    this.invoiceTotal = 0.0,
    this.showDetails = true,
    this.onTap,
  });

  final CreditCardItem card;
  final double spent;
  final double invoiceTotal;
  final bool showDetails;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baseColor = card.cardColor;
    final hsl = HSLColor.fromColor(baseColor);
    final darkerColor =
        hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final lighterColor =
        hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();

    final effectiveSpent = invoiceTotal > 0 ? invoiceTotal : spent;
    final available = card.availableLimit(effectiveSpent);
    final percent = card.limitUsedPercent(effectiveSpent);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [lighterColor, darkerColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Name & Card Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Icon(
                  Icons.credit_card,
                  color: Colors.white70,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (showDetails) ...[
              // Limit & Spent Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoiceTotal > 0 ? 'Fatura Total' : 'Fatura Atual',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(effectiveSpent),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Limite Disponível',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.limitAmount > 0
                            ? CurrencyFormatter.format(available)
                            : 'Sem limite',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (card.limitAmount > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    color: percent >= 100
                        ? Colors.redAccent.shade100
                        : percent >= 80
                            ? Colors.amberAccent
                            : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Dates: Closing and Due
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fecha dia ${card.closingDay}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Vence dia ${card.dueDay}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
