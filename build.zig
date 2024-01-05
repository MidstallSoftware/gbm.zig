const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;
    const no_tests = b.option(bool, "no-tests", "skip generating tests") orelse false;
    const use_mesa = b.option(bool, "use-mesa", "whether to use mesa's gbm as a fallback") orelse false;

    const libdrm = b.dependency("libdrm", .{
        .target = target,
        .optimize = optimize,
    });

    const options = b.addOptions();

    if (use_mesa) {
        const pkgconfig = try b.findProgram(&.{"pkg-config"}, &.{});
        options.addOption([]const u8, "libgbm", blk: {
            const tmp = b.run(&.{
                pkgconfig,
                "--variable=libdir",
                "gbm",
            });
            break :blk b.pathJoin(&.{
                tmp[0..(tmp.len - 1)],
                b.fmt("{s}gbm{s}", .{
                    std.mem.sliceTo(target.libPrefix(), 0),
                    std.mem.sliceTo(target.dynamicLibSuffix(), 0),
                }),
            });
        });
    }

    const module = b.addModule("gbm", .{
        .source_file = .{ .path = b.pathFromRoot("gbm.zig") },
        .dependencies = &.{
            .{
                .name = "libdrm",
                .module = libdrm.module("libdrm"),
            },
            .{
                .name = "options",
                .module = options.createModule(),
            },
        },
    });

    if (target.getOsTag() != .wasi) {
        const libmodule = b.addSharedLibrary(.{
            .name = "gbm",
            .root_source_file = .{ .path = b.pathFromRoot("gbm-c.zig") },
            .version = .{
                .major = 1,
                .minor = 0,
                .patch = 0,
            },
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        libmodule.addModule("libdrm", libdrm.module("libdrm"));
        libmodule.addModule("options", options.createModule());
        b.installArtifact(libmodule);
    }

    const exe_example = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{
            .path = b.pathFromRoot("example.zig"),
        },
        .target = target,
        .optimize = optimize,
    });
    exe_example.addModule("gbm", module);
    b.installArtifact(exe_example);

    if (!no_tests) {
        const step_test = b.step("test", "Run all unit tests");

        const unit_tests = b.addTest(.{
            .root_source_file = .{
                .path = b.pathFromRoot("gbm.zig"),
            },
            .target = target,
            .optimize = optimize,
        });

        unit_tests.addModule("libdrm", libdrm.module("libdrm"));
        unit_tests.addModule("options", options.createModule());

        const run_unit_tests = b.addRunArtifact(unit_tests);
        step_test.dependOn(&run_unit_tests.step);

        if (!no_docs) {
            const docs = b.addInstallDirectory(.{
                .source_dir = unit_tests.getEmittedDocs(),
                .install_dir = .prefix,
                .install_subdir = "docs",
            });

            b.getInstallStep().dependOn(&docs.step);
        }
    }
}
