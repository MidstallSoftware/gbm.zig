const options = @import("options");

pub usingnamespace if (@hasDecl(options, "libgbm")) struct {
    pub const mesa = @import("backends/mesa.zig");
} else struct {};
