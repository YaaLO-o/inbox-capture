package com.inbox.inbox_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        (application as InboxApplication).engine

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
