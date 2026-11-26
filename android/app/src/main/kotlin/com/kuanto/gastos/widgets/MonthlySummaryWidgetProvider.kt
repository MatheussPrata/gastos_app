package com.kuanto.gastos.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.kuanto.gastos.R
import kotlin.math.roundToInt

class MonthlySummaryWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WidgetPrefs.ACTION_TOGGLE_PRIVACY) {
            WidgetPrefs.toggleHideValues(context)
            WidgetPrefs.updateAllWidgets(context)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val payload = WidgetPrefs.getPayload(context)
            val isDark = WidgetPrefs.resolveIsDark(context, payload)
            val hideValues = WidgetPrefs.isHideValues(context)
            val authenticated = payload?.optBoolean("authenticated", false) == true

            val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF0F172A.toInt()
            val textSecondary = if (isDark) 0xFF94A3B8.toInt() else 0xFF64748B.toInt()
            val incomeColor = if (isDark) 0xFF4ADE80.toInt() else 0xFF43A047.toInt()
            val expenseColor = if (isDark) 0xFFF87171.toInt() else 0xFFE53935.toInt()

            val views = RemoteViews(context.packageName, R.layout.widget_monthly_summary)
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_bg_dark else R.drawable.widget_bg_light,
            )
            views.setInt(
                R.id.btn_toggle_privacy,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_icon_btn_dark else R.drawable.widget_icon_btn_light,
            )
            views.setImageViewResource(
                R.id.btn_toggle_privacy,
                if (hideValues) R.drawable.ic_widget_visibility_off else R.drawable.ic_widget_visibility,
            )
            views.setInt(R.id.btn_toggle_privacy, "setColorFilter", textSecondary)

            views.setTextColor(R.id.tv_summary_month, textSecondary)
            views.setTextColor(R.id.tv_summary_balance_label, textSecondary)
            views.setTextColor(R.id.tv_summary_income_label, textSecondary)
            views.setTextColor(R.id.tv_summary_expense_label, textSecondary)
            views.setTextColor(R.id.tv_budget_label, textSecondary)
            views.setTextColor(R.id.tv_budget_text, textPrimary)
            views.setTextColor(R.id.tv_summary_footer, textSecondary)

            val summary = payload?.optJSONObject("summary")
            if (!authenticated || summary == null) {
                views.setTextViewText(R.id.tv_summary_month, "Kuanto")
                views.setTextViewText(R.id.tv_summary_balance, "Entre no app")
                views.setTextColor(R.id.tv_summary_balance, textPrimary)
                views.setTextViewText(R.id.tv_summary_income, "—")
                views.setTextColor(R.id.tv_summary_income, textSecondary)
                views.setTextViewText(R.id.tv_summary_expense, "—")
                views.setTextColor(R.id.tv_summary_expense, textSecondary)
                views.setViewVisibility(R.id.layout_budget_section, View.GONE)
                views.setTextViewText(R.id.tv_summary_footer, "Toque para entrar na sua conta")
            } else {
                val monthLabel = summary.optString("monthLabel", "Mês atual")
                val income = summary.optDouble("income", 0.0)
                val expense = summary.optDouble("expense", 0.0)
                val balance = summary.optDouble("balance", income - expense)
                val budgetTotal = summary.optDouble("budgetTotal", 0.0)
                val budgetSpent = summary.optDouble("budgetSpent", 0.0)

                views.setTextViewText(R.id.tv_summary_month, monthLabel)
                views.setTextViewText(
                    R.id.tv_summary_balance,
                    WidgetPrefs.formatBRL(balance, hideValues),
                )
                views.setTextColor(
                    R.id.tv_summary_balance,
                    if (balance >= 0.0) incomeColor else expenseColor,
                )
                views.setTextViewText(
                    R.id.tv_summary_income,
                    WidgetPrefs.formatBRL(income, hideValues),
                )
                views.setTextColor(R.id.tv_summary_income, incomeColor)
                views.setTextViewText(
                    R.id.tv_summary_expense,
                    WidgetPrefs.formatBRL(expense, hideValues),
                )
                views.setTextColor(R.id.tv_summary_expense, expenseColor)

                if (budgetTotal > 0.0) {
                    val pct = ((budgetSpent / budgetTotal) * 100.0).roundToInt()
                    val clamped = pct.coerceIn(0, 100)
                    views.setViewVisibility(R.id.layout_budget_section, View.VISIBLE)
                    val budgetLabel = if (hideValues) {
                        "$pct% do orçamento"
                    } else {
                        "${WidgetPrefs.formatCompactAxis(budgetSpent)} / ${WidgetPrefs.formatCompactAxis(budgetTotal)} ($pct%)"
                    }
                    views.setTextViewText(R.id.tv_budget_text, budgetLabel)

                    views.setViewVisibility(R.id.progress_budget_green, View.GONE)
                    views.setViewVisibility(R.id.progress_budget_amber, View.GONE)
                    views.setViewVisibility(R.id.progress_budget_red, View.GONE)

                    val activeBarId = when {
                        pct >= 100 -> R.id.progress_budget_red
                        pct >= 80 -> R.id.progress_budget_amber
                        else -> R.id.progress_budget_green
                    }
                    views.setViewVisibility(activeBarId, View.VISIBLE)
                    views.setProgressBar(activeBarId, 100, clamped, false)
                } else {
                    views.setViewVisibility(R.id.layout_budget_section, View.GONE)
                }

                views.setTextViewText(
                    R.id.tv_summary_footer,
                    if (hideValues) "Valores ocultos • toque para abrir" else "Toque para abrir o Kuanto",
                )
            }

            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetPrefs.buildLaunchPendingIntent(context, 2001, "dashboard"),
            )
            views.setOnClickPendingIntent(
                R.id.btn_summary_add,
                WidgetPrefs.buildLaunchPendingIntent(context, 2002, "add_expense"),
            )

            val toggleIntent = Intent(context, MonthlySummaryWidgetProvider::class.java).apply {
                action = WidgetPrefs.ACTION_TOGGLE_PRIVACY
            }
            val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val togglePi = PendingIntent.getBroadcast(context, 2003, toggleIntent, piFlags)
            views.setOnClickPendingIntent(R.id.btn_toggle_privacy, togglePi)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
