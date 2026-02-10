# Ti:Sapphire Laser Alignment Stabilization Proposal

## Current Situation

The lab's Coherent Legend Elite regenerative amplifier is seeded by a borrowed Coherent Micra oscillator, replacing the original oscillator that broke down. A steering mirror between the Micra output and the regen seed input is mounted on a ThorLabs piezo mount (controlled by an MDT693B 3-axis piezo controller) to compensate for the geometry mismatch.

### The Problem

The laser system requires approximately 30 minutes of manual mirror alignment every morning, and periodic monitoring throughout the day. This alignment is currently performed exclusively by the PI, creating a critical bottleneck:

- **Single point of failure**: Only one person can operate the laser
- **Throughput ceiling**: Laser availability is limited by PI schedule
- **Scaling barrier**: As the lab grows and the PI takes on more responsibilities, laser uptime will decrease
- **Knowledge risk**: No student has been trained to handle the alignment

### Root Causes

1. **Daily thermal cycling**: The system is fully shut down each evening and cold-started each morning. Every cold start produces large thermal transients as the Micra cavity, piezo mount, baseplate, and optics expand unevenly.

2. **Piezo mount drift**: Piezoelectric actuators inherently suffer from hysteresis (position depends on voltage history) and creep (logarithmic drift after voltage changes). Even applying yesterday's voltage does not reproduce yesterday's position.

3. **Geometry mismatch**: The borrowed Micra is not in the same physical position as the original oscillator, so the steering mirror is compensating for a persistent offset — making it sensitive to any thermal or mechanical perturbation.

4. **No active feedback**: A ThorLabs KPA101 Position Aligner (quadrant photodetector with built-in PID) is already installed and wired to the MDT693B's external inputs, but the piezo controller is operated in INT (manual) mode rather than EXT (feedback) mode.

---

## Existing Hardware (Already In-Lab)

| Equipment | Model | Role | Status |
|-----------|-------|------|--------|
| Regen amplifier | Coherent Legend Elite | Amplification | Operational |
| Oscillator (borrowed) | Coherent Micra | Seed source | Operational but alignment-sensitive |
| Piezo controller | ThorLabs MDT693B | 3-axis mirror control | Operational, used in INT (manual) mode |
| Position aligner | ThorLabs KPA101 | Beam position QPD + PID | Installed, wired to MDT693B EXT inputs, **not in use** |

The KPA101 difference signal outputs (XDIFF, TDIFF) are already connected via BNC to the MDT693B external inputs on the X and Y axes. The hardware for closed-loop feedback is fully in place but not engaged.

---

## Proposed Solutions

### Intervention 1: Leave Verdi Pump Laser in Standby Overnight

**Rationale**: Daily full shutdown causes large thermal excursions that dominate the morning alignment problem. Leaving the Verdi pump in standby (emission off, diode and thermal systems active) maintains the Micra's thermal equilibrium overnight.

**Benefits**:
- Dramatically reduces morning alignment time (minutes instead of 30+ minutes)
- Reproducible day-to-day beam pointing
- Actually reduces equipment wear — thermal cycling stresses bonded optics, diodes, and mounts more than continuous operation
- Pump diode lifetime is better with steady-state operation than on/off cycling

**Concerns and responses**:

| Concern | Response |
|---------|----------|
| Diode lifetime | Standby mode extends diode life vs. thermal cycling. Verdi diodes rated for 10,000-20,000+ hours |
| Chiller wear | Chillers are designed for continuous operation |
| Safety | No beam is emitted in standby; same safety profile as powered-off with interlock armed |
| Power consumption | Minimal in standby mode |
| Unattended failure risk | Verdi has built-in fault protection and auto-shutdown on interlock/cooling failure |

**Cost**: None
**Effort**: Zero — change shutdown procedure
**Timeline**: Immediate
**Risk**: Easily reversible (resume daily shutdown at any time)

---

### Intervention 2: Engage KPA101 Closed-Loop Feedback (Two-Phase Startup)

**Rationale**: The KPA101 Position Aligner and MDT693B are already wired for closed-loop operation but are not being used in feedback mode. Previous attempts to use feedback may have failed because it was engaged during the large thermal transient at startup, overwhelming the servo loop.

**Proposed two-phase startup protocol**:

| Phase | Mode | Duration | Who | What happens |
|-------|------|----------|-----|-------------|
| 1. Warmup | INT (manual) | 10-15 min | Any trained student | Turn on laser, manually center beam on KPA101 using TRIM knobs. Adjust periodically as thermal drift settles. |
| 2. Lock | EXT (feedback) | 30 seconds | Any trained student | Once drift has slowed, verify beam is centered on KPA101 display, switch X and Y axes from INT to EXT. Servo maintains alignment. |

**PID tuning procedure** (one-time setup):
1. Manually align beam to center of KPA101 in INT mode (system thermally stable)
2. Open ThorLabs Kinesis software, connect to KPA101
3. Start with low proportional gain, zero integral and derivative
4. Switch one axis to EXT, observe response
5. Gradually increase P gain until beam position is actively corrected without oscillation
6. Add small integral gain to eliminate steady-state offset
7. Repeat for second axis
8. Save PID parameters to KPA101

**Why it may have failed before**:

| Possible failure mode | Symptom PI would have seen | Fix |
|----------------------|---------------------------|-----|
| Feedback engaged during warmup (large thermal transient) | Beam walks off QPD, servo saturates | Use two-phase startup; engage feedback only after warmup |
| PID gain too high | Beam oscillates, then drifts off | Reduce proportional gain, tune systematically via Kinesis software |
| PID gain too low | Slow drift not corrected fast enough | Increase gain incrementally |
| Wrong sign on one axis | Beam pushed away from center (positive feedback) | Swap polarity in KPA101 settings or swap BNC connections |
| Piezo voltage at rail | MDT693B saturates at 0V or 150V, can't correct further | Center the TRIM voltage near midrange before engaging feedback |

**Cost**: None (hardware already installed)
**Effort**: 2-4 hours for PID tuning and testing
**Timeline**: 1 day
**Risk**: None — switch back to INT mode at any time

---

### Intervention 3: Proper Optical Realignment with High-Stability Mount

**Rationale**: The current piezo mount is compensating for a geometry mismatch between the borrowed Micra and the original oscillator position. Properly aligning the Micra-to-regen beam path and using a high-stability kinematic mount (e.g., ThorLabs Polaris series) would reduce or eliminate the need for active correction.

**What this involves**:
- Characterize the beam height and angle the regen expects from its seed
- Realign the Micra output path to match, using proper beam-walking technique
- Replace the piezo steering mirror with a Polaris or equivalent low-drift kinematic mount
- The piezo + KPA101 can remain as a secondary correction if needed

**Cost**: ~$500 (Polaris mount + any additional optics/posts)
**Effort**: Full day of alignment work
**Timeline**: 1-2 days including testing
**Risk**: Low — improves baseline stability regardless of other interventions

---

### Intervention 4: Repair or Replace Original Oscillator

**Rationale**: The borrowed Micra is a temporary solution. Repairing the original oscillator or procuring a proper replacement eliminates the geometry mismatch entirely.

**Options**:

| Option | Estimated Cost | Timeline | Notes |
|--------|---------------|----------|-------|
| Repair original oscillator (Coherent service) | $5,000-30,000 | 2-8 weeks | Depends on what failed; get a quote |
| Purchase used Micra/Vitara | $30,000-80,000 | Varies | Check eBay, used laser dealers |
| New turnkey oscillator (Vitara or equivalent) | $100,000-200,000 | 3-6 months | Major capital equipment request |
| Fiber-based seed oscillator | $50,000-100,000 | 2-4 months | More stable, lower maintenance, modern approach |

**Cost**: Significant capital expense
**Effort**: Procurement process + installation
**Timeline**: Weeks to months
**Risk**: Standard equipment procurement

---

## Recommended Implementation Order

| Priority | Intervention | Cost | Time | Impact |
|----------|-------------|------|------|--------|
| 1 | Leave Verdi in standby overnight | $0 | Immediate | Eliminates largest source of daily drift |
| 2 | Engage KPA101 feedback (two-phase startup) | $0 | 1 day | Automates intra-day alignment maintenance |
| 3 | Proper realignment + stable mount | ~$500 | 1-2 days | Reduces baseline drift, less demand on feedback |
| 4 | Repair/replace original oscillator | $5,000+ | Weeks+ | Permanent fix (budget-dependent) |

**Interventions 1 and 2 alone** would likely reduce the PI's daily involvement from 30+ minutes of active alignment plus periodic monitoring to near zero — at zero cost with hardware already in the lab.

---

## Impact on Lab Productivity

### Current State
- Laser availability gated by PI schedule
- ~30 min/day of PI time on alignment + periodic monitoring
- Students cannot start experiments independently
- Long commutes and increasing PI responsibilities reduce available laser time

### After Interventions 1+2
- Any trained student can perform the 10-15 minute warmup in INT mode
- Feedback servo handles all subsequent drift automatically
- PI involvement only needed for troubleshooting or major realignment
- Laser uptime limited by experiment schedule, not personnel availability

### Student Training Requirements

| Task | Current | After implementation |
|------|---------|---------------------|
| Turn on laser and pump | PI only | Any trained student |
| Morning alignment (warmup) | PI only (30+ min) | Any trained student (10-15 min with TRIM knobs) |
| Engage feedback | N/A | Any trained student (flip switch) |
| Intra-day monitoring | PI (periodic) | Automated (KPA101 servo) |
| Troubleshooting | PI only | PI only (unchanged) |
| Major realignment | PI only | PI only (unchanged) |

---

## Proposed Next Steps

1. **Discuss standby operation**: Confirm there are no safety or institutional policies preventing overnight standby. If not, trial it for one week and compare morning alignment times.

2. **PID tuning session**: Spend one afternoon tuning the KPA101 feedback using the Kinesis software. Document the optimal parameters.

3. **Write startup SOP**: Document the two-phase startup procedure so any trained student can follow it.

4. **Trial period**: Run for 1-2 weeks with the new procedure, logging alignment time and laser stability. Present data to confirm improvement.

5. **Evaluate further investment**: Based on results, decide whether a Polaris mount or oscillator repair/replacement is warranted.
