package com.inbox.inbox_app

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class InboxApplication : FlutterApplication() {
    lateinit var engine: FlutterEngine
        private set

    override fun onCreate() {
        super.onCreate()
        engine = FlutterEngine(this)
        AndroidCaptureBridge.attach(engine.dartExecutor.binaryMessenger)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "inbox_engine"
    }
}
