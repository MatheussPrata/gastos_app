import 'package:flutter/material.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';

class CreditCardVisual extends StatelessWidget {
  const CreditCardVisual({
    super.key,
    required this.card,
    this.spent = 0.0,
    this.showDetails = true,
    this.onTap,
  });

  final CreditCardItem card;
  final double spent;
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

    final available = card.availableLimit(spent);
    final percent = card.limitUsedPercent(spent);

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
            // Header: Name & Brand
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
                Text(
                  card.brand.isNotEmpty ? card.brand.toUpperCase() : 'CARTÃO',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chip and Digits
            Row(
              children: [
                Container(
                  width: 34,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade300,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade600, width: 0.8),
                  ),
                  child: const Center(
                    child: Icon(Icons.memory, size: 16, color: Colors.black54),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  card.lastFourDigits.isNotEmpty
                      ? '•••• •••• •••• ${card.lastFourDigits}'
                      : '•••• •••• •••• ••••',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  ),
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
                        'Fatura Atual',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(spent),
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
                const SizedBox(height: 6),
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
