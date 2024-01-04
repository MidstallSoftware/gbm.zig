const std = @import("std");
const gbm = @import("gbm.zig");

const DestroyWrapper = struct {
    func: *const fn (*const gbm_bo, ?*anyopaque) callconv(.C) void,
    data: ?*anyopaque,

    pub fn method(bo: *const gbm.BufferObject, ctx: ?*anyopaque) void {
        const self: *DestroyWrapper = @ptrCast(@alignCast(ctx.?));
        self.func(@ptrCast(@alignCast(bo)), self.data);
        std.heap.c_allocator.destroy(self);
    }
};

pub const gbm_bo_handle = extern union {
    ptr: *anyopaque,
    signed32: i32,
    unsigned32: u32,
    signed64: i64,
    unsigned64: u64,
};

pub const gbm_device = struct {};
pub const gbm_bo = struct {};
pub const gbm_surface = struct {};

export fn gbm_device_get_fd(ctx: *gbm_device) c_int {
    const self: *gbm.Device = @ptrCast(@alignCast(ctx));
    return self.node.fd;
}

export fn gbm_device_get_backend_name(ctx: *gbm_device) callconv(.C) [*:0]const u8 {
    const self: *gbm.Device = @ptrCast(@alignCast(ctx));
    return self.backend.nameZ;
}

export fn gbm_create_device(fd: c_int) ?*gbm_device {
    return @ptrCast(@alignCast(gbm.Device.create(.{
        .allocator = std.heap.c_allocator,
        .fd = fd,
    }) catch |err| blk: {
        std.c._errno().* = @intFromEnum(switch (err) {
            error.OutOfMemory => std.c.E.NOMEM,
            else => std.c.E.IO,
        });
        break :blk null;
    }));
}

export fn gbm_device_destroy(ctx: *gbm_device) void {
    const self: *gbm.Device = @ptrCast(@alignCast(ctx));
    self.destroy();
}

export fn gbm_bo_create(ctx: *gbm_device, width: u32, height: u32, fmt: u32, flags: u32) ?*const gbm_bo {
    return gbm_bo_create_with_modifiers2(ctx, width, height, fmt, null, 0, flags);
}

export fn gbm_bo_create_with_modifiers(ctx: *gbm_device, width: u32, height: u32, fmt: u32, modifiers: ?*u64, count: c_uint, flags: u32) ?*const gbm_bo {
    return gbm_bo_create_with_modifiers2(ctx, width, height, fmt, modifiers, count, flags);
}

export fn gbm_bo_create_with_modifiers2(ctx: *gbm_device, width: u32, height: u32, fmt: u32, modifiers: ?*u64, count: c_uint, flags: u32) ?*const gbm_bo {
    const self: *gbm.Device = @ptrCast(@alignCast(ctx));
    return @ptrCast(@alignCast(self.createBufferObject(width, height, fmt, flags, if (modifiers) |m| @as([*]const u64, @ptrCast(@alignCast(m)))[0..count] else null) catch |err| blk: {
        std.c._errno().* = @intFromEnum(switch (err) {
            error.OutOfMemory => std.c.E.NOMEM,
            else => std.c.E.IO,
        });
        break :blk null;
    }));
}

export fn gbm_bo_map(ctx: *gbm_bo, x: u32, y: u32, width: u32, height: u32, flags: u32, stride: *u32, data: **anyopaque) ?*anyopaque {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.map(x, y, width, height, flags, stride, data) catch |err| blk: {
        std.c._errno().* = @intFromEnum(switch (err) {
            error.OutOfMemory => std.c.E.NOMEM,
            else => std.c.E.IO,
        });
        break :blk null;
    };
}

export fn gbm_bo_unmap(ctx: *gbm_bo, data: *anyopaque) void {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    self.unmap(data);
}

export fn gbm_bo_get_width(ctx: *gbm_bo) u32 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getWidth();
}

export fn gbm_bo_get_height(ctx: *gbm_bo) u32 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getHeight();
}

export fn gbm_bo_get_stride(ctx: *gbm_bo) u32 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getStride();
}

export fn gbm_bo_get_stride_for_plane(ctx: *gbm_bo, plane: c_int) u32 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getStrideForPlane(@intCast(plane));
}

export fn gbm_bo_get_format(ctx: *gbm_bo) u32 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getFormat();
}

export fn gbm_bo_get_bpp(ctx: *gbm_bo) u32 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getBpp();
}

export fn gbm_bo_get_offset(ctx: *gbm_bo, plane: c_int) u32 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getOffset(@intCast(plane));
}

export fn gbm_bo_get_device(ctx: *gbm_bo) *const gbm_device {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return @ptrCast(@alignCast(self.device));
}

export fn gbm_bo_get_handle(ctx: *gbm_bo) gbm_bo_handle {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return switch (self.handle) {
        inline else => |val, tag| @unionInit(gbm_bo_handle, @tagName(tag), val),
    };
}

export fn gbm_bo_get_fd(ctx: *gbm_bo) c_int {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getFd();
}

export fn gbm_bo_get_modifier(ctx: *gbm_bo) u64 {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getModifier();
}

export fn gbm_bo_get_plane_count(ctx: *gbm_bo) c_int {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return @intCast(self.getPlaneCount());
}

export fn gbm_bo_get_handle_for_plane(ctx: *gbm_bo, plane: c_int) gbm_bo_handle {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return switch (self.getHandleForPlane(@intCast(plane)) orelse gbm.BufferObject.Handle{ .ptr = undefined }) {
        inline else => |val, tag| @unionInit(gbm_bo_handle, @tagName(tag), val),
    };
}

export fn gbm_bo_get_fd_for_plane(ctx: *gbm_bo, plane: c_int) c_int {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    return self.getFdForPlane(@intCast(plane)) orelse @as(c_int, 0);
}

export fn gbm_bo_write(ctx: *gbm_bo, ptr: *const anyopaque, count: usize) c_int {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    self.write(@as([*]const u8, @ptrCast(@alignCast(ptr)))[0..count]) catch |err| {
        std.c._errno().* = @intFromEnum(switch (err) {
            error.OutOfMemory => std.c.E.NOMEM,
            else => std.c.E.IO,
        });
        return -1;
    };
    return 0;
}

export fn gbm_bo_set_user_data(ctx: *gbm_bo, data: ?*anyopaque, optFunc: ?*const fn (*const gbm_bo, ?*anyopaque) callconv(.C) void) void {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));

    if (optFunc) |func| {
        const wrapper = std.heap.c_allocator.create(DestroyWrapper) catch @panic("OOM");
        wrapper.func = func;
        wrapper.data = data;

        self.destroyUserData = wrapper;
        self.destroyFunc = DestroyWrapper.method;
    } else {
        self.destroyUserData = data;
    }
}

export fn gbm_bo_get_user_data(ctx: *gbm_bo) ?*anyopaque {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));

    if (self.destroyFunc) |_| {
        const wrapper: *DestroyWrapper = @ptrCast(@alignCast(self.destroyUserData.?));
        return wrapper.data;
    }
    return self.destroyUserData;
}

export fn gbm_bo_destroy(ctx: *gbm_bo) void {
    const self: *gbm.BufferObject = @ptrCast(@alignCast(ctx));
    self.destroy();
}

export fn gbm_surface_create(ctx: *gbm_device, width: u32, height: u32, fmt: u32, flags: u32) ?*const gbm_surface {
    return gbm_surface_create_with_modifiers2(ctx, width, height, fmt, null, 0, flags);
}

export fn gbm_surface_create_with_modifiers(ctx: *gbm_device, width: u32, height: u32, fmt: u32, modifiers: ?*u64, count: c_uint, flags: u32) ?*const gbm_surface {
    return gbm_surface_create_with_modifiers2(ctx, width, height, fmt, modifiers, count, flags);
}

export fn gbm_surface_create_with_modifiers2(ctx: *gbm_device, width: u32, height: u32, fmt: u32, modifiers: ?*u64, count: c_uint, flags: u32) ?*const gbm_surface {
    const self: *gbm.Device = @ptrCast(@alignCast(ctx));
    return @ptrCast(@alignCast(self.createSurface(width, height, fmt, flags, if (modifiers) |m| @as([*]const u64, @ptrCast(@alignCast(m)))[0..count] else null) catch |err| blk: {
        std.c._errno().* = @intFromEnum(switch (err) {
            error.OutOfMemory => std.c.E.NOMEM,
            else => std.c.E.IO,
        });
        break :blk null;
    }));
}

export fn gbm_surface_lock_front_buffer(ctx: *gbm_surface) ?*const gbm_bo {
    const self: *gbm.Surface = @ptrCast(@alignCast(ctx));
    return @ptrCast(@alignCast(self.lockFrontBuffer() catch |err| blk: {
        std.c._errno().* = @intFromEnum(switch (err) {
            error.OutOfMemory => std.c.E.NOMEM,
            else => std.c.E.IO,
        });
        break :blk null;
    }));
}

export fn gbm_surface_release_buffer(ctx: *gbm_surface, boCtx: *gbm_bo) void {
    const self: *gbm.Surface = @ptrCast(@alignCast(ctx));
    const bo: *gbm.BufferObject = @ptrCast(@alignCast(boCtx));
    return self.releaseBuffer(bo);
}

export fn gbm_surface_has_free_buffers(ctx: *gbm_surface) c_int {
    const self: *gbm.Surface = @ptrCast(@alignCast(ctx));
    return @intFromBool(self.hasFreeBuffers());
}

export fn gbm_surface_destroy(ctx: *gbm_surface) void {
    const self: *gbm.Surface = @ptrCast(@alignCast(ctx));
    self.destroy();
}
