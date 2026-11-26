package com.kuanto.gastos.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import com.kuanto.gastos.R
import kotlin.math.max

class ChartWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            WidgetPrefs.deleteChartConfig(context, appWidgetId)
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
            val primaryColor = WidgetPrefs.resolvePrimaryColor(payload)
            val chartType = WidgetPrefs.getChartType(context, appWidgetId)
            val period = WidgetPrefs.getChartPeriod(context, appWidgetId)

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 280)
                .coerceAtLeast(220)
            val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 190)
                .coerceAtLeast(150)
            val chartBodyHeightDp = max(120, minHeightDp - 48)

            val chartsObj = payload?.optJSONObject("charts")
            val periodObj = chartsObj?.optJSONObject(period)
                ?: chartsObj?.optJSONObject(WidgetPrefs.PERIOD_MONTH)

            val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF0F172A.toInt()
            val textSecondary = if (isDark) 0xFF94A3B8.toInt() else 0xFF64748B.toInt()
            val accentColor = if (isDark) 0xFF60A5FA.toInt() else primaryColor

            val views = RemoteViews(context.packageName, R.layout.widget_chart)
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_bg_dark else R.drawable.widget_bg_light,
            )
            views.setTextViewText(R.id.tv_chart_title, WidgetPrefs.chartTypeTitle(chartType))
            views.setTextColor(R.id.tv_chart_title, textPrimary)

            views.setTextViewText(
                R.id.tv_chart_period,
                WidgetPrefs.periodDisplayLabel(period, periodObj),
            )
            views.setInt(
                R.id.tv_chart_period,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_chip_dark else R.drawable.widget_chip_light,
            )
            views.setTextColor(R.id.tv_chart_period, accentColor)

            views.setInt(
                R.id.btn_chart_config,
                "setBackgroundResource",
                if (isDark) R.drawable.widget_icon_btn_dark else R.drawable.widget_icon_btn_light,
            )
            views.setInt(R.id.btn_chart_config, "setColorFilter", textSecondary)

            val bitmap = WidgetChartRenderer.render(
                context = context,
                payload = payload,
                chartType = chartType,
                period = period,
                widthDp = minWidthDp,
                heightDp = chartBodyHeightDp,
                isDark = isDark,
                primaryColor = accentColor,
                hideValues = hideValues,
            )
            views.setImageViewBitmap(R.id.img_chart, bitmap)

            val configIntent = Intent(context, ChartWidgetConfigActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val configPi = PendingIntent.getActivity(
                context,
                30000 + appWidgetId,
                configIntent,
                piFlags,
            )
            views.setOnClickPendingIntent(R.id.btn_chart_config, configPi)

            val openReportsPi = WidgetPrefs.buildLaunchPendingIntent(
                context = context,
                requestCode = 40000 + appWidgetId,
                route = "reports",
                chartType = chartType,
                period = period,
            )
            views.setOnClickPendingIntent(R.id.widget_root, openReportsPi)
            views.setOnClickPendingIntent(R.id.chart_body, openReportsPi)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
