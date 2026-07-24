package com.example.nursaflow

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Adds one thing beyond the default FlutterActivity: a "nursaflow/drive_picker"
 * platform channel that opens Android's document picker pre-navigated
 * straight into Google Drive, for the dedicated "Google Drive" button on
 * the upload screen (see upload_screen.dart's _pickFromGoogleDrive).
 *
 * This relies on Google Drive's document-provider authority
 * ("com.google.android.apps.docs.storage"), which is unofficial/undocumented
 * — it's a widely used trick, not a guaranteed public API, so it's wrapped
 * in a try/catch that falls back to the plain system picker (still lists
 * Drive as one of several sources, just not pre-selected) if Drive isn't
 * installed or the OEM's picker doesn't honor EXTRA_INITIAL_URI. Some OEM
 * Android skins (e.g. Transsion's XOS) are known to deviate from stock
 * picker behavior, so treat the "jumps straight to Drive" part as
 * best-effort, not guaranteed on every device.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "nursaflow/drive_picker"
    private val requestCodeDrive = 9821
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "pickFromDrive") {
                pendingResult = result
                openDrivePicker()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openDrivePicker() {
        val driveIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                Uri.parse("content://com.google.android.apps.docs.storage/root"),
            )
        }
        try {
            startActivityForResult(driveIntent, requestCodeDrive)
        } catch (e: Exception) {
            // Drive's document provider isn't reachable on this device —
            // fall back to the plain picker rather than failing outright.
            val fallbackIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            startActivityForResult(fallbackIntent, requestCodeDrive)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != requestCodeDrive) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingResult
        pendingResult = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result?.success(null) // user cancelled — not an error
            return
        }

        try {
            val name = queryDisplayName(uri) ?: "document"
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                result?.error("DRIVE_READ_FAILED", "Could not open a stream for the selected file.", null)
            } else {
                result?.success(mapOf("name" to name, "bytes" to bytes))
            }
        } catch (e: Exception) {
            result?.error("DRIVE_READ_FAILED", e.message, null)
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor = contentResolver.query(uri, null, null, null, null) ?: return null
        cursor.use {
            val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (it.moveToFirst() && nameIndex >= 0) {
                return it.getString(nameIndex)
            }
        }
        return null
    }
}