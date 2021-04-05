const glfw = @import("glfw3.zig");
const std = @import("std");
const gl = @import("zgl");

const verticies = [_]f32{
     0.5, -0.5, 0.0, 1.0, 0.0, 0.0,
    -0.5, -0.5, 0.0, 0.0, 1.0, 0.0,
     0.0,  0.5, 0.0, 0.0, 0.0, 1.0,
};

pub fn main() !void {
    var major : i32 = 0;
    var minor : i32 = 0;
    var rev : i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.log.info("GLFW {}.{}.{}\n", .{major, minor, rev});

    //Example of something that fails with GLFW_NOT_INITIALIZED - but will continue with execution
    //var monitor : ?*glfw.Monitor = glfw.getPrimaryMonitor();

    try glfw.init();
    defer glfw.terminate();
    std.log.info("GLFW Init Succeeded.\n", .{});
    
    var window: *glfw.Window = try glfw.createWindow(800, 640, "Hello World", null, null);

    glfw.makeContextCurrent(window);

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

    gl.bindVertexArray(vao);

    gl.bindBuffer(vbo, .array_buffer);
    gl.bufferData(.array_buffer, f32, &verticies, .static_draw);

    gl.vertexAttribPointer(
        0, 3, .float,
        false, 6*@sizeOf(f32), 0,
    );
    gl.enableVertexAttribArray(0);
    defer gl.disableVertexAttribArray(0);

    gl.vertexAttribPointer(
        1, 3, .float,
        false, 6*@sizeOf(f32), 3*@sizeOf(f32),
    );
    gl.enableVertexAttribArray(1);
    defer gl.disableVertexAttribArray(1);
    
    while(!glfw.windowShouldClose(window)){
        if(glfw.getKey(window, glfw.Key.Escape) == glfw.KeyState.Press){
            glfw.setWindowShouldClose(window, true);
        }

        gl.clearColor(0, 0, 0, 1);
        //gl.clear(.{ .color = true, .depth = false, });
        
        gl.bindVertexArray(vao);
        gl.drawArrays(.triangles, 0, 3);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}