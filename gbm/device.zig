const libdrm = @import("libdrm");
const Backend = @import("backend.zig");
const BufferObject = @import("buff-obj.zig");
const Surface = @import("surface.zig");
const Self = @This();

pub const VTable = struct {
    deinit: ?*const fn (*const Self) void = null,
};

vtable: *const VTable,
ptr: *anyopaque,
backend: Backend,
node: libdrm.Node,

pub fn create(node: libdrm.Node) !*Self {
    const self = try node.allocator.create(Self);
    errdefer node.allocator.destroy(self);

    const backend = try Backend.create(&node);
    errdefer backend.deinit();

    self.* = .{
        .vtable = &.{},
        .ptr = undefined,
        .backend = backend,
        .node = node,
    };

    if (backend.vtable.initDevice) |f| try f(self);
    return self;
}

pub fn destroy(self: *const Self) void {
    if (self.vtable.deinit) |f| f(self);
    self.backend.deinit();
    self.node.allocator.destroy(self);
}

pub inline fn createBufferObject(
    self: *const Self,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) !*const BufferObject {
    return self.backend.createBufferObject(self, width, height, fmt, flags, mods);
}

pub inline fn importBufferObject(
    self: *const Self,
    t: u32,
    buff: *anyopaque,
    usage: u32,
) !*const BufferObject {
    return self.backend.importBufferObject(self, t, buff, usage);
}

pub inline fn createSurface(
    self: *const Self,
    width: u32,
    height: u32,
    fmt: u32,
    flags: u32,
    mods: ?[]const u64,
) !*const Surface {
    return self.backend.createSurface(self, width, height, fmt, flags, mods);
}
