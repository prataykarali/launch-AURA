# Prevent shrinking of the Path Provider plugin
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class dev.flutter.pigeon.** { *; }

# Prevent shrinking of your Rust-Flutter bridge
-keep class com.example.aura_notebook.** { *; }
-keep class org.mozilla.rust_android_gradle.** { *; }

# Standard Flutter keeps
-keep class io.flutter.embedding.engine.plugins.** { *; }