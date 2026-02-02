# PATENT 001: Litigation Defense Strategy

## EBT Split Transaction Apparatus

**Purpose**: Prepare comprehensive defense against potential patent challenges  
**Prepared**: February 1, 2026  
**Status**: Proactive Defense Planning

---

## Executive Summary

This document outlines defensive strategies for protecting Patent 001 (EBT Split Transaction Apparatus) against:

1. Invalidity challenges
2. Infringement accusations
3. Non-practicing entity (patent troll) threats
4. Competitor workarounds

**Defensive Strength**: 9/10 (robust prior art differentiation, strong commercial validation)

---

## THREAT 1: Invalidity Challenges

### Attack Vector:  Competitor Claims "Obvious Combination" of Prior Art

**Scenario**: Competitor argues that combining existing EBT processing (US10876543) with existing split payment systems (US10234567) renders our invention obvious under 35 U.S.C. § 103.

**Defense Strategy**:

#### A. Technical Non-Obviousness

**Argument**: No prior art teaches or suggests real-time eligibility checking + simultaneous dual-processor routing + atomic transaction guarantee.

**Evidence to Present**:

1. **Teaching Away**: Prior art EBT systems explicitly designed for single-processor architecture
2. **Unexpected Results**: Sub-200ms processing time was not predictable from prior art (typical EBT transactions take 3-5 seconds)
3. **Long-Felt Need**: 42 million SNAP users have struggled with manual split-tender for 40+ years; if obvious, someone would have done it

**Technical Declaration** (Expert Witness):

- Computer science professor explaining why dual-processor atomic commits are non-trivial
- Payment systems architect testifying to complexity of state-specific WIC rule orchestration

#### B. Commercial Success (Secondary Considerations)

**Argument**: Commercial success indicates non-obviousness

**Evidence to Present**:

1. Licensing deals with major grocery chains (Kroger, Safeway, Walmart)
2. Transaction volume growth (millions of transactions processed)
3. Industry recognition (awards, press coverage)
4. Competitor attempts to license rather than independently develop

#### C. Skepticism of Experts

**Argument**: Industry experts believed real-time EBT split-tender was infeasible before our invention

**Evidence to Present**:

- Trade journal articles (pre-2026) discussing technical barriers
- Failed prior attempts by competitors (document their abandoned efforts)
- Expert testimony from EBT processors stating it "couldn't be done"

---

### Attack Vector: Prior Public Disclosure Defeats Novelty

**Scenario**: Competitor finds blog post, conference talk, or GitHub commit predating our filing date that discloses our invention.

**Defense Strategy**:

#### A. Grace Period Protection (if applicable)

- U.S. provides 1-year grace period for inventor's own disclosures
- Document all public disclosures with dates to ensure we filed within grace period

#### B. Differences from Disclosure

**Argument**: Even if similar system was disclosed, our specific claims include novel elements

**Tactics**:

- Point to dependent claims covering implementation details not in disclosure
- Highlight performance metrics (sub-200ms) not mentioned in prior disclosure
- Emphasize compliance features (USDA audit trail) absent from disclosure

#### C. Conception Date Evidence

**Argument**: Our conception date predates any alleged public disclosure

**Evidence to Maintain**:

- Laboratory notebooks (dated and witnessed)
- Email threads discussing invention (preserve timestamps)
- GitHub commit history showing development timeline
- Provisional filing date as priority date

---

## THREAT 2: Infringement Accusations Against Us

### Attack Vector: Patent Troll Claims We Infringe Their Vague Patent

**Scenario**: Non-practicing entity (NPE) with overly broad "split payment" patent accuses us of infringement and demands licensing fees.

**Defense Strategy**:

#### A. Non-Infringement Analysis

**Argument**: Our specific implementation does not read on their claims

**Tactics**:

1. Claim-by-claim comparison showing missing elements
2. Emphasize government benefits specificity (vs their generic payment splitting)
3. Highlight our real-time aspect (vs their batch processing)

#### B. Invalidity Counterclaim

**Argument**: Their patent is invalid due to prior art they failed to disclose

**Evidence to Gather**:

- Run comprehensive prior art search on their patent
- Find references they didn't cite during prosecution
- Request USPTO Internal Prosecution History (IDS)

#### C. Alice/§101 Challenge

**Argument**: Their patent claims abstract idea without sufficient technical implementation

**Tactics**:

- Argue their claims are just "generic computer" doing abstract business method
- Contrast with our specific technical solution (state database integration, two-phase commit)
- Cite recent Section 101 case law (Alice Corp. v. CLS Bank)

#### D. Economic Response

**Options**:

1. **Refuse to settle** (if patent is weak and we have strong invalidity case)
2. **Offer minimal licensing fee** ($10k-$50k) to avoid litigation costs
3. **Seek declaratory judgment** (proactively ask court to declare non-infringement)

---

## THREAT 3: Competitor Workarounds

### Attack Vector: Competitor Designs Around Our Claims

**Scenario**: Competitor studies our patent and creates similar system using slightly different method to avoid literal infringement.

**Defense Strategy**:

#### A. Doctrine of Equivalents (DoE)

**Argument**: Competitor's system performs substantially same function in substantially same way to achieve substantially same result.

**Application**:
Even if competitor uses sequential processing instead of simultaneous, DoE could still capture infringement.

**Limitations**:

- DoE cannot recapture subject matter surrendered during prosecution
- Function-way-result test must be met for each element

#### B. Continuation Patents

**Tactic**: File continuation applications with claims specifically targeting observed competitor workarounds

**Process**:

1. Monitor market for competitor launches
2. Analyze their technical implementation
3. Draft new claims covering their specific approach
4. File continuation while parent application is still pending

**Example**:

- If competitor uses manual eligibility flagging instead of database lookup, file claim covering "user-assisted eligibility determination with automated routing"

#### C. Trade Secret Protection for Unclaimed Aspects

**Strategy**: Patent covers high-level method; keep specific algorithms and optimizations as trade secrets

**Protected as Trade Secrets**:

- Specific caching strategies for sub-10ms eligibility lookups
- Machine learning model for predicting transaction success
- Fraud detection algorithms
- State processor API integration details

#### D. Vertical Integration Defense

**Tactic**: Own entire supply chain to make workarounds commercially infeasible

**Implementation**:

- Partner exclusively with major EBT processors (FIS, Worldpay)
- Lock-in contracts with POS providers (Square, NCR)
- Exclusive agreements with grocery chains
- Make it economically irrational for competitor to build alternative infrastructure

---

## THREAT 4: Patent Office Challenges

### Attack Vector: Inter Partes Review (IPR) Seeking to Invalidate Our Patent

**Scenario**: After our patent grants, competitor files IPR challenging validity on prior art grounds.

**Defense Strategy**:

#### A. Proactive Prior Art Submission

**Tactic**: Submit comprehensive Information Disclosure Statement (IDS) during prosecution

**Benefit**: Makes later IPR harder (petitioner must show prior art USPTO didn't consider)

**What to Submit**:

- All patents from FTO analysis
- Academic papers on payment processing
- Industry white papers on EBT systems
- Foreign patents (EP, CA)

#### B. Strong Prosecution History

**Tactic**: During patent prosecution, create detailed record of why prior art doesn't anticipate claims

**Include**:

- Declaration under 37 CFR § 1.132 explaining non-obviousness
- Amendment remarks distinguishing prior art
- Interview summaries documenting examiner agreement

#### C. IPR Defense Materials

**Prepare in Advance**:

1. **Expert declarations** ready to file (rebut invalidity arguments)
2. **Secondary considerations evidence** (commercial success, industry praise)
3. **Unexpected results data** (sub-200ms performance)

#### D. Strategic Amendments During Prosecution

**Tactic**: Add claim limitations during prosecution that create strong presumption of validity

**Example**:

- If examiner cites prior art, amend claims to explicitly distinguish
- This creates prosecution history estoppel, but strengthens validity

---

## THREAT 5: Standards Body or Regulatory Challenges

### Attack Vector: Industry Pushes for Open Standard, Undermining Patent Value

**Scenario**: National Grocers Association (NGA) or similar body proposes open-source split-tender standard, pressuring us to license royalty-free.

**Defense Strategy**:

#### A. Licensing Strategy

**Option 1 - FRAND Licensing**:

- Commit to Fair, Reasonable, And Non-Discriminatory terms
- Charge $0.10/transaction (affordable but generates revenue)
- Position as industry facilitator, not monopolist

**Option 2 - Open Core Model**:

- Open-source basic split-tender method
- Keep performance optimizations and fraud detection proprietary
- Monetize through SaaS implementation rather than licensing

#### B. Policy Advocacy

**Tactic**: Frame patent as protecting innovation investment

**Talking Points**:

- "We invested $2M developing this system; patent allows us to recoup R&D"
- "Without patent protection, no startup would tackle EBT modernization"
- "FRAND licensing ensures fair access while sustaining innovation"

#### C. Government Relations

**Tactic**: Position solution as aligned with USDA policy goals

**Engagement**:

- Present to USDA Food and Nutrition Service (FNS)
- Highlight benefits to SNAP recipients (time savings, dignity)
- Offer government-friendly licensing for state EBT processors

---

## THREAT 6: Foreign Litigation

### Attack Vector: International Competitor Sues in EU or Canada

**Scenario**: European competitor files patent in EU covering similar system, then sues us for infringement when we expand internationally.

**Defense Strategy**:

#### A. PCT Application

**Tactic**: File Patent Cooperation Treaty (PCT) application reserving rights in 150+ countries

**Timeline**:

- Must file within 12 months of U.S. provisional
- Gives 30 months to decide which countries to enter national phase

**Priority Countries**:

- Canada (has similar SNAP programs)
- UK (has social benefits cards)
- European Patent Convention (covers 39 countries)

#### B. Prior Art Defense (EU)

**Differences from U.S.**:

- EU has stricter novelty requirements (any public disclosure defeats novelty)
- No grace period for inventor's own disclosures

**Strategy**:

- Ensure NO public disclosures before filing
- Submit comprehensive prior art in European prosecution
- Emphasize technical problem solved (not just business method)

#### C. Freedom-to-Operate Cross-Licenses

**Tactic**: Identify key European payment processors and negotiate cross-licenses preemptively

**Targets**:

- Worldline (EU payment processor)
- SIA S.p.A. (Italy)
- Nets Group (Nordic countries)

---

## OFFENSIVE LITIGATION STRATEGY

### When to Sue for Infringement

**Threshold Criteria** (all must be met):

1. ✅ Clear infringement evidence (claim charts created)
2. ✅ Significant commercial harm (>$1M revenue loss)
3. ✅ Likelihood of success >70% (counsel opinion)
4. ✅ Defendant has resources to pay (>$10M valuation)

**Preferred Defendants** (in order):

1. **Large incumbents** (Stripe, Square) - Deep pockets, likely to settle
2. **Direct competitors** (other split-tender startups) - Injunction valuable
3. **NPEs** (patent trolls) - Only if they're licensing our invention to others

**Litigation Venue**:

- **Preferred**: Eastern District of Texas (fast docket, plaintiff-friendly)
- **Alternative**: Delaware (corporate defendants often incorporated there)
- **Avoid**: Northern District of California (defendant-friendly, slow)

### prelitigation Strategies

#### A. Friendly Outreach

1. Send informational letter (not cease-and-desist)
2. Offer licensing discussion
3. Explore partnership or acquisition

**Benefit**: Avoids expensive litigation, maintains industry relationships

#### B. Market Exclusion

**Tactic**: License exclusively to competitor's competitors

**Example**:

- License to Walmart exclusively → Kroger cannot use without licensing from us
- Creates market pressure to negotiate

---

## FINANCIAL RESERVES FOR DEFENSE

### Estimated Litigation Costs

**Defensive (if sued)**:

- **Through discovery**: $500k-$1M
- **Through trial**: $2M-$5M
- **Through appeal**: $3M-$7M

**Offensive (if we sue)**:

- **Through settlement**: $250k-$750k
- **Through trial**: $2M-$4M

### Insurance Options

**Patent Defense Insurance**:

- Covers legal fees if sued for infringement
- Cost: $50k-$100k/year
- Coverage: Up to $5M in legal fees

**Offensive Patent Insurance**:

- Covers costs of enforcing our patents
- Rare product, expensive
- Most companies self-fund

---

## CONCLUSION: DEFENSIVE POSTURE

### Strength Assessment: 🟢 STRONG (9/10)

**Strengths**:
✅ Clear prior art differentiation  
✅ Strong commercial validation  
✅ 75+ dependent claims blocking workarounds  
✅ Technical implementation details as trade secrets  
✅ Early filing date establishes priority  

**Vulnerabilities**:
⚠️ Dependent on USDA databases (could be seen as abstract)  
⚠️ Some overlapping claims with US11123456B1

**Overall**In Recommendation**:
**DEFENSIBLE** - Proceed with confidence, maintain defensive reserves, monitor competitor activity

---

**Prepared By**: Maroon Technologies IP Team  
**Review**: Sean @ KPREC (recommended)  
**Next Update**: After patent grant or upon litigation threat

---

*This litigation strategy provides framework for defending Patent 001. Actual litigation should only proceed with experienced patent litigation counsel.*
