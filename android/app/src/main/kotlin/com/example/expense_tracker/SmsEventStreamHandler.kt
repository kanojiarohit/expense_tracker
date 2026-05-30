package com.example.expense_tracker

import android.content.Context
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

object SmsEventStreamHandler : EventChannel.StreamHandler {
    private const val prefsName = "expense_tracker_sms"
    private const val pendingSmsKey = "pending_sms"

    private var appContext: Context? = null
    private var events: EventChannel.EventSink? = null

    fun initialize(context: Context) {
        appContext = context.applicationContext
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
        events = eventSink
        flushPending()
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    fun sendSms(context: Context, body: String, sender: String?, receivedAtMillis: Long) {
        initialize(context)
        val payload = mapOf(
            "body" to body,
            "sender" to (sender ?: ""),
            "receivedAtMillis" to receivedAtMillis,
        )
        if (events == null) {
            persist(payload)
        } else {
            events?.success(payload)
        }
    }

    private fun persist(payload: Map<String, Any>) {
        val context = appContext ?: return
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(pendingSmsKey, "[]"))
        array.put(JSONObject(payload))
        prefs.edit().putString(pendingSmsKey, array.toString()).apply()
    }

    private fun flushPending() {
        val context = appContext ?: return
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(pendingSmsKey, "[]"))
        prefs.edit().remove(pendingSmsKey).apply()
        for (index in 0 until array.length()) {
            val item = array.getJSONObject(index)
            events?.success(
                mapOf(
                    "body" to item.optString("body"),
                    "sender" to item.optString("sender"),
                    "receivedAtMillis" to item.optLong("receivedAtMillis"),
                ),
            )
        }
    }
}
