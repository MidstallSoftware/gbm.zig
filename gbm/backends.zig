const options = @import("options");

pub usingnamespace if (@hasDecl(options, "gbmLibdir")) struct {
    pub const mesa = @import("backends/mesa.zig");
} else struct {};
