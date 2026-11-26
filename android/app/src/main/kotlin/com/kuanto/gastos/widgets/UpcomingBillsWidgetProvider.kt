package com.kuanto.gastos.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.kuanto.gastos.R
import org.json.JSONArray
import kotlin.math.min

class UpcomingBillsWidgetProvider : AppWidgetProvider() {

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
        private val rowIds = intArrayOf(
            R.id.row_bill_1,
            R.id.row_bill_2,
            R.id.row_bill_3,
            R.id.row_bill_4,
        )
        private val dotIds = intArrayOf(
            R.id.dot_bill_1,
            R.id.dot_bill_2,
            R.id.dot_bill_3,
            R.id.dot_bill_4,
        )
        private val titleIds = intArrayOf(
            R.id.tv_bill_title_1,
            R.id.tv_bill_title_2,
            R.id.tv_bill_title_3,
            R.id.tv_bill_title_4,
        )
        private val dueIds = intArrayOf(
            R.id.tv_bill_due_1,
            R.id.tv_bill_due_2,
            R.id.tv_bill_due_3,
            R.id.tv_bill_due_4,
        )
        private val amountIds = intArrayOf(
            R.id.tv_bill_amount_1,
            R.id.tv_bill_amount_2,
            R.id.tv_bill_amount_3,
            R.id.tv_bill_amount_4,
        )

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
            val accentColor = if (isDark) 0xFF60A5FA.toInt() else WidgetPrefs.resolvePrimaryColor(payload)
            val incomeColor = if (isDark) 0xFF4ADE80.toInt() else 0xFF43A047.toInt()
            val expenseColor = if (isDark) 0xFFF87171.toInt() else 0xFFE53935.toInt()

            val views = RemoteViews(context.packageName, R.layout.widget_upcoming_bills)
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_bg_dark else R.drawable.widget_bg_light,
            )
            views.setTextColor(R.id.tv_bills_title, textPrimary)
            views.setInt(
                R.id.tv_bills_total,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_chip_dark else R.drawable.widget_chip_light,
            )
            views.setTextColor(R.id.tv_bills_total, accentColor)
            views.setTextColor(R.id.tv_bills_empty, textSecondary)

            for (rowId in rowIds) {
                views.setViewVisibility(rowId, View.GONE)
            }

            if (!authenticated || payload == null) {
                views.setViewVisibility(R.id.tv_bills_total, View.GONE)
                views.setViewVisibility(R.id.tv_bills_empty, View.VISIBLE)
                views.setTextViewText(R.id.tv_bills_empty, "Entre no Kuanto para acompanhar vencimentos")
            } else {
                val bills = payload.optJSONArray("upcomingBills") ?: JSONArray()
                val total = payload.optDouble("upcomingTotal", 0.0)
                if (bills.length() == 0) {
                    views.setViewVisibility(R.id.tv_bills_total, View.GONE)
                    views.setViewVisibility(R.id.tv_bills_empty, View.VISIBLE)
                    views.setTextViewText(R.id.tv_bills_empty, "Tudo em dia nos próximos 15 dias!")
                } else {
                    views.setViewVisibility(R.id.tv_bills_total, View.VISIBLE)
                    views.setTextViewText(
                        R.id.tv_bills_total,
                        WidgetPrefs.formatBRL(total, hideValues),
                    )
                    views.setViewVisibility(R.id.tv_bills_empty, View.GONE)

                    val count = min(4, bills.length())
                    for (i in 0 until count) {
                        val item = bills.optJSONObject(i) ?: continue
                        val title = item.optString("title", "Conta")
                        val amount = item.optDouble("amount", 0.0)
                        val dueLabel = item.optString("dueLabel", "")
                        val daysUntil = item.optInt("daysUntil", 7)
                        val isExpense = item.optBoolean("isExpense", true)

                        val dotDrawable = when {
                            !isExpense -> R.drawable.widget_dot_green
                            daysUntil <= 0 -> R.drawable.widget_dot_red
                            daysUntil <= 3 -> R.drawable.widget_dot_amber
                            else -> R.drawable.widget_dot_blue
                        }

                        views.setViewVisibility(rowIds[i], View.VISIBLE)
                        views.setImageViewResource(dotIds[i], dotDrawable)
                        views.setTextViewText(titleIds[i], title)
                        views.setTextColor(titleIds[i], textPrimary)
                        views.setTextViewText(dueIds[i], dueLabel)
                        views.setTextColor(
                            dueIds[i],
                            if (isExpense && daysUntil <= 0) expenseColor else textSecondary,
                        )
                        views.setTextViewText(
                            amountIds[i],
                            WidgetPrefs.formatBRL(amount, hideValues),
                        )
                        views.setTextColor(
                            amountIds[i],
                            if (isExpense) textPrimary else incomeColor,
                        )
                    }
                }
            }

            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetPrefs.buildLaunchPendingIntent(context, 5001, "dashboard"),
            )
            views.setOnClickPendingIntent(
                R.id.btn_bills_add,
                WidgetPrefs.buildLaunchPendingIntent(context, 5002, "add_expense"),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
