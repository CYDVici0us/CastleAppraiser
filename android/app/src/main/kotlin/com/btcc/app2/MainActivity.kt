package com.btcc.app2

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.btcc.app2/camera"
    private val TFLITE_CHANNEL = "com.btcc.app2/tflite"
    private var result: Result? = null
    private var REQUEST_CODE: Int = 123

    // Kept for app lifetime; Dart borrows the native handle for InterpreterOptions.
    // Held as Any to avoid compile-time clash between LiteRT and tensorflow-lite APIs.
    private var flexDelegate: Any? = null

    private var currentPhotoPath: String? = null
    @Throws(IOException::class)
    private fun createImageFile(): File {
        // Create an image file name
        val timeStamp: String = SimpleDateFormat("yyyyMMdd_HHmmss").format(Date())
        val storageDir: File? = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        return File.createTempFile(
                "JPEG_${timeStamp}_", /* prefix */
                ".jpg", /* suffix */
                storageDir /* directory */
        ).apply {
            // Save a file: path for use with ACTION_VIEW intents
            currentPhotoPath = absolutePath
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data);

        if (this.result == null) {
            // log error
            Log.e(CHANNEL, "Could not set result because result was null")
            return
        }

        if (requestCode != REQUEST_CODE) {
            this.result?.error("0", "Invalid request code", "")
            this.result = null
            return
        }

        if (resultCode == Activity.RESULT_CANCELED) {
            this.result?.error("1", "Not actually an error. Request was cancelled", "")
            this.result = null
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            this.result?.error("2", "Result code $resultCode", "")
            this.result = null
            return
        }

        this.result?.success(currentPhotoPath)
        currentPhotoPath = null
        this.result = null
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getPicture") {
                this.result = result
                dispatchTakePictureIntent(result)
            }
            else if (call.method == "setUserOrientation") {
                setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_USER);
            }
            else if (call.method == "setSensorOrientation") {
                setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR);
            }
            else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TFLITE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFlexDelegateHandle" -> {
                        try {
                            result.success(ensureFlexNativeHandle())
                        } catch (e: Exception) {
                            Log.e(TFLITE_CHANNEL, "FlexDelegate failed", e)
                            result.error("flex", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Creates org.tensorflow.lite.flex.FlexDelegate via reflection and returns
    // its native TfLiteDelegate pointer for tflite_flutter InterpreterOptions.
    private fun ensureFlexNativeHandle(): Long {
        if (flexDelegate == null) {
            val clazz = Class.forName("org.tensorflow.lite.flex.FlexDelegate")
            flexDelegate = clazz.getDeclaredConstructor().newInstance()
            Log.i(TFLITE_CHANNEL, "FlexDelegate created")
        }
        val handle = flexDelegate!!::class.java
            .getMethod("getNativeHandle")
            .invoke(flexDelegate) as Long
        if (handle == 0L) {
            throw IllegalStateException("FlexDelegate nativeHandle was 0")
        }
        return handle
    }

    private fun dispatchTakePictureIntent(result: Result) {
        Intent(MediaStore.ACTION_IMAGE_CAPTURE).also { takePictureIntent ->
            // Ensure that there's a camera activity to handle the intent
            takePictureIntent.resolveActivity(packageManager)?.also {
                // Create the File where the photo should go
                val photoFile: File? = try {
                    createImageFile()
                } catch (ex: IOException) {
                    // Error occurred while creating the File
                    null
                }

                if (photoFile == null) {
                    result.error("5", "Could not create file to save picture", "")
                    return
                }

                // Continue only if the File was successfully created
                photoFile.also {
                    val photoURI: Uri = FileProvider.getUriForFile(
                        this,
                        "com.btcc.app2.fileprovider",
                        it
                    )
                    takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, photoURI)
                    startActivityForResult(takePictureIntent, REQUEST_CODE)
                }
            }
        }
    }

}
