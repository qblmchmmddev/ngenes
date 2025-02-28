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
    var pass_action: sg.PassAction = .{};
    var shader: sg.Shader = .{};
    var pipeline: sg.Pipeline = .{};
    var vertex_buffer: sg.Buffer = .{};
    var index_buffer: sg.Buffer = .{};
    var bindings: sg.Bindings = .{};
    var image: sg.Image = .{};
    var sampler: sg.Sampler = .{};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
};

const VertexData = struct {
    pos: ig.ImVec2,
    uv: ig.ImVec2,
    col: sg.Color,
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

    State.shader = sg.makeShader(shader.mainShaderDesc(sg.queryBackend()));

    const vertices = [_]VertexData{
        .{
            .pos = .{ .x = -1, .y = -1 },
            .uv = .{ .x = 0, .y = 1 },
            .col = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        },
        .{
            .pos = .{ .x = -1, .y = 1 },
            .uv = .{ .x = 0, .y = 0 },
            .col = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        },
        .{
            .pos = .{ .x = 1, .y = 1 },
            .uv = .{ .x = 1, .y = 0 },
            .col = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        },
        .{
            .pos = .{ .x = 1, .y = -1 },
            .uv = .{ .x = 1, .y = 1 },
            .col = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
        },
    };
    State.vertex_buffer = sg.makeBuffer(.{
        .data = .{ .ptr = &vertices, .size = vertices.len * @sizeOf(@TypeOf(vertices[0])) },
        .type = .VERTEXBUFFER,
    });
    const indices = [_]u16{
        0, 3, 1,
        3, 2, 1,
    };
    State.index_buffer = sg.makeBuffer(.{
        .data = .{ .ptr = &indices, .size = indices.len * @sizeOf(@TypeOf(indices[0])) },
        .type = .INDEXBUFFER,
    });

    var pixels = [_]u8{
        255, 0,   0,   255,
        0,   255, 0,   255,
        0,   0,   255, 255,
        255, 255, 0,   255,
    };
    // var raw_image = zstbi.Image.loadFromFile("nes.png", 0) catch unreachable;
    // var raw_image = zstbi.Image.createEmpty(2, 2, 4, .{}) catch unreachable;
    // raw_image.data = pixels[0..];
    var image_desc = sg.ImageDesc{};
    image_desc.width = @intCast(2);
    image_desc.height = @intCast(2);
    image_desc.pixel_format = .RGBA8;
    image_desc.data.subimage[0][0] = .{ .ptr = &pixels, .size = 2 * 2 * 4 };
    State.image = sg.makeImage(image_desc);
    // raw_image.deinit();

    var sampler_desc = sg.SamplerDesc{};
    sampler_desc.min_filter = .NEAREST;
    sampler_desc.mag_filter = .NEAREST;
    State.sampler = sg.makeSampler(sampler_desc);

    State.bindings.vertex_buffers[0] = State.vertex_buffer;
    State.bindings.index_buffer = State.index_buffer;
    State.bindings.images[shader.IMG_tex] = State.image;
    State.bindings.samplers[shader.SMP_samp] = State.sampler;

    var pipeline_desc = sg.PipelineDesc{};
    pipeline_desc.shader = State.shader;
    pipeline_desc.layout.attrs[shader.ATTR_main_v_i_pos] = .{ .format = .FLOAT2 };
    pipeline_desc.layout.attrs[shader.ATTR_main_v_i_uv] = .{ .format = .FLOAT2 };
    pipeline_desc.layout.attrs[shader.ATTR_main_v_i_col] = .{ .format = .FLOAT4 };
    pipeline_desc.index_type = .UINT16;
    State.pipeline = sg.makePipeline(pipeline_desc);
}

export fn frame() void {
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });

    ig.igShowDemoWindow(null);
    ig.igImage(simgui.imtextureidWithSampler(State.image, State.sampler), .{ .x = 20, .y = 20 });

    sg.beginPass(.{ .action = State.pass_action, .swapchain = sglue.swapchain() });
    sg.applyPipeline(State.pipeline);
    sg.applyBindings(State.bindings);
    sg.draw(0, 6, 1);
    simgui.render();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    ig.igSaveIniSettingsToDisk("imgui.ini");
    sg.destroySampler(State.sampler);
    sg.destroyImage(State.image);
    sg.destroyBuffer(State.index_buffer);
    sg.destroyBuffer(State.vertex_buffer);
    sg.destroyShader(State.shader);
    sg.destroyPipeline(State.pipeline);
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
