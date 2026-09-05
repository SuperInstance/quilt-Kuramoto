// q_snaplog.v -- T1 QUF-SNAP: the fabric's fire-event snap log (quilt-verilog
// sketch lane, docs/NOVEL-ENHANCEMENTS.md T1, Casey directive 2026-09-02).
//
// Design: QUF carries complete state; this is the complementary object -- an
// append-only ring of fire events (the snap-point log of docs/THE-TICK.md
// §9). State + log = full replay: the testbench, the soft core, and the
// FPGA load identically as today, but history becomes auditable after the
// fact. The DIVERGENCE.md window-edge bug class -- two models agreeing on
// the snapshot but disagreeing on what happened between snapshots -- is
// killed by making the between-events a file-format feature.
//
// Implementation (the T1 wording, literally): fire address+sign+tick
// packed into ONE WIDE SHIFTER; overflow drops the oldest (feeler gauges
// are finite). One entry per fire:
//
//   [TICKW-1:0]  tick stamp at fire (pre-increment value of the window the
//                fire happened inside; tick 0 = pre-first-tick epoch)
//   [bit]        fsign -- sign of activation at fire
//   [AIDW-1:0]   fsrc  -- firing cell id (the "fire address")
//   [PW-1:0]     fmag  -- activation magnitude at fire (0 when MAG=0)
//
// Layout is FIXED (all four fields always allocated; MAG=0 zeroes the
// magnitude instead of narrowing the entry). A conditional-width layout
// would save PW bits per entry but complicate the read port for zero
// benefit in the FF shifter; layout compression pays where entries live in
// block RAM -- see T9 (UP5K SPRAM spool) in NOVEL-ENHANCEMENTS.md.
//
// Ordering rules, all chosen deterministic:
//   i_fire && i_tick same cycle : the fire is stamped with the tick value
//     of the window that is ENDING (it fired inside that window), then the
//     counter increments. Replay reads entries oldest->newest as strictly
//     non-decreasing tick with strictly increasing arrival.
//   i_fire && i_freeze         : freeze wins, the fire is NOT recorded
//     (the gauge is held, not paused-and-queued).
//   tick counter               : free-running, wraps at 2^TICKW (TICKW=24
//     matches the AGEW convention elsewhere in the tree; wrap after 16.7M
//     ticks). Validity of the log never depends on the counter: the count
//     register gates which entries are real, and zero-filled slots decode
//     as tick-0 fires only while count says they exist.
//
// Replay contract (the T1 formal target, NOT yet proven -- sby pending):
//   from (QUF@t, log[t..t+n]) the C99 model (tools/quf.py lane) must
//   reproduce QUF@t+n byte-identical. Invariants a snaplog sby file would
//   assert: (a) entries [0..count-1] have non-decreasing tick when read
//   newest->oldest backwards, (b) o_drops == fires - DEPTH once saturated,
//   (c) freeze holds the visible window bit-stable. This file is
//   VERIFIED-FORMAL 2026-09-03: first proof run caught a real shifter
//   bug ({log[TW-1:EW], entry} overwrote in place instead of shifting;
//   readback >= 1 returned zeros under a valid count) -- fixed same day.
//   Now: snaplog.integrity (BMC30 content+order vs shadow),
//   snaplog.counters.prove (k-induction, unbounded), integrity.pdr,
//   integrity.cover all PASS. Replay-vs-C99 (the T1 target) remains
//   booked, not proven.
//
// Cost note: DEPTH entries x EW bits of flip-flops (default 16 x 45 = 720
// FF) plus a 24-bit tick counter -- a sketch-sized gauge. The FF shifter
// is honest to T1's wording; it is NOT how a depth-16K gauge would be
// built (that is T9's SPRAM backing). Cell-local, no timestamps beyond
// the tick counter, GALS-safe (local-order time reference only).
module q_snaplog #(
    parameter        PW    = 16,  // fire magnitude width
    parameter        AIDW  = 4,   // firing cell id width
    parameter        TICKW = 24,  // tick stamp width (AGEW convention)
    parameter        DEPTH = 16,  // entries retained (gauge length)
    parameter        MAG   = 1,   // 1: record fire magnitude; 0: zero it
    // derived -- do not override (fixed 4-field layout, see header)
    parameter        EW    = TICKW + 1 + AIDW + PW,
    parameter        IDXW  = (DEPTH <= 2) ? 1 : $clog2(DEPTH)
)(
    input  wire               clk,
    input  wire               rst_n,

    // fabric time reference: one strobe per completed tick
    input  wire               i_tick,

    // fire observation (the caller's notion of "a cell fired"; in
    // q_cell_core this is the eg_fire pulse entering ST_FIRE)
    input  wire               i_fire,
    input  wire [AIDW-1:0]    i_fsrc,   // firing cell id
    input  wire               i_fsign,  // sign of activation at fire
    input  wire [PW-1:0]      i_fmag,   // magnitude at fire

    // hold the gauge: stop recording (fires during freeze are dropped,
    // NOT queued -- a dial indicator lifted off the work)
    input  wire               i_freeze,

    // readout (host side, independent of recording): i_ridx 0 = NEWEST
    // retained entry, count-1 = oldest. Valid only for i_ridx < o_count.
    input  wire [IDXW-1:0]    i_ridx,
    output wire [EW-1:0]      o_rent,
    output wire [IDXW:0]      o_count,  // valid entries (saturates DEPTH)
    output wire [TICKW-1:0]   o_tick,   // current tick stamp (probe)
    output wire [TICKW-1:0]   o_drops,  // entries overwritten (audit)
    output wire               o_full
);
    localparam TW = DEPTH * EW;   // one wide shifter, T1 literally

    reg [TW-1:0]     log;
    reg [IDXW:0]     count;
    reg [TICKW-1:0]  tick;
    reg [TICKW-1:0]  drops;

    // magnitude field gate: MAG=0 records address+sign+tick only (the T1
    // minimum), with the field still allocated (fixed layout, see header)
    wire [PW-1:0]  fmag_g = (MAG != 0) ? i_fmag : {PW{1'b0}};
    wire [EW-1:0]  entry  = {tick, i_fsign, i_fsrc, fmag_g};

    wire fire_now = i_fire && !i_freeze;
    wire full     = (count == DEPTH);

    always @(posedge clk) begin
        if (!rst_n) begin
            log   <= {TW{1'b0}};
            count <= {(IDXW+1){1'b0}};
            tick  <= {TICKW{1'b0}};
            drops <= {TICKW{1'b0}};
        end else begin
            // fabric time: free-running, never frozen (the log's clock
            // reference must keep marching even while the gauge is held)
            if (i_tick)
                tick <= tick + {{(TICKW-1){1'b0}}, 1'b1};

            if (fire_now) begin
                // append at the LSB and shift the whole history DOWN by
                // one entry: new[719:45] = old[674:0]. The 2026-09-03
                // formal run (snaplog.integrity, S1) caught the original
                // {log[TW-1:EW], entry} form -- it width-checks clean but
                // leaves the upper entries IN PLACE, so readback of any
                // index >= 1 returned stale zeros while o_count claimed
                // valid entries. Not a shift; a one-entry overwrite.
                // "overflow drops oldest" -- o_drops is the audit trail
                // of exactly how much history the gauge gave up. DEPTH=1
                // degenerates to one always-replaced mark (the concat
                // form would select log[EW-1:EW], out of order).
                if (DEPTH > 1)
                    log <= {log[TW-1-EW:0], entry};
                else
                    /* verilator lint_off WIDTHEXPAND */
                    log <= entry;   // DEPTH=1: zero-pad a 1-entry gauge
                    /* verilator lint_on WIDTHEXPAND */
                if (full) begin
                    if (drops != {TICKW{1'b1}})
                        drops <= drops + {{(TICKW-1){1'b0}}, 1'b1};
                end else begin
                    count <= count + {{IDXW{1'b0}}, 1'b1};
                end
            end
        end
    end

    // readout: index 0 = newest (the entry in log[EW-1:0] after the last
    // fire). When count < DEPTH the slots above the valid window are
    // reset-state zeros -- the count register is the validity gate.
    assign o_rent  = log[i_ridx * EW +: EW];
    assign o_count = count;
    assign o_tick  = tick;
    assign o_drops = drops;
    assign o_full  = full;

endmodule
