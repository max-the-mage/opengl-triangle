const glfw = @import("glfw");
const std = @import("std");
const gl = @import("zgl");
const img = @import("zigimg");

const verticies = [_]f32{
     // positions     colors          tex coords
     0.5,  0.5, 0.0,  1.0, 0.0, 0.0,  1.0, 1.0,
     0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  1.0, 0.0,
    -0.5, -0.5, 0.0,  0.0, 0.0, 1.0,  0.0, 0.0,
    -0.5,  0.5, 0.0,  1.0, 1.0, 1.0,  0.0, 1.0
};

const indicies = [_]u32{
    0, 1, 3,
    1, 2, 3,
};

pub fn main() !void {
    var major : i32 = 0;
    var minor : i32 = 0;
    var rev : i32 = 0;

    // alloc
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var alloc = &gpa.allocator;

    glfw.getVersion(&major, &minor, &rev);
    std.log.info("GLFW {}.{}.{}", .{major, minor, rev});

    // Example of something that fails with GLFW_NOT_INITIALIZED - but will continue with execution
    // var monitor : ?*glfw.Monitor = glfw.getPrimaryMonitor();

    try glfw.init();
    defer glfw.terminate();
    std.log.info("GLFW Init Succeeded.", .{});
    
    var window: *glfw.Window = try glfw.createWindow(800, 640, "Hello World", null, null);

    glfw.makeContextCurrent(window);

    // texture stuff (?)
    var brick_img = try img.Image.fromFilePath(alloc, ".\\res\\brick.png");
    defer brick_img.deinit();

    const img_size = brick_img.width * brick_img.height * 8 * 3;
    var buffer: []u8 = try alloc.alloc(u8, img_size);
    defer alloc.free(buffer);
    
    for (brick_img.pixels.?.Rgba32) |pix, i| {
        buffer[i*3] = pix.R;
        buffer[i*3 + 1] = pix.G;
        buffer[i*3 + 2] = pix.B;
    }

    std.log.info("pixel format: {}", .{brick_img.pixel_format});

    var brick_tex = gl.createTexture(.@"2d");
    defer gl.deleteTexture(brick_tex);

    gl.bindTexture(brick_tex, .@"2d");
    gl.textureImage2D(
        .@"2d", 0, .rgb, brick_img.width, brick_img.height,
        .rgb, .unsigned_byte,
        buffer.ptr,
    );

    gl.textureParameter(brick_tex, .wrap_s, .repeat);
    gl.textureParameter(brick_tex, .wrap_t, .repeat);
    gl.textureParameter(brick_tex, .min_filter, .linear);
    gl.textureParameter(brick_tex, .mag_filter, .linear);

    // shader program
    const program = gl.createProgram();
    {
        const vs = gl.createShader(.vertex);
        defer vs.delete();

        vs.source(1, &.{@embedFile("..\\shader\\test.vert")});
        vs.compile();

        const fs = gl.createShader(.fragment);
        defer fs.delete();

        fs.source(1, &.{@embedFile("..\\shader\\color.frag")});
        fs.compile();

        program.attach(vs);
        defer program.detach(vs);

        program.attach(fs);
        defer program.detach(fs);

        program.link();
    }
    gl.useProgram(program);

    var vao = gl.genVertexArray();
    defer gl.deleteVertexArray(vao);

    var vbo = gl.genBuffer();
    defer gl.deleteBuffer(vbo);

    var ebo = gl.genBuffer();
    defer gl.deleteBuffer(ebo);

    gl.bindVertexArray(vao);

    gl.bindBuffer(vbo, .array_buffer);
    gl.bufferData(.array_buffer, f32, &verticies, .static_draw);

    gl.bindBuffer(ebo, .element_array_buffer);
    gl.bufferData(.element_array_buffer, u32, &indicies, .static_draw);

    // triangle positions
    gl.vertexAttribPointer(
        0, 3, .float,
        false, 8*@sizeOf(f32), 0,
    );
    gl.enableVertexAttribArray(0);
    defer gl.disableVertexAttribArray(0);

    // colors
    gl.vertexAttribPointer(
        1, 3, .float,
        false, 8*@sizeOf(f32), 3*@sizeOf(f32),
    );
    gl.enableVertexAttribArray(1);
    defer gl.disableVertexAttribArray(1);

    // texture coords
    gl.vertexAttribPointer(
        2, 2, .float,
        false, 8*@sizeOf(f32), 6*@sizeOf(f32),
    );
    gl.enableVertexAttribArray(2);
    defer gl.disableVertexAttribArray(2);

    // main loop
    while(!glfw.windowShouldClose(window)){
        if(glfw.getKey(window, glfw.Key.Escape) == glfw.KeyState.Press){
            glfw.setWindowShouldClose(window, true);
        }

        gl.clearColor(0, 0, 0, 1);
        //gl.clear(.{ .color = true, .depth = false, });

        gl.bindVertexArray(vao);
        gl.drawElements(.triangles, 6, .u32, null);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}