const std = @import("std");
const Allocator = std.mem.Allocator;
const libdrm = @import("libdrm");
const BufferObject = @import("buff-obj.zig");
const Device = @import("device.zig");
const Surface = @import("surface.zig");
const backends = @import("backends.zig");
const Self = @This();

pub const VTable = struct {
    isSupported: *const fn (*anyopaque, *const libdrm.Node) bool,
    initDevice: ?*const fn (*Device) anyerror!void = null,
    createBufferObject: *const fn (*const Device, u32, u32, u32, u32, ?[]const u64) anyerror!*const BufferObject,
    importBufferObject: *const fn (*const Device, u32, *anyopaque, u32) anyerror!*const BufferObject,
    createSurface: *const fn (*const Device, u32, u32, u32, u32, ?[]const u64) anyerror!*const Surface,
    deinit: ?*const fn (*anyopaque) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,
name: [*:0]const u8,

pub fn create(node: *const libdrm.Node) !Self {
    if (node.getVersion() catch null) |version| {
        defer version.deinit(node.allocator);

        inline for (comptime std.meta.declarations(backends)) |decl| {
            if (std.mem.eql(u8, version.name[0..version.nameLen], decl.name)) {
                const backend = @field(backends, decl.name);
                const self = try backend.create(node.allocator);
                if (self.isSupported(node)) return self;
            }
        }
    }

    if (@hasDecl(backends, "mesa")) {
        const backend = backends.mesa;
        const self = try backend.create(node.allocator);

        if (self.isSupported(node)) return self;
    }
    return error.NotSupported;
}

pub inline fn isSupported(self: *const Self, node: *const libdrm.Node) bool {
    return self.vtable.isSupported(self.ptr, node);
}

pub inline fn createBufferObject(
    self: *const Self,
    device: *const Device,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) !*const BufferObject {
    return self.vtable.createBufferObject(device, width, height, fmt, flags, mods);
}

pub inline fn importBufferObject(
    self: *const Self,
    device: *const Device,
    t: u32,
    buff: *anyopaque,
    usage: u32,
) !*const BufferObject {
    return self.vtable.importBufferObject(device, t, buff, usage);
}

pub inline fn createSurface(
    self: *const Self,
    device: *const Device,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) !*const Surface {
    return self.vtable.createSurface(device, width, height, fmt, flags, mods);
}

pub inline fn deinit(self: *const Self) void {
    if (self.vtable.deinit) |f| f(self.ptr);
}
