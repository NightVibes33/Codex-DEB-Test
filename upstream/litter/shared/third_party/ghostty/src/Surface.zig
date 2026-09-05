Warning: truncated output (original token count: 60085)
Total output lines: 6695

//! Surface represents a single terminal "surface". A terminal surface is
//! a minimal "widget" where the terminal is drawn and responds to events
//! such as keyboard and mouse. Each surface also creates and owns its pty
//! session.
//!
//! The word "surface" is used because it is left to the higher level
//! application runtime to determine if the surface is a window, a tab,
//! a split, a preview pane in a larger window, etc. This struct doesn't care:
//! it just draws and responds to events. The events come from the application
//! runtime so the runtime can determine when and how those are delivered
//! (i.e. with focus, without focus, and so on).
const Surface = @This();

const apprt = @import("apprt.zig");
pub const Mailbox = apprt.surface.Mailbox;
pub const Message = apprt.surface.Message;

const std = @import("std");
const builtin = @import("builtin");
const assert = @import("quirks.zig").inlineAssert;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const global_state = &@import("global.zig").state;
const oni = @import("oniguruma");
const crash = @import("crash/main.zig");
const unicode = @import("unicode/main.zig");
const rendererpkg = @import("renderer.zig");
const termio = @import("termio.zig");
const font = @import("font/main.zig");
const Command = @import("Command.zig");
const terminal = @import("terminal/main.zig");
const configpkg = @import("config.zig");
const Duration = configpkg.Config.Duration;
const input = @import("input.zig");
const App = @import("App.zig");
const internal_os = @import("os/main.zig");
const inspectorpkg = @import("inspector/main.zig");
const SurfaceMouse = @import("surface_mouse.zig");
const ProcessInfo = @import("pty.zig").ProcessInfo;

const log = std.log.scoped(.surface);

// The renderer implementation to use.
const Renderer = rendererpkg.Renderer;

/// Minimum window size in cells. This is used to prevent the window from
/// being resized to a size that is too small to be useful. These defaults
/// are chosen to match the default size of Mac's Terminal.app, but is
/// otherwise somewhat arbitrary.
pub const min_window_width_cells: u32 = 10;
pub const min_window_height_cells: u32 = 4;

/// The maximum number of key tables that can be active at any
/// given time. `activate_key_table` calls after this are ignored.
const max_active_key_tables = 8;

/// Unique ID used to identify this surface for IPC purposes. It is
/// exposed to the commands running in surfaces as the environment variable
/// GHOSTTY_SURFACE_ID. It must not be zero as zero is used to incicate a null
/// value when communicating an ID over DBus as DBus does not allow null/maybe
/// values.
id: u64,

/// Allocator
alloc: Allocator,

/// The app that this surface is attached to.
app: *App,

/// The windowing system surface and app.
rt_app: *apprt.runtime.App,
rt_surface: *apprt.runtime.Surface,

/// The font structures
font_grid_key: font.SharedGridSet.Key,
font_size: font.face.DesiredSize,
font_metrics: font.Metrics,

/// This keeps track of if the font size was ever modified. If it wasn't,
/// then config reloading will change the font. If it was manually adjusted,
/// we don't change it on config reload since we assume the user wants
/// a specific size.
font_size_adjusted: bool,

/// The renderer for this surface.
renderer: Renderer,

/// The render state
renderer_state: rendererpkg.State,

/// The renderer thread manager
renderer_thread: rendererpkg.Thread,

/// The actual thread
renderer_thr: std.Thread,

/// Mouse state.
mouse: Mouse,

/// Keyboard input state.
keyboard: Keyboard,

/// A currently pressed key. This is used so that we can send a keyboard
/// release event when the surface is unfocused. Note that when the surface
/// is refocused, a key press event may not be sent again -- this depends
/// on the apprt (UI framework) in use, but we want to consistently send
/// a release.
///
/// This is only sent when a keypress event results in a key event being
/// sent to the pty. If it is consumed by a keybinding or other action,
/// this is not set.
///
/// Also note the utf8 value is not valid for this event so some unfocused
/// release events may not send exactly the right data within Kitty keyboard
/// events. This seems unspecified in the spec so for now I'm okay with
/// this. Plus, its only for release events where the key text is far
/// less important.
pressed_key: ?input.KeyEvent = null,

/// The hash value of the last keybinding trigger that we performed. This
/// is only set if the last key input matched a keybinding, consumed it,
/// and performed it. This is used to prevent sending release/repeat events
/// for handled bindings.
last_binding_trigger: u64 = 0,

/// The terminal IO handler.
io: termio.Termio,
io_thread: termio.Thread,
io_thr: std.Thread,

/// Terminal inspector
inspector: ?*inspectorpkg.Inspector = null,

/// All our sizing information.
size: rendererpkg.Size,

/// The configuration derived from the main config. We "derive" it so that
/// we don't have a shared pointer hanging around that we need to worry about
/// the lifetime of. This makes updating config at runtime easier.
config: DerivedConfig,

/// The conditional state of the configuration. This can affect
/// how certain configurations take effect such as light/dark mode.
/// This is managed completely by Ghostty core but an apprt action
/// is sent whenever this changes.
config_conditional_state: configpkg.ConditionalState,

/// This is set to true if our IO thread notifies us our child exited.
/// This is used to determine if we need to confirm, hold open, etc.
child_exited: bool = false,

/// We maintain our focus state and assume we're focused by default.
/// If we're not initially focused then apprts can call focusCallback
/// to let us know.
focused: bool = true,

/// Used to determine whether to continuously scroll.
selection_scroll_active: bool = false,

/// True if the surface is in read-only mode. When read-only, no input
/// is sent to the PTY but terminal-level operations like selections,
/// (native) scrolling, and copy keybinds still work. Warn before quit is
/// always enabled in this state.
readonly: bool = false,

/// Used to send notifications that long running commands have finished.
/// Requires that shell integration be active. Should represent a nanosecond
/// precision timestamp. It does not necessarily need to correspond to the
/// actual time, but we must be able to compare two subsequent timestamps to get
/// the wall clock time that has elapsed between timestamps.
command_timer: ?std.time.Instant = null,

/// Search state
search: ?Search = null,

/// Used to rate limit BEL handling.
last_bell_time: ?std.time.Instant = null,

/// The effect of an input event. This can be used by callers to take
/// the appropriate action after an input event. For example, key
/// input can be forwarded to the OS for further processing if it
/// wasn't handled in any way by Ghostty.
pub const InputEffect = enum {
    /// The input was not handled in any way by Ghostty and should be
    /// forwarded to other subsystems (i.e. the OS) for further
    /// processing.
    ignored,

    /// The input was handled and consumed by Ghostty.
    consumed,

    /// The input resulted in a close event for this surface so
    /// the surface, runtime surface, etc. pointers may all be
    /// unsafe to use so exit immediately.
    closed,
};

/// The search state for the surface.
const Search = struct {
    state: terminal.search.Thread,
    thread: std.Thread,

    pub fn deinit(self: *Search) void {
        // Notify the thread to stop
        self.state.stop.notify() catch |err| log.err(
            "error notifying search thread to stop, may stall err={}",
            .{err},
        );

        // Wait for the OS thread to quit
        self.thread.join();

        // Now it is safe to deinit the state
        self.state.deinit();
    }
};

/// Mouse state for the surface.
const Mouse = struct {
    /// The last tracked mouse button state by button.
    click_state: [input.MouseButton.max]input.MouseButtonState = @splat(.release),

    /// The last mods state when the last mouse button (whatever it was) was
    /// pressed or release.
    mods: input.Mods = .{},

    /// The point at which the left mouse click happened. This is in screen
    /// coordinates so that scrolling preserves the location.
    left_click_pin: ?*terminal.Pin = null,
    left_click_screen: terminal.ScreenSet.Key = .primary,

    /// The starting xpos/ypos of the left click. Note that if scrolling occurs,
    /// these will point to different "cells", but the xpos/ypos will stay
    /// stable during scrolling relative to the surface.
    left_click_xpos: f64 = 0,
    left_click_ypos: f64 = 0,

    /// The count of clicks to count double and triple clicks and so on.
    /// The left click time was the last time the left click was done. This
    /// is always set on the first left click.
    left_click_count: u8 = 0,
    left_click_time: std.time.Instant = undefined,

    /// The last x/y sent for mouse reports.
    event_point: ?terminal.point.Coordinate = null,

    /// The pressure stage for the mouse. This should always be none if
    /// the mouse is not pressed.
    pressure_stage: input.MousePressureStage = .none,

    /// Pending scroll amounts for high-precision scrolls
    pending_scroll_x: f64 = 0,
    pending_scroll_y: f64 = 0,

    /// True if the mouse is hidden
    hidden: bool = false,

    /// True if the mouse position is currently over a link.
    over_link: bool = false,

    /// The last x/y in the cursor position for links. We use this to
    /// only process link hover events when the mouse actually moves cells.
    link_point: ?terminal.point.Coordinate = null,
};

/// Keyboard state for the surface.
pub const Keyboard = struct {
    /// The currently active key sequence for the surface. If this is null
    /// then we're not currently in a key sequence.
    sequence_set: ?*const input.Binding.Set = null,

    /// The queued keys when we're in the middle of a sequenced binding.
    /// These are flushed when the sequence is completed and unconsumed or
    /// invalid.
    ///
    /// This is naturally bounded due to the configuration maximum
    /// length of a sequence.
    sequence_queued: std.ArrayListUnmanaged(termio.Message.WriteReq) = .empty,

    /// The stack of tables that is currently active. The first value
    /// in this is the first activated table (NOT the default keybinding set).
    ///
    /// This is bounded by `max_active_key_tables`.
    table_stack: std.ArrayListUnmanaged(struct {
        set: *const input.Binding.Set,
        once: bool,
    }) = .empty,

    /// The last handled binding. This is used to prevent encoding release
    /// events for handled bindings. We only need to keep track of one because
    /// at least at the time of writing this, its impossible for two keys of
    /// a combination to be handled by different bindings before the release
    /// of the prior (namely since you can't bind modifier-only).
    last_trigger: ?u64 = null,
};

/// The configuration that a surface has, this is copied from the main
/// Config struct usually to prevent sharing a single value.
const DerivedConfig = struct {
    arena: ArenaAllocator,

    /// For docs for these, see the associated config they are derived from.
    original_font_size: f32,
    keybind: configpkg.Keybinds,
    abnormal_command_exit_runtime_ms: u32,
    clipboard_read: configpkg.ClipboardAccess,
    clipboard_write: configpkg.ClipboardAccess,
    clipboard_trim_trailing_spaces: bool,
    clipboard_paste_protection: bool,
    clipboard_paste_bracketed_safe: bool,
    clipboard_codepoint_map: configpkg.Config.RepeatableClipboardCodepointMap,
    copy_on_select: configpkg.CopyOnSelect,
    right_click_action: configpkg.RightClickAction,
    middle_click_action: configpkg.MiddleClickAction,
    confirm_close_surface: configpkg.ConfirmCloseSurface,
    cursor_click_to_move: bool,
    desktop_notifications: bool,
    font: font.SharedGridSet.DerivedConfig,
    mouse_interval: u64,
    mouse_hide_while_typing: bool,
    mouse_reporting: bool,
    mouse_scroll_multiplier: configpkg.MouseScrollMultiplier,
    mouse_shift_capture: configpkg.MouseShiftCapture,
    fullscreen: configpkg.Fullscreen,
    macos_non_native_fullscreen: configpkg.NonNativeFullscreen,
    macos_option_as_alt: ?input.OptionAsAlt,
    selection_clear_on_copy: bool,
    selection_clear_on_typing: bool,
    selection_word_chars: []const u21,
    vt_kam_allowed: bool,
    wait_after_command: bool,
    window_padding_top: u32,
    window_padding_bottom: u32,
    window_padding_left: u32,
    window_padding_right: u32,
    window_padding_balance: configpkg.Config.WindowPaddingBalance,
    window_height: u32,
    window_width: u32,
    title: ?[:0]const u8,
    title_report: bool,
    links: []DerivedConfig.Link,
    link_previews: configpkg.LinkPreviews,
    scroll_to_bottom: configpkg.Config.ScrollToBottom,
    notify_on_command_finish: configpkg.Config.NotifyOnCommandFinish,
    notify_on_command_finish_action: configpkg.Config.NotifyOnCommandFinishAction,
    notify_on_command_finish_after: Duration,
    key_remaps: input.KeyRemapSet,

    const Link = struct {
        regex: oni.Regex,
        action: input.Link.Action,
        highlight: input.Link.Highlight,
    };

    pub fn init(alloc_gpa: Allocator, config: *const configpkg.Config) !DerivedConfig {
        var arena = ArenaAllocator.init(alloc_gpa);
        errdefer arena.deinit();
        const alloc = arena.allocator();

        // Build all of our links
        const links = links: {
            var links: std.ArrayList(DerivedConfig.Link) = .empty;
            defer links.deinit(alloc);
            for (config.link.links.items) |link| {
                var regex = try link.oniRegex();
                errdefer regex.deinit();
                try links.append(alloc, .{
                    .regex = regex,
                    .action = link.action,
                    .highlight = link.highlight,
                });
            }

            break :links try links.toOwnedSlice(alloc);
        };
        errdefer {
            for (links) |*link| link.regex.deinit();
            alloc.free(links);
        }

        return .{
            .original_font_size = config.@"font-size",
            .keybind = try config.keybind.clone(alloc),
            .abnormal_command_exit_runtime_ms = config.@"abnormal-command-exit-runtime",
            .clipboard_read = config.@"clipboard-read",
            .clipboard_write = config.@"clipboard-write",
            .clipboard_trim_trailing_spaces = config.@"clipboard-trim-trailing-spaces",
            .clipboard_paste_protection = config.@"clipboard-paste-protection",
            .clipboard_paste_bracketed_safe = config.@"clipboard-paste-bracketed-safe",
            .clipboard_codepoint_map = try config.@"clipboard-codepoint-map".clone(alloc),
            .copy_on_select = config.@"copy-on-select",
            .right_click_action = config.@"right-click-action",
            .middle_click_action = config.@"middle-click-action",
            .confirm_close_surface = config.@"confirm-close-surface",
            .cursor_click_to_move = config.@"cursor-click-to-move",
            .desktop_notifications = config.@"desktop-notifications",
            .font = try font.SharedGridSet.DerivedConfig.init(alloc, config),
            .mouse_interval = config.@"click-repeat-interval" * 1_000_000, // 500ms
            .mouse_hide_while_typing = config.@"mouse-hide-while-typing",
            .mouse_reporting = config.@"mouse-reporting",
            .mouse_scroll_multiplier = config.@"mouse-scroll-multiplier",
            .mouse_shift_capture = config.@"mouse-shift-capture",
            .fullscreen = config.fullscreen,
            .macos_non_native_fullscreen = config.@"macos-non-native-fullscreen",
            .macos_option_as_alt = config.@"macos-option-as-alt",
            .selection_clear_on_copy = config.@"selection-clear-on-copy",
            .selection_clear_on_typing = config.@"selection-clear-on-typing",
            .selection_word_chars = try alloc.dupe(u21, config.@"selection-word-chars".codepoints),
            .vt_kam_allowed = config.@"vt-kam-allowed",
            .wait_after_command = config.@"wait-after-command",
            .window_padding_top = config.@"window-padding-y".top_left,
            .window_padding_bottom = config.@"window-padding-y".bottom_right,
            .window_padding_left = config.@"window-padding-x".top_left,
            .window_padding_right = config.@"window-padding-x".bottom_right,
            .window_padding_balance = config.@"window-padding-balance",
            .window_height = config.@"window-height",
            .window_width = config.@"window-width",
            .title = config.title,
            .title_report = config.@"title-report",
            .links = links,
            .link_previews = config.@"link-previews",
            .scroll_to_bottom = config.@"scroll-to-bottom",
            .notify_on_command_finish = config.@"notify-on-command-finish",
            .notify_on_command_finish_action = config.@"notify-on-command-finish-action",
            .notify_on_command_finish_after = config.@"notify-on-command-finish-after",
            .key_remaps = try config.@"key-remap".clone(alloc),

            // Assignments happen sequentially so we have to do this last
            // so that the memory is captured from allocs above.
            .arena = arena,
        };
    }

    pub fn deinit(self: *DerivedConfig) void {
        for (self.links) |*link| link.regex.deinit();
        self.arena.deinit();
    }

    fn scaledPadding(self: *const DerivedConfig, x_dpi: f32, y_dpi: f32) rendererpkg.Padding {
        const padding_top: u32 = padding_top: {
            const padding_top: f32 = @floatFromInt(self.window_padding_top);
            break :padding_top @intFromFloat(@floor(padding_top * y_dpi / 72));
        };
        const padding_bottom: u32 = padding_bottom: {
            const padding_bottom: f32 = @floatFromInt(self.window_padding_bottom);
            break :padding_bottom @intFromFloat(@floor(padding_bottom * y_dpi / 72));
        };
        const padding_left: u32 = padding_left: {
            const padding_left: f32 = @floatFromInt(self.window_padding_left);
            break :padding_left @intFromFloat(@floor(padding_left * x_dpi / 72));
        };
        const padding_right: u32 = padding_right: {
            const padding_right: f32 = @floatFromInt(self.window_padding_right);
            break :padding_right @intFromFloat(@floor(padding_right * x_dpi / 72));
        };

        return .{
            .top = padding_top,
            .bottom = padding_bottom,
            .left = padding_left,
            .right = padding_right,
        };
    }
};

/// Create a new surface. This must be called from the main thread. The
/// pointer to the memory for the surface must be provided and must be
/// stable due to interfacing with various callbacks.
pub fn init(
    self: *Surface,
    alloc: Allocator,
    config_original: *const configpkg.Config,
    app: *App,
    rt_app: *apprt.runtime.App,
    rt_surface: *apprt.runtime.Surface,
) !void {
    // Apply our conditional state. If we fail to apply the conditional state
    // then we log and attempt to move forward with the old config.
    var config_: ?configpkg.Config = config_original.changeConditionalState(
        app.config_conditional_state,
    ) catch |err| err: {
        log.warn("failed to apply conditional state to config err={}", .{err});
        break :err null;
    };
    defer if (config_) |*c| c.deinit();

    // We want a config pointer for everything so we get that either
    // based on our conditional state or the original config.
    const config: *const configpkg.Config = if (config_) |*c| config: {
        // We want to preserve our original working directory. We
        // don't need to dupe memory here because termio will derive
        // it. We preserve this so directory inheritance works.
        c.@"working-directory" = config_original.@"working-directory";
        break :config c;
    } else config_original;

    // Get our configuration
    var derived_config = try DerivedConfig.init(alloc, config);
    errdefer derived_config.deinit();

    // Initialize our renderer with our initialized surface.
    try Renderer.surfaceInit(rt_surface);

    // Determine our DPI configurations so we can properly configure
    // font points to pixels and handle other high-DPI scaling factors.
    const content_scale = try rt_surface.getContentScale();
    const x_dpi = content_scale.x * font.face.default_dpi;
    const y_dpi = content_scale.y * font.face.default_dpi;
    log.debug("xscale={} yscale={} xdpi={} ydpi={}", .{
        content_scale.x,
        content_scale.y,
        x_dpi,
        y_dpi,
    });

    // The font size we desire along with the DPI determined for the surface
    const font_size: font.face.DesiredSize = .{
        .points = config.@"font-size",
        .xdpi = @intFromFloat(x_dpi),
        .ydpi = @intFromFloat(y_dpi),
    };

    // Setup our font group. This will reuse an existing font group if
    // it was already loaded.
    const font_grid_key, const font_grid = try app.font_grid_set.ref(
        &derived_config.font,
        font_size,
    );

    // Build our size struct which has all the sizes we need.
    const size: rendererpkg.Size = size: {
        var size: rendererpkg.Size = .{
            .screen = screen: {
                const surface_size = try rt_surface.getSize();
                break :screen .{
                    .width = surface_size.width,
                    .height = surface_size.height,
                };
            },

            .cell = font_grid.cellSize(),
            .padding = .{},
        };

        const explicit: rendererpkg.Padding = derived_config.scaledPadding(
            x_dpi,
            y_dpi,
        );
        if (derived_config.window_padding_balance != .false) {
            size.balancePadding(explicit, derived_config.window_padding_balance);
        } else {
            size.padding = explicit;
        }

        break :size size;
    };

    // Create our terminal grid with the initial size
    const app_mailbox: App.Mailbox = .{ .rt_app = rt_app, .mailbox = &app.mailbox };
    var renderer_impl = try Renderer.init(alloc, .{
        .config = try .init(alloc, config),
        .font_grid = font_grid,
        .size = size,
        .surface_mailbox = .{ .surface = self, .app = app_mailbox },
        .rt_surface = rt_surface,
        .thread = &self.renderer_thread,
    });
    errdefer renderer_impl.deinit();

    // The mutex used to protect our renderer state.
    const mutex = try alloc.create(std.Thread.Mutex);
    mutex.* = .{};
    errdefer alloc.destroy(mutex);

    // Create the renderer thread
    var render_thread = try rendererpkg.Thread.init(
        alloc,
        config,
        rt_surface,
        &self.renderer,
        &self.renderer_state,
        app_mailbox,
    );
    errdefer render_thread.deinit();

    // Create the IO thread
    var io_thread = try termio.Thread.init(alloc);
    errdefer io_thread.deinit();

    self.* = .{
        .id = id: {
            while (true) {
                const candidate = std.crypto.random.int(u64);
                if (candidate == 0) continue;
                break :id candidate;
            }
        },
        .alloc = alloc,
        .app = app,
        .rt_app = rt_app,
        .rt_surface = rt_surface,
        .font_grid_key = font_grid_key,
        .font_size = font_size,
        .font_size_adjusted = false,
        .font_metrics = font_grid.metrics,
        .renderer = renderer_impl,
        .renderer_thread = render_thread,
        .renderer_state = .{
            .mutex = mutex,
            .terminal = &self.io.terminal,
        },
        .renderer_thr = undefined,
        .mouse = .{},
        .keyboard = .{},
        .io = undefined,
        .io_thread = io_thread,
        .io_thr = undefined,
        .size = size,
        .config = derived_config,

        // Our conditional state is initialized to the app state. This
        // lets us get the most likely correct color theme and so on.
        .config_conditional_state = app.config_conditional_state,
    };

    // The command we're going to execute
    const command: ?configpkg.Command = command: {
        if (app.first) {
            if (config.@"initial-command") |command| {
                break :command command;
            }
        }
        break :command config.command;
    };

    // Start our IO implementation
    // This separate block ({}) is important because our errdefers must
    // be scoped here to be valid.
    {
        const rt_external = if (@hasDecl(apprt.runtime.Surface, "externalPtyOptions"))
            rt_surface.externalPtyOptions()
        else
            null;
        var io_backend: termio.backend.Backend = if (rt_external) |external| backend: {
            break :backend .{ .external = .{
                .userdata = external.userdata,
                .write = external.write,
            } };
        } else backend: {
            var env = rt_surface.defaultTermioEnv() catch |err| env: {
                // If an error occurs, we don't want to block surface startup.
                log.warn("error getting env map for surface err={}", .{err});
                break :env internal_os.getEnvMap(alloc) catch
                    std.process.EnvMap.init(alloc);
            };
            errdefer env.deinit();

            // don't leak GHOSTTY_LOG to any subprocesses
            env.remove("GHOSTTY_LOG");

            var buf: [18]u8 = undefined;
            try env.put(
                "GHOSTTY_SURFACE_ID",
                std.fmt.bufPrint(&buf, "0x{x:0>16}", .{self.id}) catch unreachable,
            );

            // Initialize our IO backend
            const io_exec = try termio.Exec.init(alloc, .{
                .command = command,
                .env = env,
                .env_override = config.env,
                .shell_integration = config.@"shell-integration",
                .shell_integration_features = config.@"shell-integration-features",
                .cursor_blink = config.@"cursor-style-blink",
                .working_directory = if (config.@"working-directory") |wd| wd.value() else null,
                .resources_dir = global_state.resources_dir.host(),
                .term = config.term,
                .rt_pre_exec_info = .init(config),
                .rt_post_fork_info = .init(config),
            });

            break :backend .{ .exec = io_exec };
        };
        errdefer io_backend.deinit();

        // Initialize our IO mailbox
        var io_mailbox = try termio.Mailbox.initSPSC(alloc);
        errdefer io_mailbox.deinit(alloc);

        try termio.Termio.init(&self.io, alloc, .{
            .size = size,
            .full_config = config,
            .config = try termio.Termio.DerivedConfig.init(alloc, config),
            .backend = io_backend,
            .mailbox = io_mailbox,
            .renderer_state = &self.renderer_state,
            .renderer_wakeup = render_thread.wakeup,
            .renderer_mailbox = render_thread.mailbox,
            .surface_mailbox = .{ .surface = self, .app = app_mailbox },
        });
    }
    // Outside the block, IO has now taken ownership of our temporary state
    // so we can just defer this and not the subcomponents.
    errdefer self.io.deinit();

    // Report initial cell size on surface creation
    _ = try rt_app.performAction(
        .{ .surface = self },
        .cell_size,
        .{ .width = size.cell.width, .height = size.cell.height },
    );

    _ = try rt_app.performAction(
        .{ .surface = self },
        .size_limit,
        .{
            .min_width = size.cell.width * min_window_width_cells,
            .min_height = size.cell.height * min_window_height_cells,
            // No max:
            .max_width = 0,
            .max_height = 0,
        },
    );

    // Call our size callback which handles all our retina setup
    // Note: this shouldn't be necessary and when we clean up the surface
    // init stuff we should get rid of this. But this is required because
    // sizeCallback does retina-aware stuff we don't do here and don't want
    // to duplicate.
    try self.resize(self.size.screen);

    // Give the renderer one more opportunity to finalize any surface
    // setup on the main thread prior to spinning up the rendering thread.
    try renderer_impl.finalizeSurfaceInit(rt_surface);

    // Start our renderer thread
    self.renderer_thr = try std.Thread.spawn(
        .{},
        rendererpkg.Thread.threadMain,
        .{&self.renderer_thread},
    );
    self.renderer_thr.setName("renderer") catch {};

    // Start our IO thread
    self.io_thr = try std.Thread.spawn(
        .{},
        termio.Thread.threadMain,
        .{ &self.io_thread, &self.io },
    );
    self.io_thr.setName("io") catch {};

    // Determine our initial window size if configured. We need to do this
    // quite late in the process because our height/width are in grid dimensions,
    // so we need to know our cell sizes first.
    //
    // Note: it is important to do this after the renderer is setup above.
    // This allows the apprt to fully initialize the surface before we
    // start messing with the window.
    self.recomputeInitialSize() catch |err| {
        // We don't treat this as a fatal error because not setting
        // an initial size shouldn't stop our terminal from working.
        log.warn("unable to set initial window size: {}", .{err});
    };

    if (config.title) |title| {
        _ = try rt_app.performAction(
            .{ .surface = self },
            .set_title,
            .{ .title = title },
        );
    } else if ((comptime builtin.os.tag == .linux) and
        config.@"_xdg-terminal-exec")
    xdg: {
        // For xdg-terminal-exec execution we special-case and set the window
        // title to the command being executed. This allows window managers
        // to set custom styling based on the command being executed.
        const v = command orelse break :xdg;
        const title = v.string(alloc) catch |err| {
            log.warn(
                "error copying command for title, title will not be set err={}",
                .{err},
            );
            break :xdg;
        };
        defer alloc.free(title);
        _ = try rt_app.performAction(
            .{ .surface = self },
            .set_title,
            .{ .title = title },
        );
    } else if (command) |cmd| switch (cmd) {
        // If a user specifies a command it is appropriate to set the title as argv[0]
        // we know in the case of a direct command it has been supplied by the user
        .direct => |cmd_str| if (cmd_str.len != 0) {
            _ = try rt_app.performAction(
                .{ .surface = self },
                .set_title,
                .{ .title = cmd_str[0] },
            );
        },

        // We won't set the title in the case the shell expands the command
        // as that should typically be used to launch a shell which should
        // set its own titles
        .shell => {},
    };

    // We are no longer the first surface
    app.first = false;
}

pub fn deinit(self: *Surface) void {
    // Stop search thread
    if (self.search) |*s| s.deinit();

    // Stop rendering thread
    {
        self.renderer_thread.stop.notify() catch |err|
            log.err("error notifying renderer thread to stop, may stall err={}", .{err});
        self.renderer_thr.join();

        // We need to become the active rendering thread again
        self.renderer.threadEnter(self.rt_surface) catch unreachable;
    }

    // Stop our IO thread
    {
        self.io_thread.stop.notify() catch |err|
            log.err("error notifying io thread to stop, may stall err={}", .{err});
        self.io_thr.join();
    }

    // We need to deinit AFTER everything is stopped, since there are
    // shared values between the two threads.
    self.renderer_thread.deinit();
    self.renderer.deinit();
    self.io_thread.deinit();
    self.io.deinit();

    if (self.inspector) |v| {
        v.deinit(self.alloc);
        self.alloc.destroy(v);
    }

    // Clean up our keyboard state
    for (self.keyboard.sequence_queued.items) |req| req.deinit();
    self.keyboard.sequence_queued.deinit(self.alloc);
    self.keyboard.table_stack.deinit(self.alloc);

    // Clean up our font grid
    self.app.font_grid_set.deref(self.font_grid_key);

    // Clean up our render state
    if (self.renderer_state.preedit) |p| self.alloc.free(p.codepoints);
    self.alloc.destroy(self.renderer_state.mutex);
    self.config.deinit();

    log.info("surface closed addr={x}", .{@intFromPtr(self)});
}

/// Close this surface. This will trigger the runtime to start the
/// close process, which should ultimately deinitialize this surface.
pub fn close(self: *Surface) void {
    self.rt_surface.close(self.needsConfirmQuit());
}

/// Returns a mailbox that can be used to send messages to this surface.
inline fn surfaceMailbox(self: *Surface) Mailbox {
    return .{
        .surface = self,
        .app = .{ .rt_app = self.rt_app, .mailbox = &self.app.mailbox },
    };
}

/// Queue a message for the IO thread.
///
/// We centralize all our logic into this spot so we can intercept
/// messages for example in readonly mode.
fn queueIo(
    self: *Surface,
    msg: termio.Message,
    mutex: termio.Termio.MutexState,
) void {
    // In readonly mode, we don't allow any writes through to the pty.
    if (self.readonly) {
        switch (msg) {
            .write_small,
            .write_stable,
            .write_alloc,
            => return,

            else => {},
        }
    }

    self.io.queueMessage(msg, mutex);
}

/// Forces the surface to render. This is useful for when the surface
/// is in the middle of animation (such as a resize, etc.) or when
/// the render timer is managed manually by the apprt.
pub fn draw(self: *Surface) !void {
    // Renderers are required to support `drawFrame` being called from
    // the main thread, so that they can update contents during resize.
    try self.renderer.drawFrame(true);
}

/// Activate the inspector. This will begin collecting inspection data.
/// This will not affect the GUI. The GUI must use performAction to
/// show/hide the inspector UI.
pub fn activateInspector(self: *Surface) !void {
    if (self.inspector != null) return;

    // Setup the inspector
    const ptr = try self.alloc.create(inspectorpkg.Inspector);
    errdefer self.alloc.destroy(ptr);
    ptr.* = try inspectorpkg.Inspector.init(self.alloc);
    errdefer ptr.deinit(self.alloc);
    self.inspector = ptr;
    errdefer self.inspector = null;

    // Put the inspector onto the render state
    {
        self.renderer_state.mutex.lock();
        defer self.renderer_state.mutex.unlock();
        assert(self.renderer_state.inspector == null);
        self.renderer_state.inspector = self.inspector;
    }

    // Notify our components we have an inspector active
    _ = self.renderer_thread.mailbox.push(.{ .inspector = true }, .{ .forever = {} });
    self.queueIo(.{ .inspector = true }, .unlocked);
}

/// Deactivate the inspector and stop collecting any information.
pub fn deactivateInspector(self: *Surface) void {
    const insp = self.inspector orelse return;

    // Remove the inspector from the render state
    {
        self.renderer_state.mutex.lock();
        defer self.renderer_state.mutex.unlock();
        assert(self.renderer_state.inspector != null);
        self.renderer_state.inspector = null;
    }

    // Notify our components we have deactivated inspector
    _ = self.renderer_thread.mailbox.push(.{ .inspector = false }, .{ .forever = {} });
    self.queueIo(.{ .inspector = false }, .unlocked);

    // Deinit the inspector
    insp.deinit(self.alloc);
    self.alloc.destroy(insp);
    self.inspector = null;
}

/// True if the surface requires confirmation to quit. This should be called
/// by apprt to determine if the surface should confirm before quitting.
pub fn needsConfirmQuit(self: *Surface) bool {
    // If the surface is in read-only mode, always require confirmation
    if (self.readonly) return true;

    // If the child has exited, then our process is certainly not alive.
    // We check this first to avoid the locking overhead below.
    if (self.child_exited) return false;

    // Check the configuration for confirming close behavior.
    return switch (self.config.confirm_close_surface) {
        .always => true,
        .false => false,
        .true => true: {
            self.renderer_state.mutex.lock();
            defer self.renderer_state.mutex.unlock();
            break :true !self.io.terminal.cursorIsAtPrompt();
        },
    };
}

/// Called from the app thread to handle mailbox messages to our specific
/// surface.
pub fn handleMessage(self: *Surface, msg: Message) !void {
    switch (msg) {
        .change_config => |config| try self.updateConfig(config),

        .set_title => |*v| {
            // We ignore the message in case the title was set via config.
            if (self.config.title != null) {
                log.debug("ignoring title change request since static title is set via config", .{});
                return;
            }

            // The ptrCast just gets sliceTo to return the proper type.
            // We know that our title should end in 0.
            const slice = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(v)), 0);
            log.debug("changing title \"{s}\"", .{slice});
            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .set_title,
                .{ .title = slice },
            );
        },

        .report_title => |style| report_title: {
            if (!self.config.title_report) {
                log.info("report_title requested, but disabled via config", .{});
                break :report_title;
            }

            const title: ?[:0]const u8 = self.rt_surface.getTitle();
            const data = switch (style) {
                .csi_21_t => try std.fmt.allocPrint(
                    self.alloc,
                    "\x1b]l{s}\x1b\\",
                    .{title orelse ""},
                ),
            };

            // We always use an allocating message because we don't know
            // the length of the title and this isn't a performance critical
            // path.
            self.queueIo(.{
                .write_alloc = .{
                    .alloc = self.alloc,
                    .data = data,
                },
            }, .unlocked);
        },

        .color_change => |change| color_change: {
            // Notify our apprt, but don't send a mode 2031 DSR report
            // because VT sequences were used to change the color.
            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .color_change,
                .{
                    .kind = switch (change.target) {
                        .palette => |v| @enumFromInt(v),
                        .dynamic => |dyn| switch (dyn) {
                            .foreground => .foreground,
                            .background => .background,
                            .cursor => .cursor,
                            // Unsupported dynamic color change notification type
                            else => break :color_change,
                        },
                        // Special colors aren't supported for change notification
                        .special => break :color_change,
                    },
                    .r = change.color.r,
                    .g = change.color.g,
                    .b = change.color.b,
                },
            );
        },

        .set_mouse_shape => |shape| {
            log.debug("changing mouse shape: {}", .{shape});
            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .mouse_shape,
                shape,
            );
        },

        .clipboard_read => |clipboard| {
            if (self.config.clipboard_read == .deny) {
                log.info("application attempted to read clipboard, but 'clipboard-read' is set to deny", .{});
                return;
            }

            _ = try self.startClipboardRequest(.standard, .{ .osc_52_read = clipboard });
        },

        .clipboard_write => |w| switch (w.req) {
            .small => |v| try self.clipboardWrite(v.data[0..v.len], w.clipboard_type),
            .stable => |v| try self.clipboardWrite(v, w.clipboard_type),
            .alloc => |v| {
                defer v.alloc.free(v.data);
                try self.clipboardWrite(v.data, w.clipboard_type);
            },
        },

        .pwd_change => |w| {
            defer w.deinit();

            // We always allocate for this because we need to null-terminate.
            const str = try self.alloc.dupeZ(u8, w.slice());
            defer self.alloc.free(str);

            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .pwd,
                .{ .pwd = str },
            );
        },

        .close => self.close(),

        .child_exited => |v| self.childExited(v),

        .desktop_notification => |notification| {
            if (!self.config.desktop_notifications) {
                log.info("application attempted to display a desktop notification, but 'desktop-notifications' is disabled", .{});
                return;
            }

            const title = std.mem.sliceTo(&notification.title, 0);
            const body = std.mem.sliceTo(&notification.body, 0);
            try self.showDesktopNotification(title, body);
        },

        .renderer_health => |health| self.updateRendererHealth(health),

        .scrollbar => |scrollbar| self.updateScrollbar(scrollbar),

        .present_surface => try self.presentSurface(),

        .password_input => |v| try self.passwordInput(v),

        .ring_bell => bell: {
            const now = std.time.Instant.now() catch unreachable;
            if (self.last_bell_time) |last| {
                if (now.since(last) < 100 * std.time.ns_per_ms) break :bell;
            }
            self.last_bell_time = now;
            _ = self.rt_app.performAction(
                .{ .surface = self },
                .ring_bell,
                {},
            ) catch |err| {
                log.warn("apprt failed to ring bell={}", .{err});
            };
        },

        .progress_report => |v| {
            _ = self.rt_app.performAction(
                .{ .surface = self },
                .progress_report,
                v,
            ) catch |err| {
                log.warn("apprt failed to report progress err={}", .{err});
            };
        },

        .selection_scroll_tick => |active| {
            self.selection_scroll_active = active;
            try self.selectionScrollTick();
        },

        .start_command => {
            self.command_timer = try .now();
        },

        .stop_command => |v| timer: {
            const end: std.time.Instant = try .now();
            const start = self.command_timer orelse break :timer;
            self.command_timer = null;

            const duration: Duration = .{ .duration = end.since(start) };
            log.debug("command took {f}", .{duration});

            _ = self.rt_app.performAction(
                .{ .surface = self },
                .command_finished,
                .{
                    .exit_code = v,
                    .duration = duration,
                },
            ) catch |err| {
                log.warn("apprt failed to notify command finish={}", .{err});
            };
        },

        .search_total => |v| {
            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .search_total,
                .{ .total = v },
            );
        },

        .search_selected => |v| {
            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .search_selected,
                .{ .selected = v },
            );
        },
    }
}

fn selectionScrollTick(self: *Surface) !void {
    // If we're no longer active then we don't do anything.
    if (!self.selection_scroll_active) return;

    // If we don't have a left mouse button down then we
    // don't do anything.
    if (self.mouse.left_click_count == 0) return;

    const pos = try self.rt_surface.getCursorPos();
    const pos_vp = self.posToViewport(pos.x, pos.y);
    const delta: isize = if (pos.y < 0) -1 else 1;

    // We need our locked state for the remainder
    self.renderer_state.mutex.lock();
    defer self.renderer_state.mutex.unlock();
    const t: *terminal.Terminal = self.renderer_state.terminal;

    // If our screen changed while this is happening, we stop our
    // selection scroll.
    if (self.mouse.left_click_screen != t.screens.active_key) {
        self.queueIo(
            .{ .selection_scroll = false },
            .locked,
        );
        return;
    }

    // Scroll the viewport as required
    t.scrollViewport(.{ .delta = delta });

    // Next, trigger our drag behavior
    const pin = t.screens.active.pages.pin(.{
        .viewport = .{
            .x = pos_vp.x,
            .y = pos_vp.y,
        },
    }) orelse {
        if (comptime std.debug.runtime_safety) unreachable;
        return;
    };
    try self.dragLeftClickSingle(pin, pos.x);

    // We modified our viewport and selection so we need to queue
    // a render.
    try self.queueRender();
}

fn childExited(self: *Surface, info: apprt.surface.Message.ChildExited) void {
    // Mark our flag that we exited immediately
    self.child_exited = true;

    // If our runtime was below some threshold then we assume that this
    // was an abnormal exit and we show an error message.
    if (info.runtime_ms <= self.config.abnormal_command_exit_runtime_ms) runtime: {
        // On macOS, our exit code detection doesn't work, possibly
        // because of our `login` wrapper. More investigation required.
        if (comptime !builtin.target.os.tag.isDarwin()) {
            // If the exit code is 0 then it was a good exit.
            if (info.exit_code == 0) break :runtime;
        }

        log.warn("abnormal process exit detected, showing error message", .{});

        // Try and show a GUI message. If it returns true, don't do anything else.
        if (self.rt_app.performAction(
            .{ .surface = self },
            .show_child_exited,
            info,
        ) catch |err| gui: {
            log.err("error trying to show native child exited GUI err={}", .{err});
            break :gui false;
        }) return;

        // If a native GUI notification was not shown, update our terminal to
        // note the abnormal exit.
        self.childExitedAbnormally(info) catch |err| {
            log.err("error handling abnormal child exit err={}", .{err});
            return;
        };

        return;
    }

    // We output a message so that the user knows what's going on and
    // doesn't think their terminal just froze. We show this unconditionally
    // on close even if `wait_after_command` is false and the surface closes
    // immediately because if a user does an `undo` to restore a closed
    // surface then they will see this message and know the process has
    // completed.
    terminal: {
        // First try and show a native GUI message.
        if (self.rt_app.performAction(
            .{ .surface = self },
            .show_child_exited,
            info,
        ) catch |err| gui: {
            log.err("error trying to show native child exited GUI err={}", .{err});
            break :gui false;
        }) break :terminal;

        // If the native GUI can't be shown, display a text message in the
        // terminal.
        self.renderer_state.mutex.lock();
        defer self.renderer_state.mutex.unlock();
        const t: *terminal.Terminal = self.renderer_state.terminal;
        t.carriageReturn();
        t.linefeed() catch break :terminal;
        t.printString("Process exited. Press any key to close the terminal.") catch
            break :terminal;
        t.modes.set(.cursor_visible, false);

        // We also want to ensure that normal keyboard encoding is on
        // so that we can close the terminal. We close the terminal on
        // any key press that encodes a character.
        t.modes.set(.disable_keyboard, false);
        t.screens.active.kitty_keyboard.set(.set, .disabled);
    }

    // Waiting after command we stop here. The terminal is updated, our
    // state is updated, and now its up to the user to decide what to do.
    if (self.config.wait_after_command) return;

    // If we aren't waiting after the command, then we exit immediately
    // with no confirmation.
    self.close();
}

/// Called when the child process exited abnormally.
fn childExitedAbnormally(
    self: *Surface,
    info: apprt.surface.Message.ChildExited,
) !void {
    var arena = ArenaAllocator.init(self.alloc);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Build up our command for the error message
    const command_args: []const []const u8 = switch (self.io.backend) {
        .exec => |*exec| exec.subprocess.args,
        .external => &.{"external pty"},
    };
    const command = try std.mem.join(alloc, " ", command_args);
    const runtime_str = try std.fmt.allocPrint(alloc, "{d} ms", .{info.runtime_ms});

    self.renderer_state.mutex.lock();
    defer self.renderer_state.mutex.unlock();
    const t: *terminal.Terminal = self.renderer_state.terminal;

    // No matter what move the cursor back to the column 0.
    t.carriageReturn();

    // Reset styles
    try t.setAttribute(.{ .unset = {} });

    // If there is data in the viewport, we want to scroll down
    // a little bit and write a horizontal rule before writing
    // our message. This lets the use see the error message the
    // command may have output.
    const viewport_str = try t.plainString(alloc);
    if (viewport_str.len > 0) {
        try t.linefeed();
        for (0..t.cols) |_| try t.print(0x2501);
        t.carriageReturn();
        try t.linefeed();
        try t.linefeed();
    }

    // Output our error message
    try t.setAttribute(.{ .@"8_fg" = .bright_red });
    try t.setAttribute(.{ .bold = {} });
    try t.printString("Ghostty failed to launch the requested command:");
    try t.setAttribute(.{ .unset = {} });

    t.carriageReturn();
    try t.linefeed();
    try t.linefeed();
    try t.printString(command);
    try t.setAttribute(.{ .unset = {} });

    t.carriageReturn();
    try t.linefeed();
    try t.linefeed();
    try t.printString("Runtime: ");
    try t.setAttribute(.{ .@"8_fg" = .red });
    try t.printString(runtime_str);
    try t.setAttribute(.{ .unset = {} });

    // We don't print this on macOS because the exit code is always 0
    // due to the way we launch the process.
    if (comptime !builtin.target.os.tag.isDarwin()) {
        const exit_code_str = try std.fmt.allocPrint(alloc, "{d}", .{info.exit_code});
        t.carriageReturn();
        try t.linefeed();
        try t.printString("Exit Code: ");
        try t.setAttribute(.{ .@"8_fg" = .red });
        try t.printString(exit_code_str);
        try t.setAttribute(.{ .unset = {} });
    }

    t.carriageReturn();
    try t.linefeed();
    try t.linefeed();
    try t.printString("Press any key to close the window.");

    // Hide the cursor
    t.modes.set(.cursor_visible, false);
}

/// Called when the terminal detects there is a password input prompt.
fn passwordInput(self: *Surface, v: bool) !void {
    {
        self.renderer_state.mutex.lock();
        defer self.renderer_state.mutex.unlock();

        // If our password input state is unchanged then we don't
        // waste time doing anything more.
        const old = self.io.terminal.flags.password_input;
        if (old == v) return;

        self.io.terminal.flags.password_input = v;
    }

    // Notify our apprt so it can do whatever it wants.
    _ = self.rt_app.performAction(
        .{ .surface = self },
        .secure_input,
        if (v) .on else .off,
    ) catch |err| {
        // We ignore this error because we don't want to fail this
        // entire operation just because the apprt failed to set
        // the secure input state.
        log.warn("apprt failed to set secure input state err={}", .{err});
    };

    try self.queueRender();
}

fn searchCallback(event: terminal.search.Thread.Event, ud: ?*anyopaque) void {
    // IMPORTANT: This function is run on the SEARCH THREAD! It is NOT SAFE
    // to access anything other than values that never change on the surface.
    // The surface is guaranteed to be valid for the lifetime of the search
    // thread.
    const self: *Surface = @ptrCast(@alignCast(ud.?));
    self.searchCallback_(event) catch |err| {
        log.warn("error in search callback err={}", .{err});
    };
}

fn searchCallback_(
    self: *Surface,
    event: terminal.search.Thread.Event,
) !void {
    // NOTE: This runs on the search thread.

    switch (event) {
        .viewport_matches => |matches_unowned| {
            var arena: ArenaAllocator = .init(self.alloc);
            errdefer arena.deinit();
            const alloc = arena.allocator();

            const matches = try alloc.dupe(terminal.highlight.Flattened, matches_unowned);
            for (matches) |*m| m.* = try m.clone(alloc);

            _ = self.renderer_thread.mailbox.push(
                .{ .search_viewport_matches = .{
                    .arena = arena,
                    .matches = matches,
                } },
                .forever,
            );
            try self.renderer_thread.wakeup.notify();
        },

        .selected_match => |selected_| {
            if (selected_) |sel| {
                // Copy the flattened match.
                var arena: ArenaAllocator = .init(self.alloc);
                errdefer arena.deinit();
                const alloc = arena.allocator();
                const match = try sel.highlight.clone(alloc);

                _ = self.renderer_thread.mailbox.push(
                    .{ .search_selected_match = .{
                        .arena = arena,
                        .match = match,
                    } },
                    .forever,
                );

                // Send the selected index to the surface mailbox
                _ = self.surfaceMailbox().push(
                    .{ .search_selected = sel.idx },
                    .forever,
                );
            } else {
                // Reset our selected match
                _ = self.renderer_thread.mailbox.push(
                    .{ .search_selected_match = null },
                    .forever,
                );

                // Reset the selected index
                _ = self.surfaceMailbox().push(
                    .{ .search_selected = null },
                    .forever,
                );
            }

            try self.renderer_thread.wakeup.notify();
        },

        .total_matches => |total| {
            _ = self.surfaceMailbox().push(
                .{ .search_total = total },
                .forever,
            );
        },

        // When we quit, tell our renderer to reset any search state.
        .quit => {
            _ = self.renderer_thread.mailbox.push(
                .{ .search_selected_match = null },
                .forever,
            );
            _ = self.renderer_thread.mailbox.push(
                .{ .search_viewport_matches = .{
                    .arena = .init(self.alloc),
                    .matches = &.{},
                } },
                .forever,
            );
            try self.renderer_thread.wakeup.notify();

            // Reset search totals in the surface
            _ = self.surfaceMailbox().push(
                .{ .search_total = null },
                .forever,
            );
            _ = self.surfaceMailbox().push(
                .{ .search_selected = null },
                .forever,
            );
        },

        // Unhandled, so far.
        .complete => {},
    }
}

/// Call this when modifiers change. This is safe to call even if modifiers
/// match the previous state.
///
/// This is not publicly exported because modifier changes happen implicitly
/// on mouse callbacks, key callbacks, etc.
///
/// The renderer state mutex MUST NOT be held.
fn modsChanged(self: *Surface, mods: input.Mods) void {
    // The only place we keep track of mods currently is on the mouse.
    if (!self.mouse.mods.equal(mods)) {
        // The mouse mods only contain binding modifiers since we don't
        // want caps/num lock or sided modifiers to affect the mouse.
        self.mouse.mods = mods.binding();

        // We also need to update the renderer so it knows if it should
        // highlight links. Additionally, mark the screen as dirty so
        // that the highlight state of all links is properly updated.
        {
            self.renderer_state.mutex.lock();
            defer self.renderer_state.mutex.unlock();
            self.renderer_state.mouse.mods = self.mouseModsWithCapture(self.mouse.mods);

            // We use the clear screen dirty flag to force a rebuild of all
            // rows because changing mouse mods can affect the highlight state
            // of a link. If there is no link this seems very wasteful but
            // its really only one frame so it's not so bad.
            self.renderer_state.terminal.flags.dirty.clear = true;
        }

        self.queueRender() catch |err| {
            // Not a big deal if this fails.
            log.warn("failed to notify renderer of mods change err={}", .{err});
        };
    }
}

/// Call this whenever the mouse moves or mods changed. The time
/// at which this is called may matter for the correctness of other
/// mouse events (see cursorPosCallback) but this is shared logic
/// for multiple events.
fn mouseRefreshLinks(
    self: *Surface,
    pos: apprt.CursorPos,
    pos_vp: terminal.point.Coordinate,
    over_link: bool,
) !void {
    // If the position is outside our viewport, do nothing
    if (pos.x < 0 or pos.y < 0) return;

    // Update the last point that we checked for links so we don't
    // recheck if the mouse moves some pixels to the same point.
    self.mouse.link_point = pos_vp;

    // We use an arena for everything below to make things easy to clean up.
    // In the case we don't do any allocs this is very cheap to setup
    // (effectively just struct init).
    var arena = ArenaAllocator.init(self.alloc);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Get our link at the current position. This returns null if there
    // isn't a link OR if we shouldn't be showing links for some reason
    // (see further comments for cases).
    const link_: ?apprt.action.MouseOverLink, const preview: bool = link: {
        // If we clicked and our mouse moved cells then we never
        // highlight links until the mouse is unclicked. This follows
        // standard macOS and Linux behavior where a click and drag cancels
        // mouse actions.
        const left_idx = @intFromEnum(input.MouseButton.left);
        if (self.mouse.click_state[left_idx] == .press) click: {
            const pin = self.mouse.left_click_pin orelse break :click;
            const click_pt = self.io.terminal.screens.active.pages.pointFromPin(
                .viewport,
                pin.*,
            ) orelse break :cl…30085 tokens truncated… drag_x_frac < threshold_point
    else
        drag_x_frac >= threshold_point;

    // If the click cell should be included in the selection then it's the
    // start, otherwise we get the previous or next cell to it depending on
    // the type and direction of the selection.
    const start_pin =
        if (include_click_cell)
            click_pin
        else if (end_before_start)
            if (rectangle_selection)
                click_pin.leftClamp(1)
            else
                click_pin.leftWrap(1) orelse click_pin
        else if (rectangle_selection)
            click_pin.rightClamp(1)
        else
            click_pin.rightWrap(1) orelse click_pin;

    // Likewise for the end pin with the drag cell.
    const end_pin =
        if (include_drag_cell)
            drag_pin
        else if (end_before_start)
            if (rectangle_selection)
                drag_pin.rightClamp(1)
            else
                drag_pin.rightWrap(1) orelse drag_pin
        else if (rectangle_selection)
            drag_pin.leftClamp(1)
        else
            drag_pin.leftWrap(1) orelse drag_pin;

    // If the click cell is the same as the drag cell and the click cell
    // shouldn't be included, or if the cells are adjacent such that the
    // start or end pin becomes the other cell, and that cell should not
    // be included, then we have no selection, so we set it to null.
    //
    // If in rectangular selection mode, we compare columns as well.
    //
    // TODO(qwerasd): this can/should probably be refactored, it's a bit
    //                repetitive and does excess work in rectangle mode.
    if ((!include_click_cell and same_pin) or
        (!include_click_cell and rectangle_selection and click_pin.x == drag_pin.x) or
        (!include_click_cell and end_pin.eql(click_pin)) or
        (!include_click_cell and rectangle_selection and end_pin.x == click_pin.x) or
        (!include_drag_cell and start_pin.eql(drag_pin)) or
        (!include_drag_cell and rectangle_selection and start_pin.x == drag_pin.x))
    {
        return null;
    }

    // TODO: Clamp selection to the screen area, don't
    //       let it extend past the last written row.

    return .init(
        start_pin,
        end_pin,
        rectangle_selection,
    );
}

/// Call to notify Ghostty that the color scheme for the terminal has
/// changed.
pub fn colorSchemeCallback(self: *Surface, scheme: apprt.ColorScheme) !void {
    // Crash metadata in case we crash in here
    crash.sentry.thread_state = self.crashThreadState();
    defer crash.sentry.thread_state = null;

    const new_scheme: configpkg.ConditionalState.Theme = switch (scheme) {
        .light => .light,
        .dark => .dark,
    };

    // If our scheme didn't change, then we don't do anything.
    if (self.config_conditional_state.theme == new_scheme) return;

    // Setup our conditional state which has the current color theme.
    self.config_conditional_state.theme = new_scheme;
    self.notifyConfigConditionalState();

    // If mode 2031 is on, then we report the change live.
    self.queueIo(.{ .color_scheme_report = .{ .force = false } }, .unlocked);
}

pub fn posToViewport(self: Surface, xpos: f64, ypos: f64) terminal.point.Coordinate {
    // Get our grid cell
    const coord: rendererpkg.Coordinate = .{ .surface = .{ .x = xpos, .y = ypos } };
    const grid = coord.convert(.grid, self.size).grid;
    return .{ .x = grid.x, .y = grid.y };
}

/// Scroll to the bottom of the viewport.
///
/// Precondition: the render_state mutex must be held.
fn scrollToBottom(self: *Surface) !void {
    self.io.terminal.scrollViewport(.{ .bottom = {} });
    try self.queueRender();
}

fn hideMouse(self: *Surface) void {
    if (self.mouse.hidden) return;
    self.mouse.hidden = true;
    _ = self.rt_app.performAction(
        .{ .surface = self },
        .mouse_visibility,
        .hidden,
    ) catch |err| {
        log.warn("apprt failed to set mouse visibility err={}", .{err});
    };
}

fn showMouse(self: *Surface) void {
    if (!self.mouse.hidden) return;
    self.mouse.hidden = false;
    _ = self.rt_app.performAction(
        .{ .surface = self },
        .mouse_visibility,
        .visible,
    ) catch |err| {
        log.warn("apprt failed to set mouse visibility err={}", .{err});
    };
}

/// Perform a binding action. A binding is a keybinding. This function
/// must be called from the GUI thread.
///
/// This function returns true if the binding action was performed. This
/// may return false if the binding action is not supported or if the
/// binding action would do nothing (i.e. previous tab with no tabs).
///
/// NOTE: At the time of writing this comment, only previous/next tab
/// will ever return false. We can expand this in the future if it becomes
/// useful. We did previous/next tab so we could implement #498.
pub fn performBindingAction(self: *Surface, action: input.Binding.Action) !bool {
    // Forward app-scoped actions to the app. Some app-scoped actions are
    // special-cased here because they do some special things when performed
    // from the surface.
    if (action.scoped(.app)) |app_action| {
        switch (app_action) {
            .new_window => try self.app.newWindow(
                self.rt_app,
                .{ .parent = self },
            ),

            // Undo and redo both support both surface and app targeting.
            // If we are triggering on a surface then we perform the
            // action with the surface target.
            .undo => return try self.rt_app.performAction(
                .{ .surface = self },
                .undo,
                {},
            ),

            .redo => return try self.rt_app.performAction(
                .{ .surface = self },
                .redo,
                {},
            ),

            else => try self.app.performAction(
                self.rt_app,
                action.scoped(.app).?,
            ),
        }
        return true;
    }

    switch (action.scoped(.surface).?) {
        .csi, .esc => |data| {
            // We need to send the CSI/ESC sequence as a single write request.
            // If you split it across two then the shell can interpret it
            // as two literals.
            var buf: [128]u8 = undefined;
            const full_data = switch (action) {
                .csi => try std.fmt.bufPrint(&buf, "\x1b[{s}", .{data}),
                .esc => try std.fmt.bufPrint(&buf, "\x1b{s}", .{data}),
                else => unreachable,
            };
            self.queueIo(try termio.Message.writeReq(
                self.alloc,
                full_data,
            ), .unlocked);

            // CSI/ESC triggers a scroll.
            {
                self.renderer_state.mutex.lock();
                defer self.renderer_state.mutex.unlock();
                self.scrollToBottom() catch |err| {
                    log.warn("error scrolling to bottom err={}", .{err});
                };
            }
        },

        .text => |data| {
            // For text we always allocate just because its easier to
            // handle all cases that way.
            const buf = try self.alloc.alloc(u8, data.len);
            defer self.alloc.free(buf);
            const text = configpkg.string.parse(buf, data) catch |err| {
                log.warn(
                    "error parsing text binding text={s} err={}",
                    .{ data, err },
                );
                return true;
            };
            self.queueIo(try termio.Message.writeReq(
                self.alloc,
                text,
            ), .unlocked);

            // Text triggers a scroll.
            {
                self.renderer_state.mutex.lock();
                defer self.renderer_state.mutex.unlock();
                self.scrollToBottom() catch |err| {
                    log.warn("error scrolling to bottom err={}", .{err});
                };
            }
        },

        .cursor_key => |ck| {
            // We send a different sequence depending on if we're
            // in cursor keys mode. We're in "normal" mode if cursor
            // keys mode is NOT set.
            const normal = normal: {
                self.renderer_state.mutex.lock();
                defer self.renderer_state.mutex.unlock();

                // With the lock held, we must scroll to the bottom.
                // We always scroll to the bottom for these inputs.
                self.scrollToBottom() catch |err| {
                    log.warn("error scrolling to bottom err={}", .{err});
                };

                break :normal !self.io.terminal.modes.get(.cursor_keys);
            };

            if (normal) {
                self.queueIo(.{ .write_stable = ck.normal }, .unlocked);
            } else {
                self.queueIo(.{ .write_stable = ck.application }, .unlocked);
            }
        },

        .reset => {
            self.renderer_state.mutex.lock();
            defer self.renderer_state.mutex.unlock();
            self.renderer_state.terminal.fullReset();
        },

        .start_search => {
            // To save resources, we don't actually start a search here,
            // we just notify the apprt. The real thread will start when
            // the first needles are set.
            return try self.rt_app.performAction(
                .{ .surface = self },
                .start_search,
                .{ .needle = "" },
            );
        },

        .search_selection => {
            const selection = try self.selectionString(self.alloc) orelse return false;
            defer self.alloc.free(selection);
            return try self.rt_app.performAction(
                .{ .surface = self },
                .start_search,
                .{ .needle = selection },
            );
        },

        .end_search => {
            // We only return that this was performed if we actually
            // stopped a search, but we also send the apprt end_search so
            // that GUIs can clean up stale stuff.
            const performed = self.search != null;

            if (self.search) |*s| {
                s.deinit();
                self.search = null;
            }

            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .end_search,
                {},
            );

            return performed;
        },

        .search => |text| search: {
            const s: *Search = if (self.search) |*s| s else init: {
                // If we're stopping the search and we had no prior search,
                // then there is nothing to do.
                if (text.len == 0) return false;

                // We need to assign directly to self.search because we need
                // a stable pointer back to the thread state.
                self.search = .{
                    .state = try .init(self.alloc, .{
                        .mutex = self.renderer_state.mutex,
                        .terminal = self.renderer_state.terminal,
                        .event_cb = &searchCallback,
                        .event_userdata = self,
                    }),
                    .thread = undefined,
                };
                const s: *Search = &self.search.?;
                errdefer s.state.deinit();

                s.thread = try .spawn(
                    .{},
                    terminal.search.Thread.threadMain,
                    .{&s.state},
                );
                s.thread.setName("search") catch {};

                break :init s;
            };

            // Zero-length text means stop searching.
            if (text.len == 0) {
                s.deinit();
                self.search = null;
                break :search;
            }

            _ = s.state.mailbox.push(
                .{ .change_needle = try .init(
                    self.alloc,
                    text,
                ) },
                .forever,
            );
            s.state.wakeup.notify() catch {};
        },

        .navigate_search => |nav| {
            const s: *Search = if (self.search) |*s| s else return false;
            _ = s.state.mailbox.push(
                .{ .select = switch (nav) {
                    .next => .next,
                    .previous => .prev,
                } },
                .forever,
            );
            s.state.wakeup.notify() catch {};
        },

        .copy_to_clipboard => |format| {
            self.renderer_state.mutex.lock();
            defer self.renderer_state.mutex.unlock();

            if (self.io.terminal.screens.active.selection) |sel| {
                try self.copySelectionToClipboards(
                    sel,
                    &.{.standard},
                    format,
                );

                // Clear the selection if configured to do so.
                if (self.config.selection_clear_on_copy) {
                    if (self.setSelection(null)) {
                        self.queueRender() catch |err| {
                            log.warn("failed to queue render after clear selection err={}", .{err});
                        };
                    } else |err| {
                        log.warn("failed to clear selection after copy err={}", .{err});
                    }
                }

                return true;
            }

            return false;
        },

        .copy_url_to_clipboard => {
            // If the mouse isn't over a link, nothing we can do.
            if (!self.mouse.over_link) return false;
            const pos = try self.rt_surface.getCursorPos();

            self.renderer_state.mutex.lock();
            defer self.renderer_state.mutex.unlock();
            if (try self.linkAtPos(pos)) |link_info| {
                const url_text = switch (link_info.action) {
                    .open => url_text: {
                        // For regex links, get the text from selection
                        break :url_text (self.io.terminal.screens.active.selectionString(self.alloc, .{
                            .sel = link_info.selection,
                            .trim = self.config.clipboard_trim_trailing_spaces,
                        })) catch |err| {
                            log.err("error reading url string err={}", .{err});
                            return false;
                        };
                    },

                    ._open_osc8 => url_text: {
                        // For OSC8 links, get the URI directly from hyperlink data
                        const uri = self.osc8URI(link_info.selection.start()) orelse {
                            log.warn("failed to get URI for OSC8 hyperlink", .{});
                            return false;
                        };
                        break :url_text try self.alloc.dupeZ(u8, uri);
                    },
                };
                defer self.alloc.free(url_text);

                self.rt_surface.setClipboard(.standard, &.{.{
                    .mime = "text/plain",
                    .data = url_text,
                }}, false) catch |err| {
                    log.err("error copying url to clipboard err={}", .{err});
                    return false;
                };

                return true;
            }

            return false;
        },

        .copy_title_to_clipboard => return try self.rt_app.performAction(
            .{ .surface = self },
            .copy_title_to_clipboard,
            {},
        ),

        .paste_from_clipboard => return try self.startClipboardRequest(
            .standard,
            .{ .paste = {} },
        ),

        .paste_from_selection => return try self.startClipboardRequest(
            .selection,
            .{ .paste = {} },
        ),

        .increase_font_size => |delta| {
            // Max delta is somewhat arbitrary.
            const clamped_delta = @max(0, @min(255, delta));

            log.debug("increase font size={}", .{clamped_delta});

            // Max point size is somewhat arbitrary.
            var size = self.font_size;
            size.points = @min(size.points + clamped_delta, 255);
            try self.setFontSize(size);

            // Mark that we manually adjusted the font size
            self.font_size_adjusted = true;
        },

        .decrease_font_size => |delta| {
            // Max delta is somewhat arbitrary.
            const clamped_delta = @max(0, @min(255, delta));

            log.debug("decrease font size={}", .{clamped_delta});

            var size = self.font_size;
            size.points = @max(1, size.points - clamped_delta);
            try self.setFontSize(size);

            // Mark that we manually adjusted the font size
            self.font_size_adjusted = true;
        },

        .reset_font_size => {
            log.debug("reset font size", .{});

            var size = self.font_size;
            size.points = self.config.original_font_size;
            try self.setFontSize(size);

            // Reset font size also resets the manual adjustment state
            self.font_size_adjusted = false;
        },

        .set_font_size => |points| {
            log.debug("set font size={d}", .{points});

            var size = self.font_size;
            size.points = std.math.clamp(points, 1.0, 255.0);
            try self.setFontSize(size);

            // Mark that we manually adjusted the font size
            self.font_size_adjusted = true;
        },

        .prompt_surface_title => return try self.rt_app.performAction(
            .{ .surface = self },
            .prompt_title,
            .surface,
        ),

        .prompt_tab_title => return try self.rt_app.performAction(
            .{ .surface = self },
            .prompt_title,
            .tab,
        ),

        .set_surface_title => |v| {
            const title = try self.alloc.dupeZ(u8, v);
            defer self.alloc.free(title);
            return try self.rt_app.performAction(
                .{ .surface = self },
                .set_title,
                .{ .title = title },
            );
        },

        .set_tab_title => |v| {
            const title = try self.alloc.dupeZ(u8, v);
            defer self.alloc.free(title);
            return try self.rt_app.performAction(
                .{ .surface = self },
                .set_tab_title,
                .{ .title = title },
            );
        },

        .clear_screen => {
            // This is a duplicate of some of the logic in termio.clearScreen
            // but we need to do this here so we can know the answer before
            // we send the message. If the currently active screen is on the
            // alternate screen then clear screen does nothing so we want to
            // return false so the keybind can be unconsumed.
            {
                self.renderer_state.mutex.lock();
                defer self.renderer_state.mutex.unlock();
                if (self.io.terminal.screens.active_key == .alternate) return false;
            }

            self.queueIo(.{
                .clear_screen = .{ .history = true },
            }, .unlocked);
        },

        .scroll_to_top => {
            self.queueIo(.{
                .scroll_viewport = .{ .top = {} },
            }, .unlocked);
        },

        .scroll_to_bottom => {
            self.queueIo(.{
                .scroll_viewport = .{ .bottom = {} },
            }, .unlocked);
        },

        .scroll_to_row => |n| {
            {
                self.renderer_state.mutex.lock();
                defer self.renderer_state.mutex.unlock();
                const t: *terminal.Terminal = self.renderer_state.terminal;
                t.screens.active.scroll(.{ .row = n });
            }

            try self.queueRender();
        },

        .scroll_to_selection => {
            {
                self.renderer_state.mutex.lock();
                defer self.renderer_state.mutex.unlock();
                const sel = self.io.terminal.screens.active.selection orelse return false;
                const tl = sel.topLeft(self.io.terminal.screens.active);
                self.io.terminal.screens.active.scroll(.{ .pin = tl });
            }

            try self.queueRender();
        },

        .scroll_page_up => {
            const rows: isize = @intCast(self.size.grid().rows);
            self.queueIo(.{
                .scroll_viewport = .{ .delta = -1 * rows },
            }, .unlocked);
        },

        .scroll_page_down => {
            const rows: isize = @intCast(self.size.grid().rows);
            self.queueIo(.{
                .scroll_viewport = .{ .delta = rows },
            }, .unlocked);
        },

        .scroll_page_fractional => |fraction| {
            const rows: f32 = @floatFromInt(self.size.grid().rows);
            const delta: isize = @intFromFloat(@trunc(fraction * rows));
            self.queueIo(.{
                .scroll_viewport = .{ .delta = delta },
            }, .unlocked);
        },

        .scroll_page_lines => |lines| {
            self.queueIo(.{
                .scroll_viewport = .{ .delta = lines },
            }, .unlocked);
        },

        .jump_to_prompt => |delta| {
            self.queueIo(.{
                .jump_to_prompt = @intCast(delta),
            }, .unlocked);
        },

        .write_screen_file => |v| try self.writeScreenFile(
            .screen,
            v,
        ),

        .write_scrollback_file => |v| try self.writeScreenFile(
            .history,
            v,
        ),

        .write_selection_file => |v| try self.writeScreenFile(
            .selection,
            v,
        ),

        .new_tab => return try self.rt_app.performAction(
            .{ .surface = self },
            .new_tab,
            {},
        ),

        .close_tab => |v| return try self.rt_app.performAction(
            .{ .surface = self },
            .close_tab,
            switch (v) {
                .this => .this,
                .other => .other,
                .right => .right,
            },
        ),

        inline .previous_tab,
        .next_tab,
        .last_tab,
        .goto_tab,
        => |v, tag| return try self.rt_app.performAction(
            .{ .surface = self },
            .goto_tab,
            switch (tag) {
                .previous_tab => .previous,
                .next_tab => .next,
                .last_tab => .last,
                .goto_tab => @enumFromInt(v),
                else => comptime unreachable,
            },
        ),

        .move_tab => |position| return try self.rt_app.performAction(
            .{ .surface = self },
            .move_tab,
            .{ .amount = position },
        ),

        .new_split => |direction| return try self.rt_app.performAction(
            .{ .surface = self },
            .new_split,
            switch (direction) {
                .right => .right,
                .left => .left,
                .down => .down,
                .up => .up,
                .auto => if (self.size.screen.width > self.size.screen.height)
                    .right
                else
                    .down,
            },
        ),

        .goto_split => |direction| return try self.rt_app.performAction(
            .{ .surface = self },
            .goto_split,
            switch (direction) {
                inline else => |tag| @field(
                    apprt.action.GotoSplit,
                    @tagName(tag),
                ),
            },
        ),

        .goto_window => |direction| return try self.rt_app.performAction(
            .{ .surface = self },
            .goto_window,
            switch (direction) {
                .previous => .previous,
                .next => .next,
            },
        ),

        .resize_split => |value| return try self.rt_app.performAction(
            .{ .surface = self },
            .resize_split,
            .{
                .amount = value[1],
                .direction = switch (value[0]) {
                    inline else => |tag| @field(
                        apprt.action.ResizeSplit.Direction,
                        @tagName(tag),
                    ),
                },
            },
        ),

        .equalize_splits => return try self.rt_app.performAction(
            .{ .surface = self },
            .equalize_splits,
            {},
        ),

        .toggle_split_zoom => return try self.rt_app.performAction(
            .{ .surface = self },
            .toggle_split_zoom,
            {},
        ),

        .toggle_readonly => {
            self.readonly = !self.readonly;
            _ = try self.rt_app.performAction(
                .{ .surface = self },
                .readonly,
                if (self.readonly) .on else .off,
            );
            return true;
        },

        .reset_window_size => return try self.rt_app.performAction(
            .{ .surface = self },
            .reset_window_size,
            {},
        ),

        .toggle_maximize => return try self.rt_app.performAction(
            .{ .surface = self },
            .toggle_maximize,
            {},
        ),

        .toggle_fullscreen => return try self.rt_app.performAction(
            .{ .surface = self },
            .toggle_fullscreen,
            switch (self.config.macos_non_native_fullscreen) {
                .false => .native,
                .true => .macos_non_native,
                .@"visible-menu" => .macos_non_native_visible_menu,
                .@"padded-notch" => .macos_non_native_padded_notch,
            },
        ),

        .toggle_window_decorations => return try self.rt_app.performAction(
            .{ .surface = self },
            .toggle_window_decorations,
            {},
        ),

        .toggle_tab_overview => return try self.rt_app.performAction(
            .{ .surface = self },
            .toggle_tab_overview,
            {},
        ),

        .toggle_window_float_on_top => return try self.rt_app.performAction(
            .{ .surface = self },
            .float_window,
            .toggle,
        ),

        .toggle_secure_input => return try self.rt_app.performAction(
            .{ .surface = self },
            .secure_input,
            .toggle,
        ),

        .toggle_mouse_reporting => {
            self.config.mouse_reporting = !self.config.mouse_reporting;
            log.debug("mouse reporting toggled: {}", .{self.config.mouse_reporting});
        },

        .toggle_command_palette => return try self.rt_app.performAction(
            .{ .surface = self },
            .toggle_command_palette,
            {},
        ),

        .toggle_background_opacity => return try self.rt_app.performAction(
            .{ .surface = self },
            .toggle_background_opacity,
            {},
        ),

        .show_on_screen_keyboard => return try self.rt_app.performAction(
            .{ .surface = self },
            .show_on_screen_keyboard,
            {},
        ),

        .select_all => {
            self.renderer_state.mutex.lock();
            defer self.renderer_state.mutex.unlock();

            const sel = self.io.terminal.screens.active.selectAll();
            if (sel) |s| {
                try self.setSelection(s);
                try self.queueRender();
            }
        },

        .inspector => |mode| return try self.rt_app.performAction(
            .{ .surface = self },
            .inspector,
            switch (mode) {
                inline else => |tag| @field(
                    apprt.action.Inspector,
                    @tagName(tag),
                ),
            },
        ),

        .close_surface => self.close(),

        .close_window => return try self.rt_app.performAction(
            .{ .surface = self },
            .close_window,
            {},
        ),

        inline .activate_key_table,
        .activate_key_table_once,
        => |name, tag| {
            // Look up the table in our config
            const set = self.config.keybind.tables.getPtr(name) orelse {
                log.debug("key table not found: {s}", .{name});
                return false;
            };

            // If this is the same table as is currently active, then
            // do nothing.
            if (self.keyboard.table_stack.items.len > 0) {
                const items = self.keyboard.table_stack.items;
                const active = items[items.len - 1].set;
                if (active == set) {
                    log.debug("ignoring duplicate activate table: {s}", .{name});
                    return false;
                }
            }

            // If we're already at the max, ignore it.
            if (self.keyboard.table_stack.items.len >= max_active_key_tables) {
                log.info(
                    "ignoring activate table, max depth reached: {s}",
                    .{name},
                );
                return false;
            }

            // Add the table to the stack.
            try self.keyboard.table_stack.append(self.alloc, .{
                .set = set,
                .once = tag == .activate_key_table_once,
            });

            // Notify the UI.
            _ = self.rt_app.performAction(
                .{ .surface = self },
                .key_table,
                .{ .activate = name },
            ) catch |err| {
                log.warn(
                    "failed to notify app of key table err={}",
                    .{err},
                );
            };

            log.debug("key table activated: {s}", .{name});
        },

        .deactivate_key_table => {
            switch (self.keyboard.table_stack.items.len) {
                // No key table active. This does nothing.
                0 => return false,

                // Final key table active, clear our state.
                1 => self.keyboard.table_stack.clearAndFree(self.alloc),

                // Restore the prior key table. We don't free any memory in
                // this case because we assume it will be freed later when
                // we finish our key table.
                else => _ = self.keyboard.table_stack.pop(),
            }

            // Notify the UI.
            _ = self.rt_app.performAction(
                .{ .surface = self },
                .key_table,
                .deactivate,
            ) catch |err| {
                log.warn(
                    "failed to notify app of key table err={}",
                    .{err},
                );
            };
        },

        .deactivate_all_key_tables => {
            return try self.deactivateAllKeyTables();
        },

        .end_key_sequence => {
            // End the key sequence and flush queued keys to the terminal,
            // but don't encode the key that triggered this action. This
            // will do that because leaf keys (keys with bindings) aren't
            // in the queued encoding list.
            self.endKeySequence(.flush, .retain);
        },

        .crash => |location| switch (location) {
            .main => @panic("crash binding action, crashing intentionally"),

            .render => {
                _ = self.renderer_thread.mailbox.push(.{ .crash = {} }, .{ .forever = {} });
                self.queueRender() catch |err| {
                    // Not a big deal if this fails.
                    log.warn("failed to notify renderer of crash message err={}", .{err});
                };
            },

            .io => self.queueIo(.{ .crash = {} }, .unlocked),
        },

        .adjust_selection => |direction| {
            self.renderer_state.mutex.lock();
            defer self.renderer_state.mutex.unlock();

            const screen: *terminal.Screen = self.io.terminal.screens.active;
            const sel = if (screen.selection) |*sel| sel else {
                // If we don't have a selection we do not perform this
                // action, allowing the keybind to fall through to the
                // terminal.
                return false;
            };
            sel.adjust(screen, switch (direction) {
                .left => .left,
                .right => .right,
                .up => .up,
                .down => .down,
                .page_up => .page_up,
                .page_down => .page_down,
                .home => .home,
                .end => .end,
                .beginning_of_line => .beginning_of_line,
                .end_of_line => .end_of_line,
            });

            // If the selection endpoint is outside of the current viewpoint,
            // scroll it in to view. Note we always specifically use sel.end
            // because that is what adjust modifies.
            scroll: {
                const viewport_tl = screen.pages.getTopLeft(.viewport);
                const viewport_br = screen.pages.getBottomRight(.viewport).?;
                if (sel.end().isBetween(viewport_tl, viewport_br))
                    break :scroll;

                // Our end point is not within the viewport. If the end
                // point is after the br then we need to adjust the end so
                // that it is at the bottom right of the viewport.
                const target = if (sel.end().before(viewport_tl))
                    sel.end()
                else
                    sel.end().up(screen.pages.rows - 1) orelse sel.end();

                screen.scroll(.{ .pin = target });
            }

            // Queue a render so its shown
            screen.dirty.selection = true;
            try self.queueRender();
        },
    }

    return true;
}

/// Returns true if performing the given action result in closing
/// the surface. This is used to determine if our self pointer is
/// still valid after performing some binding action.
fn closingAction(action: input.Binding.Action) bool {
    return switch (action) {
        .close_surface,
        .close_window,
        .close_tab,
        => true,

        else => false,
    };
}

/// The portion of the screen to write for writeScreenFile.
const WriteScreenLoc = enum {
    screen, // Full screen
    history, // History (scrollback)
    selection, // Selected text
};

fn writeScreenFile(
    self: *Surface,
    loc: WriteScreenLoc,
    write_screen: input.Binding.Action.WriteScreen,
) !void {
    // Create a temporary directory to store our scrollback.
    var tmp_dir = try internal_os.TempDir.init();
    errdefer tmp_dir.deinit();

    var filename_buf: [std.fs.max_path_bytes]u8 = undefined;
    const filename = try std.fmt.bufPrint(
        &filename_buf,
        "{s}.{s}",
        .{
            @tagName(loc),
            switch (write_screen.emit) {
                .plain, .vt => "txt",
                .html => "html",
            },
        },
    );

    // Open our scrollback file
    var file = try tmp_dir.dir.createFile(
        filename,
        switch (builtin.os.tag) {
            .windows => .{},
            else => .{ .mode = 0o600 },
        },
    );
    defer file.close();

    // Screen.dumpString writes byte-by-byte, so buffer it
    var buf: [4096]u8 = undefined;
    var file_writer = file.writer(&buf);
    var buf_writer = &file_writer.interface;

    // Write the scrollback contents. This requires a lock.
    {
        self.renderer_state.mutex.lock();
        defer self.renderer_state.mutex.unlock();

        // We only dump history if we have history. We still keep
        // the file and write the empty file to the pty so that this
        // command always works on the primary screen.
        const pages = &self.io.terminal.screens.active.pages;
        const sel_: ?terminal.Selection = switch (loc) {
            .history => history: {
                // We do not support this for alternate screens
                // because they don't have scrollback anyways.
                if (self.io.terminal.screens.active_key == .alternate) {
                    break :history null;
                }

                break :history terminal.Selection.init(
                    pages.getTopLeft(.history),
                    pages.getBottomRight(.history) orelse
                        break :history null,
                    false,
                );
            },

            .screen => screen: {
                break :screen terminal.Selection.init(
                    pages.getTopLeft(.screen),
                    pages.getBottomRight(.screen) orelse
                        break :screen null,
                    false,
                );
            },

            .selection => self.io.terminal.screens.active.selection,
        };

        const sel = sel_ orelse {
            // If we have no selection we have no data so we do nothing.
            tmp_dir.deinit();
            return;
        };

        const ScreenFormatter = terminal.formatter.ScreenFormatter;
        var formatter: ScreenFormatter = .init(self.io.terminal.screens.active, .{
            .emit = switch (write_screen.emit) {
                .plain => .plain,
                .vt => .vt,
                .html => .html,
            },
            .unwrap = true,
            .trim = false,
            .background = self.io.terminal.colors.background.get(),
            .foreground = self.io.terminal.colors.foreground.get(),
            .palette = &self.io.terminal.colors.palette.current,
        });
        formatter.content = .{ .selection = sel.ordered(
            self.io.terminal.screens.active,
            .forward,
        ) };
        try formatter.format(buf_writer);
    }
    try buf_writer.flush();

    // Get the final path
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp_dir.dir.realpath(filename, &path_buf);

    switch (write_screen.action) {
        .copy => {
            const pathZ = try self.alloc.dupeZ(u8, path);
            defer self.alloc.free(pathZ);
            try self.rt_surface.setClipboard(.standard, &.{.{
                .mime = "text/plain",
                .data = pathZ,
            }}, false);
        },
        .open => try self.openUrl(.{
            .kind = switch (write_screen.emit) {
                .plain, .vt => .text,
                .html => .html,
            },
            .url = path,
        }),
        .paste => self.queueIo(try termio.Message.writeReq(
            self.alloc,
            path,
        ), .unlocked),
    }
}

/// Call this to complete a clipboard request sent to apprt. This should
/// only be called once for each request. The data is immediately copied so
/// it is safe to free the data after this call.
///
/// If `confirmed` is true then any clipboard confirmation prompts are skipped:
///
///   - For "regular" pasting this means that unsafe pastes are allowed. Unsafe
///     data is defined as data that contains newlines, though this definition
///     may change later to detect other scenarios.
///
///   - For OSC 52 reads and writes no prompt is shown to the user if
///     `confirmed` is true.
///
/// If `confirmed` is false then this may return either an UnsafePaste or
/// UnauthorizedPaste error, depending on the type of clipboard request.
pub fn completeClipboardRequest(
    self: *Surface,
    req: apprt.ClipboardRequest,
    data: [:0]const u8,
    confirmed: bool,
) !void {
    switch (req) {
        .paste => try self.completeClipboardPaste(data, confirmed),

        .osc_52_read => |clipboard| try self.completeClipboardReadOSC52(
            data,
            clipboard,
            confirmed,
        ),

        .osc_52_write => |clipboard| try self.rt_surface.setClipboard(clipboard, &.{.{
            .mime = "text/plain",
            .data = data,
        }}, !confirmed),
    }
}

/// This starts a clipboard request, with some basic validation. For example,
/// an OSC 52 request is not actually requested if OSC 52 is disabled.
///
/// Returns true if the request was started, false if it was not (e.g., clipboard
/// doesn't contain text for paste requests). This allows performable keybinds
/// to pass through when the action cannot be performed.
fn startClipboardRequest(
    self: *Surface,
    loc: apprt.Clipboard,
    req: apprt.ClipboardRequest,
) !bool {
    switch (req) {
        .paste => {}, // always allowed
        .osc_52_read => if (self.config.clipboard_read == .deny) {
            log.info(
                "application attempted to read clipboard, but 'clipboard-read' is set to deny",
                .{},
            );
            return false;
        },

        // No clipboard write code paths travel through this function
        .osc_52_write => unreachable,
    }

    return try self.rt_surface.clipboardRequest(loc, req);
}

fn completeClipboardPaste(
    self: *Surface,
    data: []const u8,
    allow_unsafe: bool,
) !void {
    if (data.len == 0) return;

    const encode_opts: input.paste.Options = encode_opts: {
        self.renderer_state.mutex.lock();
        defer self.renderer_state.mutex.unlock();
        const opts: input.paste.Options = .fromTerminal(&self.io.terminal);

        // If we have paste protection enabled, we detect unsafe pastes and return
        // an error. The error approach allows apprt to attempt to complete the paste
        // before falling back to requesting confirmation.
        //
        // We do not do this for bracketed pastes because bracketed pastes are
        // by definition safe since they're framed.
        const unsafe = unsafe: {
            // If we've disabled paste protection then we always allow the paste.
            if (!self.config.clipboard_paste_protection) break :unsafe false;

            // If we're allowed to paste unsafe data then we always allow the paste.
            // This is set during confirmation usually.
            if (allow_unsafe) break :unsafe false;

            if (opts.bracketed) {
                // If we're bracketed and the paste contains and ending
                // bracket then something naughty might be going on and we
                // never trust it.
                if (std.mem.indexOf(u8, data, "\x1B[201~") != null) break :unsafe true;

                // If we are bracketed and configured to trust that then the
                // paste is not unsafe.
                if (self.config.clipboard_paste_bracketed_safe) break :unsafe false;
            }

            break :unsafe !input.paste.isSafe(data);
        };

        if (unsafe) {
            log.info("potentially unsafe paste detected, rejecting until confirmation", .{});
            return error.UnsafePaste;
        }

        // With the lock held, we must scroll to the bottom.
        // We always scroll to the bottom for these inputs.
        self.scrollToBottom() catch |err| {
            log.warn("error scrolling to bottom err={}", .{err});
        };

        break :encode_opts opts;
    };

    // Encode the data. In most cases this doesn't require any
    // copies, so we optimize for that case.
    var data_duped: ?[]u8 = null;
    const vecs = input.paste.encode(data, encode_opts) catch |err| switch (err) {
        error.MutableRequired => vecs: {
            const buf: []u8 = try self.alloc.dupe(u8, data);
            errdefer self.alloc.free(buf);
            data_duped = buf;
            break :vecs input.paste.encode(buf, encode_opts);
        },
    };
    defer if (data_duped) |v| {
        // This code path means the data did require a copy and mutation.
        // We must free it.
        self.alloc.free(v);
    };

    for (vecs) |vec| if (vec.len > 0) {
        self.queueIo(try termio.Message.writeReq(
            self.alloc,
            vec,
        ), .unlocked);
    };
}

fn completeClipboardReadOSC52(
    self: *Surface,
    data: []const u8,
    clipboard_type: apprt.Clipboard,
    confirmed: bool,
) !void {
    // We should never get here if clipboard-read is set to deny
    assert(self.config.clipboard_read != .deny);

    // If clipboard-read is set to ask and we haven't confirmed with the user,
    // do that now
    if (self.config.clipboard_read == .ask and !confirmed) {
        return error.UnauthorizedPaste;
    }

    // Even if the clipboard data is empty we reply, since presumably
    // the client app is expecting a reply. We first allocate our buffer.
    // This must hold the base64 encoded data PLUS the OSC code surrounding it.
    const enc = std.base64.standard.Encoder;
    const size = enc.calcSize(data.len);
    var buf = try self.alloc.alloc(u8, size + 9); // const for OSC
    defer self.alloc.free(buf);

    const kind: u8 = switch (clipboard_type) {
        .standard => 'c',
        .selection => 's',
        .primary => 'p',
    };

    // Wrap our data with the OSC code
    const prefix = try std.fmt.bufPrint(buf, "\x1b]52;{c};", .{kind});
    assert(prefix.len == 7);
    buf[buf.len - 2] = '\x1b';
    buf[buf.len - 1] = '\\';

    // Do the base64 encoding
    const encoded = enc.encode(buf[prefix.len..], data);
    assert(encoded.len == size);

    self.queueIo(try termio.Message.writeReq(
        self.alloc,
        buf,
    ), .unlocked);
}

fn showDesktopNotification(self: *Surface, title: [:0]const u8, body: [:0]const u8) !void {
    // Wyhash is used to hash the contents of the desktop notification to limit
    // how fast identical notifications can be sent sequentially.
    const hash_algorithm = std.hash.Wyhash;

    const now = try std.time.Instant.now();

    // Set a limit of one desktop notification per second so that the OS
    // doesn't kill us when we run out of resources.
    if (self.app.last_notification_time) |last| {
        if (now.since(last) < 1 * std.time.ns_per_s) {
            log.warn("rate limiting desktop notifications", .{});
            return;
        }
    }

    const new_digest = d: {
        var hash = hash_algorithm.init(0);
        hash.update(title);
        hash.update(body);
        break :d hash.final();
    };

    // Set a limit of one notification per five seconds for desktop
    // notifications with identical content.
    if (self.app.last_notification_time) |last| {
        if (self.app.last_notification_digest == new_digest) {
            if (now.since(last) < 5 * std.time.ns_per_s) {
                log.warn("suppressing identical desktop notification", .{});
                return;
            }
        }
    }

    self.app.last_notification_time = now;
    self.app.last_notification_digest = new_digest;
    _ = try self.rt_app.performAction(
        .{ .surface = self },
        .desktop_notification,
        .{
            .title = title,
            .body = body,
        },
    );
}

fn crashThreadState(self: *Surface) crash.sentry.ThreadState {
    return .{
        .type = .main,
        .surface = self,
    };
}

/// Tell the surface to present itself to the user. This may involve raising the
/// window and switching tabs.
fn presentSurface(self: *Surface) !void {
    _ = try self.rt_app.performAction(
        .{ .surface = self },
        .present_terminal,
        {},
    );
}

/// Utility function for the unit tests for mouse selection logic.
///
/// Tests a click and drag on a 10x5 cell grid, x positions are given in
/// fractional cells, e.g. 3.1 would be 10% through the cell at x = 3.
///
/// NOTE: The size tested with has 10px wide cells, meaning only one digit
///       after the decimal place has any meaning, e.g. 3.14 is equal to 3.1.
///
/// The provided start_x/y and end_x/y are the expected start and end points
/// of the resulting selection.
fn testMouseSelection(
    click_x: f64,
    click_y: u32,
    drag_x: f64,
    drag_y: u32,
    start_x: terminal.size.CellCountInt,
    start_y: u32,
    end_x: terminal.size.CellCountInt,
    end_y: u32,
    rect: bool,
) !void {
    assert(builtin.is_test);

    // Our screen size is 10x5 cells that are
    // 10x20 px, with 5px padding on all sides.
    const size: rendererpkg.Size = .{
        .cell = .{ .width = 10, .height = 20 },
        .padding = .{ .left = 5, .top = 5, .right = 5, .bottom = 5 },
        .screen = .{ .width = 110, .height = 110 },
    };
    var screen = try terminal.Screen.init(std.testing.allocator, .{ .cols = 10, .rows = 5, .max_scrollback = 0 });
    defer screen.deinit();

    // We hold both ctrl and alt for rectangular
    // select so that this test is platform agnostic.
    const mods: input.Mods = .{
        .ctrl = rect,
        .alt = rect,
    };

    try std.testing.expectEqual(rect, SurfaceMouse.isRectangleSelectState(mods));

    const click_pin = screen.pages.pin(.{
        .viewport = .{ .x = @intFromFloat(@floor(click_x)), .y = click_y },
    }) orelse unreachable;
    const drag_pin = screen.pages.pin(.{
        .viewport = .{ .x = @intFromFloat(@floor(drag_x)), .y = drag_y },
    }) orelse unreachable;

    const cell_width_f64: f64 = @floatFromInt(size.cell.width);
    const click_x_pos: u32 =
        @as(u32, @intFromFloat(@floor(click_x * cell_width_f64))) +
        size.padding.left;
    const drag_x_pos: u32 =
        @as(u32, @intFromFloat(@floor(drag_x * cell_width_f64))) +
        size.padding.left;

    const start_pin = screen.pages.pin(.{
        .viewport = .{ .x = start_x, .y = start_y },
    }) orelse unreachable;
    const end_pin = screen.pages.pin(.{
        .viewport = .{ .x = end_x, .y = end_y },
    }) orelse unreachable;

    try std.testing.expectEqualDeep(terminal.Selection{
        .bounds = .{ .untracked = .{
            .start = start_pin,
            .end = end_pin,
        } },
        .rectangle = rect,
    }, mouseSelection(
        click_pin,
        drag_pin,
        click_x_pos,
        drag_x_pos,
        mods,
        size,
    ));
}

/// Like `testMouseSelection` but checks that the resulting selection is null.
///
/// See `testMouseSelection` for more details.
fn testMouseSelectionIsNull(
    click_x: f64,
    click_y: u32,
    drag_x: f64,
    drag_y: u32,
    rect: bool,
) !void {
    assert(builtin.is_test);

    // Our screen size is 10x5 cells that are
    // 10x20 px, with 5px padding on all sides.
    const size: rendererpkg.Size = .{
        .cell = .{ .width = 10, .height = 20 },
        .padding = .{ .left = 5, .top = 5, .right = 5, .bottom = 5 },
        .screen = .{ .width = 110, .height = 110 },
    };
    var screen = try terminal.Screen.init(std.testing.allocator, .{ .cols = 10, .rows = 5, .max_scrollback = 0 });
    defer screen.deinit();

    // We hold both ctrl and alt for rectangular
    // select so that this test is platform agnostic.
    const mods: input.Mods = .{
        .ctrl = rect,
        .alt = rect,
    };

    try std.testing.expectEqual(rect, SurfaceMouse.isRectangleSelectState(mods));

    const click_pin = screen.pages.pin(.{
        .viewport = .{ .x = @intFromFloat(@floor(click_x)), .y = click_y },
    }) orelse unreachable;
    const drag_pin = screen.pages.pin(.{
        .viewport = .{ .x = @intFromFloat(@floor(drag_x)), .y = drag_y },
    }) orelse unreachable;

    const cell_width_f64: f64 = @floatFromInt(size.cell.width);
    const click_x_pos: u32 =
        @as(u32, @intFromFloat(@floor(click_x * cell_width_f64))) +
        size.padding.left;
    const drag_x_pos: u32 =
        @as(u32, @intFromFloat(@floor(drag_x * cell_width_f64))) +
        size.padding.left;

    try std.testing.expectEqual(
        null,
        mouseSelection(
            click_pin,
            drag_pin,
            click_x_pos,
            drag_x_pos,
            mods,
            size,
        ),
    );
}

/// Get information about the process(es) running within the surface. Returns
/// `null` if there was an error getting the information or the information is
/// not available on a particular platform.
pub fn getProcessInfo(self: *Surface, comptime info: ProcessInfo) ?ProcessInfo.Type(info) {
    return self.io.getProcessInfo(info);
}

test "Surface: selection logic" {
    // We disable format to make these easier to
    // read by pairing sets of coordinates per line.
    // zig fmt: off

    // -- LTR
    // single cell selection
    try testMouseSelection(
        3.0, 3, // click
        3.9, 3, // drag
        3, 3, // expected start
        3, 3, // expected end
        false, // regular selection
    );
    // including click and drag pin cells
    try testMouseSelection(
        3.0, 3, // click
        5.9, 3, // drag
        3, 3, // expected start
        5, 3, // expected end
        false, // regular selection
    );
    // including click pin cell but not drag pin cell
    try testMouseSelection(
        3.0, 3, // click
        5.0, 3, // drag
        3, 3, // expected start
        4, 3, // expected end
        false, // regular selection
    );
    // including drag pin cell but not click pin cell
    try testMouseSelection(
        3.9, 3, // click
        5.9, 3, // drag
        4, 3, // expected start
        5, 3, // expected end
        false, // regular selection
    );
    // including neither click nor drag pin cells
    try testMouseSelection(
        3.9, 3, // click
        5.0, 3, // drag
        4, 3, // expected start
        4, 3, // expected end
        false, // regular selection
    );
    // empty selection (single cell on only left half)
    try testMouseSelectionIsNull(
        3.0, 3, // click
        3.1, 3, // drag
        false, // regular selection
    );
    // empty selection (single cell on only right half)
    try testMouseSelectionIsNull(
        3.8, 3, // click
        3.9, 3, // drag
        false, // regular selection
    );
    // empty selection (between two cells, not crossing threshold)
    try testMouseSelectionIsNull(
        3.9, 3, // click
        4.0, 3, // drag
        false, // regular selection
    );

    // -- RTL
    // single cell selection
    try testMouseSelection(
        3.9, 3, // click
        3.0, 3, // drag
        3, 3, // expected start
        3, 3, // expected end
        false, // regular selection
    );
    // including click and drag pin cells
    try testMouseSelection(
        5.9, 3, // click
        3.0, 3, // drag
        5, 3, // expected start
        3, 3, // expected end
        false, // regular selection
    );
    // including click pin cell but not drag pin cell
    try testMouseSelection(
        5.9, 3, // click
        3.9, 3, // drag
        5, 3, // expected start
        4, 3, // expected end
        false, // regular selection
    );
    // including drag pin cell but not click pin cell
    try testMouseSelection(
        5.0, 3, // click
        3.0, 3, // drag
        4, 3, // expected start
        3, 3, // expected end
        false, // regular selection
    );
    // including neither click nor drag pin cells
    try testMouseSelection(
        5.0, 3, // click
        3.9, 3, // drag
        4, 3, // expected start
        4, 3, // expected end
        false, // regular selection
    );
    // empty selection (single cell on only left half)
    try testMouseSelectionIsNull(
        3.1, 3, // click
        3.0, 3, // drag
        false, // regular selection
    );
    // empty selection (single cell on only right half)
    try testMouseSelectionIsNull(
        3.9, 3, // click
        3.8, 3, // drag
        false, // regular selection
    );
    // empty selection (between two cells, not crossing threshold)
    try testMouseSelectionIsNull(
        4.0, 3, // click
        3.9, 3, // drag
        false, // regular selection
    );

    // -- Wrapping
    // LTR, wrap excluded cells
    try testMouseSelection(
        9.9, 2, // click
        0.0, 4, // drag
        0, 3, // expected start
        9, 3, // expected end
        false, // regular selection
    );
    // RTL, wrap excluded cells
    try testMouseSelection(
        0.0, 4, // click
        9.9, 2, // drag
        9, 3, // expected start
        0, 3, // expected end
        false, // regular selection
    );
}

test "Surface: rectangle selection logic" {
    // We disable format to make these easier to
    // read by pairing sets of coordinates per line.
    // zig fmt: off

    // -- LTR
    // single column selection
    try testMouseSelection(
        3.0, 2, // click
        3.9, 4, // drag
        3, 2, // expected start
        3, 4, // expected end
        true, //rectangle selection
    );
    // including click and drag pin columns
    try testMouseSelection(
        3.0, 2, // click
        5.9, 4, // drag
        3, 2, // expected start
        5, 4, // expected end
        true, //rectangle selection
    );
    // including click pin column but not drag pin column
    try testMouseSelection(
        3.0, 2, // click
        5.0, 4, // drag
        3, 2, // expected start
        4, 4, // expected end
        true, //rectangle selection
    );
    // including drag pin column but not click pin column
    try testMouseSelection(
        3.9, 2, // click
        5.9, 4, // drag
        4, 2, // expected start
        5, 4, // expected end
        true, //rectangle selection
    );
    // including neither click nor drag pin columns
    try testMouseSelection(
        3.9, 2, // click
        5.0, 4, // drag
        4, 2, // expected start
        4, 4, // expected end
        true, //rectangle selection
    );
    // empty selection (single column on only left half)
    try testMouseSelectionIsNull(
        3.0, 2, // click
        3.1, 4, // drag
        true, //rectangle selection
    );
    // empty selection (single column on only right half)
    try testMouseSelectionIsNull(
        3.8, 2, // click
        3.9, 4, // drag
        true, //rectangle selection
    );
    // empty selection (between two columns, not crossing threshold)
    try testMouseSelectionIsNull(
        3.9, 2, // click
        4.0, 4, // drag
        true, //rectangle selection
    );

    // -- RTL
    // single column selection
    try testMouseSelection(
        3.9, 2, // click
        3.0, 4, // drag
        3, 2, // expected start
        3, 4, // expected end
        true, //rectangle selection
    );
    // including click and drag pin columns
    try testMouseSelection(
        5.9, 2, // click
        3.0, 4, // drag
        5, 2, // expected start
        3, 4, // expected end
        true, //rectangle selection
    );
    // including click pin column but not drag pin column
    try testMouseSelection(
        5.9, 2, // click
        3.9, 4, // drag
        5, 2, // expected start
        4, 4, // expected end
        true, //rectangle selection
    );
    // including drag pin column but not click pin column
    try testMouseSelection(
        5.0, 2, // click
        3.0, 4, // drag
        4, 2, // expected start
        3, 4, // expected end
        true, //rectangle selection
    );
    // including neither click nor drag pin columns
    try testMouseSelection(
        5.0, 2, // click
        3.9, 4, // drag
        4, 2, // expected start
        4, 4, // expected end
        true, //rectangle selection
    );
    // empty selection (single column on only left half)
    try testMouseSelectionIsNull(
        3.1, 2, // click
        3.0, 4, // drag
        true, //rectangle selection
    );
    // empty selection (single column on only right half)
    try testMouseSelectionIsNull(
        3.9, 2, // click
        3.8, 4, // drag
        true, //rectangle selection
    );
    // empty selection (between two columns, not crossing threshold)
    try testMouseSelectionIsNull(
        4.0, 2, // click
        3.9, 4, // drag
        true, //rectangle selection
    );

    // -- Wrapping
    // LTR, do not wrap
    try testMouseSelection(
        9.9, 2, // click
        0.0, 4, // drag
        9, 2, // expected start
        0, 4, // expected end
        true, //rectangle selection
    );
    // RTL, do not wrap
    try testMouseSelection(
        0.0, 4, // click
        9.9, 2, // drag
        0, 4, // expected start
        9, 2, // expected end
        true, //rectangle selection
    );
}
