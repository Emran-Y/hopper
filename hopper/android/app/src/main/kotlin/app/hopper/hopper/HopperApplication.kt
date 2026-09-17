package app.hopper.hopper

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Owns the Flutter engine for the whole process so the Dart sync engine keeps
 * running when the window is closed. MainActivity attaches to this cached engine
 * instead of creating (and destroying) its own; HopperService keeps the process alive.
 */
class HopperApplication : Application() {
    lateinit var engine: FlutterEngine
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        HopperBridge.attach(this, engine)
    }

    companion object {
        const val ENGINE_ID = "hopper"
        lateinit var instance: HopperApplication
            private set
    }
}
