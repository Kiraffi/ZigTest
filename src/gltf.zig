const std = @import("std");
const print = std.debug.print;

const testSource = @embedFile("data/models/arrows.gltf");


pub fn runGltf() anyerror!void
{

//    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//    defer std.debug.assert(!gpa.deinit());
//
//    var parser = std.json.Parser.init(gpa.allocator(), false);
//    defer parser.deinit();
//
//    var tree = try parser.parse(testSource);
//    defer tree.deinit();
//
//    // @TypeOf(tree.root) == std.json.Value
//
//    // Access the fields value via .get() method
//    var a = tree.root.Object.get("asset").?;
//    var b = tree.root.Object.get("scene").?;
//    var c = tree.root.Object.get("nodes").?;
//    var d = a.Object.get("generator").?;
//    const e = d.String;
//    print("a = {}\n", .{a});
//    print("b = {}\n", .{b});
//    print("c = {}\n", .{c});
//    print("d = {}\n", .{d});
//    print("e = {s}\n", .{e});
//
}