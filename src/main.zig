const glfw = @import("zglfw");
const std = @import("std");
const gl = @import("zgl");
const img = @import("zigimg");

const za = @import("zalgebra");
const v3 = za.vec3;

const models = @import("models.zig");

var camera_pos = v3.new(0.0, 0.0, 3.0);
var camera_target = v3.zero();

var camera_right = v3.zero();
var camera_up: v3 = v3.zero();
var camera_front = v3.back();

var yaw: f32 = -90.0;
var pitch: f32 = 0.0;

var direction = v3.back();

var rand: *std.rand.Random = undefined;

const rand_range: f32 = 20.0;

const ObjectType = enum(usize) {
    Cube,
    Prism,
};
const type_values = @typeInfo(ObjectType).Enum.fields.len;

// std.log.info("type_vales: {}", .{type_values});

const Object = struct {
    pos: v3,
    rot: v3, // angle in degrees for x, y, z axis
    speed: f32,
    obj_type: ObjectType,
};

var objects: std.ArrayList(Object) = undefined;

fn newRandomObject(list: *std.ArrayList(Object)) void {
    var new_obj = Object{
        .pos = v3.new(
            rand.float(f32) * (rand_range*2.0) - rand_range,
            rand.float(f32) * (rand_range*2.0) - rand_range,
            rand.float(f32) * (rand_range*2.0) - rand_range,
        ),
        .rot = v3.new(
            randRot(),
            randRot(),
            randRot(),
        ),
        .speed = (rand.float(f32)+1.0) * 2.0,
        .obj_type = @intToEnum(ObjectType, rand.uintLessThan(usize, type_values)),
    };

    while (new_obj.pos.length() > rand_range * 0.8) {
        new_obj.pos = new_obj.pos.scale(0.9);
    }
    list.append(new_obj) catch |e| {
        std.log.warn("unable to add object: {}", .{e});
    };

    std.debug.print("object count: {}\n", .{list.items.len});
}

pub fn main() !void {
    var camera_direction = v3.norm(camera_pos.sub(camera_target));
    camera_right = v3.norm(v3.up().cross(camera_direction));
    camera_up = camera_direction.cross(camera_right);
    try render();
}

fn render() !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = &prng.random;

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
    
    var window: *glfw.Window = try glfw.createWindow(1280, 720, "Hello World", null, null);

    glfw.makeContextCurrent(window);
    glfw.setInputMode(window, .Cursor, 0x00034003);
    _ = glfw.setCursorPosCallback(window, mouse_callback);
    _ = glfw.setScrollCallback(window, scroll_callback);
    glfw.swapInterval(1);

    gl.enable(.depth_test);

    // texture stuff (?)
    var crate_img = try img.Image.fromFilePath(alloc, ".\\res\\crate.png");
    defer crate_img.deinit();

    objects = std.ArrayList(Object).init(alloc);
    defer objects.deinit();

    for (range(rand.uintAtMost(usize, 75) + 25)) |_| {
        newRandomObject(&objects);
    }

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

    var obama_img = try img.Image.fromFilePath(alloc, ".\\res\\obamium.png");
    defer obama_img.deinit();

    const obama_img_size = obama_img.pixels.?.len() * 8 * 4;
    var obama_buf = try alloc.alloc(u8, obama_img_size);
    defer alloc.free(obama_buf);

    var obama_iter = obama_img.iterator();
    i = 0;
    while (obama_iter.next()) |pix| : (i+=4) {
        obama_buf[i] = @floatToInt(u8, pix.R * 255);
        obama_buf[i + 1] = @floatToInt(u8, pix.G * 255);
        obama_buf[i + 2] = @floatToInt(u8, pix.B * 255);
        obama_buf[i + 3] = @floatToInt(u8, pix.A * 255);
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

    var obama_tex = gl.createTexture(.@"2d");
    defer gl.deleteTexture(obama_tex);

    gl.bindTexture(obama_tex, .@"2d");

    gl.textureParameter(obama_tex, .wrap_s, .repeat);
    gl.textureParameter(obama_tex, .wrap_t, .repeat);
    gl.textureParameter(obama_tex, .min_filter, .linear);
    gl.textureParameter(obama_tex, .mag_filter, .linear);
    
    gl.textureImage2D(
        .@"2d", 0, .rgba, obama_img.width, obama_img.height,
        .rgba, .unsigned_byte, obama_buf.ptr,
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

    gl.bindVertexArray(vao);

    gl.bindBuffer(vbo, .array_buffer);
    gl.bufferData(.array_buffer, f32, &models.cube, .static_draw);

    // triangle positions
    gl.vertexAttribPointer(
        0, 3, .float,
        false, 5*@sizeOf(f32), 0,
    );
    gl.enableVertexAttribArray(0);
    defer gl.disableVertexAttribArray(0);

    // texture coords
    gl.vertexAttribPointer(
        1, 2, .float,
        false, 5*@sizeOf(f32), 3*@sizeOf(f32),
    );
    gl.enableVertexAttribArray(1);
    defer gl.disableVertexAttribArray(1);

    var model = za.mat4.identity();

    var view = za.look_at(camera_pos, camera_target, camera_up);
    var projection = za.perspective(fov, 1280.0/720.0, 0.1, 100.0);

    const model_loc = program.uniformLocation("model");
    const view_loc = program.uniformLocation("view");
    const proj_loc = program.uniformLocation("projection");

    program.uniformMatrix4(view_loc, false, &.{view.data});
    program.uniformMatrix4(proj_loc, false, &.{projection.data});

    // main loop
    while (!glfw.windowShouldClose(window)) {
        if(glfw.getKey(window, glfw.Key.Escape) == glfw.KeyState.Press){
            glfw.setWindowShouldClose(window, true);
        }

        processInput(window);

        const time_f32 = @floatCast(f32, glfw.getTime());

        gl.clearColor(0, 0, 0, 1);
        gl.clear(.{ .color = true, .depth = true, });

        gl.bindVertexArray(vao);

        view = za.look_at(camera_pos, camera_pos.add(camera_front), camera_up);
        program.uniformMatrix4(view_loc, false, &.{view.data});

        projection = za.perspective(fov, 800.0/600.0, 0.1, 100.0);
        program.uniformMatrix4(proj_loc, false, &.{projection.data});

        gl.bindBuffer(vbo, .array_buffer);

        gl.bufferData(.array_buffer, f32, &models.cube, .static_draw);
        gl.bindTexture(zero_tex, .@"2d");
        for (objects.items) |cur,j| {

            if (cur.obj_type != .Cube) {
                continue;
            }

            model = za.mat4.identity();

            model = model.translate(cur.pos);
            model = model.rotate(cur.rot.x, v3.new(1.0, 0.0, 0.0));
            model = model.rotate(cur.rot.y, v3.new(0.0, 1.0, 0.0));
            model = model.rotate(cur.rot.z, v3.new(0.0, 0.0, 1.0));
            
            if (j == 1 or @mod(j, 3) == 0) {
                model = model.rotate(@floatCast(f32, time_f32*30.0*cur.speed), v3.new(1.0, 0.4, 0.5));
            }

            program.uniformMatrix4(model_loc, false, &.{model.data});
            
            gl.drawArrays(.triangles, 0, 36);
        }

        gl.bufferData(.array_buffer, f32, &models.prism, .static_draw);
        gl.bindTexture(obama_tex, .@"2d");
        for (objects.items) |cur,j| {

            if (cur.obj_type != .Prism) {
                continue;
            }

            model = za.mat4.identity();

            model = model.translate(cur.pos);
            model = model.rotate(cur.rot.x, v3.new(1.0, 0.0, 0.0));
            model = model.rotate(cur.rot.y, v3.new(0.0, 1.0, 0.0));
            model = model.rotate(cur.rot.z, v3.new(0.0, 0.0, 1.0));

            model = model.rotate(@floatCast(f32, time_f32*60.0*cur.speed), v3.new(0.0, 1.0, 0.0));

            program.uniformMatrix4(model_loc, false, &.{model.data});
            
            gl.drawArrays(.triangles, 0, 18);
        }

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}

fn range(len: usize) []u0 {
    return @as([*]u0, undefined)[0..len];
}

fn randRot() f32 {
    return rand.float(f32) * 360.0;
}

var e_is_pressed = false;
var q_is_pressed = false;
fn processInput(window: *glfw.Window) void {
    const camera_speed: f32 = 0.1;
    // vertically locked camera front
    
    var new_dir = v3.zero();
    new_dir.x = @cos(za.to_radians(yaw));
    new_dir.z = @sin(za.to_radians(yaw));

    const camera_vl = new_dir.norm();

    if (glfw.getKey(window, .W) == .Press)
        camera_pos = camera_pos.add(camera_vl.scale(camera_speed));
    if (glfw.getKey(window, .S) == .Press)
        camera_pos = camera_pos.sub(camera_vl.scale(camera_speed));
    if (glfw.getKey(window, .A) == .Press)
        camera_pos = camera_pos.sub((v3.norm(camera_front.cross(camera_up))).scale(camera_speed));
    if (glfw.getKey(window, .D) == .Press)
        camera_pos = camera_pos.add((v3.norm(camera_front.cross(camera_up))).scale(camera_speed));
    if (glfw.getKey(window, .LeftShift) == .Press)
        camera_pos = camera_pos.sub(camera_up.scale(camera_speed));
    if (glfw.getKey(window, .Space) == .Press)
        camera_pos = camera_pos.add(camera_up.scale(camera_speed));
    
    if (glfw.getKey(window, .E) == .Press) {
        if (!e_is_pressed) {
            const new_obj = Object{
                .pos = camera_pos.add(camera_front.scale(1.5)),
                .rot = v3.new(
                    randRot(),
                    randRot(),
                    randRot(),
                ),
                .speed = (rand.float(f32)+1.0) * 2.0,
                .obj_type = .Cube
            };

            objects.append(new_obj) catch |e| {
                std.log.warn("unable to add cube: {}", .{e});
            };

            e_is_pressed = true;
        }
    }

    if (glfw.getKey(window, .E) == .Release) {
        e_is_pressed = false;
    }

    if (glfw.getKey(window, .Q) == .Press) {
        if (!q_is_pressed) {
            const new_obj = Object{
                .pos = camera_pos.add(camera_front.scale(1.5)),
                .rot = v3.new(
                    randRot(),
                    randRot(),
                    randRot(),
                ),
                .speed = (rand.float(f32)+1.0) * 2.0,
                .obj_type = .Prism,
            };

            objects.append(new_obj) catch |e| {
                std.log.warn("unable to add prism: {}", .{e});
            };
            q_is_pressed = true;
        }
    }

    if (glfw.getKey(window, .Q) == .Release) {
        q_is_pressed = false;
    }

    if (glfw.getKey(window, .F) == .Press) {
        newRandomObject(&objects);
    }
}

var last_x: f64 = 640.0;
var last_y: f64 = 460.0;

var first_mouse = true;
fn mouse_callback(window: *glfw.Window, xpos: f64, ypos: f64) callconv(.C) void {
    if (first_mouse) {
        last_x = xpos;
        last_y = ypos;
        first_mouse = false;
    }
    var xoffset = xpos - last_x;
    var yoffset = last_y - ypos;
    last_x = xpos;
    last_y = ypos;

    const sensitivity: f64 = 0.1;
    xoffset *= sensitivity;
    yoffset *= sensitivity;

    yaw += @floatCast(f32, xoffset);
    pitch += @floatCast(f32, yoffset);

    if (pitch > 89.0) pitch = 89.0;
    if (pitch < -89.0) pitch = -89.0;

    direction.x = @cos(za.to_radians(yaw)) * @cos(za.to_radians(pitch));
    direction.y = @sin(za.to_radians(pitch));
    direction.z = @sin(za.to_radians(yaw)) * @cos(za.to_radians(pitch));

    camera_front = direction.norm();
}

var fov: f32 = 70.0;

fn scroll_callback(window: *glfw.Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    fov -= @floatCast(f32, yoffset);
    if (fov < 1.0) fov = 1.0;
    if (fov > 179.0) fov = 179.0;
}