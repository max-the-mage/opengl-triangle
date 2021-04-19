const glfw = @import("glfw");
const std = @import("std");
const gl = @import("zgl");
const img = @import("zigimg");

const verticies = [_]f32{
     // positions     colors          tex coords
     0.7,  0.7, 0.0,  1.0, 0.0, 0.0,  1.0, 0.0, // top right
     0.7, -0.7, 0.0,  0.0, 1.0, 0.0,  1.0, 1.0, // bottom right
    -0.7, -0.7, 0.0,  0.0, 0.0, 1.0,  0.0, 1.0, // bottom left
    -0.7,  0.7, 0.0,  1.0, 1.0, 1.0,  0.0, 0.0, // top left
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
    
    var window: *glfw.Window = try glfw.createWindow(800, 800, "Hello World", null, null);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    // texture stuff (?)
    var crate_img = try img.Image.fromFilePath(alloc, ".\\res\\crate.png");
    defer crate_img.deinit();

    const img_size = crate_img.pixels.?.len() * 8 * 4;
    var crate_buf: []u8 = try alloc.alloc(u8, img_size);
    defer alloc.free(crate_buf);

    std.log.info("pixel format: {}", .{crate_img.pixel_format});
    
    var img_iter = crate_img.iterator();
    var i: usize = 0;
    while (img_iter.next()) |pix| : (i+=4) {
        crate_buf[i] = @floatToInt(u8, pix.R * 255);
        crate_buf[i + 1] = @floatToInt(u8, pix.G * 255);
        crate_buf[i + 2] = @floatToInt(u8, pix.B * 255);
        crate_buf[i + 3] = @floatToInt(u8, pix.A * 255);
    }

    var zero_img = try img.Image.fromFilePath(alloc, ".\\res\\zero.png");
    defer zero_img.deinit();

    const zero_img_size = zero_img.pixels.?.len() * 8 * 4;
    var zero_buf = try alloc.alloc(u8, zero_img_size);
    defer alloc.free(zero_buf);

    var zero_iter = zero_img.iterator();
    i = 0;
    while (zero_iter.next()) |pix| : (i+=4) {
        zero_buf[i] = @floatToInt(u8, pix.R * 255);
        zero_buf[i + 1] = @floatToInt(u8, pix.G * 255);
        zero_buf[i + 2] = @floatToInt(u8, pix.B * 255);
        zero_buf[i + 3] = @floatToInt(u8, pix.A * 255);
    }

    var crate_tex = gl.createTexture(.@"2d");
    defer gl.deleteTexture(crate_tex);

    gl.activeTexture(.texture_0);
    gl.bindTexture(crate_tex, .@"2d");

    gl.textureParameter(crate_tex, .wrap_s, .repeat);
    gl.textureParameter(crate_tex, .wrap_t, .repeat);
    gl.textureParameter(crate_tex, .min_filter, .linear);
    gl.textureParameter(crate_tex, .mag_filter, .linear);

    gl.textureImage2D(
        .@"2d", 0, .rgba, crate_img.width, crate_img.height,
        .rgba, .unsigned_byte, crate_buf.ptr,
    );

    var zero_tex = gl.createTexture(.@"2d");
    defer gl.deleteTexture(zero_tex);

    gl.activeTexture(.texture_1);
    gl.bindTexture(zero_tex, .@"2d");

    gl.textureParameter(zero_tex, .wrap_s, .repeat);
    gl.textureParameter(zero_tex, .wrap_t, .repeat);
    gl.textureParameter(zero_tex, .min_filter, .linear);
    gl.textureParameter(zero_tex, .mag_filter, .linear);

    gl.textureImage2D(
        .@"2d", 0, .rgba, zero_img.width, zero_img.height,
        .rgba, .unsigned_byte, zero_buf.ptr,
    );


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

    gl.programUniform1i(program, program.uniformLocation("tex1"), 0);
    gl.programUniform1i(program, program.uniformLocation("tex2"), 1);

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