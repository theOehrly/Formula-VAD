const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Simulation = @import("../simulator.zig").Simulation;
const statistics = @import("../Evaluator/statistics.zig");
const SingleStats = statistics.SingleStats;
const AggregateStats = statistics.AggregateStats;
const StatConfig = statistics.StatConfig;

pub const definitions =
    \\P   (Positives):                            Total number of real speech segments (from reference labels)
    \\TP  (True positives):                       Number of correctly detected speech segments
    \\FP  (False positives):                      Number of incorrectly detected speech segments
    \\FN  (False negatives):                      Number of missed speech segments
    \\TPR (True positive rate, sensitivity):      Probability that VAD detects a real speech segment. = TP / P
    \\FNR (False negative rate, miss rate):       Probability that VAD misses a speech segment.       = FN / P
    \\PPV (Precision, Positive predictive value): Probability that detected speech segment is true.   = TP / (TP + FP)
    \\FDR (False discovery rate):                 Probability that detected speech segment is false.  = FP / (TP + FP)
;

pub const table_header_fmt = "| {s: >30} | {s: >4} | {s: >4} | {s: >4} | {s: >4} | {s: >6} | {s: >6} | {s: >6} | {s: >8} |\n";
pub const table_header_vals = .{ "Name", "P", "TP", "FP", "FN", "TPR", "FNR", "PPV", "FDR (!)" };

pub const table_separator_fmt = "| {s:->30} | {s:->4} | {s:->4} | {s:->4} | {s:->4} | {s:->6} | {s:->6} | {s:->6} | {s:->8} |\n";
pub const table_separator_vals = .{ "", "", "", "", "", "", "", "", "" };

pub const table_row_fmt = "| {s: >30} | {d: >4.0} | {d: >4.0} | {d: >4.0} | {d: >4.0} | {d: >5.1}% | {d: >5.1}% | {d: >5.1}% | {d: >7.1}% |\n";

pub fn bufPrintSimulationReport(
    allocator: Allocator,
    simulation: Simulation,
    stat_config: StatConfig,
) ![]const u8 {
    var array_buf = ArrayList(u8).init(allocator);
    const writer = array_buf.writer();

    // Aggregate results and print them
    var all_stats_list = std.ArrayList(SingleStats).init(allocator);
    errdefer all_stats_list.deinit();

    try writer.print("\n\n=> Definitions\n\n{s}", .{definitions});
    try writer.print("\n\n=> Performance Report\n\n", .{});
    try writer.print(table_header_fmt, table_header_vals);
    try writer.print(table_separator_fmt, table_separator_vals);

    for (simulation.instances) |instance| {
        if (instance.evaluator) |evaluator| {
            const stats = try statistics.fromEvaluator(evaluator, stat_config);
            try all_stats_list.append(stats);

            try writer.print(table_row_fmt, .{
                instance.name,
                stats.total_positives_sec,
                stats.true_positives_sec,
                stats.false_positives_sec,
                stats.false_negatives_sec,
                stats.true_positive_rate * 100,
                stats.false_negative_rate * 100,
                stats.precision * 100,
                stats.false_discovery_rate * 100,
            });
        }
    }

    const all_stats = try all_stats_list.toOwnedSlice();
    defer allocator.free(all_stats);

    const agg = statistics.aggregate(all_stats);

    try writer.print("\n=> Aggregate stats \n\n", .{});
    try writer.print("Total speech duration  (P): {d: >7.1} sec\n", .{agg.total_positives_sec});
    try writer.print("True positives        (TP): {d: >7.1} sec\n", .{agg.true_positives_sec});
    try writer.print("False positives       (FP): {d: >7.1} sec\n", .{agg.false_positives_sec});
    try writer.print("False negatives       (FN): {d: >7.1} sec", .{agg.false_negatives_sec});
    try writer.print("    Min.    Avg.    Max. \n", .{});
    try writer.print(
        "True positive rate   (TPR):   {d: >5.1}%  |  {d: >5.1}% /{d: >5.1}% /{d: >5.1}% \n",
        .{
            agg.true_positive_rate.overall * 100,
            agg.true_positive_rate.min * 100,
            agg.true_positive_rate.avg * 100,
            agg.true_positive_rate.max * 100,
        },
    );
    try writer.print(
        "False negative rate  (FNR):   {d: >5.1}%  |  {d: >5.1}% /{d: >5.1}% /{d: >5.1}% \n",
        .{
            agg.false_negative_rate.overall * 100,
            agg.false_negative_rate.min * 100,
            agg.false_negative_rate.avg * 100,
            agg.false_negative_rate.max * 100,
        },
    );
    try writer.print(
        "Precision            (PPV):   {d: >5.1}%  |  {d: >5.1}% /{d: >5.1}% /{d: >5.1}% \n",
        .{
            agg.precision.overall * 100,
            agg.precision.min * 100,
            agg.precision.avg * 100,
            agg.precision.max * 100,
        },
    );
    try writer.print(
        "False discovery rate (FDR):   {d: >5.1}%  |  {d: >5.1}% /{d: >5.1}% /{d: >5.1}% \n",
        .{
            agg.false_discovery_rate.overall * 100,
            agg.false_discovery_rate.min * 100,
            agg.false_discovery_rate.avg * 100,
            agg.false_discovery_rate.max * 100,
        },
    );
    try writer.print("F-Score (β = {d: >5.2})       :   {d: >5.1}% \n", .{ agg.f_score_beta, agg.f_score * 100 });
    try writer.print("Fowlkes-Mallows index     :   {d: >5.1}% \n", .{agg.fm_index * 100});

    return array_buf.toOwnedSlice();
}

const SingleResultSection = struct {
    name: []const u8,
    stats: SingleStats
};

const JsonRoot = struct {
    results: []SingleResultSection,
    aggregated: AggregateStats,
    alt: []AggregateStats,
};

pub fn createJsonSimulationReport(
    allocator: Allocator,
    simulation: Simulation,
    stat_config: StatConfig,
) ![]const u8 {
    var array_buf = ArrayList(u8).init(allocator);
    const writer = array_buf.writer();

    var all_stats_list = std.ArrayList(SingleStats).init(allocator);
    errdefer all_stats_list.deinit();

    var single_results_list = std.ArrayList(SingleResultSection).init(allocator);
    errdefer single_results_list.deinit();

    for (simulation.instances) |instance| {
        if (instance.evaluator) |evaluator| {
            var stats = statistics.fromEvaluator(evaluator, stat_config);
            const result = SingleResultSection{
                .name = instance.name,
                .stats = stats
            };
            try all_stats_list.append(stats);
            try single_results_list.append(result);
        }
    }

    const all_stats = try all_stats_list.toOwnedSlice();
    defer allocator.free(all_stats);

    const single_results = try single_results_list.toOwnedSlice();
    defer allocator.free(single_results);

    const agg = statistics.aggregate(all_stats);

    var alt_all_stats_list = std.ArrayList([]SingleStats).init(allocator);
    errdefer {
        for (alt_all_stats_list.items) |slice| {
            allocator.free(slice);
        }
        alt_all_stats_list.deinit();
    }

    var per_alt_all_stats_list = std.ArrayList(SingleStats).init(allocator);
    errdefer per_alt_all_stats_list.deinit();
    if (simulation.config.vad_config.alt_vad_machine_configs) |alt_configs| {
        for (0..alt_configs.len) |i| {
            for (simulation.instances) |instance| {
                if (instance.alt_evaluators) |alt_evaluators| {
                    var stats = statistics.fromEvaluator(alt_evaluators[i], stat_config);
                    try per_alt_all_stats_list.append(stats);
                }
            }
            const per_alt_all_stats = try per_alt_all_stats_list.toOwnedSlice();
            try alt_all_stats_list.append(per_alt_all_stats);
        }
    }

    const alt_all_stats = try alt_all_stats_list.toOwnedSlice();
    defer {
        for (0..alt_all_stats.len) |i| {
            allocator.free(alt_all_stats[i]);
        }
        allocator.free(alt_all_stats);
    }

    var alt_agg_list = std.ArrayList(AggregateStats).init(allocator);
    errdefer alt_agg_list.deinit();

    for (0..alt_all_stats.len) |i| {
        const alt_agg = statistics.aggregate(alt_all_stats[i]);
        try alt_agg_list.append(alt_agg);
    }

    const alt_aggs = try alt_agg_list.toOwnedSlice();

    const json_root = JsonRoot {
        .results = single_results,
        .aggregated = agg,
        .alt = alt_aggs
    };

    const options = std.json.StringifyOptions{
        .whitespace = .{
            .indent_level = 0,
            .indent = .{ .space = 4 },
            .separator = true,
        },
    };

    try std.json.stringify(json_root, options, writer);

    return array_buf.toOwnedSlice();
}