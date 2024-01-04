const std = @import("std");
const Allocator = std.mem.Allocator;
const libdrm = @import("libdrm");
const BufferObject = @import("buff-obj.zig");
const Device = @import("device.zig");
const Surface = @import("surface.zig");
const backends = @import("backends.zig");
const Self = @This();

pub const VTable = struct {
    isSupported: *const fn (*const libdrm.Node) bool,
    createBufferObject: *const fn (*const libdrm.Node, u32, u32, u32, u32, ?[]const u64) anyerror!*const BufferObject,
    importBufferObject: *const fn (*const libdrm.Node, u32, *anyopaque, u32) anyerror!*const BufferObject,
    createSurface: *const fn (*const libdrm.Node, u32, u32, u32, u32, ?[]const u64) anyerror!*const Surface,
};

vtable: *const VTable,
name: []const u8,
nameZ: [*:0]const u8,

pub fn create(node: libdrm.Node) !Self {
    if (node.getVersion() catch null) |version| {
        defer version.deinit(node.allocator);

        inline for (comptime std.meta.declarations(backends)) |decl| {
            if (std.mem.eql(u8, version.name[0..version.nameLen], decl.name)) {
                const backend = @field(backends, decl.name);
                const self = Self{
                    .vtable = &.{
                        .isSupported = backend.isSupported,
                        .createBufferObject = backend.createBufferObject,
                        .importBufferObject = backend.importBufferObject,
                        .createSurface = backend.createSurface,
                    },
                    .name = decl.name,
                    .nameZ = decl.name,
                };

                if (self.isSupported(node)) return self;
            }
        }
    }

    // TODO: allow for falling back to mesa3d's gbm.
    return error.NotSupported;
}

pub inline fn isSupported(self: *const Self, node: libdrm.Node) bool {
    return self.vtable.isSupported(node);
}

pub inline fn createBufferObject(
    self: *const Self,
    node: *const libdrm.Node,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) !*const BufferObject {
    return self.vtable.createBufferObject(node, width, height, fmt, flags, mods);
}

pub inline fn importBufferObject(
    self: *const Self,
    node: *const libdrm.Node,
    t: u32,
    buff: *anyopaque,
    usage: u32,
) !*const BufferObject {
    return self.vtable.importBufferObject(node, t, buff, usage);
}

pub inline fn createSurface(
    self: *const Self,
    node: *const libdrm.Node,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) !*const Surface {
    return self.vtable.createSurface(node, width, height, fmt, flags, mods);
}
