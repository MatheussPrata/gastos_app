package com.kuanto.gastos.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.os.Build
import com.kuanto.gastos.MainActivity
import org.json.JSONObject
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Locale
import kotlin.math.abs

object WidgetPrefs {
    private const val PREFS_NAME = "kuanto_widgets_prefs"
    private const val KEY_PAYLOAD = "widget_payload_json"
    private const val KEY_HIDE_VALUES = "widget_hide_values"
    private const val KEY_CHART_TYPE_PREFIX = "chart_type_"
    private const val KEY_CHART_PERIOD_PREFIX = "chart_period_"

    const val ACTION_WIDGET_LAUNCH = "com.kuanto.gastos.ACTION_WIDGET_LAUNCH"
    const val ACTION_TOGGLE_PRIVACY = "com.kuanto.gastos.ACTION_TOGGLE_WIDGET_PRIVACY"

    const val EXTRA_ROUTE = "widget_route"
    const val EXTRA_CHART_TYPE = "widget_chart_type"
    const val EXTRA_PERIOD = "widget_period"

    const val CHART_CATEGORIES = "categories"
    const val CHART_BALANCE = "balance"
    const val CHART_MONTHLY = "monthly"
    const val CHART_PAYMENT_METHODS = "payment_methods"
    const val CHART_CARDS = "cards"

    const val PERIOD_MONTH = "month"
    const val PERIOD_QUARTER = "quarter"
    const val PERIOD_YEAR = "year"

    private val brSymbols = DecimalFormatSymbols(Locale("pt", "BR")).apply {
        decimalSeparator = ','
        groupingSeparator = '.'
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun savePayload(context: Context, payloadJson: String) {
        prefs(context).edit().putString(KEY_PAYLOAD, payloadJson).apply()
    }

    fun getPayload(context: Context): JSONObject? {
        val raw = prefs(context).getString(KEY_PAYLOAD, null) ?: return null
        if (raw.isBlank()) return null
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            null
        }
    }

    fun isHideValues(context: Context): Boolean =
        prefs(context).getBoolean(KEY_HIDE_VALUES, false)

    fun setHideValues(context: Context, hide: Boolean) {
        prefs(context).edit().putBoolean(KEY_HIDE_VALUES, hide).apply()
    }

    fun toggleHideValues(context: Context): Boolean {
        val next = !isHideValues(context)
        setHideValues(context, next)
        return next
    }

    fun getChartType(context: Context, appWidgetId: Int): String {
        val value = prefs(context).getString(KEY_CHART_TYPE_PREFIX + appWidgetId, CHART_CATEGORIES)
        return when (value) {
            CHART_CATEGORIES,
            CHART_BALANCE,
            CHART_MONTHLY,
            CHART_PAYMENT_METHODS,
            CHART_CARDS -> value
            else -> CHART_CATEGORIES
        }
    }

    fun getChartPeriod(context: Context, appWidgetId: Int): String {
        val value = prefs(context).getString(KEY_CHART_PERIOD_PREFIX + appWidgetId, PERIOD_MONTH)
        return when (value) {
            PERIOD_MONTH, PERIOD_QUARTER, PERIOD_YEAR -> value
            else -> PERIOD_MONTH
        }
    }

    fun saveChartConfig(
        context: Context,
        appWidgetId: Int,
        chartType: String,
        period: String,
    ) {
        prefs(context).edit()
            .putString(KEY_CHART_TYPE_PREFIX + appWidgetId, chartType)
            .putString(KEY_CHART_PERIOD_PREFIX + appWidgetId, period)
            .apply()
    }

    fun deleteChartConfig(context: Context, appWidgetId: Int) {
        prefs(context).edit()
            .remove(KEY_CHART_TYPE_PREFIX + appWidgetId)
            .remove(KEY_CHART_PERIOD_PREFIX + appWidgetId)
            .apply()
    }

    fun resolveIsDark(context: Context, payload: JSONObject?): Boolean {
        return when (payload?.optString("themeMode")) {
            "dark" -> true
            "light" -> false
            else -> {
                val mask = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                mask == Configuration.UI_MODE_NIGHT_YES
            }
        }
    }

    fun resolvePrimaryColor(payload: JSONObject?): Int {
        if (payload != null && payload.has("primaryColor")) {
            val raw = payload.optLong("primaryColor", 0xFF2563EBL)
            if (raw != 0L) return raw.toInt()
        }
        return 0xFF2563EB.toInt()
    }

    fun formatBRL(value: Double, hideValues: Boolean = false): String {
        if (hideValues) return "R$ ••••"
        val formatter = DecimalFormat("#,##0.00", brSymbols)
        val formatted = formatter.format(abs(value))
        return if (value < -0.005) "-R$ $formatted" else "R$ $formatted"
    }

    fun formatCompactAxis(value: Double): String {
        if (abs(value) < 0.5) return "0"
        val sign = if (value < 0) "-" else ""
        val absVal = abs(value)
        if (absVal >= 1_000_000.0) {
            val formatted = String.format(Locale.US, "%.1f", absVal / 1_000_000.0)
                .replace(".0", "")
                .replace(".", ",")
            return "$sign${formatted}M"
        }
        if (absVal >= 10_000.0) {
            return "$sign${String.format(Locale.US, "%.0f", absVal / 1_000.0)}k"
        }
        if (absVal >= 1_000.0) {
            val formatted = String.format(Locale.US, "%.1f", absVal / 1_000.0)
                .replace(".0", "")
                .replace(".", ",")
            return "$sign${formatted}k"
        }
        return "$sign${String.format(Locale.US, "%.0f", absVal)}"
    }

    fun chartTypeTitle(chartType: String): String = when (chartType) {
        CHART_CATEGORIES -> "Gastos por categoria"
        CHART_BALANCE -> "Saldo ao longo do tempo"
        CHART_MONTHLY -> "Comparativo mensal"
        CHART_PAYMENT_METHODS -> "Formas de pagamento"
        CHART_CARDS -> "Gastos por cartão"
        else -> "Gastos por categoria"
    }

    fun periodDisplayLabel(period: String, periodObj: JSONObject?): String {
        val fromPayload = periodObj?.optString("periodLabel")
        if (!fromPayload.isNullOrBlank()) return fromPayload
        return when (period) {
            PERIOD_QUARTER -> "3 meses"
            PERIOD_YEAR -> "Ano"
            else -> "Mês"
        }
    }

    fun buildLaunchPendingIntent(
        context: Context,
        requestCode: Int,
        route: String,
        chartType: String? = null,
        period: String? = null,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_WIDGET_LAUNCH
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ROUTE, route)
            if (chartType != null) putExtra(EXTRA_CHART_TYPE, chartType)
            if (period != null) putExtra(EXTRA_PERIOD, period)
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(context, requestCode, intent, piFlags)
    }

    fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)

        val quickIds = manager.getAppWidgetIds(
            ComponentName(context, QuickAddWidgetProvider::class.java),
        )
        for (id in quickIds) {
            QuickAddWidgetProvider.updateWidget(context, manager, id)
        }

        val summaryIds = manager.getAppWidgetIds(
            ComponentName(context, MonthlySummaryWidgetProvider::class.java),
        )
        for (id in summaryIds) {
            MonthlySummaryWidgetProvider.updateWidget(context, manager, id)
        }

        val chartIds = manager.getAppWidgetIds(
            ComponentName(context, ChartWidgetProvider::class.java),
        )
        for (id in chartIds) {
            ChartWidgetProvider.updateWidget(context, manager, id)
        }

        val billIds = manager.getAppWidgetIds(
            ComponentName(context, UpcomingBillsWidgetProvider::class.java),
        )
        for (id in billIds) {
            UpcomingBillsWidgetProvider.updateWidget(context, manager, id)
        }
    }
}
