package com.retrytech.retrytech_plugin

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.util.Log
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.SessionState
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import androidx.core.content.ContextCompat



/** RetrytechPlugin */
class RetrytechPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    var context: Activity? = null


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "retrytech_plugin"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "runFFmpegCommand" -> {
                Log.d("TAG", "onMethodCall: ${call.arguments}")
                FFmpegKit.executeAsync(
                    call.arguments.toString()
                ) {
                    result.success(it.state == SessionState.COMPLETED)
                }
            }
            "shareToInstagram" ->{
                Log.d("TAG","Share To instagram")
                val text = call.arguments as String?
                if (text != null) {
                    shareTextToInstagram(text)
                }
                result.success(null)
            }

            else -> {
                result.notImplemented()
            }
        }

    }

    private fun shareTextToInstagram(text: String) {
        val shareIntent = Intent(Intent.ACTION_SEND)
        shareIntent.type = "text/plain"
        shareIntent.putExtra(Intent.EXTRA_TEXT, text)
        val pm = context!!.packageManager
        pm.queryIntentActivities(shareIntent, 0)
        shareIntent.setPackage("com.instagram.android")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
        } else {
            shareIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET)
        }
        context!!.startActivity(shareIntent)
    }




    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
