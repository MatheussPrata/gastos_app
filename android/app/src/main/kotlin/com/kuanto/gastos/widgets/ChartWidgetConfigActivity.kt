package com.kuanto.gastos.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.RadioGroup
import com.kuanto.gastos.R

class ChartWidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_chart_widget_config)

        val rgType = findViewById<RadioGroup>(R.id.rg_chart_type)
        val rgPeriod = findViewById<RadioGroup>(R.id.rg_chart_period)
        val btnCancel = findViewById<Button>(R.id.btn_cancel)
        val btnSave = findViewById<Button>(R.id.btn_save)

        val currentType = WidgetPrefs.getChartType(this, appWidgetId)
        val currentPeriod = WidgetPrefs.getChartPeriod(this, appWidgetId)

        rgType.check(
            when (currentType) {
                WidgetPrefs.CHART_BALANCE -> R.id.rb_chart_balance
                WidgetPrefs.CHART_MONTHLY -> R.id.rb_chart_monthly
                WidgetPrefs.CHART_PAYMENT_METHODS -> R.id.rb_chart_payment_methods
                WidgetPrefs.CHART_CARDS -> R.id.rb_chart_cards
                else -> R.id.rb_chart_categories
            },
        )

        rgPeriod.check(
            when (currentPeriod) {
                WidgetPrefs.PERIOD_QUARTER -> R.id.rb_period_quarter
                WidgetPrefs.PERIOD_YEAR -> R.id.rb_period_year
                else -> R.id.rb_period_month
            },
        )

        btnCancel.setOnClickListener {
            finish()
        }

        btnSave.setOnClickListener {
            val selectedType = when (rgType.checkedRadioButtonId) {
                R.id.rb_chart_balance -> WidgetPrefs.CHART_BALANCE
                R.id.rb_chart_monthly -> WidgetPrefs.CHART_MONTHLY
                R.id.rb_chart_payment_methods -> WidgetPrefs.CHART_PAYMENT_METHODS
                R.id.rb_chart_cards -> WidgetPrefs.CHART_CARDS
                else -> WidgetPrefs.CHART_CATEGORIES
            }
            val selectedPeriod = when (rgPeriod.checkedRadioButtonId) {
                R.id.rb_period_quarter -> WidgetPrefs.PERIOD_QUARTER
                R.id.rb_period_year -> WidgetPrefs.PERIOD_YEAR
                else -> WidgetPrefs.PERIOD_MONTH
            }

            WidgetPrefs.saveChartConfig(this, appWidgetId, selectedType, selectedPeriod)
            val manager = AppWidgetManager.getInstance(this)
            ChartWidgetProvider.updateWidget(this, manager, appWidgetId)

            val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }
}
