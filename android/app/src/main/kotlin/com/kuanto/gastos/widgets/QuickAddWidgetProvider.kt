package com.kuanto.gastos.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.kuanto.gastos.R

class QuickAddWidgetProvider : AppWidgetProvider() {

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

            val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_bg_dark else R.drawable.widget_bg_light,
            )

            views.setOnClickPendingIntent(
                R.id.btn_add_expense,
                WidgetPrefs.buildLaunchPendingIntent(context, 1001, "add_expense"),
            )
            views.setOnClickPendingIntent(
                R.id.btn_add_income,
                WidgetPrefs.buildLaunchPendingIntent(context, 1002, "add_income"),
            )
            views.setOnClickPendingIntent(
                R.id.btn_scan_receipt,
                WidgetPrefs.buildLaunchPendingIntent(context, 1003, "scan_receipt"),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
