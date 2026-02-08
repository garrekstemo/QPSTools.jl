# Quantum Photo-Science Laboratory Transformation Assessment

**Date**: January 31, 2026  
**Current Structure**: Traditional Japanese Kōza system  
**Goal**: Transform to high-output research pipeline  

---

## Executive Summary

**The Problem**: Our lab operates on a linear, serial research model where PhD students collect data for 2+ years before writing, creating bottlenecks, lost institutional knowledge, and slow publication cycles. We cannot respond quickly to opportunities like special issue calls.

**The Vision**: Transform to a parallel pipeline system where research groups work in vertical squads, manuscripts are living documents, and knowledge is systematically captured and shared.

---

## Current State Analysis

### Lab Demographics & Structure
- **Staff**: 2 (PI + Assistant Professor)
- **Students**: 12 total per year
  - 4 M1 (1st year Masters)
  - 4 M2 (2nd year Masters) 
  - 4 PhD students
- **Student Lifecycle**: 
  - M1 → M2 (2 years total)
  - PhD (typically 3+ years)
  - High turnover with Masters graduation

### Research Areas
**1. Ultrafast spectroscopy of vibrational strong coupling in liquid phase**
- Status: Most mature (Garrek's original masters/PhD work)
- Readiness: High for squad formation

**2. Ultrafast spectroscopy of 2D materials (TMDC) -- eventually in cavities**
- Status: Struggling to get off the ground but slowly progressing
- Ownership: PI's project
- Challenge: Getting momentum

**3. Exciton polaritons in dyes**
- Status: PI's newer project
- Context: Collaboration at university
- Readiness: TBD

**4. Optical properties of metal organic framework glasses (MOF) -- ZIF-62**
- Status: Garrek's new project
- Current: One student assigned
- Readiness: Early stage

### Equipment & Technique Overlap
**Major Equipment:**
- **Ti:sapphire laser/OPA**: Workhorse for exciton + MIR ultrafast research (Projects 1 & 3)
  - *Issue: Obtained used, consistently has problems*
- **MIRA 900 ultrafast laser**: Higher rep rate, dedicated to TMDC work (Project 2)
- **Tabletop spectrometers**: FTIR, UV-vis, USB spectrometers (shared across projects)

**Natural Equipment Groupings:**
- Projects 1 & 3: Share Ti:sapp/OPA system
- Project 2: Standalone MIRA system
- Project 4: Likely uses tabletop characterization tools

**Analysis & Software:**
- **Transition: Igor Pro → Julia** (Garrek-led improvement)
- **Current benefit**: Everyone helps each other with coding, better figures (less Excel)
- **Current inefficiency**: Everyone still codes from scratch despite similar needs
- **Automation opportunity**: Standardize common analysis tools

**Theoretical Framework Overlap:**
- **High similarity**: All projects use similar spectroscopy analysis
- **Common tasks**: Curve fitting, peak analysis (standard spectroscopy)
- **Exception**: One PhD doing more advanced analysis

### Student Overlap Potential
**High overlap potential (~80-90% of students)**
- **Core commonality**: All doing spectroscopy, just different wavelengths
- **Skill transferability**: "Everyone should know how to do everyone else's project if we were more efficient"
- **Successful collaboration example**: PhD + M2 worked together on VSC problem, then separated to individual projects
- **Differentiation**: Sample-specific expertise (not fundamental technique differences)

### Data & Publication Status
**Major bottleneck identified**: 
- **No orphan datasets available for satellite papers**
- **High-risk model**: If student isn't getting good data, there's no fallback
- **Result**: "Nail-biting" situation with potential for complete project failure

### Equipment Bottlenecks
**Most contested equipment**: Ti:sapphire laser/OPA
- **Users**: Projects 1 & 3 students (VSC + exciton polaritons)
- **Problem**: Used equipment with consistent reliability issues
- **Impact**: Creates scheduling conflicts and unpredictable downtime

**Secondary bottleneck**: FTIR
- **Demand**: High across multiple projects
- **Mitigation**: Not complicated to operate, so scheduling manageable

### Experiment Operator Requirements
**Current state**: All experiments basically require an operator
- **High labor intensity**: No autonomous experiments currently
- **Student time commitment**: Full operator attention needed

**Automation opportunity identified**: 
- **Target**: MIR pump probe setup (Project 1 - VSC)
- **Concept**: AI + automatic analysis integration
- **Potential impact**: Automate most/all data collection for most mature project

### Major Failure Points & Timeline Impact
**Biggest bottleneck**: TMDC fabrication (Project 2)
- **Duration**: Years of failed attempts
- **Resources wasted**: Multiple students + collaborators
- **Ownership issue**: PI's project, Garrek lacks time to fix
- **Recent breakthrough**: New student with TMDC background + progress-oriented mindset finally making progress
- **Key insight**: Student mindset/background matters significantly for project success

## STUDENT DEVELOPMENT ECOSYSTEM

### Learning Curves & Skill Transfer

**Current M1 learning bottlenecks** (in order of urgency):
1. **Theoretical understanding** - BIGGEST CURRENT PROBLEM
   - Status: "Very few obtain until writing thesis at end"
   - Impact: Students operate experiments without understanding
   - Priority: "This must change"

2. **Data analysis** - IMPROVED & AUTOMATABLE
   - Status: Better now with Julia transition
   - Future: Can be further automated

3. **Experimental technique** - MUCH IMPROVED
   - Status: Much better with tutorials + peer help
   - Success factor: Systematic training + collaboration

### Knowledge Transfer & Institutional Memory

**Historical problem**: Project knowledge lost when students graduate
- **Traditional issue**: Whatever project was done by previous student gets lost
- **Exception**: Knowledge gained through tutorials persists

**Recent improvements** (last year):
- **Hand-off procedure implemented**: Modest but effective
- **Cross-year collaboration**: M1 and M2 students working together
- **Result**: Knowledge loss reduced but still needs improvement

**Current biggest loss**: Theoretical knowledge
- **Issue**: Deep understanding of physics/theory disappears with graduates
- **Impact**: New students start from theoretical ground zero each time

### Current Squad Leadership Potential

**Strong potential leaders**:
1. **Outstanding PhD (VSC project)**
   - Language: English speaker, teaches with Japanese help from others
   - Leadership: Natural mentor despite language barrier

2. **TMDC PhD student** 
   - Personality: Natural leader, assertive
   - Constraint: Project struggles have limited her knowledge development

3. **Current M2 cohort**
   - Strength: Very good at collaborating and helping each other
   - Group dynamics: Strong peer-to-peer support

**Current M1 concerns**:
- **Two outstanding students**: Will surpass M2s (one continuing to PhD - 5 years)
- **Unmotivated student**: Attendance improved after PhD accountability intervention
- **Anxious student**: Social anxiety + 1-hour commute + new driver affecting lab presence
  - Note: Enthusiastic about work but logistical/social barriers

## OPERATIONAL EFFICIENCY MICROSCOPE

### Time & Energy Drains

**Garrek's current time allocation** (biggest bottlenecks):
1. **Heavy manuscript lifting** - even for best PhD student
   - Reasons: Faster at programming, reading articles, data interpretation, writing
   - Example: Currently doing heavy lifting on manuscript despite good student
   - Constraint: Paper needs to get out, so doing it personally for speed

2. **Unblocking students** - biggest operational hurdle
   - Pattern: Equipment working smoothly = not needed
   - Problem: Any hiccup = immediate intervention required

**Critical insight**: Speed multipliers available but not distributed
- **Claude access**: Massive speed advantage for Garrek's work
- **Theoretical capability**: "Could do everyone's analysis and be a one-man lab faster than everyone else"
- **Imperative identified**: "Automation and greater student independence is imperative!"

**Absurd resource allocation**: PI running Ti:sapphire laser
- **Problem**: Highest-level person doing technical operation
- **Impact**: Massive inefficiency in expertise deployment

### Reinvention vs. Building on Existing Work

**Historical pattern**: PI had students reinvent basically everything
- **Current intervention**: Garrek jumps in when this starts happening
- **Questions used**: "Does it really need to be done? Timeline? Has someone done this before? What's the plan?"
- **Result**: Happens less but still occurs

**Coding inefficiency**:
- **Quantification challenge**: Hard to measure (can't see everyone's computers)
- **Student capability**: Good coders don't struggle with technical implementation
- **Real problem**: "Hard time applying analysis to it" 
- **Assessment**: "Still one of the biggest bottlenecks"

### Information & Decision Flow

**Project ownership structure**:
- **Garrek's projects**: Brand new (second year as assistant prof)
- **PI's projects**: Most of the students
- **Cross-pollination**: Garrek heavily interacts with VSC team

**Student autonomy evolution**:
- **Previous state**: Students "didn't even know what they were doing -- just going through motions"
- **Current state**: "Students better at asking questions now"
- **Collaboration improvement**: Now collaborating whereas before they weren't
- **Remaining gap**: "Would like students to work together more, but they lack knowledge still"

**Decision-making constraint**: Limited by student theoretical understanding

## EXTERNAL ECOSYSTEM

### University & Cultural Context

**Japanese lab system benefits**:
- **Pursuit of perfection**: Cultural emphasis on quality and thoroughness
- **Funding stability**: Don't have to worry about funding (even though brings in own grants)
- **Shared mentoring burden**: Can distribute student supervision responsibilities
- **Language dynamics**: Usually 2-3 English speaking students; Japanese M1s typically have limited English initially
- **Cultural blindness**: Garrek notes he may not recognize uniquely Japanese aspects due to immersion

**Constraint acknowledgment**: Need outside perspective to identify what should be preserved vs. changed

### Outside Perspective

**Management consultant assessment**: Biggest inefficiency would be "doing so much from scratch"
- **Problem**: Almost zero standardization or automation
- **Exception**: Garrek standardized the onboarding process
- **Opportunity**: Scale the onboarding standardization approach to all lab operations

### Current Workflow Problems
1. **Linear Data Collection Model**
   - Students collect data for 2+ years before writing
   - High risk: if story doesn't work after 24 months, student is stuck
   - No output for 2 years of funding per project

2. **Knowledge Transfer Issues**
   - Oral tradition for procedures
   - Lost expertise when students graduate
   - Each new student "reinvents the wheel"

3. **Lack of Collaboration**
   - Students work in silos
   - No cross-year mentoring
   - Limited equipment sharing strategies

4. **Publication Pipeline**
   - "Big fish" paper approach (one major paper per PhD)
   - No modular/satellite publications
   - Cannot respond to special issue deadlines

### Cultural Factors (Japanese Academic Context)
- **Shokunin mentality**: Process mastery before output
- **Hierarchical information flow**: Student → Assistant Prof → PI
- **Thesis-focused**: Paper seen as afterthought to thesis
- **Risk aversion**: Preference for "complete" over "iterative" work

---

## Assessment Questions Framework

### RESEARCH ECOSYSTEM
*[Detailed answers needed below]*

### STUDENT DEVELOPMENT & MENTORING
*[Detailed answers needed below]*

### OPERATIONAL EFFICIENCY
*[Detailed answers needed below]*

### CULTURAL & SYSTEMIC BARRIERS
*[Detailed answers needed below]*

### EXTERNAL CONSTRAINTS
*[Detailed answers needed below]*

---

## Success Metrics (To Be Defined)

### Quantitative Goals
- [ ] Papers per year: Current ___ → Target ___
- [ ] Student graduation timeline: Current ___ → Target ___
- [ ] Time to first publication per student: Current ___ → Target ___
- [ ] Response time to opportunities (special issues): Current ___ → Target ___

### Qualitative Goals
- [ ] Improved knowledge retention in lab
- [ ] Better student collaboration and mentoring
- [ ] Reduced assistant professor bottleneck
- [ ] Enhanced research agility and responsiveness

---

## Next Steps
1. Complete detailed assessment questionnaire
2. Map current research themes to potential vertical squads
3. Identify pilot transformation areas
4. Design implementation timeline
5. Create new lab operating procedures

---

*This document will be continuously updated as we gather more information and develop the transformation plan.*