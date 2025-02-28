const std = @import("std");

const ig = @import("cimgui");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const simgui = sokol.imgui;
const shader = @import("shader.zig");

const State = struct {
    var pixels = [_]u8{
        255, 0,   0,   255,
        0,   255, 0,   255,
        0,   0,   255, 255,
        255, 255, 0,   255,
    };
    var pass_action: sg.PassAction = .{};
    var image_data: sg.ImageData = .{};
    var image: sg.Image = .{};
    var sampler: sg.Sampler = .{};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
};

export fn init() void {
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

    var image_desc = sg.ImageDesc{};
    image_desc.width = @intCast(2);
    image_desc.height = @intCast(2);
    image_desc.pixel_format = .RGBA8;
    image_desc.usage = .STREAM;
    State.image = sg.makeImage(image_desc);

    var sampler_desc = sg.SamplerDesc{};
    sampler_desc.min_filter = .NEAREST;
    sampler_desc.mag_filter = .NEAREST;
    State.sampler = sg.makeSampler(sampler_desc);
    State.image_data.subimage[0][0] = .{ .ptr = &State.pixels, .size = 2 * 2 * 4 };
}

export fn frame() void {
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });
    State.pixels[0] -%= 1;
    sg.updateImage(State.image, State.image_data);

    ig.igShowMetricsWindow(null);
    ig.igImage(simgui.imtextureidWithSampler(State.image, State.sampler), .{ .x = 20, .y = 20 });

    sg.beginPass(.{ .action = State.pass_action, .swapchain = sglue.swapchain() });
    simgui.render();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    ig.igSaveIniSettingsToDisk("imgui.ini");
    sg.destroySampler(State.sampler);
    sg.destroyImage(State.image);
    simgui.shutdown();
    sg.shutdown();
}

export fn event(ev: [*c]const sapp.Event) void {
    _ = simgui.handleEvent(ev.*);
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
    });
}
