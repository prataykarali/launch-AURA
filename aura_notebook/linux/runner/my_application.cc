#include "my_application.h"

#include <cstring>
#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

struct BarWindowMoveContext {
  GtkWindow* window;
  GtkWidget* view;
  gboolean dragging;
  gint width;
  gint height;
  gint pointer_start_x;
  gint pointer_start_y;
  gint window_start_x;
  gint window_start_y;
};

const gint kBarWidth = 760;
const gint kBarCompactHeight = 96;
const gint kBarBubbleHeight = 220;

static gboolean get_pointer_position(GtkWidget* view, gint* root_x, gint* root_y) {
  GdkDisplay* display = gtk_widget_get_display(view);
  GdkSeat* seat =
      display != nullptr ? gdk_display_get_default_seat(display) : nullptr;
  GdkDevice* pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
  if (pointer == nullptr) {
    return FALSE;
  }

  GdkScreen* screen = nullptr;
  gdk_device_get_position(pointer, &screen, root_x, root_y);
  return TRUE;
}

static void respond_success(FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  fl_method_call_respond(method_call, response, nullptr);
}

static void move_bar_to_bottom(GtkWindow* window, gint width, gint height) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  GdkMonitor* monitor =
      display != nullptr ? gdk_display_get_primary_monitor(display) : nullptr;
  if (monitor == nullptr) {
    return;
  }

  GdkRectangle workarea;
  gdk_monitor_get_workarea(monitor, &workarea);
  const gint bottom_gap = 4;
  gint x = workarea.x + ((workarea.width - width) / 2);
  gint y = workarea.y + workarea.height - height - bottom_gap;
  gtk_window_move(window, x > 0 ? x : 0, y > 0 ? y : 0);
}

static void bar_window_method_call_cb(FlMethodChannel* channel,
                                      FlMethodCall* method_call,
                                      gpointer user_data) {
  (void)channel;
  auto* context = static_cast<BarWindowMoveContext*>(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (std::strcmp(method, "begin_drag") == 0) {
    gint root_x = 0;
    gint root_y = 0;
    if (get_pointer_position(context->view, &root_x, &root_y)) {
      gtk_window_get_position(context->window, &context->window_start_x,
                              &context->window_start_y);
      context->pointer_start_x = root_x;
      context->pointer_start_y = root_y;
      context->dragging = TRUE;
    }

    respond_success(method_call);
    return;
  }

  if (std::strcmp(method, "update_drag") == 0) {
    if (context->dragging) {
      gint root_x = 0;
      gint root_y = 0;
      if (get_pointer_position(context->view, &root_x, &root_y)) {
        gtk_window_move(
            context->window,
            context->window_start_x + (root_x - context->pointer_start_x),
            context->window_start_y + (root_y - context->pointer_start_y));
      }
    }

    respond_success(method_call);
    return;
  }

  if (std::strcmp(method, "end_drag") == 0) {
    context->dragging = FALSE;
    respond_success(method_call);
    return;
  }

  if (std::strcmp(method, "resize_bar") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    gint width = context->width;
    gint height = context->height;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* width_value = fl_value_lookup_string(args, "width");
      FlValue* height_value = fl_value_lookup_string(args, "height");
      if (width_value != nullptr &&
          fl_value_get_type(width_value) == FL_VALUE_TYPE_INT) {
        width = static_cast<gint>(fl_value_get_int(width_value));
      }
      if (height_value != nullptr &&
          fl_value_get_type(height_value) == FL_VALUE_TYPE_INT) {
        height = static_cast<gint>(fl_value_get_int(height_value));
      }
    }

    if (width > 0 && height > 0 &&
        (width != context->width || height != context->height)) {
      context->width = width;
      context->height = height;
      gtk_widget_set_size_request(context->view, width, height);
      gtk_window_set_default_size(context->window, width, height);
      GdkGeometry geometry;
      geometry.min_width = kBarWidth;
      geometry.max_width = kBarWidth;
      geometry.min_height = kBarCompactHeight;
      geometry.max_height = kBarBubbleHeight;
      gtk_window_set_geometry_hints(
          context->window, context->view, &geometry,
          static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE));
      gtk_window_resize(context->window, width, height);
      if (!context->dragging) {
        move_bar_to_bottom(context->window, width, height);
      }
    }

    respond_success(method_call);
    return;
  }

  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

static void register_child_window_plugins(FlPluginRegistry* registry) {
  fl_register_plugins(registry);
  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registry_get_registrar_for_plugin(
          registry, "AuraChildWindowRegistrar");
  FlView* view = fl_plugin_registrar_get_view(registrar);
  GtkWidget* toplevel = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (!GTK_IS_WINDOW(toplevel)) {
    return;
  }

  GtkWindow* window = GTK_WINDOW(toplevel);

  GdkScreen* screen = gtk_window_get_screen(window);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr && gdk_screen_is_composited(screen)) {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
  }

  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* bar_window_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), "aura/bar_window",
      FL_METHOD_CODEC(codec));
  auto* move_context = g_new0(BarWindowMoveContext, 1);
  move_context->window = window;
  move_context->view = GTK_WIDGET(view);
  move_context->width = kBarWidth;
  move_context->height = kBarCompactHeight;
  fl_method_channel_set_method_call_handler(
      bar_window_channel, bar_window_method_call_cb, move_context, g_free);

  gtk_widget_set_size_request(GTK_WIDGET(view), kBarWidth, kBarCompactHeight);
  gtk_window_set_title(window, "AURA Bar");
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_resizable(window, FALSE);
  gtk_window_set_keep_above(window, TRUE);
  gtk_window_set_skip_taskbar_hint(window, TRUE);
  gtk_window_set_default_size(window, kBarWidth, kBarCompactHeight);
  GdkGeometry geometry;
  geometry.min_width = kBarWidth;
  geometry.max_width = kBarWidth;
  geometry.min_height = kBarCompactHeight;
  geometry.max_height = kBarBubbleHeight;
  gtk_window_set_geometry_hints(
      window, GTK_WIDGET(view), &geometry,
      static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE | GDK_HINT_MAX_SIZE));
  gtk_window_resize(window, kBarWidth, kBarCompactHeight);
  move_bar_to_bottom(window, kBarWidth, kBarCompactHeight);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "aura_notebook");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "aura_notebook");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  desktop_multi_window_plugin_set_window_created_callback(
      register_child_window_plugins);
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
