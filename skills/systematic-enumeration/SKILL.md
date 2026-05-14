---
name: Systematic Enumeration
description: Forces element-by-element verification for finite sets to prevent counting errors.
version: 1.0
user-invocable: true
disable-model-invocation: false
---

# Systematic Enumeration & Verification Skill

## **Objective**
To eliminate heuristic errors and "hallucinated patterns" when analyzing finite sets. This protocol overrides the model's tendency toward "holistic recognition" in favor of systematic, element-by-element verification.

## **Execution Protocol**
When this skill is triggered, you MUST NOT provide a direct answer immediately. Follow these three phases to ensure accuracy:

### **Phase 1: Set Definition**
Explicitly define the boundaries and members of the finite set being analyzed. 
*   **Requirement:** List the members before performing any tests.
*   *Example:* "The set consists of the files in the `/src` directory: [main.rs, utils.rs, types.rs]."

### **Phase 2: Atomic Element Testing (O(n))**
Iterate through every item in the set. For each item, perform a literal check against the target property.
*   **Format:** Use a list or table to force token-level focus on each element.
*   **Structure:** `[Item] -> [Logic/Observation] -> [Boolean Result]`
*   *Note:* For character-based tests, split the string into individual characters to bypass tokenization bias.

### **Phase 3: Reduction & Summation**
Aggregate the `True` results from Phase 2 to derive the final answer.
*   **Self-Correction:** Verify that the count of items tested in Phase 2 exactly matches the count of the set defined in Phase 1. If there is a mismatch, restart Phase 2.

## **Constraints & Anti-Patterns**
*   **STRICT BAN on Heuristics:** Do not use phrases like "typically," "usually," or "it appears that."
*   **NO Pattern Matching:** Do not extrapolate a rule (e.g., "every other item") as a substitute for testing every item.
*   **Computational Justification:** Treat the process as an $O(n)$ operation where $n$ is small enough that accuracy is the only priority.

## **Trigger Scenarios**
*   Counting specific characters or substrings within a string.
*   Verifying property adherence across a list of variables, files, or objects.
*   Membership testing in sets where false negatives are high-risk.
