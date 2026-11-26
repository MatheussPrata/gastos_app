package com.kuanto.gastos.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

object WidgetChartRenderer {

    private const val MAX_BITMAP_BYTES = 560_000 // < 1 MB limite do Binder IPC (RGB_565 = 2 B/px)
    private const val COLOR_BG_LIGHT = 0xFFFFFFFF.toInt()
    private const val COLOR_BG_DARK = 0xFF121B2B.toInt()
    private const val COLOR_INCOME = 0xFF43A047.toInt()
    private const val COLOR_INCOME_DARK = 0xFF4ADE80.toInt()
    private const val COLOR_EXPENSE = 0xFFE53935.toInt()
    private const val COLOR_EXPENSE_DARK = 0xFFF87171.toInt()
    private const val COLOR_WARNING = 0xFFF59E0B.toInt()

    fun render(
        context: Context,
        payload: JSONObject?,
        chartType: String,
        period: String,
        widthDp: Int,
        heightDp: Int,
        isDark: Boolean,
        primaryColor: Int,
        hideValues: Boolean,
    ): Bitmap {
        val density = context.resources.displayMetrics.density.coerceIn(1.5f, 3.0f)
        val rawW = (max(widthDp, 220) * density).roundToInt()
        val rawH = (max(heightDp, 140) * density).roundToInt()

        val pixelBudget = MAX_BITMAP_BYTES / 2.0
        val currentPixels = rawW.toDouble() * rawH.toDouble()
        val scale = if (currentPixels > pixelBudget) sqrt(pixelBudget / currentPixels) else 1.0
        val pxW = max(240, (rawW * scale).roundToInt())
        val pxH = max(140, (rawH * scale).roundToInt())

        val bitmap = Bitmap.createBitmap(pxW, pxH, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        val bgColor = if (isDark) COLOR_BG_DARK else COLOR_BG_LIGHT
        canvas.drawColor(bgColor)

        val unit = min(pxW / 320f, pxH / 180f).coerceIn(0.85f, 2.6f)
        val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF0F172A.toInt()
        val textSecondary = if (isDark) 0xFF94A3B8.toInt() else 0xFF64748B.toInt()
        val gridColor = if (isDark) 0x3394A3B8 else 0x2664748B

        if (payload == null || !payload.optBoolean("authenticated", false)) {
            drawEmptyMessage(
                canvas,
                pxW,
                pxH,
                unit,
                textSecondary,
                "Entre no Kuanto para ver seus gráficos",
            )
            return bitmap
        }

        val chartsObj = payload.optJSONObject("charts")
        val periodObj = chartsObj?.optJSONObject(period) ?: chartsObj?.optJSONObject(WidgetPrefs.PERIOD_MONTH)
        if (periodObj == null) {
            drawEmptyMessage(canvas, pxW, pxH, unit, textSecondary, "Sem dados sincronizados ainda")
            return bitmap
        }

        when (chartType) {
            WidgetPrefs.CHART_CATEGORIES -> drawCategoriesDonut(
                canvas = canvas,
                w = pxW,
                h = pxH,
                unit = unit,
                periodObj = periodObj,
                bgColor = bgColor,
                textPrimary = textPrimary,
                textSecondary = textSecondary,
                hideValues = hideValues,
            )
            WidgetPrefs.CHART_BALANCE -> drawBalanceLine(
                canvas = canvas,
                w = pxW,
                h = pxH,
                unit = unit,
                periodObj = periodObj,
                isDark = isDark,
                primaryColor = primaryColor,
                textPrimary = textPrimary,
                textSecondary = textSecondary,
                gridColor = gridColor,
                hideValues = hideValues,
            )
            WidgetPrefs.CHART_MONTHLY -> drawMonthlyComparison(
                canvas = canvas,
                w = pxW,
                h = pxH,
                unit = unit,
                periodObj = periodObj,
                isDark = isDark,
                textPrimary = textPrimary,
                textSecondary = textSecondary,
                gridColor = gridColor,
                hideValues = hideValues,
            )
            WidgetPrefs.CHART_PAYMENT_METHODS -> drawPaymentMethods(
                canvas = canvas,
                w = pxW,
                h = pxH,
                unit = unit,
                periodObj = periodObj,
                textPrimary = textPrimary,
                textSecondary = textSecondary,
                trackColor = gridColor,
                hideValues = hideValues,
            )
            WidgetPrefs.CHART_CARDS -> drawCardsUsage(
                canvas = canvas,
                w = pxW,
                h = pxH,
                unit = unit,
                periodObj = periodObj,
                isDark = isDark,
                textPrimary = textPrimary,
                textSecondary = textSecondary,
                trackColor = gridColor,
                hideValues = hideValues,
            )
            else -> drawCategoriesDonut(
                canvas = canvas,
                w = pxW,
                h = pxH,
                unit = unit,
                periodObj = periodObj,
                bgColor = bgColor,
                textPrimary = textPrimary,
                textSecondary = textSecondary,
                hideValues = hideValues,
            )
        }

        return bitmap
    }

    private fun drawEmptyMessage(
        canvas: Canvas,
        w: Int,
        h: Int,
        unit: Float,
        textColor: Int,
        message: String,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor
            textSize = 13f * unit
            textAlign = Paint.Align.CENTER
        }
        val y = h / 2f - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(message, w / 2f, y, paint)
    }

    private fun drawCategoriesDonut(
        canvas: Canvas,
        w: Int,
        h: Int,
        unit: Float,
        periodObj: JSONObject,
        bgColor: Int,
        textPrimary: Int,
        textSecondary: Int,
        hideValues: Boolean,
    ) {
        val items = periodObj.optJSONArray("categories") ?: JSONArray()
        val total = periodObj.optDouble("categoriesTotal", 0.0)
        if (items.length() == 0 || total <= 0.0) {
            drawEmptyMessage(canvas, w, h, unit, textSecondary, "Nenhum gasto registrado neste período")
            return
        }

        val pad = 8f * unit
        val donutDiameter = min(w * 0.42f, h - pad * 2f)
        val radius = donutDiameter / 2f
        val cx = pad + radius
        val cy = h / 2f
        val oval = RectF(cx - radius, cy - radius, cx + radius, cy + radius)

        val slicePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        var startAngle = -90f
        for (i in 0 until items.length()) {
            val item = items.optJSONObject(i) ?: continue
            val value = item.optDouble("total", 0.0)
            if (value <= 0.0) continue
            val sweep = ((value / total) * 360.0).toFloat()
            val gap = if (items.length() > 1 && sweep > 4f) 1.6f else 0f
            slicePaint.color = item.optLong("color", 0xFF2563EBL).toInt()
            canvas.drawArc(oval, startAngle, max(1f, sweep - gap), true, slicePaint)
            startAngle += sweep
        }

        // Centro vazado (rosca)
        val holePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = bgColor
            style = Paint.Style.FILL
        }
        canvas.drawCircle(cx, cy, radius * 0.58f, holePaint)

        // Texto no centro do donut
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textSecondary
            textSize = 9.5f * unit
            textAlign = Paint.Align.CENTER
        }
        val totalPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textPrimary
            textSize = if (hideValues) 11f * unit else 10.5f * unit
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val totalStr = if (hideValues) "••••" else WidgetPrefs.formatBRL(total, false)
        canvas.drawText("Total", cx, cy - 3f * unit, labelPaint)
        canvas.drawText(
            truncateText(totalStr, totalPaint, radius * 1.06f),
            cx,
            cy + 11f * unit,
            totalPaint,
        )

        // Legenda à direita (top 5)
        val legendLeft = cx + radius + 12f * unit
        val legendRight = w - pad
        if (legendRight - legendLeft < 70f * unit) return

        val maxItems = min(5, items.length())
        val rowHeight = min(28f * unit, (h - pad * 2f) / maxItems)
        val startY = (h - rowHeight * maxItems) / 2f + rowHeight / 2f

        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textPrimary
            textSize = 11f * unit
        }
        val valPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textSecondary
            textSize = 10.5f * unit
            textAlign = Paint.Align.RIGHT
        }

        for (i in 0 until maxItems) {
            val item = items.optJSONObject(i) ?: continue
            val name = item.optString("name", "Outros")
            val amount = item.optDouble("total", 0.0)
            val color = item.optLong("color", 0xFF94A3B8L).toInt()
            val pct = ((amount / total) * 100.0).roundToInt()
            val rightText = if (hideValues) "$pct%" else "${WidgetPrefs.formatCompactAxis(amount)} · $pct%"
            val rightW = valPaint.measureText(rightText)

            val y = startY + i * rowHeight
            dotPaint.color = color
            canvas.drawCircle(legendLeft + 4f * unit, y - 3f * unit, 4f * unit, dotPaint)

            val availableNameW = max(20f, legendRight - (legendLeft + 13f * unit) - rightW - 6f * unit)
            val truncatedName = truncateText(name, namePaint, availableNameW)
            canvas.drawText(truncatedName, legendLeft + 13f * unit, y, namePaint)
            canvas.drawText(rightText, legendRight, y, valPaint)
        }
    }

    private fun drawBalanceLine(
        canvas: Canvas,
        w: Int,
        h: Int,
        unit: Float,
        periodObj: JSONObject,
        isDark: Boolean,
        primaryColor: Int,
        textPrimary: Int,
        textSecondary: Int,
        gridColor: Int,
        hideValues: Boolean,
    ) {
        val series = periodObj.optJSONArray("balanceSeries") ?: JSONArray()
        if (series.length() == 0) {
            drawEmptyMessage(canvas, w, h, unit, textSecondary, "Sem lançamentos no período")
            return
        }

        val values = ArrayList<Double>(series.length())
        val labels = ArrayList<String>(series.length())
        for (i in 0 until series.length()) {
            val pt = series.optJSONObject(i) ?: continue
            values.add(pt.optDouble("value", 0.0))
            labels.add(pt.optString("label", ""))
        }
        if (values.isEmpty()) {
            drawEmptyMessage(canvas, w, h, unit, textSecondary, "Sem lançamentos no período")
            return
        }

        val minRaw = values.minOrNull() ?: 0.0
        val maxRaw = values.maxOrNull() ?: 0.0
        val span = maxRaw - minRaw
        val padVal = if (span == 0.0) max(kotlin.math.abs(maxRaw) * 0.2, 10.0) else span * 0.18
        val minY = minRaw - padVal
        val maxY = maxRaw + padVal

        val axisLeft = if (hideValues) 14f * unit else 44f * unit
        val chartTop = 22f * unit
        val chartRight = w - 12f * unit
        val chartBottom = h - 22f * unit
        val chartW = max(40f, chartRight - axisLeft)
        val chartH = max(40f, chartBottom - chartTop)

        // Saldo atual no topo direito
        val lastBalance = values.last()
        val incomeColor = if (isDark) COLOR_INCOME_DARK else COLOR_INCOME
        val expenseColor = if (isDark) COLOR_EXPENSE_DARK else COLOR_EXPENSE
        val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (lastBalance >= 0) incomeColor else expenseColor
            textSize = 11.5f * unit
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.RIGHT
        }
        canvas.drawText(
            "Saldo: ${WidgetPrefs.formatBRL(lastBalance, hideValues)}",
            chartRight,
            13f * unit,
            badgePaint,
        )

        // Grade horizontal + eixo Y
        val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = gridColor
            strokeWidth = 1f * unit
        }
        val axisPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textSecondary
            textSize = 9.5f * unit
            textAlign = Paint.Align.RIGHT
        }
        for (step in 0..3) {
            val ratio = step / 3f
            val y = chartBottom - ratio * chartH
            canvas.drawLine(axisLeft, y, chartRight, y, gridPaint)
            if (!hideValues) {
                val valAt = minY + (maxY - minY) * ratio
                canvas.drawText(
                    WidgetPrefs.formatCompactAxis(valAt),
                    axisLeft - 5f * unit,
                    y + 3f * unit,
                    axisPaint,
                )
            }
        }

        // Linha do zero tracejada
        if (minY < 0.0 && maxY > 0.0) {
            val zeroY = chartBottom - ((0.0 - minY) / (maxY - minY)).toFloat() * chartH
            val zeroPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = textSecondary
                alpha = 140
                strokeWidth = 1f * unit
                pathEffect = DashPathEffect(floatArrayOf(5f * unit, 4f * unit), 0f)
            }
            canvas.drawLine(axisLeft, zeroY, chartRight, zeroY, zeroPaint)
        }

        val linePath = Path()
        val areaPath = Path()
        val xs = FloatArray(values.size)
        val ys = FloatArray(values.size)

        for (i in values.indices) {
            val x = if (values.size == 1) {
                axisLeft + chartW / 2f
            } else {
                axisLeft + (i.toFloat() / (values.size - 1)) * chartW
            }
            val y = chartBottom - (((values[i] - minY) / (maxY - minY)).toFloat() * chartH)
            xs[i] = x
            ys[i] = y
            if (i == 0) {
                linePath.moveTo(x, y)
                areaPath.moveTo(x, chartBottom)
                areaPath.lineTo(x, y)
            } else {
                val prevX = xs[i - 1]
                val prevY = ys[i - 1]
                val midX = (prevX + x) / 2f
                linePath.cubicTo(midX, prevY, midX, y, x, y)
                areaPath.cubicTo(midX, prevY, midX, y, x, y)
            }
        }
        areaPath.lineTo(xs.last(), chartBottom)
        areaPath.close()

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            shader = LinearGradient(
                0f,
                chartTop,
                0f,
                chartBottom,
                (primaryColor and 0x00FFFFFF) or 0x44000000,
                (primaryColor and 0x00FFFFFF) or 0x00000000,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawPath(areaPath, fillPaint)

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = primaryColor
            style = Paint.Style.STROKE
            strokeWidth = 2.5f * unit
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(linePath, strokePaint)

        // Pontos quando série curta + último ponto destacado
        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        if (values.size <= 14) {
            for (i in values.indices) {
                dotPaint.color = if (values[i] >= 0) incomeColor else expenseColor
                canvas.drawCircle(xs[i], ys[i], 2.8f * unit, dotPaint)
            }
        } else {
            dotPaint.color = if (lastBalance >= 0) incomeColor else expenseColor
            canvas.drawCircle(xs.last(), ys.last(), 3.6f * unit, dotPaint)
        }

        // Eixo X
        val xPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textSecondary
            textSize = 9.5f * unit
            textAlign = Paint.Align.CENTER
        }
        val step = max(1, (values.size + 4) / 5)
        for (i in values.indices) {
            if (i % step == 0 || i == values.size - 1) {
                canvas.drawText(labels[i], xs[i], h - 6f * unit, xPaint)
            }
        }
    }

    private fun drawMonthlyComparison(
        canvas: Canvas,
        w: Int,
        h: Int,
        unit: Float,
        periodObj: JSONObject,
        isDark: Boolean,
        textPrimary: Int,
        textSecondary: Int,
        gridColor: Int,
        hideValues: Boolean,
    ) {
        val items = periodObj.optJSONArray("monthlyComparison") ?: JSONArray()
        if (items.length() == 0) {
            drawEmptyMessage(canvas, w, h, unit, textSecondary, "Sem histórico mensal neste período")
            return
        }

        val incomeColor = if (isDark) COLOR_INCOME_DARK else COLOR_INCOME
        val expenseColor = if (isDark) COLOR_EXPENSE_DARK else COLOR_EXPENSE

        // Legenda superior direita
        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val legendPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textPrimary
            textSize = 10f * unit
        }
        val expLabelW = legendPaint.measureText("Saídas")
        val expX = w - 12f * unit - expLabelW
        val incLabelW = legendPaint.measureText("Entradas")
        val incX = expX - 18f * unit - incLabelW

        dotPaint.color = incomeColor
        canvas.drawCircle(incX - 6f * unit, 10f * unit, 3.5f * unit, dotPaint)
        canvas.drawText("Entradas", incX, 13f * unit, legendPaint)

        dotPaint.color = expenseColor
        canvas.drawCircle(expX - 6f * unit, 10f * unit, 3.5f * unit, dotPaint)
        canvas.drawText("Saídas", expX, 13f * unit, legendPaint)

        var maxVal = 0.0
        for (i in 0 until items.length()) {
            val item = items.optJSONObject(i) ?: continue
            maxVal = max(maxVal, max(item.optDouble("income", 0.0), item.optDouble("expense", 0.0)))
        }
        if (maxVal <= 0.0) {
            drawEmptyMessage(canvas, w, h, unit, textSecondary, "Sem movimentações neste período")
            return
        }

        val maxY = maxVal * 1.15
        val axisLeft = if (hideValues) 14f * unit else 44f * unit
        val chartTop = 22f * unit
        val chartRight = w - 10f * unit
        val chartBottom = h - 22f * unit
        val chartW = max(40f, chartRight - axisLeft)
        val chartH = max(40f, chartBottom - chartTop)

        val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = gridColor
            strokeWidth = 1f * unit
        }
        val axisPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textSecondary
            textSize = 9.5f * unit
            textAlign = Paint.Align.RIGHT
        }
        for (step in 0..3) {
            val ratio = step / 3f
            val y = chartBottom - ratio * chartH
            canvas.drawLine(axisLeft, y, chartRight, y, gridPaint)
            if (!hideValues && step > 0) {
                canvas.drawText(
                    WidgetPrefs.formatCompactAxis(maxY * ratio),
                    axisLeft - 5f * unit,
                    y + 3f * unit,
                    axisPaint,
                )
            }
        }

        val n = items.length()
        val groupW = chartW / n
        val barW = min(14f * unit, max(3.5f * unit, groupW * 0.28f))
        val gap = min(4f * unit, barW * 0.35f)
        val xPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textSecondary
            textSize = if (n <= 6) 10f * unit else 8.5f * unit
            textAlign = Paint.Align.CENTER
        }
        val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val corner = min(3.5f * unit, barW / 2f)

        for (i in 0 until n) {
            val item = items.optJSONObject(i) ?: continue
            val inc = item.optDouble("income", 0.0)
            val exp = item.optDouble("expense", 0.0)
            val label = item.optString("label", "")
            val centerX = axisLeft + groupW * (i + 0.5f)

            val incH = ((inc / maxY) * chartH).toFloat()
            if (incH > 1f) {
                barPaint.color = incomeColor
                val left = centerX - gap / 2f - barW
                canvas.drawRoundRect(
                    RectF(left, chartBottom - incH, left + barW, chartBottom),
                    corner,
                    corner,
                    barPaint,
                )
            }

            val expH = ((exp / maxY) * chartH).toFloat()
            if (expH > 1f) {
                barPaint.color = expenseColor
                val left = centerX + gap / 2f
                canvas.drawRoundRect(
                    RectF(left, chartBottom - expH, left + barW, chartBottom),
                    corner,
                    corner,
                    barPaint,
                )
            }

            if (n <= 8 || i % 2 == 0 || i == n - 1) {
                canvas.drawText(label, centerX, h - 6f * unit, xPaint)
            }
        }
    }

    private fun drawPaymentMethods(
        canvas: Canvas,
        w: Int,
        h: Int,
        unit: Float,
        periodObj: JSONObject,
        textPrimary: Int,
        textSecondary: Int,
        trackColor: Int,
        hideValues: Boolean,
    ) {
        val items = periodObj.optJSONArray("paymentMethods") ?: JSONArray()
        val total = periodObj.optDouble("paymentTotal", 0.0)
        if (items.length() == 0 || total <= 0.0) {
            drawEmptyMessage(canvas, w, h, unit, textSecondary, "Sem gastos neste período")
            return
        }

        val pad = 10f * unit
        val barLeft = pad
        val barRight = w - pad
        val barW = barRight - barLeft
        val barTop = 6f * unit
        val barH = 10f * unit

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = trackColor }
        canvas.drawRoundRect(
            RectF(barLeft, barTop, barRight, barTop + barH),
            5f * unit,
            5f * unit,
            trackPaint,
        )

        val segPath = Path().apply {
            addRoundRect(
                RectF(barLeft, barTop, barRight, barTop + barH),
                5f * unit,
                5f * unit,
                Path.Direction.CW,
            )
        }
        canvas.save()
        canvas.clipPath(segPath)
        val segPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        var cursorX = barLeft
        for (i in 0 until items.length()) {
            val item = items.optJSONObject(i) ?: continue
            val valAmt = item.optDouble("total", 0.0)
            if (valAmt <= 0.0) continue
            val segW = if (i == items.length() - 1) barRight - cursorX else ((valAmt / total) * barW).toFloat()
            segPaint.color = item.optLong("color", 0xFF78909CL).toInt()
            canvas.drawRect(cursorX, barTop, cursorX + segW, barTop + barH, segPaint)
            cursorX += segW
        }
        canvas.restore()

        val maxRows = min(5, items.length())
        val listTop = barTop + barH + 14f * unit
        val rowHeight = min(30f * unit, (h - listTop - 4f * unit) / maxRows)

        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textPrimary
            textSize = 11.5f * unit
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val countPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textSecondary
            textSize = 10f * unit
        }
        val amtPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textPrimary
            textSize = 11.5f * unit
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.RIGHT
        }

        for (i in 0 until maxRows) {
            val item = items.optJSONObject(i) ?: continue
            val method = item.optString("method", "Outro")
            val amount = item.optDouble("total", 0.0)
            val count = item.optInt("count", 0)
            val color = item.optLong("color", 0xFF78909CL).toInt()
            val pct = ((amount / total) * 100.0).roundToInt()

            val y = listTop + i * rowHeight + 10f * unit
            dotPaint.color = color
            canvas.drawCircle(pad + 5f * unit, y - 3f * unit, 4.5f * unit, dotPaint)

            val rightText = if (hideValues) "$pct%" else "${WidgetPrefs.formatBRL(amount, false)} · $pct%"
            val rightW = amtPaint.measureText(rightText)
            val nameMaxW = max(30f, barRight - (pad + 16f * unit) - rightW - 8f * unit)
            val countText = if (count == 1) " (1)" else " ($count)"
            val fullName = truncateText(method, titlePaint, nameMaxW - countPaint.measureText(countText))
            canvas.drawText(fullName, pad + 16f * unit, y, titlePaint)
            canvas.drawText(
                countText,
                pad + 16f * unit + titlePaint.measureText(fullName),
                y,
                countPaint,
            )
            canvas.drawText(rightText, barRight, y, amtPaint)
        }
    }

    private fun drawCardsUsage(
        canvas: Canvas,
        w: Int,
        h: Int,
        unit: Float,
        periodObj: JSONObject,
        isDark: Boolean,
        textPrimary: Int,
        textSecondary: Int,
        trackColor: Int,
        hideValues: Boolean,
    ) {
        val items = periodObj.optJSONArray("cards") ?: JSONArray()
        if (items.length() == 0) {
            drawEmptyMessage(canvas, w, h, unit, textSecondary, "Sem gastos em cartões neste período")
            return
        }

        var totalCardsSpent = 0.0
        for (i in 0 until items.length()) {
            totalCardsSpent += items.optJSONObject(i)?.optDouble("spent", 0.0) ?: 0.0
        }

        val pad = 10f * unit
        val maxRows = min(4, items.length())
        val availH = h - pad
        val rowHeight = min(42f * unit, availH / maxRows)
        val expenseColor = if (isDark) COLOR_EXPENSE_DARK else COLOR_EXPENSE
        val incomeColor = if (isDark) COLOR_INCOME_DARK else COLOR_INCOME

        val namePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textPrimary
            textSize = 11.5f * unit
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val valPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textPrimary
            textSize = 11.5f * unit
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.RIGHT
        }
        val subPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 9.5f * unit
        }
        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = trackColor }
        val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)

        for (i in 0 until maxRows) {
            val item = items.optJSONObject(i) ?: continue
            val name = item.optString("name", "Cartão")
            val spent = item.optDouble("spent", 0.0)
            val limit = item.optDouble("limit", 0.0)
            val isPaid = item.optBoolean("isPaid", false)
            val cardColor = item.optLong("color", 0xFF7E57C2L).toInt()

            val hasLimit = limit > 0.0
            val ratio = if (hasLimit) {
                (spent / limit).toFloat()
            } else if (totalCardsSpent > 0.0) {
                (spent / totalCardsSpent).toFloat()
            } else {
                0f
            }
            val barColor = when {
                hasLimit && ratio >= 1.0f -> expenseColor
                hasLimit && ratio >= 0.8f -> COLOR_WARNING
                else -> cardColor
            }

            val top = 6f * unit + i * rowHeight
            val pct = (ratio * 100f).roundToInt()
            val paidSuffix = if (isPaid) " · Paga" else ""
            val subText = if (hasLimit) {
                if (hideValues) "$pct% do limite$paidSuffix"
                else "$pct% de ${WidgetPrefs.formatBRL(limit, false)}$paidSuffix"
            } else {
                "$pct% dos gastos em cartão"
            }

            val amtText = WidgetPrefs.formatBRL(spent, hideValues)
            val rightW = valPaint.measureText(amtText)
            val nameMaxW = max(40f, w - pad * 2f - rightW - 8f * unit)

            canvas.drawText(truncateText(name, namePaint, nameMaxW), pad, top + 11f * unit, namePaint)
            canvas.drawText(amtText, w - pad, top + 11f * unit, valPaint)

            val barY = top + 16f * unit
            val barH = 5.5f * unit
            val barRight = w - pad
            canvas.drawRoundRect(
                RectF(pad, barY, barRight, barY + barH),
                3f * unit,
                3f * unit,
                trackPaint,
            )
            val fillW = (barRight - pad) * ratio.coerceIn(0f, 1f)
            if (fillW > 1f) {
                barPaint.color = barColor
                canvas.drawRoundRect(
                    RectF(pad, barY, pad + fillW, barY + barH),
                    3f * unit,
                    3f * unit,
                    barPaint,
                )
            }

            subPaint.color = when {
                isPaid -> incomeColor
                hasLimit && ratio >= 0.8f -> barColor
                else -> textSecondary
            }
            canvas.drawText(
                truncateText(subText, subPaint, w - pad * 2f),
                pad,
                barY + barH + 10.5f * unit,
                subPaint,
            )
        }
    }

    private fun truncateText(text: String, paint: Paint, maxWidth: Float): String {
        if (maxWidth <= 0f) return ""
        if (paint.measureText(text) <= maxWidth) return text
        val ellipsis = "…"
        val ellW = paint.measureText(ellipsis)
        if (ellW >= maxWidth) return ""
        var end = text.length
        while (end > 0 && paint.measureText(text, 0, end) + ellW > maxWidth) {
            end--
        }
        return if (end <= 0) ellipsis else text.substring(0, end) + ellipsis
    }
}
