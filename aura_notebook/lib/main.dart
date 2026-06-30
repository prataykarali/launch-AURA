import 'package:aura_notebook/main/launch.dart';
import 'package:aura_notebook/main/overlay_app.dart';

export 'main/aura_app.dart' show AuraApp;
export 'main/aura_root.dart' show AuraRoot;
export 'main/overlay_app.dart' show AuraOverlayApp;
export 'main/open_main_app.dart' show openMainApp;

void main(List<String> rawArgs) async {
  await runAura(rawArgs);
}

@pragma("vm:entry-point")
void overlayMain() {
  runOverlay();
}
