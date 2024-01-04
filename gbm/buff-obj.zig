const std = @import("std");
const Device = @import("device.zig");
const Self = @This();

pub const Handle = union(enum) {
    ptr: *anyopaque,
    signed32: i32,
    unsigned32: u32,
    signed64: i64,
    unsigned64: u64,
};

pub const VTable = struct {
    map: *const fn (Handle, *const Device, u32, u32, u32, u32, u32, *u32, **anyopaque) anyerror!*anyopaque,
    unmap: *const fn (Handle, *const Device, *anyopaque) void,
    getWidth: *const fn (Handle, *const Device) u32,
    getHeight: *const fn (Handle, *const Device) u32,
    getStride: *const fn (Handle, *const Device) u32,
    getStrideForPlane: *const fn (Handle, *const Device, usize) u32,
    getFormat: *const fn (Handle, *const Device) u32,
    getBpp: *const fn (Handle, *const Device) u32,
    getOffset: *const fn (Handle, *const Device, usize) u32,
    getFd: *const fn (Handle, *const Device) std.os.fd_t,
    getModifier: *const fn (Handle, *const Device) u64,
    getPlaneCount: *const fn (Handle, *const Device) usize,
    getHandleForPlane: *const fn (Handle, *const Device, usize) ?Handle,
    getFdForPlane: *const fn (Handle, *const Device, usize) ?std.os.fd_t,
    write: *const fn (Handle, *const Device, []const u8) anyerror!void,
    destroy: *const fn (Handle, *const Device) void,
};

pub const DestroyUserFunc = *const fn (*const Self, ?*anyopaque) void;

vtable: *const VTable,
device: *const Device,
handle: Handle,
destroyUserData: ?*anyopaque,
destroyFunc: ?DestroyUserFunc = null,

pub inline fn map(self: *const Self, x: u32, y: u32, width: u32, height: u32, flags: u32, stride: *u32, data: **anyopaque) anyerror!*anyopaque {
    return self.vtable.map(self.handle, self.device, x, y, width, height, flags, stride, data);
}

pub inline fn unmap(self: *const Self, data: *anyopaque) void {
    return self.vtable.unmap(self.handle, self.device, data);
}

pub inline fn getWidth(self: *const Self) u32 {
    return self.vtable.getWidth(self.handle, self.device);
}

pub inline fn getHeight(self: *const Self) u32 {
    return self.vtable.getHeight(self.handle, self.device);
}

pub inline fn getStride(self: *const Self) u32 {
    return self.vtable.getStride(self.handle, self.device);
}

pub inline fn getStrideForPlane(self: *const Self, plane: usize) u32 {
    return self.vtable.getStrideForPlane(self.handle, self.device, plane);
}

pub inline fn getFormat(self: *const Self) u32 {
    return self.vtable.getFormat(self.handle, self.device);
}

pub inline fn getBpp(self: *const Self) u32 {
    return self.vtable.getBpp(self.handle, self.device);
}

pub inline fn getOffset(self: *const Self, plane: usize) u32 {
    return self.vtable.getOffset(self.handle, self.device, plane);
}

pub inline fn getFd(self: *const Self) std.os.fd_t {
    return self.vtable.getFd(self.handle, self.device);
}

pub inline fn getModifier(self: *const Self) u64 {
    return self.vtable.getModifier(self.handle, self.device);
}

pub inline fn getPlaneCount(self: *const Self) u64 {
    return self.vtable.getPlaneCount(self.handle, self.device);
}

pub inline fn getHandleForPlane(self: *const Self, plane: usize) ?Handle {
    return self.vtable.getHandleForPlane(self.handle, self.device, plane);
}

pub inline fn getFdForPlane(self: *const Self, plane: usize) ?std.os.fd_t {
    return self.vtable.getFdForPlane(self.handle, self.device, plane);
}

pub inline fn write(self: *const Self, buff: []const u8) !void {
    return self.vtable.write(self.handle, self.device, buff);
}

pub inline fn destroy(self: *const Self) void {
    if (self.destroyFunc) |f| f(self, self.destroyUserData);
    return self.vtable.destroy(self.handle, self.device);
}
