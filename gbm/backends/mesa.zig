const std = @import("std");
const options = @import("options");
const libdrm = @import("libdrm");
const Backend = @import("../backend.zig");
const BufferObject = @import("../buff-obj.zig");
const Device = @import("../device.zig");
const Surface = @import("../surface.zig");
const Self = @This();

comptime {
    if (!@hasDecl(options, "libgbm")) @compileError("Mesa was not enabled for Zig GBM.");
}

const gbm_bo_handle = extern union {
    ptr: *anyopaque,
    signed32: i32,
    unsigned32: u32,
    signed64: i64,
    unsigned64: u64,
};

const gbm_device = opaque {};
const gbm_bo = opaque {};
const gbm_surface = opaque {};

const VTable = struct {
    create_device: *const fn (c_int) ?*gbm_device,
    device_destroy: *const fn (*const gbm_device) void,
    bo_create_with_modifiers2: *const fn (*const gbm_device, u32, u32, u32, ?[*]const u64, c_uint, u32) ?*gbm_bo,
    bo_import: *const fn (*const gbm_device, u32, *anyopaque, u32) ?*gbm_bo,
    bo_map: *const fn (*const gbm_bo, u32, u32, u32, u32, u32, *u32, **anyopaque) ?*anyopaque,
    bo_unmap: *const fn (*const gbm_bo, *anyopaque) void,
    bo_get_width: *const fn (*const gbm_bo) u32,
    bo_get_height: *const fn (*const gbm_bo) u32,
    bo_get_stride: *const fn (*const gbm_bo) u32,
    bo_get_stride_for_plane: *const fn (*const gbm_bo, c_int) u32,
    bo_get_format: *const fn (*const gbm_bo) u32,
    bo_get_bpp: *const fn (*const gbm_bo) u32,
    bo_get_offset: *const fn (*const gbm_bo, c_int) u32,
    bo_get_handle: *const fn (*const gbm_bo) gbm_bo_handle,
    bo_get_fd: *const fn (*const gbm_bo) c_int,
    bo_get_modifier: *const fn (*const gbm_bo) u64,
    bo_get_plane_count: *const fn (*const gbm_bo) c_int,
    bo_get_handle_for_plane: *const fn (*const gbm_bo, c_int) gbm_bo_handle,
    bo_get_fd_for_plane: *const fn (*const gbm_bo, c_int) c_int,
    bo_write: *const fn (*const gbm_bo, *const anyopaque, usize) c_int,
    bo_destroy: *const fn (*const gbm_bo) void,
    surface_create_with_modifiers2: *const fn (*const gbm_device, u32, u32, u32, ?[*]const u64, c_uint, u32) ?*gbm_surface,
    surface_lock_front_buffer: *const fn (*const gbm_device) ?*gbm_bo,
    surface_release_buffer: *const fn (*const gbm_surface, *const gbm_bo) void,
    surface_has_free_buffers: *const fn (*const gbm_surface) c_int,
    surface_destroy: *const fn (*const gbm_surface) void,

    pub fn init(lib: *std.DynLib) VTable {
        var self: VTable = undefined;
        inline for (comptime std.meta.fields(VTable)) |field| {
            const funcName = "gbm_" ++ field.name;
            @field(self, field.name) = lib.lookup(@TypeOf(@field(self, field.name)), funcName) orelse @panic("Function " ++ funcName ++ " not found");
        }
        return self;
    }
};

allocator: std.mem.Allocator,
lib: std.DynLib,
vtable: VTable,

pub fn create(alloc: std.mem.Allocator) !Backend {
    const self = try alloc.create(Self);
    errdefer alloc.destroy(self);

    self.* = .{
        .allocator = alloc,
        .lib = try std.DynLib.open(options.libgbm),
        .vtable = undefined,
    };
    errdefer self.lib.close();

    self.vtable = VTable.init(&self.lib);
    return .{
        .vtable = &.{
            .isSupported = isSupported,
            .initDevice = initDevice,
            .createBufferObject = createBufferObject,
            .importBufferObject = importBufferObject,
            .createSurface = createSurface,
            .deinit = deinit,
        },
        .ptr = self,
        .name = "mesa",
    };
}

fn initBufferObject(self: *Self, device: *const Device, ptr: *const gbm_bo) !*const BufferObject {
    const bo = try self.allocator.create(BufferObject);
    errdefer self.allocator.destroy(bo);

    bo.* = .{
        .vtable = &.{
            .map = mapBufferObject,
            .unmap = unmapBufferObject,
            .getWidth = getWidthBufferObject,
            .getHeight = getHeightBufferObject,
            .getStride = getStrideBufferObject,
            .getStrideForPlane = getStrideForPlaneBufferObject,
            .getFormat = getFormatBufferObject,
            .getBpp = getBppBufferObject,
            .getOffset = getOffsetBufferObject,
            .getFd = getFdBufferObject,
            .getModifier = getModifierBufferObject,
            .getPlaneCount = getPlaneCountBufferObject,
            .getHandleForPlane = getHandleForPlaneBufferObject,
            .getFdForPlane = getFdForPlaneBufferObject,
            .write = writeBufferObject,
            .destroy = destroyBufferObject,
        },
        .device = device,
        .handle = .{
            .unsigned32 = self.vtable.bo_get_handle(ptr).unsigned32,
        },
        .ptr = @ptrCast(@constCast(ptr)),
    };
    return bo;
}

fn isSupported(ctx: *anyopaque, node: *const libdrm.Node) bool {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const ptr = self.vtable.create_device(node.fd) orelse return false;
    self.vtable.device_destroy(ptr);
    return true;
}

fn initDevice(device: *Device) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    device.ptr = @ptrCast(self.vtable.create_device(device.node.fd) orelse return switch (std.c.getErrno(-1)) {
        .NOSYS => error.NotImplemented,
        else => |e| std.os.unexpectedErrno(e),
    });
}

fn createBufferObject(
    device: *const Device,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) anyerror!*const BufferObject {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));

    const ptr = self.vtable.bo_create_with_modifiers2(@ptrCast(@alignCast(device.ptr)), width, height, fmt, if (mods) |m| m.ptr else null, if (mods) |m| @intCast(m.len) else 0, flags) orelse return switch (std.c.getErrno(-1)) {
        .NOSYS => error.NotImplemented,
        .INVAL => error.InvalidArgument,
        else => |e| std.os.unexpectedErrno(e),
    };
    errdefer self.vtable.bo_destroy(ptr);
    return self.initBufferObject(device, ptr);
}

fn importBufferObject(
    device: *const Device,
    t: u32,
    buff: *anyopaque,
    usage: u32,
) !*const BufferObject {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));

    const ptr = self.vtable.bo_import(@ptrCast(@alignCast(device.ptr)), t, buff, usage) orelse return switch (std.c.getErrno(-1)) {
        .NOSYS => error.NotImplemented,
        .INVAL => error.InvalidArgument,
        else => |e| std.os.unexpectedErrno(e),
    };
    errdefer self.vtable.bo_destroy(ptr);
    return self.initBufferObject(device, ptr);
}

fn createSurface(
    device: *const Device,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) !*const Surface {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));

    const ptr = self.vtable.surface_create_with_modifiers2(@ptrCast(@alignCast(device.ptr)), width, height, fmt, if (mods) |m| m.ptr else null, if (mods) |m| @intCast(m.len) else 0, flags) orelse return switch (std.c.getErrno(-1)) {
        .NOSYS => error.NotImplemented,
        .INVAL => error.InvalidArgument,
        else => |e| std.os.unexpectedErrno(e),
    };
    errdefer self.vtable.surface_destroy(ptr);

    const surf = try self.allocator.create(Surface);
    errdefer self.allocator.destroy(surf);

    surf.* = .{
        .vtable = &.{
            .lockFrontBuffer = lockFrontBufferSurface,
            .releaseBuffer = releaseBufferSurface,
            .hasFreeBuffers = hasFreeBuffersSurface,
            .destroy = destroySurface,
        },
        .device = device,
        .ptr = ptr,
    };
    return surf;
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.lib.close();
    self.allocator.destroy(self);
}

fn mapBufferObject(
    ctx: *anyopaque,
    _: BufferObject.Handle,
    device: *const Device,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    flags: u32,
    stride: *u32,
    mapData: **anyopaque,
) anyerror!*anyopaque {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_map(@ptrCast(ctx), x, y, width, height, flags, stride, mapData) orelse return switch (std.c.getErrno(-1)) {
        .NOSYS => error.NotImplemented,
        else => |e| std.os.unexpectedErrno(e),
    };
}

fn unmapBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device, value: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    self.vtable.bo_unmap(@ptrCast(ctx), value);
}

fn getWidthBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) u32 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_width(@ptrCast(ctx));
}

fn getHeightBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) u32 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_height(@ptrCast(ctx));
}

fn getStrideBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) u32 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_stride(@ptrCast(ctx));
}

fn getStrideForPlaneBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device, plane: usize) u32 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_stride_for_plane(@ptrCast(ctx), @intCast(plane));
}

fn getFormatBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) u32 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_format(@ptrCast(ctx));
}

fn getBppBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) u32 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_bpp(@ptrCast(ctx));
}

fn getOffsetBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device, plane: usize) u32 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_offset(@ptrCast(ctx), @intCast(plane));
}

fn getFdBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) std.os.fd_t {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_fd(@ptrCast(ctx));
}

fn getModifierBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) u64 {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_modifier(@ptrCast(ctx));
}

fn getPlaneCountBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) usize {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return @intCast(self.vtable.bo_get_plane_count(@ptrCast(ctx)));
}

fn getHandleForPlaneBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device, plane: usize) ?BufferObject.Handle {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return .{
        .unsigned32 = self.vtable.bo_get_handle_for_plane(@ptrCast(ctx), @intCast(plane)).unsigned32,
    };
}

fn getFdForPlaneBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device, plane: usize) ?std.os.fd_t {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.bo_get_fd_for_plane(@ptrCast(ctx), @intCast(plane));
}

fn writeBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device, buff: []const u8) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return switch (std.c.getErrno(self.vtable.bo_write(@ptrCast(ctx), @ptrCast(@alignCast(buff.ptr)), buff.len))) {
        .SUCCESS => {},
        .NOSYS => error.NotImplemented,
        .INVAL => error.InvalidArgument,
        else => |e| std.os.unexpectedErrno(e),
    };
}

fn destroyBufferObject(ctx: *anyopaque, _: BufferObject.Handle, device: *const Device) void {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    self.vtable.bo_destroy(@ptrCast(ctx));
    self.allocator.destroy(self);
}

fn lockFrontBufferSurface(ctx: *anyopaque, device: *const Device) anyerror!*const BufferObject {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    const ptr = self.vtable.surface_lock_front_buffer(@ptrCast(ctx)) orelse return switch (std.c.getErrno(-1)) {
        .NOSYS => error.NotImplemented,
        .INVAL => error.InvalidArgument,
        else => |e| std.os.unexpectedErrno(e),
    };
    errdefer self.vtable.bo_destroy(ptr);
    return try self.initBufferObject(device, ptr);
}

fn releaseBufferSurface(ctx: *anyopaque, device: *const Device, bo: *const BufferObject) void {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    self.vtable.surface_release_buffer(@ptrCast(ctx), @ptrCast(bo.ptr));
}

fn hasFreeBuffersSurface(ctx: *anyopaque, device: *const Device) bool {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    return self.vtable.surface_has_free_buffers(@ptrCast(ctx)) == 1;
}

fn destroySurface(ctx: *anyopaque, device: *const Device) void {
    const self: *Self = @ptrCast(@alignCast(device.backend.ptr));
    self.vtable.surface_destroy(@ptrCast(ctx));
    self.allocator.destroy(self);
}
