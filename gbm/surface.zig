const std = @import("std");
const BufferObject = @import("buff-obj.zig");
const Device = @import("device.zig");
const Self = @This();

pub const VTable = struct {
    lockFrontBuffer: *const fn (*anyopaque, *const Device) anyerror!*const BufferObject,
    releaseBuffer: *const fn (*anyopaque, *const Device, *const BufferObject) void,
    hasFreeBuffers: *const fn (*anyopaque, *const Device) bool,
    destroy: *const fn (*anyopaque, *const Device) void,
};

vtable: *const VTable,
device: *const Device,
ptr: *anyopaque,

pub inline fn lockFrontBuffer(self: *const Self) !*const BufferObject {
    return self.vtable.lockFrontBuffer(self.ptr, self.device);
}

pub inline fn releaseBuffer(self: *const Self, bo: *const BufferObject) void {
    return self.vtable.releaseBuffer(self.ptr, self.device, bo);
}

pub inline fn hasFreeBuffers(self: *const Self) bool {
    return self.vtable.hasFreeBuffers(self.ptr, self.device);
}

pub inline fn destroy(self: *const Self) void {
    self.vtable.destroy(self.ptr, self.device);
}
