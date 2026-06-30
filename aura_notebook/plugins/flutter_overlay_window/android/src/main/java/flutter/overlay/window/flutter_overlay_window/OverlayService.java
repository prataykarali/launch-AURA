package flutter.overlay.window.flutter_overlay_window;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.app.PendingIntent;
import android.graphics.Point;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Display;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import io.flutter.embedding.android.FlutterTextureView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterEngineGroup;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.JSONMessageCodec;
import io.flutter.plugin.common.MethodChannel;

public class OverlayService extends Service implements View.OnTouchListener {
    private final int DEFAULT_NAV_BAR_HEIGHT_DP = 48;
    private final int DEFAULT_STATUS_BAR_HEIGHT_DP = 25;

    private Integer mStatusBarHeight = -1;
    private Integer mNavigationBarHeight = -1;
    private Resources mResources;

    public static final String INTENT_EXTRA_IS_CLOSE_WINDOW = "IsCloseWindow";

    private static OverlayService instance;
    public static boolean isRunning = false;
    private WindowManager windowManager = null;
    private FlutterView flutterView;
    private MethodChannel flutterChannel;
    private BasicMessageChannel<Object> overlayMessageChannel;
    private int clickableFlag = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;

    private Handler mAnimationHandler = new Handler();
    private float lastX, lastY;
    private int lastYPosition;
    private boolean dragging;
    private static final float MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER = 0.8f;
    private Point szWindow = new Point();
    private Timer mTrayAnimationTimer;
    private TrayAnimationTimerTask mTrayTimerTask;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void onDestroy() {
        Log.d("OverLay", "Destroying the overlay window service");
        if (windowManager != null) {
            windowManager.removeView(flutterView);
            windowManager = null;
            flutterView.detachFromFlutterEngine();
            flutterView = null;
        }
        isRunning = false;
        NotificationManager notificationManager = (NotificationManager) getApplicationContext().getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancel(OverlayConstants.NOTIFICATION_ID);
        instance = null;
    }

    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        mResources = getApplicationContext().getResources();
        int startX = intent.getIntExtra("startX", OverlayConstants.DEFAULT_XY);
        int startY = intent.getIntExtra("startY", OverlayConstants.DEFAULT_XY);
        boolean isCloseWindow = intent.getBooleanExtra(INTENT_EXTRA_IS_CLOSE_WINDOW, false);
        if (isCloseWindow) {
            if (windowManager != null) {
                windowManager.removeView(flutterView);
                windowManager = null;
                flutterView.detachFromFlutterEngine();
                stopSelf();
            }
            isRunning = false;
            return START_STICKY;
        }
        if (windowManager != null) {
            // The overlay is ALREADY showing. showOverlay() is idempotent on the
            // Dart side (guarded by isActive()), but the resume-lifecycle hook
            // and the double-showBar() path can still call startService() while
            // the window is live. Previously this branch did removeView() +
            // stopSelf(), which KILLED the service mid-stream — the overlay
            // vanished and every subsequent shareData/updateFlag call failed.
            // Now we simply re-apply the current flag/position to the EXISTING
            // view and return, leaving the running overlay untouched.
            Log.d("onStartCommand", "Overlay already active — re-applying layout, no restart");
            WindowManager.LayoutParams params =
                    (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.flags = WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS |
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR |
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED |
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH;
            params.gravity = WindowSetup.gravity;
            windowManager.updateViewLayout(flutterView, params);
            isRunning = true;
            return START_STICKY;
        }
        isRunning = true;
        Log.d("onStartCommand", "Service started");
        FlutterEngine engine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);
        flutterView = new FlutterView(getApplicationContext(), new FlutterTextureView(getApplicationContext()));
        flutterView.attachToFlutterEngine(FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG));
        flutterView.setFitsSystemWindows(true);
        flutterView.setFocusable(true);
        flutterView.setFocusableInTouchMode(true);
        flutterView.setBackgroundColor(Color.TRANSPARENT);
        flutterChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("updateFlag")) {
                String flag = call.argument("flag").toString();
                updateOverlayFlag(result, flag);
            } else if (call.method.equals("updateOverlayPosition")) {
                int x = call.<Integer>argument("x");
                int y = call.<Integer>argument("y");
                moveOverlay(x, y, result);
            } else if (call.method.equals("resizeOverlay")) {
                int width = call.argument("width");
                int height = call.argument("height");
                boolean enableDrag = call.argument("enableDrag");
                resizeOverlay(width, height, enableDrag, result);
            }
        });
        overlayMessageChannel.setMessageHandler((message, reply) -> {
            if (WindowSetup.messenger != null) {
                WindowSetup.messenger.send(message, reply::reply);
            } else {
                reply.reply(null);
            }
        });
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
            windowManager.getDefaultDisplay().getSize(szWindow);
        } else {
            DisplayMetrics displaymetrics = new DisplayMetrics();
            windowManager.getDefaultDisplay().getMetrics(displaymetrics);
            int w = displaymetrics.widthPixels;
            int h = displaymetrics.heightPixels;
            szWindow.set(w, h);
        }
        
        boolean isBottom = (WindowSetup.gravity & Gravity.BOTTOM) == Gravity.BOTTOM;
        int defaultY = isBottom ? 0 : -statusBarHeightPx();
        int dx = startX == OverlayConstants.DEFAULT_XY ? 0 : startX;
        int dy = startY == OverlayConstants.DEFAULT_XY ? defaultY : startY;
        // IMPORTANT: WindowSetup.height/width arrive in DP (e.g. 130), not px.
        // The INITIAL LayoutParams below must convert via dpToPx() — exactly
        // what resizeOverlay() does on the update path. Previously this passed
        // the raw dp value as px, so on a ~3x-density Samsung screen a 130dp
        // bar rendered at only ~130px (≈43dp) and was visibly cut off.
        int initialWidth  = WindowSetup.width  == -1999 ? -1
                : (WindowSetup.width  == -1 ? -1 : dpToPx(WindowSetup.width));
        int initialHeight = WindowSetup.height == -1999 ? screenHeight()
                : (WindowSetup.height == -1 ? -1 : dpToPx(WindowSetup.height));
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                initialWidth,
                initialHeight,
                0,
                defaultY,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE,
                WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR
                        | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
                        | WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.TRANSLUCENT
        );
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
            params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
        }
        params.gravity = WindowSetup.gravity;
        flutterView.setOnTouchListener(this);
        // Add the overlay window FIRST. On Android 15+/16 and Samsung One UI,
        // an app holding SYSTEM_ALERT_WINDOW is only allowed to promote a
        // service to the foreground if it ALREADY has a visible overlay window.
        windowManager.addView(flutterView, params);
        moveOverlay(dx, dy, null);

        // Resume engine lifecycle after views are added and layout is settled
        engine.getLifecycleChannel().appIsResumed();

        // Promote to foreground AFTER the overlay window exists. The service
        // is started via plain startService() (NOT startForegroundService()),
        // so there is NO 5-second ForegroundServiceDidNotStartInTimeException
        // timer ticking. If this call throws on restrictive OEM builds, we
        // simply stay a background service — the overlay stays visible, no crash.
        promoteToForeground();

        return START_STICKY;
    }

    /**
     * Attempt to promote this service to the foreground. Safe on any Android
     * version. Wrapped in try/catch so a denial on restrictive OEM builds
     * (Samsung) never crashes the app — the overlay window is already on
     * screen by the time this runs.
     */
    private void promoteToForeground() {
        try {
            createNotificationChannel();
            Intent notificationIntent = new Intent(this, FlutterOverlayWindowPlugin.class);
            int pendingFlags = android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S
                    ? PendingIntent.FLAG_IMMUTABLE : PendingIntent.FLAG_UPDATE_CURRENT;
            PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, pendingFlags);
            final int notifyIcon = getDrawableResourceId("mipmap", "launcher");
            Notification notification = new NotificationCompat.Builder(this, OverlayConstants.CHANNEL_ID)
                    .setContentTitle("AURA Bar")
                    .setContentText("AURA floating assistant")
                    .setSmallIcon(notifyIcon == 0 ? R.drawable.notification_icon : notifyIcon)
                    .setContentIntent(pendingIntent)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .build();

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(OverlayConstants.NOTIFICATION_ID, notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK |
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
            } else {
                startForeground(OverlayConstants.NOTIFICATION_ID, notification);
            }
            Log.d("OverlayService", "promoteToForeground succeeded");
        } catch (Exception e) {
            // Not fatal: the overlay window is already shown. Some Samsung
            // builds deny FGS even with all permissions granted.
            Log.w("OverlayService", "promoteToForeground denied, running as background service: " + e.getMessage());
        }
    }


    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    private int screenHeight() {
        Display display = windowManager.getDefaultDisplay();
        DisplayMetrics dm = new DisplayMetrics();
        display.getRealMetrics(dm);
        return inPortrait() ?
                dm.heightPixels + statusBarHeightPx() + navigationBarHeightPx()
                :
                dm.heightPixels + statusBarHeightPx();
    }

    private int statusBarHeightPx() {
        if (mStatusBarHeight == -1) {
            int statusBarHeightId = mResources.getIdentifier("status_bar_height", "dimen", "android");

            if (statusBarHeightId > 0) {
                mStatusBarHeight = mResources.getDimensionPixelSize(statusBarHeightId);
            } else {
                mStatusBarHeight = dpToPx(DEFAULT_STATUS_BAR_HEIGHT_DP);
            }
        }

        return mStatusBarHeight;
    }

    int navigationBarHeightPx() {
        if (mNavigationBarHeight == -1) {
            int navBarHeightId = mResources.getIdentifier("navigation_bar_height", "dimen", "android");

            if (navBarHeightId > 0) {
                mNavigationBarHeight = mResources.getDimensionPixelSize(navBarHeightId);
            } else {
                mNavigationBarHeight = dpToPx(DEFAULT_NAV_BAR_HEIGHT_DP);
            }
        }

        return mNavigationBarHeight;
    }


    private void updateOverlayFlag(MethodChannel.Result result, String flag) {
        if (windowManager != null) {
            WindowSetup.setFlag(flag);
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.flags = WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS |
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR |
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED |
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
                params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
            } else {
                params.alpha = 1;
            }
            windowManager.updateViewLayout(flutterView, params);
            if ("focusPointer".equalsIgnoreCase(flag) || "flagNotTouchModal".equalsIgnoreCase(flag)) {
                flutterView.post(() -> {
                    flutterView.requestFocus();
                    flutterView.requestFocusFromTouch();
                });
            }
            if (result != null) {
                result.success(true);
            }
        } else {
            if (result != null) {
                result.success(false);
            }
        }
    }

    private void resizeOverlay(int width, int height, boolean enableDrag, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.width = (width == -1999 || width == -1) ? -1 : dpToPx(width);
            params.height = (height == -1999) ? screenHeight() : ((height == -1) ? -1 : dpToPx(height));
            WindowSetup.enableDrag = enableDrag;
            windowManager.updateViewLayout(flutterView, params);
            result.success(true);
        } else {
            result.success(false);
        }
    }

    private void moveOverlay(int x, int y, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.x = (x == -1999 || x == -1) ? -1 : dpToPx(x);
            params.y = dpToPx(y);
            windowManager.updateViewLayout(flutterView, params);
            if (result != null)
                result.success(true);
        } else {
            if (result != null)
                result.success(false);
        }
    }


    public static Map<String, Double> getCurrentPosition() {
        if (instance != null && instance.flutterView != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
            Map<String, Double> position = new HashMap<>();
            position.put("x", instance.pxToDp(params.x));
            position.put("y", instance.pxToDp(params.y));
            return position;
        }
        return null;
    }

    public static boolean moveOverlay(int x, int y) {
        if (instance != null && instance.flutterView != null) {
            if (instance.windowManager != null) {
                WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
                params.x = (x == -1999 || x == -1) ? -1 : instance.dpToPx(x);
                params.y = instance.dpToPx(y);
                instance.windowManager.updateViewLayout(instance.flutterView, params);
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }


    // ── onCreate ──────────────────────────────────────────────────────────────
    //
    // Lightweight: ONLY set up the FlutterEngine and channels here. We do NOT
    // call startForeground() in onCreate() because:
    //   1. On Android 15+/16 and Samsung One UI, a SYSTEM_ALERT_WINDOW app can
    //      only call startForeground() AFTER its overlay window is visible —
    //      which doesn't happen until onStartCommand() runs addView().
    //   2. If started with startForegroundService(), the 5-second FGS timer
    //      would kill us if startForeground() failed. We avoid that entirely
    //      by using plain startService() from the plugin (see
    //      FlutterOverlayWindowPlugin) and promoting to foreground later in
    //      onStartCommand() via promoteToForeground().

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        mResources = getApplicationContext().getResources();

        // Get or create the cached FlutterEngine
        FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);

        if (flutterEngine == null) {
            Log.e("OverlayService", "Flutter engine not found, hence creating new flutter engine");
            FlutterEngineGroup engineGroup = new FlutterEngineGroup(this);
            DartExecutor.DartEntrypoint entryPoint = new DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "overlayMain"
            );

            FlutterOverlayWindowPlugin.isOverlayEngine = true;
            flutterEngine = engineGroup.createAndRunEngine(this, entryPoint);
            FlutterOverlayWindowPlugin.isOverlayEngine = false;
            FlutterEngineCache.getInstance().put(OverlayConstants.CACHED_TAG, flutterEngine);
        }

        // Create the MethodChannel with the properly initialized FlutterEngine
        if (flutterEngine != null) {
            flutterChannel = new MethodChannel(flutterEngine.getDartExecutor(), OverlayConstants.OVERLAY_TAG);
            overlayMessageChannel = new BasicMessageChannel(flutterEngine.getDartExecutor(), OverlayConstants.MESSENGER_TAG, JSONMessageCodec.INSTANCE);
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                    OverlayConstants.CHANNEL_ID,
                    "AURA Bar Service",
                    NotificationManager.IMPORTANCE_LOW
            );
            serviceChannel.setDescription("Keeps the AURA floating assistant bar active");
            serviceChannel.setShowBadge(false);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(serviceChannel);
            }
        }
    }

    private int getDrawableResourceId(String resType, String name) {
        return getApplicationContext().getResources().getIdentifier(String.format("ic_%s", name), resType, getApplicationContext().getPackageName());
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP,
                Float.parseFloat(dp + ""), mResources.getDisplayMetrics());
    }

    private double pxToDp(int px) {
        return (double) px / mResources.getDisplayMetrics().density;
    }

    private boolean inPortrait() {
        return mResources.getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
    }

    @Override
    public boolean onTouch(View view, MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_OUTSIDE) {
            Log.d("OverlayService", "Touch outside detected — resetting focus flag");
            updateOverlayFlag(null, "defaultFlag");
            if (flutterChannel != null) {
                flutterView.post(() -> {
                    flutterChannel.invokeMethod("focusChanged", false);
                });
            }
            return false;
        }
        if (windowManager != null && WindowSetup.enableDrag) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    dragging = false;
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    break;
                case MotionEvent.ACTION_MOVE:
                    float dx = event.getRawX() - lastX;
                    float dy = event.getRawY() - lastY;
                    if (!dragging && dx * dx + dy * dy < 25) {
                        return false;
                    }
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    // Use bitwise AND so that combined gravity values
                    // (e.g. BOTTOM | CENTER_HORIZONTAL) are detected correctly.
                    boolean invertX = (WindowSetup.gravity & Gravity.RIGHT) == Gravity.RIGHT;
                    boolean invertY = (WindowSetup.gravity & Gravity.BOTTOM) == Gravity.BOTTOM;
                    int xx = params.x + ((int) dx * (invertX ? -1 : 1));
                    int yy = params.y + ((int) dy * (invertY ? -1 : 1));
                    params.x = xx;
                    params.y = yy;
                    if (windowManager != null) {
                        windowManager.updateViewLayout(flutterView, params);
                    }
                    dragging = true;
                    // MUST return true to consume the event; returning false
                    // lets the system re-apply the window position immediately,
                    // making the bar appear stuck / unable to drag.
                    return true;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    if (!dragging) {
                        return false;
                    }
                    lastYPosition = params.y;
                    if (!WindowSetup.positionGravity.equals("none")) {
                        if (windowManager == null) return false;
                        windowManager.updateViewLayout(flutterView, params);
                        mTrayTimerTask = new TrayAnimationTimerTask();
                        mTrayAnimationTimer = new Timer();
                        mTrayAnimationTimer.schedule(mTrayTimerTask, 0, 25);
                    }
                    return false;
                default:
                    return false;
            }
            return false;
        }
        return false;
    }

    private class TrayAnimationTimerTask extends TimerTask {
        int mDestX;
        int mDestY;
        WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();

        public TrayAnimationTimerTask() {
            super();
            mDestY = lastYPosition;
            switch (WindowSetup.positionGravity) {
                case "auto":
                    mDestX = (params.x + (flutterView.getWidth() / 2)) <= szWindow.x / 2 ? 0 : szWindow.x - flutterView.getWidth();
                    return;
                case "left":
                    mDestX = 0;
                    return;
                case "right":
                    mDestX = szWindow.x - flutterView.getWidth();
                    return;
                default:
                    mDestX = params.x;
                    mDestY = params.y;
                    break;
            }
        }

        @Override
        public void run() {
            mAnimationHandler.post(() -> {
                params.x = (2 * (params.x - mDestX)) / 3 + mDestX;
                params.y = (2 * (params.y - mDestY)) / 3 + mDestY;
                if (windowManager != null) {
                    windowManager.updateViewLayout(flutterView, params);
                }
                if (Math.abs(params.x - mDestX) < 2 && Math.abs(params.y - mDestY) < 2) {
                    TrayAnimationTimerTask.this.cancel();
                    mTrayAnimationTimer.cancel();
                }
            });
        }
    }


}
