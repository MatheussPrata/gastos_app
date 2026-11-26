package com.kuanto.gastos

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import com.kuanto.gastos.widgets.ChartWidgetProvider
import com.kuanto.gastos.widgets.MonthlySummaryWidgetProvider
import com.kuanto.gastos.widgets.QuickAddWidgetProvider
import com.kuanto.gastos.widgets.UpcomingBillsWidgetProvider
import com.kuanto.gastos.widgets.WidgetPrefs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: Map<String, String?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = extractWidgetAction(intent) ?: return
        val channel = widgetChannel
        if (channel != null) {
            channel.invokeMethod("onWidgetAction", action)
        } else {
            pendingWidgetAction = action
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.kuanto.gastos/widgets",
        )
        widgetChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
                    val payload = call.argument<String>("payload")
                    if (payload == null) {
                        result.error("INVALID_ARGS", "payload is required", null)
                        return@setMethodCallHandler
                    }
                    WidgetPrefs.savePayload(applicationContext, payload)
                    WidgetPrefs.updateAllWidgets(applicationContext)
                    result.success(true)
                }

                "setHideValues" -> {
                    val hide = call.argument<Boolean>("hide") ?: false
                    WidgetPrefs.setHideValues(applicationContext, hide)
                    WidgetPrefs.updateAllWidgets(applicationContext)
                    result.success(true)
                }

                "getHideValues" -> {
                    result.success(WidgetPrefs.isHideValues(applicationContext))
                }

                "consumeInitialAction" -> {
                    val action = pendingWidgetAction
                    pendingWidgetAction = null
                    result.success(action)
                }

                "getActiveChartWidgets" -> {
                    val manager = AppWidgetManager.getInstance(applicationContext)
                    val ids = manager.getAppWidgetIds(
                        ComponentName(applicationContext, ChartWidgetProvider::class.java),
                    )
                    val list = ids.map { id ->
                        mapOf(
                            "widgetId" to id,
                            "chartType" to WidgetPrefs.getChartType(applicationContext, id),
                            "period" to WidgetPrefs.getChartPeriod(applicationContext, id),
                        )
                    }
                    result.success(list)
                }

                "configureChartWidget" -> {
                    val widgetId = call.argument<Int>("widgetId")
                    val chartType = call.argument<String>("chartType")
                    val period = call.argument<String>("period")
                    if (widgetId == null || chartType == null || period == null) {
                        result.error("INVALID_ARGS", "widgetId, chartType and period are required", null)
                        return@setMethodCallHandler
                    }
                    WidgetPrefs.saveChartConfig(applicationContext, widgetId, chartType, period)
                    ChartWidgetProvider.updateWidget(
                        applicationContext,
                        AppWidgetManager.getInstance(applicationContext),
                        widgetId,
                    )
                    result.success(true)
                }

                "isPinWidgetSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        AppWidgetManager.getInstance(applicationContext).isRequestPinAppWidgetSupported
                    result.success(supported)
                }

                "requestPinWidget" -> {
                    val kind = call.argument<String>("kind") ?: ""
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val manager = AppWidgetManager.getInstance(applicationContext)
                    if (!manager.isRequestPinAppWidgetSupported) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val providerClass = when (kind) {
                        "quick_add" -> QuickAddWidgetProvider::class.java
                        "summary" -> MonthlySummaryWidgetProvider::class.java
                        "chart" -> ChartWidgetProvider::class.java
                        "upcoming_bills" -> UpcomingBillsWidgetProvider::class.java
                        else -> null
                    }
                    if (providerClass == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val ok = manager.requestPinAppWidget(
                        ComponentName(applicationContext, providerClass),
                        null,
                        null,
                    )
                    result.success(ok)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun captureWidgetIntent(intent: Intent?) {
        val action = extractWidgetAction(intent) ?: return
        pendingWidgetAction = action
    }

    private fun extractWidgetAction(intent: Intent?): Map<String, String?>? {
        if (intent == null || intent.action != WidgetPrefs.ACTION_WIDGET_LAUNCH) return null
        val route = intent.getStringExtra(WidgetPrefs.EXTRA_ROUTE) ?: return null
        return mapOf(
            "route" to route,
            "chartType" to intent.getStringExtra(WidgetPrefs.EXTRA_CHART_TYPE),
            "period" to intent.getStringExtra(WidgetPrefs.EXTRA_PERIOD),
        )
    }
}
