package com.pdftool.pro

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.pdftool.pro/python"
    private val LOG_CHANNEL = "com.pdftool.pro/logs"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Chaquopy
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        // Method Channel for calling functions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val scriptName = call.argument<String>("script")
            val argsJson = call.argument<String>("args")

            if (scriptName != null && argsJson != null) {
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val py = Python.getInstance()
                        val bridge = py.getModule("bridge")
                        val pyResult = bridge.callAttr("run_script", scriptName, argsJson)
                        
                        // Parse result in Kotlin or send raw JSON back
                        val responseStr = pyResult.toString()
                        
                        withContext(Dispatchers.Main) {
                            result.success(responseStr)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        withContext(Dispatchers.Main) {
                            result.error("PYTHON_ERROR", e.message, null)
                        }
                    }
                }
            } else {
                result.error("INVALID_ARGS", "Missing script or args", null)
            }
        }

        // Event Channel for Logs (Optional, simple polling via method channel return might be easier for one-shot tasks, 
        // but if we wanted real-time streaming we'd need a more complex Python callback setup. 
        // For now, the Python 'bridge' captures stdout and returns it at the end. 
        // We can keep this for future expansion.)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }
}
