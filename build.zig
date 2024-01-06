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

        b.getInstallStep().dependOn(&b.addInstallHeaderFile(blk: {
            const tmp = b.run(&.{
                pkgconfig,
                "--variable=includedir",
                "gbm",
            });
            break :blk b.pathJoin(&.{
                tmp[0..(tmp.len - 1)],
                "gbm.h",
            });
        }, "gbm.h").step);

        options.addOption([]const u8, "libgbm", blk: {
            const tmp = b.run(&.{
                pkgconfig,
                "--variable=libdir",
                "gbm",
            });
            break :blk b.pathJoin(&.{
                tmp[0..(tmp.len - 1)],
                b.fmt("{s}gbm{s}", .{
                    std.mem.sliceTo(target.result.libPrefix(), 0),
                    std.mem.sliceTo(target.result.dynamicLibSuffix(), 0),
                }),
            });
        });
    }

    const module = b.addModule("gbm", .{
        .root_source_file = .{ .path = b.pathFromRoot("gbm.zig") },
        .imports = &.{
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

    if (target.result.os.tag != .wasi) {
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

        libmodule.root_module.addImport("libdrm", libdrm.module("libdrm"));
        libmodule.root_module.addImport("options", options.createModule());
        b.installArtifact(libmodule);

        const file = try b.cache_root.join(b.allocator, &[_][]const u8{"gbm.pc"});
        const pkgconfig_file = try std.fs.cwd().createFile(file, .{});

        const writer = pkgconfig_file.writer();
        try writer.print(
            \\prefix={s}
            \\includedir=${{prefix}}/include
            \\libdir=${{prefix}}/lib
            \\
            \\Name: gbm
            \\URL: https://github.com/MidstallSoftware/gbm.zig
            \\Description: Mesa gbm library (zig port)
            \\Version: 23.1.9
            \\Cflags: -I${{includedir}}
            \\Libs: -L${{libdir}} -lgbm
        , .{b.install_prefix});
        defer pkgconfig_file.close();

        b.installFile(file, "share/pkgconfig/gbm.pc");
    }

    const exe_example = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{
            .path = b.pathFromRoot("example.zig"),
        },
        .target = target,
        .optimize = optimize,
    });
    exe_example.root_module.addImport("gbm", module);
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

        unit_tests.root_module.addImport("libdrm", libdrm.module("libdrm"));
        unit_tests.root_module.addImport("options", options.createModule());

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
