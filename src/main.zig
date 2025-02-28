const std = @import("std");

const ig = @import("cimgui");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const simgui = sokol.imgui;
const shader = @import("shader.zig");
const cartridge = @import("cartridge.zig");
const Cartridge = cartridge.Cartridge;
const State = struct {
    var pass_action: sg.PassAction = .{};
    var image_desc: sg.ImageDesc = .{};
    var image: sg.Image = .{};
    var sampler: sg.Sampler = .{};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator: std.mem.Allocator = undefined;
    var cart: ?Cartridge = null;
};

export fn init() void {
    State.allocator = State.gpa.allocator();
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    simgui.setup(.{
        .logger = .{ .func = slog.func },
    });
    ig.igLoadIniSettingsFromDisk("imgui.ini");

    State.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.5, .b = 1.0, .a = 1.0 },
    };

    var sampler_desc = sg.SamplerDesc{};
    sampler_desc.min_filter = .NEAREST;
    sampler_desc.mag_filter = .NEAREST;
    State.sampler = sg.makeSampler(sampler_desc);
}

export fn frame() void {
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });
    ig.igShowMetricsWindow(null);
    if (State.cart) |cart| {
        _ = ig.igBegin("Cartridge", null, ig.ImGuiWindowFlags_None);
        render_buffer("CHR", &cart.chr_rom);
        ig.igImage(
            simgui.imtextureidWithSampler(State.image, State.sampler),
            .{
                .x = @floatFromInt(State.image_desc.width * 4),
                .y = @floatFromInt(State.image_desc.height * 4),
            },
        );
        ig.igEnd();
    }

    sg.beginPass(.{ .action = State.pass_action, .swapchain = sglue.swapchain() });
    simgui.render();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    if (State.cart) |*c| c.deinit(State.allocator);
    ig.igSaveIniSettingsToDisk("imgui.ini");
    sg.destroySampler(State.sampler);
    sg.destroyImage(State.image);
    simgui.shutdown();
    sg.shutdown();
}

export fn event(ev: [*c]const sapp.Event) void {
    _ = simgui.handleEvent(ev.*);
    if (ev.*.type == .FILES_DROPPED) {
        set_cart(sapp.getDroppedFilePath(0));
    }
}

fn set_cart(path: [:0]const u8) void {
    if (State.cart) |*cart| cart.deinit(State.allocator);
    State.cart = Cartridge.load(State.allocator, path) catch unreachable;
    sg.destroyImage(State.image);
    State.image = cartridge.createImage(State.cart.?.chr_rom, &State.image_desc, State.allocator) catch unreachable;
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .window_title = "Ngenes",
        .width = 800,
        .height = 600,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
        .enable_dragndrop = true,
    });
}
fn render_buffer(comptime title: []const u8, buffer: *const []u8) void {
    if (ig.igCollapsingHeader(title.ptr, ig.ImGuiTreeNodeFlags_None)) {
        ig.igPushID(title.ptr);
        defer ig.igPopID();
        const bytes_per_line = 16; // keep this 2^N
        const num_lines = (buffer.*.len + (bytes_per_line - 1)) / bytes_per_line;
        const content_avail = ig.igGetContentRegionAvail();
        const line_height = ig.igGetTextLineHeight();
        const num_lines_f32 = @as(f32, @floatFromInt(num_lines));
        const content_height = line_height * num_lines_f32;

        _ = ig.igBeginChild("##renbuf", ig.ImVec2{ .x = content_avail.x, .y = clamp(f32, content_height, line_height, content_avail.y) }, ig.ImGuiChildFlags_None, ig.ImGuiWindowFlags_NoMove | ig.ImGuiWindowFlags_NoNav);
        defer ig.igEndChild();

        var clipper: ig.ImGuiListClipper = .{};
        ig.ImGuiListClipper_Begin(&clipper, @as(c_int, @intCast(num_lines)), ig.igGetTextLineHeight());
        defer ig.ImGuiListClipper_End(&clipper);

        _ = ig.ImGuiListClipper_Step(&clipper);
        for (@intCast(@max(0, clipper.DisplayStart))..@intCast(@max(0, clipper.DisplayEnd))) |line_i| {
            const start_offset = line_i * bytes_per_line;
            var end_offset = start_offset + bytes_per_line;
            if (end_offset >= buffer.*.len) end_offset = buffer.*.len;

            ig.igText("%04X: ", start_offset);
            for (start_offset..end_offset) |i| {
                ig.igSameLine();
                ig.igText("%02X ", buffer.*[i]);
            }
            ig.igSameLine();
            for (start_offset..end_offset) |i| {
                if (i != start_offset) {
                    ig.igSameLine();
                }
                var c: u8 = buffer.*[i];
                if ((c < 32) or (c > 127)) {
                    c = '.';
                }
                ig.igText("%c", c);
            }
        }
    }
}
fn clamp(comptime t: type, value: t, min: t, max: t) t {
    return @min(max, @max(value, min));
}
