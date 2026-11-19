package com.notivo.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Receives PDFs sent with "Abrir com" or "Compartilhar", copies each to the
/// cache and hands the file path to Flutter, which imports it.
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notivo/incoming").apply {
            // Flutter asks once it is ready; a PDF that launched the app waits here.
            setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
        pending = copyPdf(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val path = copyPdf(intent) ?: return
        channel?.invokeMethod("opened", path)
    }

    private fun copyPdf(intent: Intent?): String? {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            else -> null
        } ?: return null
        return try {
            var name = "partitura.pdf"
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst() && !it.isNull(0)) name = it.getString(0)
            }
            // Only the bare name is kept, so a crafted one can't leave the folder.
            name = File(name).name.ifBlank { "partitura.pdf" }
            if (!name.lowercase().endsWith(".pdf")) name += ".pdf"
            val folder = File(cacheDir, "incoming").apply { mkdirs() }
            val target = File(folder, name)
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { input.copyTo(it) }
            } ?: return null
            // Don't hand the same file over again if the activity is recreated.
            intent?.action = null
            target.absolutePath
        } catch (error: Exception) {
            null
        }
    }
}
