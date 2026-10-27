package com.example.mai_ai

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Recibe lo que llega del sistema y se lo pasa a Dart por el canal
 * `mai/lanzador` (ver lib/sistema/lanzador.dart):
 * - el tile de ajustes rápidos ([MaiTileService]) pide escuchar;
 * - "Compartir → Mai" desde otra app trae un texto.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val ACCION_ESCUCHAR = "com.example.mai_ai.ESCUCHAR"
        private const val CANAL = "mai/lanzador"
    }

    private var canal: MethodChannel? = null

    /** Petición con la que se abrió la app, hasta que Dart la pida. */
    private var inicial: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        inicial = peticionDe(intent)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "peticionInicial") {
                    result.success(inicial)
                    inicial = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    // Con la app ya abierta (launchMode singleTop) las peticiones llegan aquí.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        peticionDe(intent)?.let { canal?.invokeMethod("peticion", it) }
    }

    private fun peticionDe(intent: Intent?): Map<String, String>? = when {
        intent == null -> null
        intent.action == ACCION_ESCUCHAR -> mapOf("tipo" to "escuchar")
        intent.action == Intent.ACTION_SEND && intent.type == "text/plain" ->
            intent.getStringExtra(Intent.EXTRA_TEXT)
                ?.takeIf { it.isNotBlank() }
                ?.let { mapOf("tipo" to "compartir", "texto" to it) }
        else -> null
    }
}
